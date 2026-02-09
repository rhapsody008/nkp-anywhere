variable "resource_prefix" {
  description = "Prefix for naming AWS resources"
  type        = string
  default     = "nkp"
}

variable "aws_vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.100.0.0/16"
}

variable "aws_public_subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.100.1.0/24"
}

variable "aws_private_subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.100.2.0/24"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "ec2_ami_id" {
  description = "AMI ID for the EC2 instances"
  type        = string
  default     = "ami-0827b3068f1548bf6"
}

variable "ec2_type_bastion" {
  description = "EC2 instance type for bastion host"
  type        = string
  default     = "t3.medium"
}
