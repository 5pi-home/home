local domain = 'd.42o.de';

local config = (importstr 'media/nzbget.conf') % {
  server1_username: std.extVar("media_server1_username"),
  server1_password: std.extVar("media_server1_password"),
};

local NzbGet = (import 'nzbget/main.libsonnet') + {
  _config+:: {
    external_domain: 'nzbget.' + domain,
    node_selector: {
      'kubernetes.io/hostname': 'openwrt'
    },
    config: config,
  }
};
NzbGet.all
