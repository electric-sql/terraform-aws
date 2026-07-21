variable "cluster_name" {
  description = "Name of the ECS cluster instances will join (baked into user-data)"
  type        = string
}

variable "vpc_id" {
  description = "VPC to create the instance security group in"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for the autoscaling group. Use public subnets (with associate_public_ip = true) unless the VPC has a NAT gateway"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type. Use an i4i/m6id type for NVMe instance store, or m6a/m6i/m7a/m7i with data_storage.kind = \"ebs-gp3\""
  type        = string
}

variable "instance_label" {
  description = "Label used in the host data directory path (/mnt/nvme/electric/<label>)"
  type        = string
  default     = "main"
}

variable "associate_public_ip" {
  description = "Give instances a public IP. Required for image pulls when instances are in public subnets without a NAT gateway"
  type        = bool
  default     = true
}

variable "name_prefix" {
  description = "Prefix for resource names created by this module"
  type        = string
  default     = "electric-ec2"
}

variable "data_storage" {
  description = "Storage backing for /mnt/nvme. kind = \"nvme\" uses the host's instance store (no extra volume); kind = \"ebs-gp3\" attaches a gp3 data volume with the given size/IOPS/throughput"
  type = object({
    kind            = string
    size_gb         = optional(number, 100)
    iops            = optional(number, 3000)
    throughput_mbps = optional(number, 125)
  })

  validation {
    condition     = contains(["nvme", "ebs-gp3"], var.data_storage.kind)
    error_message = "data_storage.kind must be \"nvme\" or \"ebs-gp3\"."
  }
}
