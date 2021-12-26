resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  vpc_id = var.vpc_id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }
}

resource "aws_security_group" "worker_group_mgmt_two" {
  name_prefix = "worker_group_mgmt_two"
  vpc_id = var.vpc_id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"

    cidr_blocks = [
      "192.168.0.0/16",
    ]
  }
}

resource "aws_security_group" "all_worker_mgmt" {
  name_prefix = "all_worker_management"
  vpc_id = var.vpc_id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }
}

module "eks" {
  source = "terraform-aws-modules/eks/aws"
  cluster_name = var.cluster_name
  cluster_version = "1.21"
  subnets = var.private_subnets
  enable_irsa = true
  write_kubeconfig = false

  tags = {
    Environment = "training"
    GithubRepo = "terraform-aws-eks"
    GithubOrg = "terraform-aws-modules"
  }

  vpc_id = var.vpc_id

  workers_group_defaults = {
    root_volume_type = "gp2"
  }

  worker_groups = [
    {
      name = "worker-group-1"
      instance_type = "t2.small"
      asg_desired_capacity = 2
      # additional_security_group_ids = [
        # aws_security_group.worker_group_mgmt_one.id, var.rds-sg.id]
    },
    {
      name = "worker-group-2"
      instance_type = "t2.small"
      # additional_security_group_ids = [
        # aws_security_group.worker_group_mgmt_two.id,var.rds-sg.id]
      asg_desired_capacity = 1
    },
  ]
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity"]
    effect = "Allow"

    condition {
      test = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values = [
        "system:serviceaccount:default:secrets-sa"]
    }

    principals {
      identifiers = [
        module.eks.oidc_provider_arn]
      type = "Federated"
    }
  }
}

resource "aws_iam_role" "assume_role" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  name = "assume-role-${var.cluster_name}"
}

resource "aws_iam_policy" "policy" {
  name = "aws-secrets-manager-policy-${var.cluster_name}"
  description = "A test policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
    "Statement": [ {
        "Effect": "Allow",
        "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
        "Resource": ["arn:*:secretsmanager:*:*:secret:*"]
    } ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role = aws_iam_role.assume_role.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "kubernetes_service_account" "this" {
  metadata {
    name = "secrets-sa"
    namespace = "default"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.assume_role.arn
    }
  }
  automount_service_account_token = true
}

resource "helm_release" "secrets-store-csi-driver" {
  name = "secrets-store-csi-driver"
  chart = "secrets-store-csi-driver"
  repository = "https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/master/charts"
  namespace = "kube-system"

  set {
    name = "syncSecret.enabled"
    value = "true"
  }
  set {
    name = "provider"
    value = "aws"
  }
}

data "local_file" "foo" {
  filename = "${path.module}/aws-secrets-provider-install.yaml"
}

resource "kubectl_manifest" "aws-secrets-provider-install" {
  yaml_body = <<YAML
  # https://kubernetes.io/docs/reference/access-authn-authz/rbac
apiVersion: v1
kind: ServiceAccount
metadata:
  name: csi-secrets-store-provider-aws
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: csi-secrets-store-provider-aws-cluster-role
rules:
- apiGroups: [""]
  resources: ["serviceaccounts/token"]
  verbs: ["create"]
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["get"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: csi-secrets-store-provider-aws-cluster-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: csi-secrets-store-provider-aws-cluster-role
subjects:
- kind: ServiceAccount
  name: csi-secrets-store-provider-aws
  namespace: kube-system
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  namespace: kube-system
  name: csi-secrets-store-provider-aws
  labels:
    app: csi-secrets-store-provider-aws
spec:
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: csi-secrets-store-provider-aws
  template:
    metadata:
      labels:
        app: csi-secrets-store-provider-aws
    spec:
      serviceAccountName: csi-secrets-store-provider-aws
      hostNetwork: true
      containers:
        - name: provider-aws-installer
          image: public.ecr.aws/aws-secrets-manager/secrets-store-csi-driver-provider-aws:1.0.r1-10-g1942553-2021.06.04.00.07-linux-amd64
          imagePullPolicy: Always
          args:
              - --provider-volume=/etc/kubernetes/secrets-store-csi-providers
          resources:
            requests:
              cpu: 50m
              memory: 100Mi
            limits:
              cpu: 50m
              memory: 100Mi
          volumeMounts:
            - mountPath: "/etc/kubernetes/secrets-store-csi-providers"
              name: providervol
            - name: mountpoint-dir
              mountPath: /var/lib/kubelet/pods
              mountPropagation: HostToContainer
      volumes:
        - name: providervol
          hostPath:
            path: "/etc/kubernetes/secrets-store-csi-providers"
        - name: mountpoint-dir
          hostPath:
            path: /var/lib/kubelet/pods
            type: DirectoryOrCreate
      nodeSelector:
        kubernetes.io/os: linux
YAML
}