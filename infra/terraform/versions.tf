terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    akp = {
      source  = "akuity/akp"
      version = "~> 0.12"
    }
  }
}
