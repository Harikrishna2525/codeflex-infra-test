variable "aws_region" {
  type        = string
  description = "used This Aws region for this project"
}

variable "vpc_cidr" {
  type        = string
  description = "used VPC CIDR block for this project "
}

variable "subnet_cidr" {
  type        = list(string)
  description = "used this for public subnets  "
}

variable "availability_zones" {
  type        = list(string)
  description = "Added HA for this project"
}