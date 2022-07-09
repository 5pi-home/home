# home
*personal infrastructure for cloud native nerds*

- Kubernetes based personal infrastucture

## Bootstrapping
Create secret to allow build-site-job to clone pass repo:

```
ssh-keyscan github.com > /tmp/github-keyscan 2>&1
pass home/5pi-home-deploy-key | \
  kubectl create secret generic 5pi-home-deploy-key \
    --from-file=id_rsa=/dev/stdin \
    --from-file=known_hosts=/tmp/github-keyscan
```

## TODO
- [ ] Fix whatever is deleting the flannel routes from openwrt
- [ ] Fix coredns forwarding statement (default config with resolv.conf doesn't seem to work)