resource "random_string" "suffix" {
  length = 8
  special = false
}

locals {
  suffix = random_string.suffix.result
  cluster_name = "kr-${var.environment}-eks-${random_string.suffix.result}"
  vpc_name = "kr-${var.environment}-vpc"
}

terraform {
  backend "s3" {
    bucket = "kr-infra-tf-state"
    key = "env/dev"
    region = "us-east-1"
  }
}

module "vpc_network" {
  source = "./modules/network"

  region = var.region
  environment = var.environment
  vpc_cidr = var.vpc_cidr
  public_subnets_cidr = var.public_subnets_cidr
  private_subnets_cidr = var.private_subnets_cidr
  vpc_name = local.vpc_name
  suffix = local.suffix

  cluster_name = local.cluster_name
}

//module "ecs_cluster" {
//  source = "./modules/ecs"
//  vpc_id = module.vpc_network.vpc_id
//  internet_gateway = module.vpc_network.ig
//  environment = var.environment
//  public_subnet = module.vpc_network.public_subnets
//}

//module "eks_cluster" {
//  source = "./modules/eks"
//
//  vpc_id = module.vpc_network.vpc_id
//  internet_gateway = module.vpc_network.ig
//  environment = var.environment
//  public_subnet = module.vpc_network.public_subnets
//  cluster_name =  "fr-eks-${random_string.suffix.result}"
//
//  private_subnets = module.vpc_network.private_subnets
//  region = var.region
//}


module "eks_cluster" {
  source = "./modules/eks"

#   rds-sg = module.vpc_network.rds-sg
  private_subnets_cidr = var.private_subnets_cidr
  environment = var.environment
  vpc_id = module.vpc_network.vpc_id
  private_subnets = module.vpc_network.private_subnets
  cluster_name = local.cluster_name
}
