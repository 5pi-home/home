local k = import 'k.libsonnet';

local fpl = import 'fpl.libsonnet';
local cert_manager = fpl.apps.cert_manager;

fpl.stacks.monitoring {
  _config+:: {
    prometheus+: {
      host: 'prometheus.' + $._config.domain,
      storage_class: 'zfs-stripe-ssd',
      storage_size: '15G',
      prometheus_config+: {
        scrape_configs+: [
          {
            job_name: 'mouldy',
            static_configs: [{
              targets: ['n-office', 'n-bedroom', 'n-garden'],
            }],
          },
          {
            job_name: 'wmi',
            static_configs: [{
              targets: ['leviathan:9182'],
            }],
          },
          {
            job_name: 'nvidia-gpu-exporter',
            static_configs: [{
              targets: ['leviathan:9835'],
            }],
          },
          {
            job_name: 'blackbox-exporter',
            params: {
              module: ['http_2xx'],
            },
            metrics_path: '/probe',
            static_configs: [{
              targets: [
                'https://www.pyur.com/',
                'https://google.com/',
                'https://5pi.de/',
              ],
            }],
            relabel_configs: [{
              source_labels: ['__address__'],
              target_label: '__param_target',
            }, {
              source_labels: ['__param_target'],
              target_label: 'instance',
            }, {
              target_label: '__address__',
              replacement: 'blackbox-exporter:9115',
            }],
          },
          {
            job_name: 'prosafe-exporter',
            metrics_path: '/probe',
            static_configs: [{
              targets: [
                'sw-core:*',
                'sw-office:*',
              ],
            }],
            relabel_configs: [{
              source_labels: ['__address__'],
              target_label: '__param_target',
            }, {
              source_labels: ['__param_target'],
              target_label: 'instance',
            }, {
              target_label: '__address__',
              replacement: 'prosafe-exporter:9493',
            }],
          },
        ],
      },

    },
    node_exporter+: {
      args: ['--collector.ethtool'],
    },
    grafana+: {
      external_domain: 'grafana.' + $._config.domain,
      version: '9.3.2',
      dashboards+: {
        'minecraft-server.json': (import 'files/grafana-dashboards/minecraft-server-dashboard.json'),
        'minecraft-players.json': (import 'files/grafana-dashboards/minecraft-players-dashboard.json'),
        'smokeping.json': (import 'files/grafana-dashboards/smokeping.json'),
        'garden.json': (import 'files/grafana-dashboards/garden.json'),
        'prosafe.json': (import 'files/grafana-dashboards/prosafe.json'),
      },
      config: {
        sections: {
          server: {
            root_url: 'https://' + $._config.grafana.external_domain,
          },
          'auth.github': {
            enabled: true,
            allow_sign_up: true,
            client_id: '7fb952e1283dff23be79',
            client_secret: std.extVar('monitoring_grafana_oauth_client_secret'),
            scopes: 'user:email,read:org',
            auth_url: 'https://github.com/login/oauth/authorize',
            token_url: 'https://github.com/login/oauth/access_token',
            api_url: 'https://api.github.com/user',
            allowed_organizations: '5pi-home',
          },
          users: {
            viewers_can_edit: true,
          },
        },
      },
    },
  },
  grafana+: {
    ingress+: k.networking.v1.ingress.metadata.withAnnotationsMixin({
      'nginx.ingress.kubernetes.io/enable-global-auth': 'false',
    }) + cert_manager.ingressCertManagerTLSMixin($._config.grafana.external_domain, $._config.tls_issuer),
  },
  prometheus+: cert_manager.withCertManagerTLS($._config.tls_issuer),
  _grafana+:: {
    _config+:: {
      grafana+:: {
        dashboards+:: {

        },
      },
    },
  },
  smokeping_exporter: fpl.apps.smokeping_exporter.new({
    config: std.manifestYamlDoc(
      {
        targets: [{
          hosts: [
            'google.com',
            'heise.de',
            '137.221.66.43',
            '104.44.32.105',
          ],
        }],
      }
    ),
  }) + {
    deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector({
                   'kubernetes.io/hostname': 'openwrt',
                 }) +
                 k.apps.v1.deployment.spec.template.metadata.withAnnotationsMixin({ 'prometheus.io/scrape': 'true', 'prometheus.io/port': '9374' }),

  },

  prosafe_exporter: fpl.apps.prosafe_exporter.new({
    node_selector: { 'kubernetes.io/arch': 'amd64' },
  }),

  ssh_tunnel: fpl.lib.app.newWebApp('ssh-tunnel', 'kroniak/ssh-client:3.19', 'ssh-tunnel.' + $._config.domain, 9100, namespace="monitoring") + {
    secret: k.core.v1.secret.new('ssh-tunnel', {
      'id_rsa': std.base64(std.extVar('monitoring_ssh_tunnel_id_rsa') + '\n'),
      'known_hosts': std.base64(std.extVar('monitoring_ssh_tunnel_known_hosts') + '\n'),
    }) + k.core.v1.secret.metadata.withNamespace('monitoring'),
    deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector({ 'kubernetes.io/arch': 'amd64' }),
    container+: k.core.v1.container.withCommand(['ssh', '-N', '-T', '-L0.0.0.0:9100:localhost:9100', 'fish@52.117.41.204']),
    service+: k.core.v1.service.metadata.withAnnotationsMixin({
      'prometheus.io/scrape': 'true',
      'prometheus.io/port': '9100',
    }) +
    k.core.v1.service.metadata.withLabels({
      'job': 'node',
    }),
  } + fpl.lib.app.withVolumeMixin(
      k.core.v1.volume.fromSecret('ssh-tunnel', 'ssh-tunnel') +
      k.core.v1.volume.secret.withDefaultMode(std.parseOctal('0600')),
      '/root/.ssh'
    )
}
