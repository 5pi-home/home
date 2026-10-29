# k8s

Everything that runs in the cluster.

```sh
k8s/apply --diff   # show what would change
k8s/apply          # apply all of it
```

`k8s/apply` runs, in this order:

1. `helmfile.yaml`: third-party software from upstream charts (cert-manager,
   ingress-nginx, CloudNativePG, immich, vikunja). Charts come first because
   they install CRDs our manifests use.
2. `kustomization.yaml`: our own manifests, plain YAML.
3. `apply-secrets`: Secrets from `pass`.

On an empty cluster, run it twice: `cluster/zfs-localpv` installs the CRD for
the VolumeSnapshotClass in the same apply.

Needs `kubectl`, `helm` with the [helm-diff] plugin, `helmfile`, `pass`,
`htpasswd` and [yq] (mikefarah's).

[helm-diff]: https://github.com/databus23/helm-diff
[yq]: https://github.com/mikefarah/yq

## Layout

```
k8s/
  apply, apply-secrets    see above
  helmfile.yaml           third-party charts
  helm-adopt              one-off, see "Migrating from site.jsonnet"
  kustomization.yaml      lists the directories below
  cluster/                cluster-wide: storage classes, zfs-localpv driver
  <namespace>/
    kustomization.yaml    sets the namespace, lists the apps
    namespace.yaml
    <app>/                directory named like the app's objects
      kustomization.yaml
      deployment.yaml, service.yaml, ingress.yaml, config files, ...
```

## Conventions

- Third-party software comes from its upstream chart in `helmfile.yaml`, with
  a pinned version. Exception: `cluster/zfs-localpv` is vendored YAML (see its
  header).
- Our manifests are plain YAML as they appear in the cluster. Kustomize only
  sets the namespace and builds ConfigMaps from real files
  (`configMapGenerator` with `disableNameSuffixHash`); no patches, overlays or
  templating.
- No `metadata.namespace` in app manifests; the namespace kustomization sets it.
- Objects are named after the app, pods select on `name: <app>`.
- Pin the node with `nodeSelector: kubernetes.io/hostname` when an app uses
  host paths or devices.
- hostPath devices get `type: CharDevice`. Without a type, a missing device
  makes the kubelet create an empty directory in its place.
- Public ingress: `cert-manager.io/cluster-issuer: letsencrypt-production`
  plus a `tls` entry with `secretName: <host>`. Everything is behind
  oauth2-proxy unless the ingress sets
  `nginx.ingress.kubernetes.io/enable-global-auth: "false"`.
- Secrets never go into the repo or the builds. Add them to `apply-secrets`
  and reference them by name. Config files that need a secret take it from
  an environment variable (see grafana, nzbget).
- Changing a ConfigMap doesn't restart anything. Restart the app with
  `kubectl rollout restart` if it doesn't reload its config by itself.

Nothing is pruned: an object removed from here stays in the cluster until
it's deleted by hand.

## Images

`minecraft/minecraft/image/Containerfile` is our only own image. Build and
push it by hand, then update the tag in the deployment:

```sh
tag=$(date +%Y%m%d)
podman build -t registry.d.42o.de/minecraft:$tag k8s/minecraft/minecraft/image
podman login registry.d.42o.de -u default   # password: pass home/image-registry/default
podman push registry.d.42o.de/minecraft:$tag
```

## Migrating from site.jsonnet

The objects were applied with `kubectl apply` from `site.jsonnet`, so helm
refuses to take over cert-manager and ingress-nginx. Once, before the first
`k8s/apply`:

```sh
k8s/helm-adopt cert-manager
k8s/helm-adopt ingress-nginx
```

It labels the existing objects as part of the release and installs it, so
helm upgrades them in place (no downtime, CRDs and certificates stay). For
ingress-nginx it also rewrites the controller's port lists first, because
helm can't patch a port used for both TCP and UDP. With Helm 4 it installs
with client-side apply, because server-side apply conflicts with the fields
`kubectl apply` set. It's safe to rerun, e.g. after a failed `k8s/apply`.

Left over afterwards, delete by hand when convenient:

- `ingress-nginx`: ConfigMaps `tcp-services` and `udp-services` (the chart
  creates `ingress-nginx-tcp`/`-udp`).
- `monitoring`: Secrets `grafana-config`, `grafana-datasources`, ConfigMap
  `grafana-dashboards` (now ConfigMap `grafana`).
- `image-pull-secret` and the default ServiceAccount's `imagePullSecrets` in
  every namespace but `minecraft`.
- `argo`: Argo Workflows 3.2.6, unused since the CI workflow was removed.
  Not converted; `kubectl delete ns argo` plus its CRDs and ClusterRoles.
