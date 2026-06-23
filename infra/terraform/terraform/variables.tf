variable "aws_region" {
  type        = string
  description = "AWS region for the EKS clusters."
  default     = "us-west-1"
}

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

variable "kubernetes_version" {
  type        = string
  description = "EKS Kubernetes version. Leave null to use the EKS default."
  default     = "1.30"
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for the managed node groups."
  default     = "t3.medium"
}

variable "eks_clusters" {
  type = map(object({
    vpc_cidr = string
  }))
  description = "EKS clusters to create. The map key becomes the cluster name and the Akuity env label."
  default = {
    dev  = { vpc_cidr = "10.0.0.0/16" }
    prod = { vpc_cidr = "10.1.0.0/16" }
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
