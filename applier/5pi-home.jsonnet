local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';

local domain = 'd.42o.de';
local site = (import 'lib/site.jsonnet');

local zfs = (import 'stacks/zfs.jsonnet') + {
  _config+: {
    pools: ['mirror', 'stripe-nvme'],
  },
};

local media = (import 'stacks/media.jsonnet') + {
  _config+: {
    domain: domain,
    storage_class: 'zfs-stripe-nvme',
    media_path: '/pool-mirror/media',

    usenet: {
      server1_username: std.extVar('media_server1_username'),
      server1_password: std.extVar('media_server1_password'),
    },
  },
};

local monitoring = (import 'stacks/monitoring.jsonnet') + {
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
          targets: ['78.47.234.52:9100'],
        }],
      }, {
        job_name: 'pluto-kubelet',
        scheme: 'https',
        tls_config: {
          ca_file: '/etc/prometheus/pluto-kubelet-ca/ca.pem',
          cert_file: '/etc/prometheus/pluto-kubelet/tls.crt',
          key_file: '/etc/prometheus/pluto-kubelet/tls.key',
          insecure_skip_verify: true,
        },
        static_configs: [{
          targets: [
            '78.47.234.52:10250',
            '78.47.234.52:10250',
          ],
        }],
      }, {
        job_name: 'pluto-cadvisor',
        scheme: 'https',
        tls_config: {
          ca_file: '/etc/prometheus/pluto-kubelet-ca/ca.pem',
          cert_file: '/etc/prometheus/pluto-kubelet/tls.crt',
          key_file: '/etc/prometheus/pluto-kubelet/tls.key',
          insecure_skip_verify: true,
        },
        metrics_path: '/metrics/cadvisor',
        static_configs: [{
          targets: [
            '78.47.234.52:10250',
          ],
        }],
      }],
    },
    container+: {
      volumeMounts+: [
        k.core.v1.volumeMount.new('kubelet-pluto-ca', '/etc/prometheus/pluto-kubelet-ca'),
        k.core.v1.volumeMount.new('kubelet-pluto', '/etc/prometheus/pluto-kubelet'),
      ],
    },
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            volumes+: [
              k.core.v1.volume.fromConfigMap('kubelet-pluto-ca', 'kubelet-pluto-ca'),
              k.core.v1.volume.fromSecret('kubelet-pluto', 'kubelet-pluto'),
            ],
          },
        },
      },
    },
  },
};

site.render({
  zfs: zfs,
  monitoring: monitoring,
  media: media,
})
