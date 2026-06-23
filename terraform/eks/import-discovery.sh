#!/usr/bin/env bash
# Discover an existing EKS cluster's resources and emit (1) the eks_clusters
# override block and (2) terraform import blocks, so the cluster can be ADOPTED
# into the eks module instead of recreated. Requires awscli + jq and credentials
# for the target account.
#
# Usage: ./import-discovery.sh <aws-cluster-name> <region> <akuity-name>
#   e.g. ./import-discovery.sh dev  us-west-1 eks-us-west-1-dev
#        ./import-discovery.sh prod us-west-1 eks-us-west-1-prod
set -euo pipefail

AWS_NAME="${1:?usage: import-discovery.sh <aws-cluster-name> <region> <akuity-name>}"
REGION="${2:?region required}"
KEY="${3:?akuity name / map key required}"

case "$REGION" in
  us-west-1) MOD="module.eks_usw1[\"$KEY\"]" ;;
  us-east-1) MOD="module.eks_use1[\"$KEY\"]" ;;
  *)         MOD="module.eks_<region>[\"$KEY\"]" ;;
esac

aws_() { aws --region "$REGION" --output json "$@"; }

# Emit a multi-line terraform import block (single-line form with two args is
# invalid HCL).
imp() { printf 'import {\n  to = %s\n  id = "%s"\n}\n' "$1" "$2"; }

CLUSTER=$(aws_ eks describe-cluster --name "$AWS_NAME")
VPC_ID=$(jq -r '.cluster.resourcesVpcConfig.vpcId' <<<"$CLUSTER")
CLUSTER_ROLE=$(jq -r '.cluster.roleArn | split("/") | last' <<<"$CLUSTER")
VPC_CIDR=$(aws_ ec2 describe-vpcs --vpc-ids "$VPC_ID" | jq -r '.Vpcs[0].CidrBlock')
mapfile -t SUBNETS < <(jq -r '.cluster.resourcesVpcConfig.subnetIds[]' <<<"$CLUSTER")

NG_NAME=$(aws_ eks list-nodegroups --cluster-name "$AWS_NAME" | jq -r '.nodegroups[0]')
NODE_ROLE=$(aws_ eks describe-nodegroup --cluster-name "$AWS_NAME" --nodegroup-name "$NG_NAME" \
  | jq -r '.nodegroup.nodeRole | split("/") | last')

IGW_ID=$(aws_ ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" | jq -r '.InternetGateways[0].InternetGatewayId')
RTB_ID=$(aws_ ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=false" \
  | jq -r '.RouteTables[0].RouteTableId // empty')

cat <<EOF
# --- eks_clusters["$KEY"] override -- set in terraform.tfvars (confirm env) ---
"$KEY" = {
  vpc_cidr          = "$VPC_CIDR"
  region            = "$REGION"
  env               = "<dev|prod>"
  aws_name          = "$AWS_NAME"
  cluster_role_name = "$CLUSTER_ROLE"
  node_role_name    = "$NODE_ROLE"
  node_group_name   = "$NG_NAME"
}

# --- import blocks -- put in terraform/eks/imports.tf, then \`terraform plan\` ---
EOF

imp "$MOD.aws_eks_cluster.this"    "$AWS_NAME"
imp "$MOD.aws_eks_node_group.this" "$AWS_NAME:$NG_NAME"
imp "$MOD.aws_iam_role.cluster"    "$CLUSTER_ROLE"
imp "$MOD.aws_iam_role.node"       "$NODE_ROLE"
imp "$MOD.aws_iam_role_policy_attachment.cluster" "$CLUSTER_ROLE/arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
imp "$MOD.aws_iam_role_policy_attachment.node[\"arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy\"]"          "$NODE_ROLE/arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
imp "$MOD.aws_iam_role_policy_attachment.node[\"arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy\"]"               "$NODE_ROLE/arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
imp "$MOD.aws_iam_role_policy_attachment.node[\"arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly\"]" "$NODE_ROLE/arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
imp "$MOD.aws_vpc.this"             "$VPC_ID"
imp "$MOD.aws_internet_gateway.this" "$IGW_ID"
imp "$MOD.aws_route_table.public"   "$RTB_ID"
imp "$MOD.aws_route.default"        "${RTB_ID}_0.0.0.0/0"

i=0
for s in "${SUBNETS[@]}"; do
  imp "$MOD.aws_subnet.public[$i]"                "$s"
  imp "$MOD.aws_route_table_association.public[$i]" "$s/$RTB_ID"
  i=$((i + 1))
done

cat <<'EOF'

# NOTES
# - subnet[] / route_table_association[] indices follow AZ order (the module
#   orders subnets by data.aws_availability_zones). If plan wants to replace a
#   subnet, swap the [0]/[1] indices.
# - Assumes the cluster mirrors the module: one non-main route table + two public
#   subnets. If the CloudFormation layout differs, adjust the blocks.
# - After importing, run `terraform plan`. In-place diffs (tags, etc.) are fine to
#   apply; anything marked "must be replaced" is a ForceNew mismatch to fix in
#   config (or the override fields) BEFORE applying.
EOF
