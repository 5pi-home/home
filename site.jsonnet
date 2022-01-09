local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';

local domain = 'd.42o.de';

local fplibs = {
  release: import 'github.com/5pi/jsonnet-libs/main.libsonnet',
  dev: import '../jsonnet-libs/main.libsonnet',
};

local fpl = if std.extVar('fpl_local') == 'true' then fplibs.dev else fplibs.release;

local cert_manager = fpl.apps.cert_manager;
local tls_issuer = 'letsencrypt-production';
local zfs = fpl.stacks.zfs {
  _config+: {
    pools: [
      {
        name: 'zfs-mirror',
        pool_name: 'pool-mirror',
        hostname: 'filer',
      },
      {
        name: 'zfs-stripe-ssd',
        pool_name: 'pool-stripe-ssd',
        hostname: 'filer',
      },
      {
        name: 'pool-mirror-hdd',
        hostname: 'filer',
      },
    ],
  },
};

local media = fpl.stacks.media {
  _config+: {
    domain: domain,
    storage_class: 'zfs-stripe-ssd',
    media_path: '/pool-mirror-hdd/media',

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
            job_name: 'macbook-node-exporter',
            static_configs: [{
              targets: ['192.168.1.188:9100'],
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

local minecraft =
  (import 'github.com/discordianfish/minecraft/lib/minecraft/kubernetes.jsonnet') +
  {
    _config+: {
      image: 'fish/minecraft:1a0cbc486a56a58b1fed7e0ce5a922e35fbd3ab0',
      single_node: false,
      memory_limit: 4 * 1024 + 'M',
    },
    // container:: super,
    deployment+: k.apps.v1.deployment.metadata.withNamespace('minecraft'),
  } +
  fpl.lib.app.withPVC('minecraft', '50G', '/data', 'zfs-stripe-ssd') +
  fpl.lib.app.withWeb('minecraft.' + domain, 8123) +
  cert_manager.withCertManagerTLS(tls_issuer) + {
    ingress+: k.networking.v1.ingress.metadata.withAnnotationsMixin({
      'nginx.ingress.kubernetes.io/enable-global-auth': 'false',
    }),
    service+: k.core.v1.service.spec.withPortsMixin([
      k.core.v1.servicePort.newNamed('game', 25565, 25565),
      k.core.v1.servicePort.newNamed('game-udp', 19132, 19132) +
      k.core.v1.servicePort.withProtocol('UDP'),
    ]),
  };

local manifests = fpl.lib.site.build({
  cluster_scope: {
    storage: {
      volume_snapshot_class: {
        kind: 'VolumeSnapshotClass',
        apiVersion: 'snapshot.storage.k8s.io/v1beta1',
        metadata: {
          name: 'default-snapshot-class',
          annotations: {
            'snapshot.storage.kubernetes.io/is-default-class': 'true',
          },
        },
        driver: 'zfs.csi.openebs.io',
        deletionPolicy: 'Delete',
      },
    },
  },
  'kube-system': {
    coredns: {
      configmap:
        k.core.v1.configMap.new(
          'coredns', { Corefile: importstr 'files/Corefile' }
        ) +
        k.core.v1.configMap.metadata.withNamespace('kube-system'),
    },
    openwrt: {
      _port:: 5080,
      ingress_rule:: k.networking.v1.ingressRule.withHost('openwrt.' + domain) +
                     k.networking.v1.ingressRule.http.withPaths([
                       k.networking.v1.httpIngressPath.withPath('/') +
                       k.networking.v1.httpIngressPath.withPathType('Prefix') +
                       k.networking.v1.httpIngressPath.backend.service.withName(self.service.metadata.name) +
                       k.networking.v1.httpIngressPath.backend.service.port.withNumber(self._port),
                     ]),
      ingress: k.networking.v1.ingress.new('openwrt') +
               k.networking.v1.ingress.metadata.withNamespace(self.service.metadata.namespace) +
               k.networking.v1.ingress.spec.withRules([self.ingress_rule]) +
               cert_manager.ingressCertManagerTLSMixin(self.ingress_rule.host, tls_issuer),

      service: k.core.v1.service.new('openwrt', {}, k.core.v1.servicePort.new(self._port, self._port)) +
               k.core.v1.service.metadata.withNamespace('kube-system') +
               k.core.v1.service.spec.withType('ExternalName') +
               k.core.v1.service.spec.withExternalName('localhost'),
    },
    'fuse-device-plugin': fpl.apps.fuse_device_plugin.new({
      node_selector: { 'kubernetes.io/arch': 'amd64' },
    }),
    registry: fpl.apps.registry.new({
      host: 'registry.' + domain,
      storage_class: 'zfs-stripe-ssd',
      htpasswd: std.extVar('registry_htpasswd'),
    }) + {
      ingress+: k.networking.v1.ingress.metadata.withAnnotationsMixin({
        'nginx.ingress.kubernetes.io/enable-global-auth': 'false',
        'nginx.ingress.kubernetes.io/proxy-body-size': '0',
      }),
    } + cert_manager.withCertManagerTLS(tls_issuer),
  },
  zfs: zfs,
  ingress: {
    ingress_nginx: ingress_nginx {
      local container = ingress_nginx['ingress-nginx-controller-deployment'].spec.template.spec.containers[0],
      // FIXME: We need to run as root since capabilities seem not to work on my openwrt image
      'ingress-nginx-controller-deployment'+: k.apps.v1.deployment.spec.template.spec.withContainers(
        [
          container +
          k.core.v1.container.securityContext.withRunAsUser(0) +
          k.core.v1.container.securityContext.capabilities.withDrop([]) +
          k.core.v1.container.withArgs(container.args + ['--tcp-services-configmap=$(POD_NAMESPACE)/tcp-services', '--udp-services-configmap=$(POD_NAMESPACE)/udp-services']),
        ]
      ),
      'tcp-services-configmap': k.core.v1.configMap.new('tcp-services', { '25565': 'minecraft/minecraft:25565' }) + k.core.v1.configMap.metadata.withNamespace(ingress_nginx['ingress-nginx-controller-deployment'].metadata.namespace),
      'udp-services-configmap': k.core.v1.configMap.new('udp-services', { '19132': 'minecraft/minecraft:19132' }) + k.core.v1.configMap.metadata.withNamespace(ingress_nginx['ingress-nginx-controller-deployment'].metadata.namespace),
      'ingress-nginx-controller-configmap'+: {
        data: {
          'global-auth-url': 'https://oauth2-proxy.' + domain + '/oauth2/auth',
          'global-auth-signin': 'https://oauth2-proxy.' + domain + '/start?rd=$scheme://$host$request_uri',
          'main-snippet': 'user root;',  // Required for nginx to be able to read passwd files written by ingress controller
        },
      },
    },
    oauth2_proxy: fpl.apps.oauth2_proxy.new({
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
    jupyter: fpl.apps.jupyterlab.new({
      host: 'jupyter.' + domain,
      node_selector: { 'kubernetes.io/hostname': 'filer' },
      data_path: '/pool-mirror-hdd/jupyter',
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
  minecraft: {
    minecraft: minecraft,
  },
  monitoring: monitoring,
  media: media,
  home_automation: home_automation,
  argo: {
    argo: fpl.apps.argo.new({
      node_selector: { 'kubernetes.io/arch': 'amd64' },
      config: {
        containerRuntimeExecutor: 'emissary',
      },
    }),
  },
  ci: {
    k8s_webhook_handler: fpl.apps.k8s_webhook_handler.new({
      host: 'k8s-webhook-handler.' + domain,
      webhook_secret: std.extVar('k8s_webhook_handler_webhook_secret'),
      github_username: '5pi-bot',
      github_token: std.extVar('k8s_webhook_handler_github_token'),
      node_selector: { 'kubernetes.io/arch': 'amd64' },
      rbac_rules: [
        k.rbac.v1.policyRule.withApiGroups('argoproj.io') +
        k.rbac.v1.policyRule.withResources('workflows') +
        k.rbac.v1.policyRule.withVerbs('create'),
      ],
    }) + {
      ingress+: k.networking.v1.ingress.metadata.withAnnotationsMixin(
        {
          'nginx.ingress.kubernetes.io/enable-global-auth': 'false',
        },
      ),
      service_account+: k.core.v1.serviceAccount.withImagePullSecrets([{ name: 'image-pull-secret' }]),
    } + cert_manager.withCertManagerTLS(tls_issuer),
  },
});

local namespaces = std.uniq(std.sort([
  manifest.metadata.namespace
  for manifest in std.filter(
    function(manifest) std.objectHas(manifest, 'metadata') && std.objectHas(manifest.metadata, 'namespace'),
    std.objectValues(manifests)
  )
]));

local dockerconfigjson = {
  auths: {
    ['registry.' + domain]: {
      username: 'default',
      password: std.extVar('registry_password'),
      auth: std.base64('default:' + std.extVar('registry_password')),
    },
  },
};

local image_pull_secret = k.core.v1.secret.new('image-pull-secret', {
  '.dockerconfigjson': std.base64(std.manifestJson(dockerconfigjson)),
}) + k.core.v1.secret.withType('kubernetes.io/dockerconfigjson');

fpl.lib.site.render(manifests + {
  [namespace + '-namespace.yaml']: k.core.v1.namespace.new(namespace)
  for namespace in namespaces
} + {
  [namespace + '-image-pull-secrets.yaml']:
    image_pull_secret +
    k.core.v1.secret.metadata.withNamespace(namespace)
  for namespace in namespaces
} + {
  [namespace + '-default-serviceaccount.yaml']:
    k.core.v1.serviceAccount.new('default') +
    k.core.v1.serviceAccount.metadata.withNamespace(namespace) +
    k.core.v1.serviceAccount.withImagePullSecrets({ name: image_pull_secret.metadata.name })
  for namespace in namespaces
})
