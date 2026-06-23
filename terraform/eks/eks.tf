# One EKS cluster per entry in var.eks_clusters, split by region so each module
# instance receives the AWS provider for its region. Mirrors the infra/eks
# CloudFormation: VPC + two public subnets + IAM + cluster + managed node group.

module "eks_usw1" {
  source   = "./modules/eks"
  for_each = { for name, c in var.eks_clusters : name => c if c.region == "us-west-1" }

  providers = {
    aws = aws.usw1
  }

  cluster_name       = each.key
  vpc_cidr           = each.value.vpc_cidr
  kubernetes_version = var.kubernetes_version
  node_instance_type = var.node_instance_type
}

module "eks_use1" {
  source   = "./modules/eks"
  for_each = { for name, c in var.eks_clusters : name => c if c.region == "us-east-1" }

  providers = {
    aws = aws.use1
  }

  cluster_name       = each.key
  vpc_cidr           = each.value.vpc_cidr
  kubernetes_version = var.kubernetes_version
  node_instance_type = var.node_instance_type
}
