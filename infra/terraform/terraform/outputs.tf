output "eks_clusters" {
  description = "EKS cluster endpoints by name."
  value       = { for k, m in module.eks : k => m.cluster_endpoint }
}

output "argocd_instance_id" {
  description = "Akuity Argo CD instance ID."
  value       = akp_instance.argocd.id
}

output "kargo_instance_id" {
  description = "Akuity Kargo instance ID."
  value       = akp_kargo_instance.kargo.id
}

output "registered_clusters" {
  description = "Argo CD cluster IDs by name."
  value       = { for k, c in akp_cluster.eks : k => c.id }
}
