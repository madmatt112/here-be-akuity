variable "cluster_name" {
  type        = string
  description = "EKS cluster name (also used in resource names and subnet tags)."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR. Use a distinct range per cluster so they can peer later."
}

variable "kubernetes_version" {
  type        = string
  description = "EKS Kubernetes version."
  default     = "1.30"
}

variable "node_instance_type" {
  type        = string
  default     = "t3.medium"
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 3
}
