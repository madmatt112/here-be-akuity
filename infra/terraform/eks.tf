# One EKS cluster per entry in var.eks_clusters (dev, prod). Mirrors the
# infra/eks/platform-clusters.yaml CloudFormation: VPC + two public subnets +
# IAM + cluster + managed node group.

module "eks" {
  source   = "./modules/eks"
  for_each = var.eks_clusters

  cluster_name       = each.key
  vpc_cidr           = each.value.vpc_cidr
  kubernetes_version = var.kubernetes_version
  node_instance_type = var.node_instance_type
}
