local k = import 'k.libsonnet';

local domain = 'd.42o.de';
local image_registry = 'registry.' + domain;
local version = std.extVar('version');
local jb_dep_sums = {
  [dep.source.git.remote]: dep.sum

  for dep in std.extVar('jsonnetfile_lock').dependencies
};

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
    nzbget+: {
      image: image_registry + '/nzbget:' + std.md5(std.manifestJsonEx($.nzbget.image.spec.containerfile, '  ')),
    },
    sonarr+: {
      image: image_registry + '/sonarr:' + std.md5(std.manifestJsonEx($.sonarr.image.spec.containerfile, '  ')),
    },
    radarr+: {
      image: image_registry + '/radarr:' + std.md5(std.manifestJsonEx($.radarr.image.spec.containerfile, '  ')),
    },
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
  _grafana+:: {
    _config+:: {
      grafana+:: {
        dashboards+:: {
          'minecraft-server.json': (import 'files/grafana-dashboards/minecraft-server-dashboard.json'),
          'minecraft-players.json': (import 'files/grafana-dashboards/minecraft-players-dashboard.json'),
        },
      },
    },
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

local minecraft_config = {
  papermc_url: 'https://papermc.io/api/v2/projects/paper/versions/1.18.1/builds/134/downloads/paper-1.18.1-134.jar',
  single_node: true,
  plugins: [
    (import 'github.com/discordianfish/minecraft/apps/minecraft/plugins/amk_mc_auth_se.jsonnet'),
    (import 'github.com/discordianfish/minecraft/apps/minecraft/plugins/grief_prevention.jsonnet'),
    (import 'github.com/discordianfish/minecraft/apps/minecraft/plugins/geyser.jsonnet'),
    (import 'github.com/discordianfish/minecraft/apps/minecraft/plugins/dynmap.jsonnet'),
    (import 'github.com/discordianfish/minecraft/apps/minecraft/plugins/prometheus_exporter.jsonnet'),
  ],
  memory_limit_mb: 4.0 * 1024,
  build_job: true,
};

local minecraft_app = (import 'github.com/discordianfish/minecraft/apps/minecraft/main.jsonnet').new(
  minecraft_config {
    image: image_registry + '/minecraft:' + std.md5(
      std.manifestJsonEx(minecraft_config { jb_sum: jb_dep_sums['https://github.com/discordianfish/minecraft.git'] }, ' ')
    ),
  }
);

local minecraft = minecraft_app.manifests {
  container+: k.core.v1.container.resources.withRequests({ memory: minecraft_config.memory_limit_mb + 'M' }),
  deployment+: k.apps.v1.deployment.metadata.withNamespace('minecraft') +
               k.apps.v1.deployment.spec.template.metadata.withAnnotationsMixin({ 'prometheus.io/scrape': 'true', 'prometheus.io/port': '9225' }) +
               k.apps.v1.deployment.spec.template.spec.withNodeSelector({ 'kubernetes.io/hostname': 'pluto' }),
  podman_build_job+: k.batch.v1.job.metadata.withNamespace('minecraft') +
                     k.batch.v1.job.spec.template.spec.withNodeSelector({ 'kubernetes.io/hostname': 'filer' }),
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
      host: image_registry,
      storage_class: 'zfs-stripe-ssd',
      htpasswd: std.extVar('registry_htpasswd'),
    }) + {
      ingress+: k.networking.v1.ingress.metadata.withAnnotationsMixin({
        'nginx.ingress.kubernetes.io/enable-global-auth': 'false',
        'nginx.ingress.kubernetes.io/proxy-body-size': '0',
      }),
    } + cert_manager.withCertManagerTLS(tls_issuer),
    imagecontroller: fpl.apps.k8s_image_controller.new({
      namespace: 'kube-system',
      image_ref: 'caa47c5b000c7c2b80b944d982a6ba067bf949a5',
      image_registry: image_registry,
      image_tag: std.md5(std.manifestJsonEx($['kube-system'].imagecontroller.image.spec.containerfile, '  ')),
    }) + {
      serviceaccount+: k.core.v1.serviceAccount.withImagePullSecrets([{ name: 'image-pull-secret' }]),
      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector({
        'kubernetes.io/arch': 'amd64',
      }),
    },
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
      server_args: ['--auth-mode', 'server'],
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
    deployer: {
      service_account: k.core.v1.serviceAccount.new('ci-deployer') +
                       k.core.v1.serviceAccount.metadata.withNamespace('ci') +
                       k.core.v1.serviceAccount.withImagePullSecrets([{ name: 'image-pull-secret' }]),
      admin_cluster_role_binding:
        k.rbac.v1.clusterRoleBinding.new('ci-deployer-admin') +
        k.rbac.v1.clusterRoleBinding.roleRef.withApiGroup('rbac.authorization.k8s.io') +
        k.rbac.v1.clusterRoleBinding.roleRef.withKind('ClusterRole') +
        k.rbac.v1.clusterRoleBinding.roleRef.withName('cluster-admin') +
        k.rbac.v1.clusterRoleBinding.withSubjects([
          k.rbac.v1.subject.fromServiceAccount(self.service_account),
        ]),
    },
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
