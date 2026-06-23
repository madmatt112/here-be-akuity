# platform-addons: apply guide

A second Kargo Project that renders a Helm cluster add-on (ingress-nginx) via the
Rendered Manifests Pattern & promotes it dev -> prod across two EKS clusters.
Contrast w/ the guestbook app: there a stage is a namespace on one cluster; here
a stage IS a cluster (dev cluster, then prod cluster), so dev can run a newer
add-on version than prod during a promotion window.

## Layout

- `addons/ingress-nginx/` — umbrella Helm chart on `main`; Kargo renders this.
- `platform-addons/kargo/` — Kargo Project, Warehouse & Stages (`kargo apply`).
- `akuity/addon-ingress-nginx-appset.yaml` — the add-on ApplicationSet.
- `akuity/cluster-dev.yaml`, `akuity/cluster-prod.yaml` — Cluster registrations w/ `env` labels.
- `infra/eks/` — CloudFormation for the two EKS clusters.

The chart lives at `addons/ingress-nginx/` because the Stage steps render
`./src/addons/ingress-nginx`, where `./src` is a checkout of `main`.

## How it works

- Warehouse subscribes to the ingress-nginx Helm chart (SemVer) -> Freight.
- Stage `dev`: `helm-update-chart` pins the umbrella's dependency to the Freight
  version, `helm-template` renders to `manifests.yaml`, push to `addons/dev`,
  `argocd-update` syncs the dev cluster's app (selected by labels).
- Stage `prod`: same render, but PR-gated. Pushes a generated branch, opens a PR
  into `addons/prod`, waits for merge, then syncs prod to the POST-merge commit
  (`outputs['wait-for-pr'].commit`), the fix for the argocd-update sync loop.
- ApplicationSet (clusters generator) stamps each cluster's app w/ its env label
  & points `targetRevision` at `addons/<env>`, so dev tracks `addons/dev` &
  prod tracks `addons/prod`.

## Apply order

1. Ensure the chart + manifests are committed to `main` & pushed.
2. Provision the EKS clusters (see `infra/eks/DEPLOY.md`). Name them `dev` &
   `prod` so they match `cluster-dev.yaml` / `cluster-prod.yaml`.
3. Declare the clusters + the add-on ApplicationSet on the Argo CD instance.
   This registers `dev` & `prod` (w/ their `env` labels) plus the
   ApplicationSet. The clusters show Progressing until an agent connects.

   ```
   akuity argocd apply -f akuity/
   ```
4. Install the Akuity agent into each EKS cluster. The Cluster must already be
   declared (step 3) so the CLI can fetch its agent manifests. Point kubectl at
   the cluster first, then apply. The instance name comes from
   `akuity/argocd.yaml` (`my-argocd-instance`); confirm w/
   `akuity argocd instance list`.

   ```
   # dev
   aws eks update-kubeconfig --name dev --region us-west-1
   kubectl config current-context        # confirm you're on the dev EKS cluster
   akuity argocd cluster get-agent-manifests \
     --instance-name=my-argocd-instance dev | kubectl apply -f -

   # prod (when ready)
   aws eks update-kubeconfig --name prod --region us-west-1
   akuity argocd cluster get-agent-manifests \
     --instance-name=my-argocd-instance prod | kubectl apply -f -
   ```

   Wait for each cluster to show a green/Healthy status in the Akuity Clusters
   dashboard before moving on.
5. `kargo apply -f platform-addons/kargo/project.yaml`
6. Create git write creds in the new project (chart repo is public, no creds):

   ```
   kargo create repo-credentials github-creds \
     --project platform-addons --git \
     --username ${GITHUB_USER} --password ${KARGO_QUICKSTART_PAT} \
     --repo-url https://github.com/madmatt112/here-be-akuity
   ```
7. `kargo apply -f platform-addons/kargo/warehouse.yaml`
8. `kargo apply -f platform-addons/kargo/stages.yaml`
9. Promote: dev first (creates `addons/dev`), then prod (opens a PR into
   `addons/prod`; merge it). The add-on apps go Healthy once their branch exists.

## Notes / decisions

- The `addons/dev` & `addons/prod` branches are created by the first promotion
  (`git-clone ... create: true`). The dev/prod apps show Missing until then.
- The chart repo is public, so Kargo needs no chart creds. If you later use a
  private/OCI chart, add image/chart repo-credentials to this project.
- In-cluster verification (AnalysisRuns) would require switching the Kargo agent
  to self-hosted on the target cluster.
- Heads-up: registering a 2nd cluster makes the EXISTING guestbook matrix
  ApplicationSet fan to both EKS clusters (6 apps). Scope it (add an env
  selector) if you don't want guestbook on the prod add-on cluster.
- `ServerSideApply=true` is set on the add-on apps to avoid last-applied
  annotation size limits on larger add-on charts.
