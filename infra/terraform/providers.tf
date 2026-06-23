# The platform spans two regions. Each EKS module instance is passed the AWS
# provider for its cluster's region (see eks.tf). No default aws provider is
# needed because every aws resource lives inside the eks module.
provider "aws" {
  alias  = "usw1"
  region = "us-west-1"
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

# The akp provider reads credentials from the environment:
#   AKUITY_API_KEY_ID and AKUITY_API_KEY_SECRET
# Generate these in the Akuity Platform under Organization -> API Keys (Owner role).
provider "akp" {
  org_name = var.akuity_org_name
}
