
data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.66.0"

  name                 = var.vpc_name
  cidr                 = var.vpc_cidr
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = var.private_subnets_cidr
  public_subnets       = var.public_subnets_cidr
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

# # Security Group for RDS
# resource "aws_security_group" "rds-sg" {
#   name        = "rds-db-sg-${var.suffix}"
#   description = "security group for webservers"
#   vpc_id      = module.vpc.vpc_id


#   # Allowing traffic only for Postgres and that too from same VPC only.
#   ingress {
#     description = "postgres"
#     from_port   = 5432
#     to_port     = 5432
#     protocol    = "tcp"
#     cidr_blocks = var.private_subnets_cidr
#   }


#   # Allowing all outbound traffic
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Environment = var.environment
#     Name = "rds sg"
#   }
# }

# resource "aws_db_subnet_group" "default" {
#   name       = "main"
#   subnet_ids = module.vpc.private_subnets

#   tags = {
#     Name = "My DB subnet group"
#   }
# }