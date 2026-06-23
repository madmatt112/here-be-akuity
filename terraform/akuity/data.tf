# Look the EKS clusters up by name (built by the eks/ root, or out of band) for
# their API endpoint and CA, so the cluster registrations can attach without this
# root depending on the eks/ root's state. Split by region for the right provider.

data "aws_eks_cluster" "usw1" {
  for_each = { for name, c in var.eks_clusters : name => c if c.region == "us-west-1" }
  provider = aws.usw1
  name     = each.key
}

data "aws_eks_cluster" "use1" {
  for_each = { for name, c in var.eks_clusters : name => c if c.region == "us-east-1" }
  provider = aws.use1
  name     = each.key
}

locals {
  eks_clusters_data = merge(data.aws_eks_cluster.usw1, data.aws_eks_cluster.use1)
}
