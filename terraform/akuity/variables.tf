variable "akuity_org_name" {
  type        = string
  description = "Akuity Platform organization name."
}

variable "argocd_instance_name" {
  type        = string
  description = "Name of the Akuity-hosted Argo CD instance."
  default     = "my-argocd-instance"
}

variable "argocd_version" {
  type        = string
  description = "Argo CD version (must be an Akuity-supported argocd image tag). Kept current to avoid the EOL-schema ComparisonError."
  default     = "v3.4.3"
}

variable "kargo_instance_name" {
  type        = string
  description = "Name of the Akuity-hosted Kargo instance."
  default     = "platform-kargo"
}

variable "kargo_version" {
  type        = string
  description = "Kargo version for the instance."
  default     = "v1.10.7"
}

variable "eks_clusters" {
  type = map(object({
    vpc_cidr = string
    region   = string
    env      = string
    # Map key is the Akuity cluster name; aws_name is the real AWS EKS cluster
    # name to look up (defaults to the key). The existing us-west-1 clusters are
    # named "dev"/"prod" in AWS but registered in Akuity as eks-us-west-1-*.
    aws_name          = optional(string)
    cluster_role_name = optional(string) # unused here; kept for tfvars parity with eks/
    node_role_name    = optional(string) # unused here
    node_group_name   = optional(string) # unused here
  }))
  description = <<-EOT
    The EKS clusters to register with the Argo CD instance, keyed by the Akuity
    cluster name. `region` selects which AWS provider looks the cluster up;
    `aws_name` (default = key) is the real AWS EKS cluster name; `env` becomes the
    Akuity routing label (dev/prod). The other fields are unused here but kept so a
    single tfvars can be shared with the eks/ root.
  EOT
  default = {
    "eks-us-west-1-dev"  = { vpc_cidr = "10.0.0.0/16", region = "us-west-1", env = "dev", aws_name = "dev" }
    "eks-us-west-1-prod" = { vpc_cidr = "10.1.0.0/16", region = "us-west-1", env = "prod", aws_name = "prod" }
    "eks-us-east-1-dev"  = { vpc_cidr = "10.2.0.0/16", region = "us-east-1", env = "dev" }
    "eks-us-east-1-prod" = { vpc_cidr = "10.3.0.0/16", region = "us-east-1", env = "prod" }
  }
}

variable "github_repo_url" {
  type        = string
  description = "GitOps repo URL Kargo writes rendered manifests to."
  default     = "https://github.com/madmatt112/here-be-akuity"
}

variable "github_user" {
  type        = string
  description = "GitHub username for the Kargo git write credentials."
}

variable "github_pat" {
  type        = string
  description = "GitHub PAT (repo + write) for Kargo to push to env branches. Supply via TF_VAR_github_pat or a secrets backend; do not commit."
  sensitive   = true
}

variable "kargo_admin_password_hash" {
  type        = string
  description = "bcrypt hash for the Kargo admin account. Supply via TF_VAR_kargo_admin_password_hash; do not commit."
  sensitive   = true
}
