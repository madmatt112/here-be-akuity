output "clusters" {
  description = "Created EKS clusters by name, with API endpoint. The akuity/ root looks these up by name via the aws_eks_cluster data source."
  value = {
    for k, m in merge(module.eks_usw1, module.eks_use1) : k => {
      name     = m.cluster_name
      endpoint = m.cluster_endpoint
    }
  }
}
