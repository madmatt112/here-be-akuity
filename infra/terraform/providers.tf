provider "aws" {
  region = var.aws_region
}

# The akp provider reads credentials from the environment:
#   AKUITY_API_KEY_ID and AKUITY_API_KEY_SECRET
# Generate these in the Akuity Platform under Organization -> API Keys (Owner role).
provider "akp" {
  org_name = var.akuity_org_name
}
