variable "vpc_id" {
  description = "ID of the VPC to run the RDS instance in"
}

variable "private_subnet_ids" {
  description = "List of private subnets that will form the subnet group for the RDS instance"
}

variable "db_name" {
  description = "Name for the new database"
}

variable "db_username" {
  description = "Name of the main database role"
}

variable "db_password" {
  description = "Password for the main database role"
}

variable "security_group_name_prefix" {
  description = "Name prefix to use for the 'Security group name' attribute"
  default     = "electric-rds-"
}

variable "security_group_name" {
  description = "Name of the security group created for the RDS instance"
  default     = "Electric RDS security group"
}

variable "subnet_group_name" {
  description = "Name of the new subnet group"
  default     = "electric-subnet-group"
}

variable "parameter_group_name" {
  description = "Name of the new parameter group"
  default     = "electric-parameter-group"
}

variable "instance_identifier" {
  description = "Identifier of the database instance. Also used for its Name tag."
  default     = "electric-db"
}
