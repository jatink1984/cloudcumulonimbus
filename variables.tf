variable "aws_region" {}
variable "aws_profile" {}
variable "vpc_cidr" {}
data "aws_availability_zones" "available" {}

variable "cidrs" {
  type = "map"
}

variable "localip" {}
variable "domain_name" {}
variable "db_instance_class" {}
variable "dbname" {}
variable "dbuser" {}
variable "dbpassword" {}