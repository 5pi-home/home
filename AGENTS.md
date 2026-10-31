# AGENTS.md

Notes for AI agents (and anyone else) changing this repo. How the cluster
config is organized is in [`k8s/README.md`](k8s/README.md).

## Git

- Linear history: PRs are rebase-merged. Base PR branches on current `main`
  and keep them as a series of focused commits. Never merge `main` into a
  PR branch.
- If `main` moves and a PR needs a rebase: rebase and force-push only your
  own PR branch (`--force-with-lease`). Where force-pushing isn't possible,
  push the rebased commits as a new branch, open a replacement PR and close
  the old one with a link to it.
- Never force-push `main` or delete branches.

## Changes to the cluster

- Check with `k8s/apply --diff` before applying; say in the PR what the diff
  showed and what was tested (e.g. on a throwaway kind cluster).
- Say which pods restart and which manual steps remain (objects to delete by
  hand: nothing is pruned).
- Secrets never go into the repo; see `k8s/apply-secrets`.
- To switch an app off for a while, set `replicas: 0` (charts:
  `installed: false` in `helmfile.yaml`, which uninstalls the release).
  Don't comment it out of a kustomization: nothing is pruned, so its objects
  stay in the cluster, and the files stop being checked.
- To retire an app, delete its directory and add it to "Removed apps" in
  `k8s/README.md`.
