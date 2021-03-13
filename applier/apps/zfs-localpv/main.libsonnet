local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';
local zfs = import 'zfs-operator.json';

local version = '1.4.0';
local driver_image = 'openebs/zfs-driver:' + version;

local nameMap(containers) = { [c.name]: c for c in containers };

// - adds amd64 node selector since that appears to be the only platform supported
// - pins zfs driver version
zfs {
  'openebs-zfs-controller-statefulset'+:
    k.apps.v1.statefulSet.spec.template.spec.withContainers(
      std.objectValues(
        nameMap(zfs['openebs-zfs-controller-statefulset'].spec.template.spec.containers) + { 'openebs-zfs-plugin'+: { image: driver_image } }
      )
    ) +
    k.apps.v1.statefulSet.spec.template.spec.withNodeSelectorMixin({ 'beta.kubernetes.io/arch': 'amd64' }),

  'openebs-zfs-node-daemonset'+:
    k.apps.v1.daemonSet.spec.template.spec.withContainers(
      std.objectValues(
        nameMap(zfs['openebs-zfs-node-daemonset'].spec.template.spec.containers) + { 'openebs-zfs-plugin'+: { image: driver_image } }
      )
    ) +
    k.apps.v1.daemonSet.spec.template.spec.withNodeSelectorMixin({ 'beta.kubernetes.io/arch': 'amd64' }),
}
