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

# Optional name overrides, for importing an existing (e.g. CloudFormation-built)
# cluster whose resource names differ from the defaults. These attributes are
# ForceNew, so they must match the live resource or Terraform would replace it.
# Leave null for greenfield clusters to use the default naming.
variable "cluster_role_name" {
  type        = string
  default     = null
  description = "EKS cluster IAM role name. Defaults to eks-<cluster_name>-cluster."
}

variable "node_role_name" {
  type        = string
  default     = null
  description = "Node group IAM role name. Defaults to eks-<cluster_name>-node."
}

variable "node_group_name" {
  type        = string
  default     = null
  description = "Managed node group name. Defaults to <cluster_name>-ng."
}
