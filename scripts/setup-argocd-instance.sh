#!/bin/bash
set -e  # Exit on non-zero exit code from commands

[[ -z ${AKUITY_API_KEY_ID} ]] || [[ -z ${AKUITY_API_KEY_SECRET} ]] && echo "Please export Akuity API Creds" && exit 13

INSTANCE=my-argocd-instance

# The platform's four EKS clusters. The Akuity cluster name matches the AWS EKS
# cluster name (as created by infra/terraform), and the region is derived from the
# name (eks-<region>-<env>). If your AWS cluster names differ, adjust here.
CLUSTERS=(
  eks-us-west-1-dev
  eks-us-west-1-prod
  eks-us-east-1-dev
  eks-us-east-1-prod
)

# Function to get the health status code
get_health_status() {
    akuity argocd instance list -o json | jq -r '.[0].healthStatus.code'
}

ORG_ID=$(akuity org list | awk 'NR==2 {print $1}')
# Set the organization id in the cli config so users don't have to set it.
akuity config set --organization-id=${ORG_ID}
echo "Set the org id to \"${ORG_ID}\"."

# Apply the declarative akuity platform configuration (Argo CD instance, cluster
# registrations, and the ApplicationSets under akuity/appsets/).
echo "Applying the Akuity platform configuration..."
akuity argocd apply -f akuity/

# Loop until the instance becomes healthy.
echo -n "Waiting for the Argo CD instance to be healthy."
counter=0
while true; do
    [[ ${counter} -ge 5 ]] && echo -e "\nError: Timed out waiting for instance" && exit 13
    health_status=$(get_health_status)
    if [ "$health_status" = "STATUS_CODE_HEALTHY" ]; then
        echo -e "\nThe Argo CD instance is healthy!"
        break
    fi
    echo -n "."
    counter=$((counter + 1))
    sleep 30  # Average 90 seconds
done

# Install the Akuity agent into each EKS cluster. Each cluster must already be
# declared on the instance (done by the apply above) so the CLI can fetch its
# agent manifests. Point kubectl at each cluster in turn via aws eks
# update-kubeconfig, deriving the region from the cluster name.
for cluster in "${CLUSTERS[@]}"; do
    rest=${cluster#eks-}      # e.g. us-west-1-dev
    region=${rest%-*}         # e.g. us-west-1
    echo "Installing the Akuity agent into ${cluster} (${region})..."
    aws eks update-kubeconfig --name "${cluster}" --region "${region}"
    akuity argocd cluster get-agent-manifests \
      --instance-name="${INSTANCE}" "${cluster}" | kubectl apply -f -
done

argocd login \
  "$(akuity argocd instance get ${INSTANCE} -o json | jq -r '.id').cd.akuity.cloud" \
  --username admin \
  --password akuity-argocd \
  --grpc-web
echo "Configured the \"argocd\" cli."

# Trigger a refresh on each generated Application so it doesn't sit in
# ComparisonError if it lands before the repo server is ready. Both ApplicationSets
# produce one app per cluster (ingress-nginx-<cluster> and guestbook-<cluster>).
# Apps may not exist yet (they appear once clusters connect, and go Healthy only
# after the first promotion creates their rendered branch), so ignore errors.
sleep 5
for cluster in "${CLUSTERS[@]}"; do
    argocd app get "ingress-nginx-${cluster}" --refresh > /dev/null 2>&1 || true
    argocd app get "guestbook-${cluster}"     --refresh > /dev/null 2>&1 || true
done

echo "======================="
echo "Argo CD instance setup!"
echo "======================="
