variable "eks_clusters" {
  type = map(object({
    vpc_cidr = string
    region   = string
    env      = string
  }))
  description = <<-EOT
    EKS clusters to create, keyed by cluster name. `region` selects which AWS
    provider builds the cluster (us-west-1 -> aws.usw1, us-east-1 -> aws.use1).
    `env` is unused by this root (it is the Akuity routing label, consumed by the
    akuity/ root) but kept here so a single tfvars can be shared between roots.
  EOT
  default = {
    "eks-us-west-1-dev"  = { vpc_cidr = "10.0.0.0/16", region = "us-west-1", env = "dev" }
    "eks-us-west-1-prod" = { vpc_cidr = "10.1.0.0/16", region = "us-west-1", env = "prod" }
    "eks-us-east-1-dev"  = { vpc_cidr = "10.2.0.0/16", region = "us-east-1", env = "dev" }
  }
}

variable "kubernetes_version" {
  type        = string
  description = "EKS Kubernetes version."
  default     = "1.30"
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for the managed node groups."
  default     = "t3.medium"
}
