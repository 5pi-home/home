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
    grafana_config: {
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
      },
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
  grafana+: {
    ingress+: k.networking.v1.ingress.metadata.withAnnotationsMixin({
      'nginx.ingress.kubernetes.io/enable-global-auth': 'false',
    }) + cert_manager.ingressCertManagerTLSMixin($._config.grafana.external_domain, tls_issuer),
  },

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
      'ingress-nginx-controller-configmap'+: {
        data: {
          'global-auth-url': 'https://oauth2-proxy.' + domain + '/oauth2/auth',
          'global-auth-signin': 'https://oauth2-proxy.' + domain + '/start?rd=$scheme://$host$request_uri',
          'main-snippet': 'user root;',  // Required for nginx to be able to read passwd files written by ingress controller
        },
      },
    },
    oauth2_proxy: (import '../jsonnet-libs/apps/oauth2-proxy/main.libsonnet').new({
      namespace: 'ingress-nginx',
      client_id: 'd57fc7ff4afeeb24fc66',
      client_secret: std.extVar('oauth2_proxy_client_secret'),
      cookie_secret: std.extVar('oauth2_proxy_cookie_secret'),
      host: 'oauth2-proxy.' + domain,
      node_selector: { 'kubernetes.io/arch': 'amd64' },
      args: [
        '--provider=github',
        '--github-org=5pi-home',
        '--email-domain=*',
        '--upstream=file:///dev/null',
        '--cookie-domain=.' + domain,
        '--whitelist-domain=.' + domain,
      ],
    }) + cert_manager.withCertManagerTLS(tls_issuer),
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
