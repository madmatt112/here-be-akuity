variable "eks_clusters" {
  type = map(object({
    vpc_cidr = string
    region   = string
    env      = string
    # The map key is the Akuity cluster name (what the appsets/stages reference).
    # aws_name is the actual AWS EKS cluster name; it defaults to the key, but is
    # set explicitly when adopting a pre-existing cluster whose AWS name differs
    # (the existing us-west-1 clusters are named "dev"/"prod"). The *_name fields
    # let an imported cluster keep its existing (ForceNew) resource names.
    aws_name          = optional(string)
    cluster_role_name = optional(string)
    node_role_name    = optional(string)
    node_group_name   = optional(string)
  }))
  description = <<-EOT
    EKS clusters to create or adopt, keyed by Akuity cluster name. `region`
    selects which AWS provider builds/looks up the cluster (us-west-1 -> aws.usw1,
    us-east-1 -> aws.use1). `env` is unused by this root (it is the Akuity routing
    label, consumed by the akuity/ root) but kept so a single tfvars can be shared.
    The optional `aws_name` / `*_name` fields are for importing existing clusters.
  EOT
  default = {
    "eks-us-west-1-dev"  = { vpc_cidr = "10.0.0.0/16", region = "us-west-1", env = "dev", aws_name = "dev" }
    "eks-us-west-1-prod" = { vpc_cidr = "10.1.0.0/16", region = "us-west-1", env = "prod", aws_name = "prod" }
    "eks-us-east-1-dev"  = { vpc_cidr = "10.2.0.0/16", region = "us-east-1", env = "dev" }
    "eks-us-east-1-prod" = { vpc_cidr = "10.3.0.0/16", region = "us-east-1", env = "prod" }
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
