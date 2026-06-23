terraform {
  required_version = ">= 1.5.0"

  required_providers {
    akp = {
      source  = "akuity/akp"
      version = "~> 0.12"
    }
    # Used only for the aws_eks_cluster data sources (cluster endpoint + CA).
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
