local ingress = import 'contrib/ingress-nginx/main.json';
local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';
local default_config = {
  host_mode: false,  // host_mode disables the service and runs ingress-nginx on host networking
  node_selector: error 'Must define node_selector when using host_mode',
};

{
  new(user_config):
    local config = default_config + user_config;
    ingress +
    if config.host_mode then {
      'ingress-nginx-controller-service':: super['ingress-nginx-controller-service'],
      'ingress-nginx-controller-deployment'+:
        k.apps.v1.deployment.spec.strategy.withType('Recreate') +
        k.apps.v1.deployment.spec.template.spec.withHostNetwork(true) +
        k.apps.v1.deployment.spec.template.spec.withNodeSelectorMixin(config.node_selector),
    } else {},
}
