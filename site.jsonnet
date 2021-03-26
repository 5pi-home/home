local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';

local domain = 'd.42o.de';
local fpl = (import 'github.com/5pi/jsonnet-libs/main.libsonnet');

local zfs = fpl.stacks.zfs + {
  _config+: {
    pools: ['mirror', 'stripe-nvme'],
  },
};

local media = fpl.stacks.media + {
  _config+: {
    domain: domain,
    storage_class: 'zfs-stripe-nvme',
    media_path: '/pool-mirror/media',

    usenet: {
      server1_username: std.extVar('media_server1_username'),
      server1_password: std.extVar('media_server1_password'),
    },

    timezone: 'Europe/Berlin',
    plex_env: [{ name: 'PLEX_CLAIM', value: std.extVar('media_plex_claim_token') }],
  },
};

local monitoring = fpl.stacks.monitoring + {
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

local home_automation = fpl.stacks['home-automation'] + {
  _config+: {
    domain: domain,
    node_selector: { 'kubernetes.io/hostname': 'rpi-living' },
    mqtt_node_selector: { 'kubernetes.io/hostname': 'openwrt' },
  },
};

local ingress_nginx = fpl.apps['ingress-nginx'].new({
  host_mode: true,
  node_selector: { 'kubernetes.io/hostname': 'openwrt' },
});

fpl.lib.site.render({
  zfs: zfs,
  ingress: {
    ingress_nginx: ingress_nginx {
      // FIXME: We need to run as root since capabilities seem not to work on my openwrt image
      'ingress-nginx-controller-deployment'+: k.apps.v1.deployment.spec.template.spec.withContainers(
        [
          ingress_nginx['ingress-nginx-controller-deployment'].spec.template.spec.containers[0] +
          k.core.v1.container.securityContext.withRunAsUser(0) +
          k.core.v1.container.securityContext.capabilities.withDrop([]),
        ]
      ),
    },
  },
  monitoring: monitoring,
  media: media,
  home_automation: home_automation,
})
