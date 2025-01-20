local fpl = import 'fpl.libsonnet';
local cert_manager = fpl.apps.cert_manager;

fpl.stacks.media {
  _config+: {
    storage_class: 'zfs-stripe-ssd',
    media_path: '/pool-mirror-hdd/media',

    timezone: 'Europe/Berlin',
    plex_env: [
      { name: 'PLEX_CLAIM', value: std.extVar('media_plex_claim_token') },
    ],
    nzbget+: {
      config: |||
        Server1.Active=yes
        Server1.Name=news.eweka.nl
        Server1.Host=news.eweka.nl
        Server1.Port=563
        Server1.Username=%(server1_username)s
        Server1.Password=%(server1_password)s
        Server1.Encryption=yes
        Server1.Cipher=ECDHE-RSA-AES256-GCM-SHA384
        Server1.Connections=20
        Feed1.Name=nzbgeek
        Feed1.URL=%(rss_feed)s
        HealthCheck=delete
        Category5.Name=XXX
        Category5.DestDir=/media/porn
      ||| % {
        server1_username: std.extVar('media_server1_username'),
        server1_password: std.extVar('media_server1_password'),
        rss_feed: std.extVar('media_nzbgeek_rss_feed'),
      },
    },
    sonarr+: {
       storage_size: "1Gi",
    },
  },
  nzbget+: cert_manager.withCertManagerTLS($._config.tls_issuer),
  radarr+: cert_manager.withCertManagerTLS($._config.tls_issuer),
  sonarr+: cert_manager.withCertManagerTLS($._config.tls_issuer),
  plex+: cert_manager.withCertManagerTLS($._config.tls_issuer),
  spotifyd: fpl.apps.spotifyd.new({
    image: 'docker.io/fish/spotifyd:v0.3.3',
    node_selector: { 'kubernetes.io/hostname': 'rpi-kitchen' },
    gid: 29,  // audio
  }),
  shairport_sync: fpl.apps.shairport_sync.new({
    node_selector: { 'kubernetes.io/hostname': 'rpi-kitchen' },
  }),
  pulseaudio: fpl.apps.pulseaudio.new({
    node_selector: { 'kubernetes.io/hostname': 'rpi-kitchen' },
  }),
}
