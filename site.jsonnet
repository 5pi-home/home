local k = import 'k.libsonnet';

local domain = 'd.42o.de';
local tls_issuer = 'letsencrypt-production';
local image_registry = 'registry.' + domain;
local version = std.extVar('version');

local fpl = import 'fpl.libsonnet';


local media = (import 'media.libsonnet') + {
  _config+: {
    domain: domain,
    image_registry: image_registry,
    tls_issuer: tls_issuer,
  },
};

local monitoring = (import 'monitoring.libsonnet') + {
  _config+: {
    domain: domain,
    tls_issuer: tls_issuer,
  },
};

local minecraft = import 'minecraft.libsonnet';

local cert_manager = fpl.apps.cert_manager;
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

local home_automation = fpl.stacks['home-automation'] {
  _config+: {
    domain: domain,
    mqtt_passwd: std.extVar('mqtt_passwd'),
  },
  home_assistant+: cert_manager.withCertManagerTLS(tls_issuer) + {
    ingress+: k.networking.v1.ingress.metadata.withAnnotationsMixin({
      'nginx.ingress.kubernetes.io/enable-global-auth': 'false',
    }),
    deployment+: k.apps.v1.deployment.spec.template.spec.dnsConfig.withOptions({
      name: 'ndots',
      value: '1',
    }),
  },
  zwave2mqtt+: cert_manager.withCertManagerTLS(tls_issuer),
} + {
  'zigbee2mqtt': fpl.apps.zigbee2mqtt.new({
    namespace: 'home-automation',
    host: 'zigbee.' + domain,
    zigbee_dev: '/dev/ttyUSB0', // '/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_a8cadaff5412ef11b6466fb8bf9df066-if00-port0',
    storage_class: 'zfs-stripe-ssd',
  }) + cert_manager.withCertManagerTLS(tls_issuer),
};

local ingress_nginx = fpl.apps['ingress-nginx'].new({
  service_type: 'LoadBalancer',
  node_selector: { 'kubernetes.io/hostname': 'filer' },
});

local portmappings = {
  tcp: {
    '25565': 'minecraft/minecraft:25565',
  },
  udp: {
    '25565': 'minecraft/minecraft:25565',
    '19132': 'minecraft/minecraft:19132',
  },
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
               k.core.v1.service.spec.withExternalName('192.168.1.1'),
    },
    cam: {
      _port:: 443,
      ingress_rule:: k.networking.v1.ingressRule.withHost('cam.' + domain) +
                     k.networking.v1.ingressRule.http.withPaths([
                       k.networking.v1.httpIngressPath.withPath('/') +
                       k.networking.v1.httpIngressPath.withPathType('Prefix') +
                       k.networking.v1.httpIngressPath.backend.service.withName(self.service.metadata.name) +
                       k.networking.v1.httpIngressPath.backend.service.port.withNumber(self._port),
                     ]),
      ingress: k.networking.v1.ingress.new('cam') +
               k.networking.v1.ingress.metadata.withNamespace(self.service.metadata.namespace) +
               k.networking.v1.ingress.spec.withRules([self.ingress_rule]) +
               k.networking.v1.ingress.metadata.withAnnotationsMixin({
                 'nginx.ingress.kubernetes.io/backend-protocol': 'HTTPS',
                 'nginx.ingress.kubernetes.io/enable-global-auth': 'false',
               }) +
               cert_manager.ingressCertManagerTLSMixin(self.ingress_rule.host, tls_issuer),

      service: k.core.v1.service.new('cam', {}, k.core.v1.servicePort.new(self._port, self._port)) +
               k.core.v1.service.metadata.withNamespace('kube-system') +
               k.core.v1.service.spec.withType('ExternalName') +
               k.core.v1.service.spec.withExternalName('dafang'),
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
  },
  zfs: zfs,
  ingress: {
    ingress_nginx: ingress_nginx {
      local container = ingress_nginx['ingress-nginx-controller-deployment'].spec.template.spec.containers[0],
      'ingress-nginx-controller-deployment'+: k.apps.v1.deployment.spec.template.spec.withContainers(
        [
          container +
          k.core.v1.container.withArgs(container.args + ['--tcp-services-configmap=$(POD_NAMESPACE)/tcp-services', '--udp-services-configmap=$(POD_NAMESPACE)/udp-services', '--watch-ingress-without-class']),
        ]
      ),
      'tcp-services-configmap': k.core.v1.configMap.new('tcp-services', portmappings.tcp) + k.core.v1.configMap.metadata.withNamespace(ingress_nginx['ingress-nginx-controller-deployment'].metadata.namespace),
      'udp-services-configmap': k.core.v1.configMap.new('udp-services', portmappings.udp) + k.core.v1.configMap.metadata.withNamespace(ingress_nginx['ingress-nginx-controller-deployment'].metadata.namespace),
      'ingress-nginx-controller-configmap'+: {
        data: {
          'global-auth-url': 'https://oauth2-proxy.' + domain + '/oauth2/auth',
          'global-auth-signin': 'https://oauth2-proxy.' + domain + '/start?rd=$scheme://$host$request_uri',
        },
      },
      'ingress-nginx-controller-service'+:
        k.core.v1.service.spec.withIpFamilyPolicy('PreferDualStack') +
        k.core.v1.service.spec.withIpFamilies(['IPv4', 'IPv6']) +
        k.core.v1.service.spec.withPortsMixin(
        [
          local port = std.parseInt(p);
          k.core.v1.servicePort.newNamed(p, port, port)
          for p in std.objectFields(portmappings.tcp)
        ] + [
          local port = std.parseInt(p);
          k.core.v1.servicePort.newNamed(p + '-udp', port, port) +
          k.core.v1.servicePort.withProtocol('UDP')
          for p in std.objectFields(portmappings.udp)
        ],
      ),
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
    }) + cert_manager.withCertManagerTLS(tls_issuer) + {
      ingress+: k.networking.v1.ingress.metadata.withAnnotationsMixin(
        {
          'nginx.ingress.kubernetes.io/enable-global-auth': 'false',
        },
      ),
    },
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
  ci: (import 'ci.libsonnet') + { _config:: { domain: domain, tls_issuer: tls_issuer } },
  data: {
    rclone: fpl.apps.rclone.new({
      namespace: 'data',
      host: 'rclone.' + domain,
      image: image_registry + '/rclone:' + std.md5(std.manifestJsonEx($.data.rclone.image.spec.containerfile, '  ')),
      data_path: '/pool-mirror-hdd',
      node_selector: { 'kubernetes.io/hostname': 'filer' },
      uid: 1001,
      args: ['--config', '/data/rclone/rclone.conf'],
      jobs: [
        {
          name: 'gdrive-daily',
          schedule: '15 4 * * *',
          args: ['sync', 'GoogleDrive:/', '/data/GoogleDrive'],
        },
        {
          name: 'gphotos-daily',
          schedule: '15 4 * * *',
          args: ['sync', 'GooglePhotos:/', '/data/GooglePhotos'],
        },
      ],
    }),
    minio: fpl.apps.minio.new({
      namespace: 'data',
      host: 'minio.' + domain,
      data_path: '/pool-mirror-hdd/minio',
      node_selector: { 'kubernetes.io/hostname': 'filer' },
      uid: 1003,  // minio
      args: ['server', '/data/minio'],
    }) + cert_manager.withCertManagerTLS(tls_issuer) + {
      ingress+: k.networking.v1.ingress.metadata.withAnnotationsMixin(
        {
          'nginx.ingress.kubernetes.io/enable-global-auth': 'false',
        },
      ),
      container+: k.core.v1.container.withEnvMap({
        'MINIO_ROOT_USER': 'admin',
        'MINIO_ROOT_PASSWORD': std.extVar('minio_passwd'),
      }),
    },
  },
  /*
  web: {
    gotosocial: fpl.apps.gotosocial.new({
      host: 'gotosocial.' + domain,
      namespace: 'web',
      storage_class: 'zfs-mirror',
    }) + cert_manager.withCertManagerTLS(tls_issuer),
  },
  */
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
