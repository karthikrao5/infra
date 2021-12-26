output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "private_subnet_cidrs" {
  value = var.private_subnets_cidr
}

# output "rds-sg" {
#   value = aws_security_group.rds-sg
# }