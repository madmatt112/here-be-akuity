# Akuity-hosted Argo CD instance + the platform-addons ApplicationSet, plus the
# EKS clusters registered as Argo CD clusters (the agent is installed by the
# provider via kube_config.exec).

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
# kube_config.exec uses `aws eks get-token`, so no static kubeconfig/token.
resource "akp_cluster" "eks" {
  for_each = module.eks

  instance_id = akp_instance.argocd.id
  name        = each.key
  namespace   = "akuity"

  # The env label is what the platform-addons ApplicationSet routes on
  # (targetRevision addons/{{metadata.labels.env}}).
  labels = {
    env = each.key
  }

  spec = {
    data = {
      size              = "small"
      eks_addon_enabled = true
    }
  }

  kube_config = {
    host                   = each.value.cluster_endpoint
    cluster_ca_certificate = base64decode(each.value.cluster_ca_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", each.key, "--region", var.aws_region]
    }
  }

  ensure_healthy = true
}
