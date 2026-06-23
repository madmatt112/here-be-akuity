# Terraform: platform environment

Greenfield-creates the **platform** environment from the take-home: four EKS
clusters (dev + prod in both us-west-1 and us-east-1), the Akuity-hosted Argo CD
and Kargo instances, the cluster registrations + agents, the `platform-addons`
ingress-nginx ApplicationSet, and the `platform-addons` Kargo pipeline (Project /
Warehouse / gated fan-out Stages).

Providers: `hashicorp/aws` and `akuity/akp`.

## What Terraform manages vs. what it can't

The research question up front: most of it **is** Terraform-manageable via the
`akp` provider, which was more capable than expected.

Managed here:

| Resource | How |
| --- | --- |
| EKS dev+prod in us-west-1 & us-east-1 (VPC, subnets, IAM, cluster, node group) | `module.eks_usw1` / `module.eks_use1` (aws, one per region) |
| Argo CD instance + `argocd-cm` | `akp_instance` |
| Argo CD cluster registration + agent install | `akp_cluster` (kube_config.exec `aws eks get-token`) |
| Add-on `ApplicationSet` | `akp_instance.argocd_resources` (from `argocd-manifests/`) |
| Kargo instance + admin account | `akp_kargo_instance` |
| Kargo `Project` / `Warehouse` / `Stage`s | `akp_kargo_instance.kargo_resources` (from `kargo-manifests/`) |
| Kargo git write-credential `Secret` | built in `locals.tf` from `var.github_pat` |
| Kargo agent (Akuity-managed) | `akp_kargo_agent` |

**Not** Terraform-manageable (by design — GitOps/runtime/artifacts):

- The Git branch **contents**: the per-cluster `addons/<cluster>` rendered-manifest
  branches and the umbrella chart on `main`. Kargo writes the rendered branches at
  promotion time; the chart is source that the Stages clone. Terraform owns the
  Stage/AppSet *definitions*, not the bytes they produce or consume.
- **Freight** — discovered at runtime by the Warehouse; not declarative.
- **Promotions** — runtime actions (you/automation trigger them).
- The **ghcr image** artifact and its package visibility — built/pushed out of band.
- **Secret values** (GitHub PAT, Kargo admin hash) — supplied via sensitive vars,
  not committed. The secret *resources* are managed; the values are not in code.
- The original **k3d quickstart** cluster — replaced by the dev/prod EKS clusters.

Both environments are managed, sharing the one Argo CD instance and one Kargo
instance:

- **platform-addons** — ingress-nginx add-on fanned out across the four EKS clusters
  (`addon-ingress-nginx` ApplicationSet, one Application per cluster; Kargo Project
  `platform-addons`, Warehouse `ingress-nginx`). The Stages form a gated fan-out:
  `dev` and `prod` control-flow gates, then a per-cluster deploy Stage for each
  cluster that renders to its own `addons/<cluster>` branch (prod-tier Stages are
  PR-gated).
- **quickstart** — guestbook (`guestbook` ApplicationSet; Kargo Project `kargo-simple`,
  Warehouse `guestbook`, dev/staging/prod Stages).

Because k3d (the original quickstart cluster) isn't Terraform-managed, the guestbook
ApplicationSet now lands on the EKS clusters via its matrix generator
(clusters x [dev,staging,prod]).

## Layout

```
terraform/
  versions.tf / providers.tf / variables.tf / locals.tf / outputs.tf
  eks.tf                         # module.eks_usw1 / module.eks_use1 (per-region for_each)
  akuity_argocd.tf               # akp_instance + akp_cluster (4 clusters, both regions)
  akuity_kargo.tf                # akp_kargo_instance + akp_kargo_agent
  modules/eks/                   # VPC + subnets + IAM + cluster + node group
  argocd-manifests/              # ApplicationSet(s) -> argocd_resources
  kargo-manifests/               # Project/Warehouse/Stages -> kargo_resources
  terraform.tfvars.example
```

## Prerequisites

```bash
export AKUITY_API_KEY_ID=...        # Akuity org API key (Owner)
export AKUITY_API_KEY_SECRET=...
export TF_VAR_github_pat=...        # GitHub PAT: repo + write:packages
export TF_VAR_kargo_admin_password_hash='$2a$10$...'  # bcrypt
# plus AWS credentials (profile/role) for the target account
cp terraform.tfvars.example terraform.tfvars   # set akuity_org_name, github_user
```

## Apply

```bash
terraform init
terraform plan
terraform apply
```

Dependency order is handled by references: EKS clusters come up first, then
`akp_cluster` connects via `aws eks get-token` and installs the agent, then the
ApplicationSet gives each cluster its own Application (keyed by cluster name)
tracking its `addons/<cluster>` branch.

## Importing existing resources

To adopt what you already built instead of recreating it, use `import` blocks
(TF 1.5+), then `terraform plan` to reconcile:

```hcl
import { to = akp_instance.argocd,                 id = "my-argocd-instance" }
import { to = akp_kargo_instance.kargo,            id = "platform-kargo" }
import { to = akp_cluster.eks["eks-us-west-1-dev"],  id = "<argocd-instance-id>/eks-us-west-1-dev" }
import { to = akp_cluster.eks["eks-us-west-1-prod"], id = "<argocd-instance-id>/eks-us-west-1-prod" }
import { to = akp_cluster.eks["eks-us-east-1-dev"],  id = "<argocd-instance-id>/eks-us-east-1-dev" }
import { to = akp_cluster.eks["eks-us-east-1-prod"], id = "<argocd-instance-id>/eks-us-east-1-prod" }
import { to = akp_kargo_agent.agent,               id = "platform-kargo-agent" }
```

EKS resources import by AWS id under the module address, e.g.:

```bash
terraform import 'module.eks_usw1["eks-us-west-1-dev"].aws_eks_cluster.this' eks-us-west-1-dev
terraform import 'module.eks_usw1["eks-us-west-1-dev"].aws_vpc.this' vpc-xxxxxxxx
# us-east-1 clusters live under module.eks_use1["eks-us-east-1-<env>"]
# ...repeat per resource; `terraform plan` will show what's still unmanaged
```

Set `argocd_instance_name` / `kargo_instance_name` to your existing instance
names before importing.

## Caveats

- Generated without running `terraform` (the authoring shell was unavailable), so
  treat it as unvalidated: run `terraform validate` / `plan` and expect to adjust.
- `akp` attribute names/nesting were taken from the v0.12 provider docs; if an
  attribute is rejected, check that exact version's schema.
- Creating instances via `akp_instance` is marked beta by Akuity; for production
  they suggest referencing manually-created instances via the `akp_instance`