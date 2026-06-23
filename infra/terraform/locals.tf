# Loads the embedded Argo CD and Kargo manifests and converts each YAML document
# into the JSON-string map shape the akp provider expects for argocd_resources /
# kargo_resources. Splits multi-doc files on "\n---\n" and keys each resource by
# apiVersion/kind/namespace/name.

locals {
  # --- Argo CD resources (ApplicationSets / Applications / AppProjects) ---
  argocd_yaml_files = fileset("${path.module}/argocd-manifests", "*.yaml")

  argocd_resources = merge([
    for file_name in local.argocd_yaml_files : {
      for doc in split("\n---\n", file("${path.module}/argocd-manifests/${file_name}")) :
      "${yamldecode(doc).apiVersion}/${yamldecode(doc).kind}/${try(yamldecode(doc).metadata.namespace, "")}/${yamldecode(doc).metadata.name}" => jsonencode(yamldecode(doc))
      if trimspace(doc) != ""
    }
  ]...)

  # --- Kargo resources (Project / Warehouse / Stage) from embedded files ---
  kargo_yaml_files = fileset("${path.module}/kargo-manifests", "*.yaml")

  kargo_resources_files = merge([
    for file_name in local.kargo_yaml_files : {
      for doc in split("\n---\n", file("${path.module}/kargo-manifests/${file_name}")) :
      "${yamldecode(doc).apiVersion}/${yamldecode(doc).kind}/${try(yamldecode(doc).metadata.namespace, "")}/${yamldecode(doc).metadata.name}" => jsonencode(yamldecode(doc))
      if trimspace(doc) != ""
    }
  ]...)

  # Kargo git write-credential Secrets, built in HCL so the PAT comes from a
  # sensitive variable and is never committed in a manifest file. Kargo
  # credentials are namespace-scoped, so one per Project that needs to push.
  kargo_git_cred_namespaces = ["platform-addons", "kargo-simple"]

  kargo_git_credentials = {
    for ns in local.kargo_git_cred_namespaces :
    "v1/Secret/${ns}/github-creds" => jsonencode({
      apiVersion = "v1"
      kind       = "Secret"
      metadata = {
        name      = "github-creds"
        namespace = ns
        labels    = { "kargo.akuity.io/cred-type" = "git" }
      }
      stringData = {
        repoURL  = var.github_repo_url
        username = var.github_user
        password = var.github_pat
      }
    })
  }

  kargo_resources = merge(local.kargo_resources_files, local.kargo_git_credentials)