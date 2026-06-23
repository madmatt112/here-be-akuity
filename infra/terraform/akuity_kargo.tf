# Akuity-hosted Kargo instance + the platform-addons Kargo resources
# (Project / Warehouse / Stages, plus the git write-credential Secret), and an
# Akuity-managed Kargo agent wired to the Argo CD instance.

resource "akp_kargo_instance" "kargo" {
  name = var.kargo_instance_name

  kargo = {
    spec = {
      version             = var.kargo_version
      kargo_instance_spec = {}
    }
  }

  kargo_cm = {
    adminAccountEnabled = "true"
  }

  kargo_secret = {
    adminAccountPasswordHash = var.kargo_admin_password_hash
  }

  # Project / Warehouse / Stages (kargo-manifests/) + the git cred Secret (locals.tf).
  kargo_resources = local.kargo_resources
}

# Akuity-managed Kargo agent, associated with the Argo CD instance so Kargo can
# trigger syncs and reflect Application health.
#
# NOTE: switch to a self-hosted agent (akuity_managed = false + kube_config)
# only if you add in-cluster verification (AnalysisRuns run Jobs on the target
# cluster); the Akuity-managed agent cannot run those.
resource "akp_kargo_agent" "agent" {
  instance_id = akp_kargo_instance.kargo.id
  name        = "platform-kargo-agent"

  spec = {
    data = {
      akuity_managed = true
      remote_argocd  = akp_instance.argocd.id
    }
  }
}
