# home
*personal infrastructure for cloud native nerds*

- Kubernetes based personal infrastucture
- Manifests are moving from `site.jsonnet` to plain YAML + kustomize in
  [`k8s/`](k8s/README.md), one namespace at a time.

## Bootstrapping
Create secret to allow build-site-job to clone pass repo:

```
ssh-keyscan github.com > /tmp/github-keyscan 2>&1
pass home/5pi-home-deploy-key | \
  kubectl create secret generic 5pi-home-deploy-key \
    --from-file=id_rsa=/dev/stdin \
    --from-file=known_hosts=/tmp/github-keyscan
```
