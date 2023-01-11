local k = import 'k.libsonnet';
local fpl = import 'fpl.libsonnet';
local cert_manager = fpl.apps.cert_manager;

local domain = 'd.42o.de';
local image_registry = 'registry.' + domain;
local tls_issuer = 'letsencrypt-production';

local minecraft_version = '1.18.1';
local papermc_build = '197';

local minecraft_config = {
  papermc_url: 'https://papermc.io/api/v2/projects/paper/versions/' + minecraft_version + '/builds/' + papermc_build + '/downloads/paper-' + minecraft_version + '-' + papermc_build + '.jar',
  single_node: false,
  plugins: [
    (import 'github.com/discordianfish/minecraft/apps/minecraft/plugins/amk_mc_auth_se.jsonnet'),
    (import 'github.com/discordianfish/minecraft/apps/minecraft/plugins/grief_prevention.jsonnet'),
    (import 'github.com/discordianfish/minecraft/apps/minecraft/plugins/geyser.jsonnet'),
    (import 'github.com/discordianfish/minecraft/apps/minecraft/plugins/dynmap.jsonnet'),
    (import 'github.com/discordianfish/minecraft/apps/minecraft/plugins/prometheus_exporter.jsonnet'),
  ],
  memory_limit_mb: 4 * 1024,
  build_job: true,
};

local minecraft_app = (import 'github.com/discordianfish/minecraft/apps/minecraft/main.jsonnet').new(
  minecraft_config {
    image: image_registry + '/minecraft:' + std.md5(
      std.manifestJsonEx(minecraft_config { jb_sum: 'FIXME' }, ' ')
    ),
  }
);

minecraft_app.manifests {
                    container+: k.core.v1.container.resources.withRequests({ memory: minecraft_config.memory_limit_mb + 'M' }),
                    deployment+: k.apps.v1.deployment.metadata.withNamespace('minecraft') +
                                 k.apps.v1.deployment.spec.template.metadata.withAnnotationsMixin({ 'prometheus.io/scrape': 'true', 'prometheus.io/port': '9225' }),
                    podman_build_job+: k.batch.v1.job.metadata.withNamespace('minecraft') +
                                       k.batch.v1.job.spec.template.spec.withNodeSelector({ 'kubernetes.io/hostname': 'filer' }),
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
}
