// Prometheus rules and Grafana dashboards from the upstream mixins, configured
// for this cluster. Rendered by ./build into ../prometheus and
// ../grafana/dashboards; don't edit those files by hand.
local kubernetes = (import 'kubernetes-mixin/mixin.libsonnet') + {
  _config+:: {
    nodeExporterSelector: 'job="node"',
    // k3s runs the scheduler, controller-manager and kube-proxy in the k3s
    // process, which serves all their metrics on the apiserver's and the
    // kubelet's /metrics. The kube-apiserver job has the scheduler and
    // controller-manager; kube-proxy runs on every node, so use the kubelet
    // job for it.
    kubeSchedulerSelector: 'job="kube-apiserver"',
    kubeControllerManagerSelector: 'job="kube-apiserver"',
    kubeProxySelector: 'job="kubelet"',
  },
};

local node = (import 'node-mixin/mixin.libsonnet') + {
  _config+:: {
    // 3 samples at our 30s scrape interval
    rateInterval: '1m30s',
  },
};

// KubeMemoryOvercommit fires when the pods wouldn't fit after losing the
// largest node. With filer and a small Pi that's never the case.
local skipAlerts = ['KubeMemoryOvercommit'];
local alerts(mixin) = mixin.prometheusAlerts {
  groups: [
    g { rules: [r for r in g.rules if !std.member(skipAlerts, std.get(r, 'alert', ''))] }
    for g in mixin.prometheusAlerts.groups
  ],
};

// Dashboards for nodes we don't have
local skip = ['nodes-aix.json', 'nodes-darwin.json'];
local dashboards = {
  [name]: d
  for mixin in [kubernetes, node]
  for name in std.objectFields(mixin.grafanaDashboards)
  if std.length(std.findSubstr('windows', name)) == 0 && !std.member(skip, name)
  for d in [mixin.grafanaDashboards[name]]
};

{
  ['prometheus/kubernetes.recording.rules.yaml']: std.manifestYamlDoc(kubernetes.prometheusRules),
  ['prometheus/kubernetes.alerting.rules.yaml']: std.manifestYamlDoc(alerts(kubernetes)),
  ['prometheus/node.recording.rules.yaml']: std.manifestYamlDoc(node.prometheusRules),
  ['prometheus/node.alerting.rules.yaml']: std.manifestYamlDoc(alerts(node)),
} + {
  ['grafana/dashboards/' + name]: std.manifestJsonEx(dashboards[name], '  ') + '\n'
  for name in std.objectFields(dashboards)
}
