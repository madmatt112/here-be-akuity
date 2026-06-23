# Akuity-hosted Argo CD instance + the ApplicationSets, plus the EKS clusters
# registered as Argo CD clusters (the agent is installed by the provider via
# kube_config.exec).

resource "akp_instance" "argocd" {
  name = var.argocd_instance_name

  argocd = {
    spec = {
      version = var.argocd_version
      instance_spec = {
        declarative_management_enabled = true
      }
    }
  }

  # argocd-cm: enable Helm and Kustomize tooling for rendered sources.
  argocd_cm = {
    "helm.enabled"      = "true"
    "kustomize.enabled" = "true"
  }

  # ApplicationSets / Applications / AppProjects (from argocd-manifests/).
  argocd_resources = local.argocd_resources
}

# Register each EKS cluster with the Argo CD instance and install the agent.
# Endpoint + CA come from the aws_eks_cluster data sources (data.tf); the token
# comes from `aws eks get-token`, so no static kubeconfig is stored.
resource "akp_cluster" "eks" {
  for_each = local.eks_clusters_data

  instance_id = akp_instance.argocd.id
  name        = each.key
  namespace   = "akuity"

  # env is the tier label the platform-addons ApplicationSet selector filters on;
  # the appsets key the per-cluster branch/Application/Kargo stage off the cluster
  # name itself (each.key).
  labels = {
    env = var.eks_clusters[each.key].env
  }

  spec = {
    data = {
      size              = "small"
      eks_addon_enabled = true
    }
  }

  kube_config = {
    host                   = each.value.endpoint
    cluster_ca_certificate = base64decode(each.value.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", each.key, "--region", var.eks_clusters[each.key].region]
    }
  }

  ensure_healthy = true
}
