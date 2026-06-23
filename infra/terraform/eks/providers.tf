# The platform spans two regions. Each EKS module instance is passed the AWS
# provider for its cluster's region (see eks.tf).
provider "aws" {
  alias  = "usw1"
  region = "us-west-1"
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}
