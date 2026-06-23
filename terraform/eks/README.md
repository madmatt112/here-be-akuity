# Terraform: EKS clusters

AWS-only root. Creates the platform's EKS clusters (VPC + two public subnets +
IAM + cluster + managed node group) across two regions, one module instance per
cluster. Nothing Akuity-related lives here.

This is one of two independent roots under `infra/terraform/`:

- **`eks/`** (this root) — the EKS clusters.
- **`akuity/`** — the Akuity Argo CD / Kargo instances, cluster registrations,
  ApplicationSets, and Kargo pipelines. It looks the clusters up by name with the
  `aws_eks_cluster` data source, so it depends only on the clusters *existing* —
  not on this root's state.

Apply one, the other, or both. For a from-scratch build, apply `eks/` first so
the clusters exist before `akuity/` registers them.

## Layout

```
eks/
  versions.tf / providers.tf / variables.tf / eks.tf / outputs.tf
  modules/eks/                   # VPC + subnets + IAM + cluster + node group
  terraform.tfvars.example
```

## Apply

```bash
cp terraform.tfvars.example terraform.tfvars   # optional overrides
terraform init
terraform plan
terraform apply
```

`var.eks_clusters` keys become both the AWS EKS cluster name and the Akuity
cluster name; keep them in sync with the `akuity/` root's `eks_clusters` (the two
roots can share one tfvars). The map's `region` field selects the regional AWS
provider (`aws.usw1` / `aws.use1`); `env` is unused here.

Heads-up: this builds 4 EKS control planes + their node groups — real cost. Use
`-target=module.eks_use1` to limit a run to just the us-east-1 clusters.
