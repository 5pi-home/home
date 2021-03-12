local domain = 'd.42o.de';

local k = import 'ksonnet.beta.4/k.libsonnet';
local container = k.apps.v1.deployment.mixin.spec.template.spec.containersType;
local volume = k.apps.v1.deployment.mixin.spec.template.spec.volumesType;
local containerVolumeMount = container.volumeMountsType;
local configMap = k.core.v1.configMap;

local plutoCAvm = containerVolumeMount.new("kubelet-pluto-ca", "/etc/prometheus/pluto-kubelet-ca");
local plutoCAv = volume.withName("kubelet-pluto-ca") + volume.mixin.configMap.withName("kubelet-pluto-ca");

local plutoCertvm = containerVolumeMount.new("kubelet-pluto", "/etc/prometheus/pluto-kubelet");
local plutoCertv = volume.withName("kubelet-pluto") + { secret: { secretName: "kubelet-pluto" } };

local Monitoring = (import 'monitoring/main.libsonnet') + {
  _config+:: {
    prometheus+: {
      external_domain: 'prometheus.' + domain,
      storage_class: 'zfs-stripe-nvme',
    },
    grafana+: {
      external_domain: 'grafana.' + domain,
    },
  },
  prometheus+: {
    prometheus_config+: {
      scrape_configs+: [{
        job_name: 'pluto-node-exporter',
        static_configs: [{
          targets: [ "78.47.234.52:9100" ],
        }],
      }, {
        job_name: 'pluto-kubelet',
        scheme: 'https',
        tls_config: {
          ca_file: "/etc/prometheus/pluto-kubelet-ca/ca.pem",
          cert_file: "/etc/prometheus/pluto-kubelet/tls.crt",
          key_file: "/etc/prometheus/pluto-kubelet/tls.key",
          insecure_skip_verify: true
        },
        static_configs: [{
          targets: [
            "78.47.234.52:10250",
            "78.47.234.52:10250"
          ],
        }],
      }, {
        job_name: 'pluto-cadvisor',
        scheme: 'https',
        tls_config: {
          ca_file: "/etc/prometheus/pluto-kubelet-ca/ca.pem",
          cert_file: "/etc/prometheus/pluto-kubelet/tls.crt",
          key_file: "/etc/prometheus/pluto-kubelet/tls.key",
          insecure_skip_verify: true
        },
        metrics_path: '/metrics/cadvisor',
        static_configs: [{
          targets: [
            "78.47.234.52:10250",
          ],
        }]
      }]
    },
    container+: {
      volumeMounts+: [plutoCAvm, plutoCertvm ]
    },
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            volumes+: [plutoCAv, plutoCertv]
          }
        }
      }
    }
  },
};
Monitoring.all
