# Terraform: Akuity platform

`akp` (+ `aws` for data lookups) root. Manages everything on the Akuity Platform
for this repo: the Argo CD instance, the EKS cluster registrations + agents, the
ApplicationSets, and the Kargo instance + Projects / Warehouses / Stages.

One of two independent roots under `infra/terraform/`:

- **`eks/`** — the EKS clusters themselves (AWS only).
- **`akuity/`** (this root) — the Akuity resources. It looks the clusters up by
  name with the `aws_eks_cluster` data source (see `data.tf`), so it depends only
  on the clusters *existing*, not on the `eks/` root's state. Apply this root
  alone (against clusters built any way you like), the `eks/` root alone, or both.

> This root and the live CLI flow (`akuity argocd apply -f akuity/` +
> `kargo apply -f kargo/...`) manage the **same** Argo CD / Kargo objects. Pick one
> as the source of truth -- don't drive both.

## What it manages

| Resource | How |
| --- | --- |
| Argo CD instance + `argocd-cm` | `akp_instance` |
| Argo CD cluster registration + agent install | `akp_cluster` (endpoint/CA from `aws_eks_cluster` data; token via `aws eks get-token`) |
| ApplicationSets | `akp_instance.argocd_resources` (from `argocd-manifests/`) |
| Kargo instance + admin account | `akp_kargo_instance` |
| Kargo `Project` / `Warehouse` / `Stage`s | `akp_kargo_instance.kargo_resources` (from `kargo-manifests/`) |
| Kargo git write-credential `Secret`s | built in `locals.tf` from `var.github_pat` |
| Kargo agent (Akuity-managed) | `akp_kargo_agent` |

Not managed here (GitOps/runtime): the rendered branch contents (`addons/<cluster>`,
`env/<tier>`), Freight (warehouse-discovered), promotions (runtime actions), the
ghcr image artifact, and secret values (supplied via sensitive vars).

## Layout

```
akuity/
  versions.tf / providers.tf / variables.tf / data.tf / locals.tf / outputs.tf
  akuity_argocd.tf               # akp_instance + akp_cluster (4 clusters, both regions)
  akuity_kargo.tf                # akp_kargo_instance + akp_kargo_agent
  argocd-manifests/              # ApplicationSet(s) -> argocd_resources
  kargo-manifests/               # Projects/Warehouses/Stages -> kargo_resources
  terraform.tfvars.example
```

## Prerequisites

```bash
export AKUITY_API_KEY_ID=...        # Akuity org API key (Owner)
export AKUITY_API_KEY_SECRET=...
export TF_VAR_github_pat=...        # GitHub PAT: repo + write:packages
export TF_VAR_kargo_admin_password_hash='$2a$10$...'  # bcrypt
# plus AWS credentials (for the aws_eks_cluster data lookups)
cp terraform.tfvars.example terraform.tfvars   # set akuity_org_name, github_user
```

## Apply

```bash
terraform init
terraform plan
terraform apply
```

The EKS clusters must already exist (apply `../eks` first, or build them another
way) -- the `aws_eks_cluster` data sources fail if a named cluster is missing.
`var.eks_clusters` keys must match the AWS EKS cluster names.

## Importing existing resources

To adopt resources you already created via the CLI instead of recreating them,
use `import` blocks (TF 1.5+), then `terraform plan` to reconcile:

```hcl
import { to = akp_instance.argocd,                   id = "my-argocd-instance" }
import { to = akp_kargo_instance.kargo,              id = "platform-kargo" }
import { to = akp_cluster.eks["eks-us-west-1-dev"],  id = "<argocd-instance-id>/eks-us-west-1-dev" }
import { to = akp_cluster.eks["eks-us-west-1-prod"], id = "<argocd-instance-id>/eks-us-west-1-prod" }
import { to = akp_cluster.eks["eks-us-east-1-dev"],  id = "<argocd-instance-id>/eks-us-east-1-dev" }
import { to = akp_kargo_agent.agent,                 id = "platform-kargo-agent" }
```

## Caveats

- Generated without running `terraform`, so treat as unvalidated: run
  `terraform validate` / `plan` and expect to adjust.
- `akp` attribute names/nesting were taken from the v0.12 provider docs; if an
  attribute is rejected, check that exact version's schema.
- Creating instances via `akp_instance` is marked beta by Akuity; for production
  they suggest referencing manually-created instances via the `akp_instance`
  data source instead.
