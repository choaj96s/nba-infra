variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-west-2"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  default     = "vpc-0d10c556876dde109"
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
  default     = "subnet-0a5c32e66f3d6947a"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ec2_key_name" {
  type = string
}