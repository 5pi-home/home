local domain = 'd.42o.de';
local namespace = 'media';
local media_path = '/pool-mirror/media';

local config = (importstr 'media/nzbget.conf') % {
  server1_username: std.extVar('media_server1_username'),
  server1_password: std.extVar('media_server1_password'),
};

local NzbGet = (import 'nzbget/main.libsonnet') + {
  _config+:: {
    external_domain: 'nzbget.' + domain,
    namespace: namespace,
    config: config,
    storage_class: 'zfs-stripe-nvme',
    media_path: media_path,
  },
};

local sonarr = (import 'sonarr/main.jsonnet') + {
  _config+:: {
    namespace: namespace,
    host: 'sonarr.' + domain,
    storage_class: 'zfs-stripe-nvme',
    media_path: media_path,
  },
};

NzbGet.all + sonarr.all
