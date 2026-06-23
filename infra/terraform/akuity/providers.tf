# The akp provider reads credentials from the environment:
#   AKUITY_API_KEY_ID and AKUITY_API_KEY_SECRET
# Generate these in the Akuity Platform under Organization -> API Keys (Owner role).
provider "akp" {
  org_name = var.akuity_org_name
}

# Regional AWS providers, used only to look up the EKS clusters (endpoint + CA)
# so the cluster registrations can attach to them.
provider "aws" {
  alias  = "usw1"
  region = "us-west-1"
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}
