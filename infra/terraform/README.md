# Terraform

The platform IaC is split into two independent roots so you can build the
infrastructure, the Akuity platform, or both:

- **[`eks/`](./eks/)** — the EKS clusters (AWS only): VPC + subnets + IAM +
  cluster + node group, four clusters across us-west-1 and us-east-1.
- **[`akuity/`](./akuity/)** — the Akuity Platform resources: Argo CD instance,
  cluster registrations + agents, ApplicationSets, and the Kargo instance +
  Projects / Warehouses / Stages.

The roots are decoupled: `akuity/` looks the clusters up by name with the
`aws_eks_cluster` data source, so it depends only on the clusters *existing*, not
on the `eks/` root's state. For a from-scratch build, apply `eks/` first.

> The `akuity/` root and the live CLI flow (`akuity argocd apply -f akuity/` +
> `kargo apply -f kargo/...`) manage the **same** Argo CD / Kargo objects. Pick one
> as the source of truth -- don't drive both.

See each root's README for prerequisites, apply steps, and import blocks.
