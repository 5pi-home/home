local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';

local domain = 'd.42o.de';

local fplibs = {
  release: import 'github.com/5pi/jsonnet-libs/main.libsonnet',
  dev: import '../jsonnet-libs/main.libsonnet',
};

local fpl = if std.extVar('fpl_local') == 'true' then fplibs.dev else fplibs.release;


local cert_manager = (import '../jsonnet-libs/apps/cert-manager/main.jsonnet');
local tls_issuer = 'letsencrypt-production';
local zfs = fpl.stacks.zfs {
  _config+: {
    pools: ['mirror', 'stripe-ssd'],
  },
};

local media = fpl.stacks.media {
  _config+: {
    domain: domain,
    storage_class: 'zfs-stripe-ssd',
    media_path: '/pool-mirror/media',

    usenet: {
      server1_username: std.extVar('media_server1_username'),
      server1_password: std.extVar('media_server1_password'),
    },

    timezone: 'Europe/Berlin',
    plex_env: [{ name: 'PLEX_CLAIM', value: std.extVar('media_plex_claim_token') }],
  },
  nzbget+: cert_manager.withCertManagerTLS(tls_issuer),
  radarr+: cert_manager.withCertManagerTLS(tls_issuer),
  sonarr+: cert_manager.withCertManagerTLS(tls_issuer),
  plex+: cert_manager.withCertManagerTLS(tls_issuer),
};

local monitoring = fpl.stacks.monitoring {
  _config+:: {
    prometheus+: {
      host: 'prometheus.' + domain,
      storage_class: 'zfs-stripe-ssd',
      storage_size: '10G',
      prometheus_config+: {
        scrape_configs+: [
          {
            job_name: 'pluto-node-exporter',
            static_configs: [{
              targets: ['78.47.234.52:9100'],
            }],
          },
          {
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
          },
          {
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
          },
          {
            job_name: 'mouldy',
            static_configs: [{
              targets: ['n-office', 'n-bedroom', 'n-living'],
            }],
          },
        ],
      },

    },
    node_exporter+: {
      args: ['--collector.ethtool'],
    },
    grafana+: {
      external_domain: 'grafana.' + domain,
    },
  },
  prometheus+: {
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
  } + cert_manager.withCertManagerTLS(tls_issuer),
  // grafana+: cert_manager.withCertManagerTLS(tls_issuer),
};

local home_automation = fpl.stacks['home-automation'] {
  _config+: {
    domain: domain,
    node_selector: { 'kubernetes.io/hostname': 'rpi-living' },
    mqtt_node_selector: { 'kubernetes.io/hostname': 'openwrt' },
  },
  home_assistant+: cert_manager.withCertManagerTLS(tls_issuer),
  zwave2mqtt+: cert_manager.withCertManagerTLS(tls_issuer),
};

local ingress_nginx = fpl.apps['ingress-nginx'].new({
  host_mode: true,
  node_selector: { 'kubernetes.io/hostname': 'openwrt' },
});

local auth_host = 'auth-internal.' + domain;
local auth_port = 8080;

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
      'ingress-nginx-controller-dummy-server-service': k.core.v1.service.new(
        'auth-internal',
        {
          'app.kubernetes.io/component': 'controller',
          'app.kubernetes.io/instance': 'ingress-nginx',
          'app.kubernetes.io/name': 'ingress-nginx',
        },
        k.core.v1.servicePort.new(auth_port, auth_port),
      ) + k.core.v1.service.metadata.withNamespace(ingress_nginx['ingress-nginx-controller-deployment'].metadata.namespace),
      'auth-ingress': k.networking.v1.ingress.new('auth-internal') +
                      k.networking.v1.ingress.metadata.withNamespace(ingress_nginx['ingress-nginx-controller-deployment'].metadata.namespace) +
                      k.networking.v1.ingress.metadata.withAnnotations({
                        'nginx.ingress.kubernetes.io/auth-type': 'basic',
                        'nginx.ingress.kubernetes.io/auth-secret': 'basic-auth',
                        'nginx.ingress.kubernetes.io/auth-realm': 'Authentication Required - auth',
                        'nginx.ingress.kubernetes.io/enable-global-auth': 'false',
                        'nginx.ingress.kubernetes.io/server-snippet': |||
                          if ($remote_addr ~* "192.168.1.") {
                            return 200; // FIXME DOES NOT WORK
                            break;
                          }
                        |||,
                      }) +
                      k.networking.v1.ingress.spec.withRules(
                        k.networking.v1.ingressRule.withHost(auth_host) +
                        k.networking.v1.ingressRule.http.withPaths(
                          k.networking.v1.httpIngressPath.withPath('/') +
                          k.networking.v1.httpIngressPath.withPathType('Prefix') +
                          k.networking.v1.httpIngressPath.backend.service.withName('auth-internal') +
                          k.networking.v1.httpIngressPath.backend.service.port.withNumber(8080)
                        )
                      ),
      'ingress-nginx-controller-configmap'+: {
        data: {
          'global-auth-url': 'http://' + auth_host,
          //'whitelist-source-range': '192.168.1.0/24',
          'main-snippet': 'user root;',  // Required for nginx to be able to read passwd files written by ingress controller
          'http-snippet': |||
            server {
              listen %d default_server;
              location / {
                return 200 OK;
              }
            }
          ||| % auth_port,
        },
      },
    },
  },
  jupyter: {
    jupyter: (import 'github.com/5pi/jsonnet-libs/apps/jupyterlab/main.libsonnet').new({
      host: 'jupyter.' + domain,
      node_selector: { 'kubernetes.io/hostname': 'filer' },
      data_path: '/pool-mirror/jupyter',
    }) + cert_manager.withCertManagerTLS(tls_issuer),
  },

  'cert-manager': {
    'cert-manager': cert_manager.new({
      email: 'acme@5pi.de',
      args: [
        '--default-issuer-name=letsencrypt-staging',
        '--default-issuer-kind=ClusterIssuer',
        '--default-issuer-group=cert-manager.io',
      ],
    }) + {
      'cluster-issuer-letsencrypt-staging': cert_manager.acme_issuer('acme@5pi.de', 'nginx'),
      'cluster-issuer-letsencrypt-production': cert_manager.acme_issuer('acme@5pi.de', 'nginx', env='production'),
    },
  },
  monitoring: monitoring,
  media: media,
  home_automation: home_automation,
})
