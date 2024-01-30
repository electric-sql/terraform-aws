variable "cidr_block" {
  description = "Address space for the VPC, in CIDR notation"
}

variable "private_subnet_cidrs" {
  description = "Address spaces for private subnets, in CIDR notation"
}

variable "public_subnet_cidr" {
  description = "Address space for the public subnet, in CIDR notation"
}

variable "vpc_name" {
  description = "Name of the VPC"
  default     = "Electric VPC"
}

variable "private_subnet_name_prefix" {
  description = "Name prefix to use for the private subnets"
  default     = "Electric Private Subnet"
}

variable "public_subnet_name" {
  description = "Name of the public subnet"
  default     = "Electric Public Subnet"
}

variable "internet_gateway_name" {
  description = "Name of the Internet gateway created in this VPC"
  default     = "Electric Internet Gateway"
}

variable "public_route_table_name" {
  description = "Name of the route table that associates the public subnet with the Internet gateway"
  default     = "Electric Public Route Table"
}
