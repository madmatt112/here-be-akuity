# platform-addons: apply guide

A second Kargo Project that renders a Helm cluster add-on (ingress-nginx) via the
Rendered Manifests Pattern & promotes it dev -> prod across two EKS clusters.
Contrast w/ the guestbook app: there a stage is a namespace on one cluster; here
a stage IS a cluster (dev cluster, then prod cluster), so dev can run a newer
add-on version than prod during a promotion window.

## Repo-path mapping

These files live in the vault for review. Copy them into the repo at:

| This folder                                  | Repo path                                  | Applied by            |
| -------------------------------------------- | ------------------------------------------ | --------------------- |
| `addons/ingress-nginx/`                      | `addons/ingress-nginx/` (on `main`)        | rendered by Kargo      |
| `kargo/project.yaml`                         | `platform-addons/kargo/project.yaml`       | `kargo apply`         |
| `kargo/warehouse.yaml`                       | `platform-addons/kargo/warehouse.yaml`     | `kargo apply`         |
| `kargo/stages.yaml`                          | `platform-addons/kargo/stages.yaml`        | `kargo apply`         |
| `akuity/addon-ingress-nginx-appset.yaml`     | `akuity/addon-ingress-nginx-appset.yaml`   | `akuity argocd apply` |
| `akuity/cluster-dev.yaml`                    | `akuity/cluster-dev.yaml`                  | `akuity argocd apply` |
| `akuity/cluster-prod.yaml`                   | `akuity/cluster-prod.yaml`                 | `akuity argocd apply` |

The chart must sit at `addons/ingress-nginx/` on `main` because the Stage steps
render `./src/addons/ingress-nginx` (where `./src` is a checkout of `main`).

## How it works

- Warehouse subscribes to the ingress-nginx Helm chart (SemVer) -> Freight.
- Stage `dev`: `helm-update-chart` pins the umbrella's dependency to the Freight
  version, `helm-template` renders to `manifests.yaml`, push to `addons/dev`,
  `argocd-update` syncs the dev cluster's app (selected by labels).
- Stage `prod`: same render, but PR-gated. Pushes a generated branch, opens a PR
  into `addons/prod`, waits for merge, then syncs prod to the POST-merge commit
  (`outputs['wait-for-pr'].commit`) — the fix for the argocd-update sync loop.
- ApplicationSet (clusters generator) stamps each cluster's app w/ its env label
  & points `targetRevision` at `addons/<env>`, so dev tracks `addons/dev` &
  prod tracks `addons/prod`.

## Apply order

1. Commit the chart + manifests to `main` (per the mapping above) & push.
2. Register the two EKS clusters w/ the Argo CD instance (install the agent in
   each, same as the quickstart's `get-agent-manifests | kubectl apply`).
   Name them `dev` & `prod` to match `cluster-dev.yaml` / `cluster-prod.yaml`.
3. `akuity argocd apply -f akuity/`  (creates/labels clusters + the ApplicationSet)
4. `kargo apply -f platform-addons/kargo/project.yaml`
5. Create git write creds in the new project (chart repo is public, no creds):

   ```
   kargo create repo-credentials github-creds \
     --project platform-addons --git \
     --username ${GITHUB_USER} --password ${KARGO_QUICKSTART_PAT} \
     --repo-url https://github.com/madmatt112/here-be-akuity
   ```
6. `kargo apply -f platform-addons/kargo/warehouse.yaml`
7. `kargo apply -f platform-addons/kargo/stages.yaml`
8. Promote: dev first (creates `addons/dev`), then prod (opens a PR into
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
