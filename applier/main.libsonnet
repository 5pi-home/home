local k = import "ksonnet-lib/ksonnet.beta.4/k.libsonnet";
local configMap = k.core.v1.configMap;

local kubernetes_mixins = import "kubernetes-mixins/mixin.libsonnet";


// std.manifestYamlDoc(kubernetes_mixins.prometheusAlerts)
[
  configMap.new("prometheus") +
  configMap.withData({
      'prometheus.yaml': 'oo',
      "alerts.yaml": std.manifestYamlDoc(kubernetes_mixins.prometheusAlerts),
      "rules.yaml": std.manifestYamlDoc(kubernetes_mixins.prometheusRules),
  }),
  configMap.new("grafana") +
  configMap.withData(kubernetes_mixins.grafanaDashboards)
]
 // (import "kubernetes-mixins/mixin.libsonnet").prometheusAlerts)
