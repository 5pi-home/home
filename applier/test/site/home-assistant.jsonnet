local util = import 'util.libsonnet';

local HomeAssistant = (import 'home_assistant/main.libsonnet') + {
  _config+:: {
    external_domain: 'home.example.com',
  }
};

util.toList(
  HomeAssistant +
  HomeAssistant.withDevice("/dev/ACM0")
)
