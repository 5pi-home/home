# k8s

Plain Kubernetes manifests, one kustomization per namespace. This replaces
`site.jsonnet` one stack at a time; whatever isn't here yet is still rendered
by jsonnet.

## Layout

```
k8s/
  apply-secrets           Secrets from pass (not part of any build)
  <namespace>/
    kustomization.yaml    sets the namespace, lists the apps
    namespace.yaml
    <app>/                directory named like the app's objects
      kustomization.yaml
      deployment.yaml, service.yaml, ingress.yaml, ...
```

## Conventions

- Manifests are plain YAML as they appear in the cluster. Kustomize only sets
  the namespace and builds ConfigMaps from real files (`configMapGenerator`
  with `disableNameSuffixHash`); no patches, overlays or templating.
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
  and reference them by name.

## Use

```sh
kubectl diff -k k8s/home-automation    # needs no secrets
kubectl apply -k k8s/home-automation
k8s/apply-secrets                      # needs pass; --dry-run=server to test
```

Apply doesn't prune: an object removed from here stays in the cluster until
it's deleted by hand.
