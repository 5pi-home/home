local domain = 'd.42o.de';
local site = (import 'lib/site.jsonnet');

local media = (import 'stacks/media.jsonnet') + {
  _config+: {
    domain: domain,
    storage_class: 'zfs-stripe-nvme',
    media_path: '/pool-mirror/media',

    usenet: {
      server1_username: std.extVar('media_server1_username'),
      server1_password: std.extVar('media_server1_password'),
    }
  }
};

local monitoring = (import 'stacks/monitoring.jsonnet') + {


site.render({
  media: media,
})
