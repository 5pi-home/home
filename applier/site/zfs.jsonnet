local k = import "github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet";
k.core.v1.list.new([
  k.storage.v1.storageClass.new("zfs-" + pool) +
  k.storage.v1.storageClass.withAllowVolumeExpansion(true) +
  k.storage.v1.storageClass.withProvisioner("zfs.csi.openebs.io") +
  k.storage.v1.storageClass.withParameters({
    recordsize: "4k",
    compression: "off",
    dedup: "off",
    fstype: "zfs",
    poolname: "pool-" + pool,
  }) +
  k.storage.v1.storageClass.withAllowedTopologies([{
    matchLabelExpressions: [{
      key: "kubernetes.io/hostname",
      values: [ "filer" ]
    }]
  }]) for pool in [ "mirror", "stripe-nvme"]])
