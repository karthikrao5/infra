variable "region" {
  default     = "us-east-1"
  description = "AWS region"
}

variable "vpc_cidr" {
    default = "10.0.0.0/16"
}

variable "environment" {
    default = "dev"
}

variable "public_subnets_cidr" {
    default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "private_subnets_cidr" {
    default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}