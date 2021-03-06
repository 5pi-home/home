local k = import "github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet";
local zfs = import 'zfs-operator.json';

local version = '1.4.0';
local driver_image = 'openebs/zfs-driver:' + version;

local nameMap(containers) = { [c.name]: c for c in containers };


// - adds amd64 node selector since that appears to be the only platform supported
// - pins zfs driver version

k.core.v1.list.new([
  zfs["openebs-namespace"],
  zfs["openebs-zfs-controller-sa-serviceaccount"] +
  zfs["openebs-zfs-controller-statefulset"] + k.apps.v1.statefulSet.spec.template.spec.withContainers(
    std.objectValues(
      nameMap(zfs["openebs-zfs-controller-statefulset"].spec.template.spec.containers) + { "openebs-zfs-plugin"+: { "image": driver_image } }
    )
  ) +
  k.apps.v1.statefulSet.spec.template.spec.withNodeSelectorMixin({"beta.kubernetes.io/arch": "amd64"}),

  zfs["openebs-zfs-driver-registrar-binding-clusterrolebinding"],
  zfs["openebs-zfs-driver-registrar-role-clusterrole"],
  zfs["openebs-zfs-node-daemonset"] + k.apps.v1.daemonSet.spec.template.spec.withContainers(
    std.objectValues(
      nameMap(zfs["openebs-zfs-node-daemonset"].spec.template.spec.containers) + { "openebs-zfs-plugin"+: { "image": driver_image } }
    )
  ) +
  k.apps.v1.daemonSet.spec.template.spec.withNodeSelectorMixin({"beta.kubernetes.io/arch": "amd64"}),

  zfs["openebs-zfs-node-sa-serviceaccount"],
  zfs["openebs-zfs-provisioner-binding-clusterrolebinding"],
  zfs["openebs-zfs-provisioner-role-clusterrole"],
  zfs["openebs-zfs-snapshotter-binding-clusterrolebinding"],
  zfs["openebs-zfs-snapshotter-role-clusterrole"],
  zfs["openebs-zfspv-bin-configmap"],
  zfs["volumesnapshotclasses.snapshot.storage.k8s.io-customresourcedefinition"],
  zfs["volumesnapshotcontents.snapshot.storage.k8s.io-customresourcedefinition"],
  zfs["volumesnapshots.snapshot.storage.k8s.io-customresourcedefinition"],
  zfs["zfs.csi.openebs.io-csidriver"],
  zfs["zfsbackups.zfs.openebs.io-customresourcedefinition"],
  zfs["zfsrestores.zfs.openebs.io-customresourcedefinition"],
  zfs["zfssnapshots.zfs.openebs.io-customresourcedefinition"],
  zfs["zfsvolumes.zfs.openebs.io-customresourcedefinition"],
])
