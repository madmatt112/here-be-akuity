# Kargo Quickstart tutorial: step ordering, agent-immutability detour, stale references, and a missing three-layer orientation

**About this document.** This is docs feedback on the Kargo Quickstart tutorial
(https://docs.akuity.io/tutorials/kargo-quickstart/). The docs site is not open
source and I could not find a docs-feedback repo or channel, so I've written it up
here and linked it from the companion code PR. That PR (against
`akuity/kargo-quickstart-template`) covers the template-side fixes (EOL Argo CD pin,
a dead `kargo-argocd-manifestupdate.sh`, the health-check lookup, and a README
orientation table); this document covers the tutorial prose itself.

I completed the quickstart end to end on the Akuity Pro trial, deploying to AWS EKS.
The product worked well; the friction below was almost all in the walkthrough, not
the platform.

## High impact: step ordering creates two avoidable failures

**Argo CD is created after the Kargo Stages that depend on it.** Every Stage in
section 3.3 ends with an `argocd-update` step, but the Argo CD instance is not stood
up until later in the flow. On a first read-through, promoting in 3.3 fails because
there is no instance for `argocd-update` to talk to. Reordering so the Argo CD
instance exists before any promotion removes this entirely.

**The first Kargo agent is created without an Argo CD binding, and that binding is
immutable.** Section 2.4 has you register an agent with "Akuity Managed Argo CD"
left empty, so it is not bound to an Argo CD instance. Because that association
cannot be changed after creation, section 4.3.1 has you register a *second* agent
with the Argo CD instance selected and set it as the default shard (step 8), then
optionally delete the first (step 10). The throwaway agent is avoidable: either have
2.4 bind the Argo CD instance up front, or defer agent creation until the Argo CD
instance exists in section 4. As written, a new user creates an agent, discovers it
cannot be edited to add Argo CD, and has to recreate it.

## High impact: the tutorial's manifests use the deprecated Kargo API

The Stage manifests shown in the prose are the pre-v1 Kargo API and do not match the
files in the template. Section 3.2.3 shows Stages built on
`spec.promotionMechanisms.gitRepoUpdates` (with `pullRequest: {}` on prod), and
section 4.3.2 runs `kargo-argocd-manifestupdate.sh`, which patches
`spec.promotionMechanisms.argoCDAppUpdates`. Both fields belong to the old API. The
template's `kargo/stages.yaml` already uses the current `promotionTemplate.spec.steps`
model (`git-clone`, `kustomize-build`, `git-push`, `argocd-update`), so what a reader
applies from the repo does not match what the tutorial shows and walks through. This
mismatch is the root of the prod pull-request discrepancy (3.3.3, below) and of the
dead manifest-update script the companion PR removes. Refreshing the prose manifests
to the step-based API resolves several of the per-section items at once.

## Per-section corrections

- **2.4 (connect a Kargo agent):** the names and labels shown do not match what the
  template/platform actually use.
- **3.2.1 (Kargo Project):** the Project manifest is missing its `annotations`.
- **3.3 (promoting with Kargo):** as above, the `argocd-update` step in each Stage
  fails until the Argo CD instance exists.
- **3.3.3 (pull-request promotions):** the docs describe and walk through a PR being
  opened when promoting to prod (the older `pullRequest: {}` behavior, including
  "merge it" steps), but the template does not implement this. All three Stages,
  prod included, push directly to `env/<stage>` and call `argocd-update` with
  `desiredRevision: ${{ outputs.commit.commit }}`. There is no
  `git-open-pr` / `git-wait-for-pr` step anywhere, so following the docs you never
  get a prod PR. Either restore PR-gating in the template or update the docs to
  match the direct-push reality.

## Stale references

- **Tested-with versions:** the guide references Kargo `v0.5.2` while the current
  platform ships Kargo `v1.x`, whose Stage CRD and promotion-step model are
  substantially different. Refresh the version callouts.
- **kind vs k3d:** the prose and the Codespace bootstrap disagree on the local
  cluster tool (the devcontainer creates a k3d cluster); align the wording.
- **UI screenshots / Supademo walkthroughs:** several no longer match the current
  console UI and are worth re-capturing.

## The biggest gap: no orientation across the three products

The single hardest part of onboarding was not any step, it was working out how
Akuity, Kargo, and Argo CD relate and which of three doc sites owns which concept.
The products are layered, but their docs are siloed, and a single manifest routinely
spans all three with no signpost. For example, the add-on / env `ApplicationSet`
combines an Akuity cluster registration and `env` label, an Argo CD `clusters`
generator and `targetRevision`, and a Kargo `authorized-stage` annotation, one file,
three doc sites.

The cheapest high-leverage fix is a short orientation box at the top of the
quickstart:

| Layer | What it is | Owns (CRDs) | Docs |
| --- | --- | --- | --- |
| Argo CD | OSS GitOps engine (deploys manifests) | `Application`, `ApplicationSet`, `AppProject` | argo-cd.readthedocs.io |
| Kargo | OSS promotion orchestration on top of Argo CD | `Project`, `Warehouse`, `Freight`, `Stage`, `Promotion` (+ Argo Rollouts `AnalysisTemplate`) | docs.kargo.io |
| Akuity Platform | Hosted control planes + outbound agent | `argocd.akuity.io` `Cluster`, `ArgoCD` instance | docs.akuity.io |

Plus one line up front: "you will be reading three doc sites; here is which owns
what and why." That alone erases most of the first-hour confusion for a new customer.

## Companion template PR

A separate PR against `akuity/kargo-quickstart-template` handles the code-side
issues this tutorial relies on: bumping the EOL `v2.10.9` Argo CD pin, removing the
`kargo-argocd-manifestupdate.sh` script (it patches the removed
`spec.promotionMechanisms.argoCDAppUpdates` field), hardening the
`setup-argocd-instance.sh` health check to look the instance up by name, and adding
the orientation table above to the template README.
