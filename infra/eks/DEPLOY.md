# EKS clusters (CloudFormation) — deploy guide

One reusable template (`eks-cluster.yaml`) deployed as two stacks: `eks-dev` and
`eks-prod`. Minimal demo footprint: a small VPC w/ two public subnets across two
AZs, an EKS control plane, and a managed node group of 2x t3.medium. Region: us-west-1.

Repo path (suggested): `infra/eks/`. These are provisioned w/ the AWS CLI, NOT by
Argo CD or Kargo.

## Prerequisites

- AWS CLI v2, authenticated to the target account.
- `kubectl`.
- Permission to create VPC, EKS, IAM, and EC2 resources.

## Deploy

```bash
# dev
aws cloudformation deploy \
  --region us-west-1 \
  --stack-name eks-dev \
  --template-file eks-cluster.yaml \
  --parameter-overrides ClusterName=dev VpcCidr=10.0.0.0/16 \
  --capabilities CAPABILITY_IAM

# prod (distinct CIDR so the two can peer later if needed)
aws cloudformation deploy \
  --region us-west-1 \
  --stack-name eks-prod \
  --template-file eks-cluster.yaml \
  --parameter-overrides ClusterName=prod VpcCidr=10.1.0.0/16 \
  --capabilities CAPABILITY_IAM
```

Each stack takes ~15 min (control plane + node group). To pin a version, add
`KubernetesVersion=1.31` to the overrides; otherwise EKS uses the region default.

## After creation

```bash
aws eks update-kubeconfig --name dev  --region us-west-1
kubectl get nodes
aws eks update-kubeconfig --name prod --region us-west-1
kubectl get nodes
```

Then, register the clusters in ArgoCD, and configure/deploy the ArgoCD & Kargo resources by following `../platform-addons/APPLY.md`

## Cost

~$0.10/hr per EKS control plane plus 2x t3.medium per cluster. Two clusters is
roughly $0.30-0.40/hr all-in. Tear down when not actively demoing.

## Teardown (important ordering)

The ingress-nginx `Service` of type LoadBalancer creates an AWS ELB that
CloudFormation does not own. Delete the Kubernetes LoadBalancer Services first,
or the VPC delete will fail on leftover ELB ENIs.

```bash
# 1. Remove the add-on (or at least its LoadBalancer Services) from each cluster
kubectl --context <dev-context>  -n ingress-nginx delete svc --all
kubectl --context <prod-context> -n ingress-nginx delete svc --all

# 2. Then delete the stacks
aws cloudformation delete-stack --region us-west-1 --stack-name eks-prod
aws cloudformation delete-stack --region us-west-1 --stack-name eks-dev
```
