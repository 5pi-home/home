{
  global: {
    scrape_interval: '30s'
  },
  rule_files: [
    '/etc/prometheus/*.rules.yaml'
  ],
  scrape_configs+: [
    {
      bearer_token_file: '/var/run/secrets/kubernetes.io/serviceaccount/token',
      job_name: 'kube-apiserver',
      kubernetes_sd_configs: [
        {
          role: 'endpoints',
        },
      ],
      relabel_configs: [
        {
          action: 'keep',
          regex: 'default;kubernetes;https',
          source_labels: [
            '__meta_kubernetes_namespace',
            '__meta_kubernetes_service_name',
            '__meta_kubernetes_endpoint_port_name',
          ],
        },
      ],
      scheme: 'https',
      tls_config: {
        ca_file: '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
      },
    },
    {
      bearer_token_file: '/var/run/secrets/kubernetes.io/serviceaccount/token',
      job_name: 'kubelet',
      kubernetes_sd_configs: [
        {
          role: 'node',
        },
      ],
      relabel_configs: [
        {
          action: 'labelmap',
          regex: '__meta_kubernetes_node_label_(.+)',
        },
        {
          replacement: 'kubernetes.default.svc:443',
          target_label: '__address__',
        },
        {
          regex: '(.+)',
          replacement: '/api/v1/nodes/${1}/proxy/metrics',
          source_labels: [
            '__meta_kubernetes_node_name',
          ],
          target_label: '__metrics_path__',
        },
      ],
      scheme: 'https',
      tls_config: {
        ca_file: '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
      },
    },
    {
      bearer_token_file: '/var/run/secrets/kubernetes.io/serviceaccount/token',
      job_name: 'cadvisor',
      kubernetes_sd_configs: [
        {
          role: 'node',
        },
      ],
      relabel_configs: [
        {
          action: 'labelmap',
          regex: '__meta_kubernetes_node_label_(.+)',
        },
        {
          replacement: 'kubernetes.default.svc:443',
          target_label: '__address__',
        },
        {
          regex: '(.+)',
          replacement: '/api/v1/nodes/${1}/proxy/metrics/cadvisor',
          source_labels: [
            '__meta_kubernetes_node_name',
          ],
          target_label: '__metrics_path__',
        },
      ],
      metric_relabel_configs: [
        // Drop container_* metrics with no image.
        {
          source_labels: ['__name__', 'image'],
          regex: 'container_([a-z_]+);',
          action: 'drop',
        },

        // Drop a bunch of metrics which are disabled but still sent, see
        // https://github.com/google/cadvisor/issues/1925.
        {
          source_labels: ['__name__'],
          regex: 'container_(network_tcp_usage_total|network_udp_usage_total|tasks_state|cpu_load_average_10s)',
          action: 'drop',
        },
      ],
      scheme: 'https',
      tls_config: {
        ca_file: '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
      },
    },
    // A separate scrape config for kube-state-metrics which doesn't add a namespace
    // label, instead taking the namespace label from the exported timeseries.  This
    // prevents the exported namespace label being renamed to exported_namespace, and
    // allows us to route alerts based on namespace.
    {
      job_name: 'kube-state-metrics',
      kubernetes_sd_configs: [{
        role: 'pod',
      }],

      tls_config: {
        ca_file: '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
      },
      bearer_token_file: '/var/run/secrets/kubernetes.io/serviceaccount/token',

      relabel_configs: [

        // Drop anything who's service is not kube-state-metrics
        // Rename jobs to be <namespace>/<name, from pod name label>
        {
          source_labels: ['__meta_kubernetes_pod_label_name'],
          regex: 'kube-state-metrics',
          action: 'keep',
        },

        // Rename instances to be the pod name.
        // As the scrape two ports of KSM, include the port name in the instance
        // name.  Otherwise alerts about scrape failures and timeouts won't work.
        {
          source_labels: ['__meta_kubernetes_pod_name', '__meta_kubernetes_pod_container_port_name'],
          action: 'replace',
          separator: ':',
          target_label: 'instance',
        },
      ],
    },
    // A separate scrape config for node-exporter which maps the nodename onto the
    // instance label.
    {
      job_name: 'node',
      kubernetes_sd_configs: [{
        role: 'pod',
      }],

      tls_config: {
        ca_file: '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
      },
      bearer_token_file: '/var/run/secrets/kubernetes.io/serviceaccount/token',

      relabel_configs: [
        // Drop anything who's name is not node-exporter.
        {
          source_labels: ['__meta_kubernetes_pod_label_name'],
          regex: 'node-exporter',
          action: 'keep',
        },

        // Rename instances to be the node name.
        {
          source_labels: ['__meta_kubernetes_pod_node_name'],
          action: 'replace',
          target_label: 'instance',
        },

        // But also include the namespace as a separate label, for routing alerts
        {
          source_labels: ['__meta_kubernetes_namespace'],
          action: 'replace',
          target_label: 'namespace',
        },

        {
          source_labels: ['__address__'],
          replacement: '${1}:9100',
          target_label: '__address__',
        },

      ],
    },
    {
      job_name: 'kubernetes-service-endpoints',
      kubernetes_sd_configs: [
        {
          role: 'endpoints',
        },
      ],
      relabel_configs: [
        {
          action: 'keep',
          regex: 'true',
          source_labels: [ '__meta_kubernetes_service_annotation_prometheus_io_scrape' ],
        },
        {
          action: 'labelmap',
          regex: '__meta_kubernetes_service_label_(.+)',
        },
        {
          action: 'replace',
          source_labels: [
            '__meta_kubernetes_namespace',
          ],
          target_label: 'kubernetes_namespace',
        },
        {
          action: 'replace',
          source_labels: [
            '__meta_kubernetes_service_name',
          ],
          target_label: 'kubernetes_name',
        },
      ],
    },
    {
      job_name: 'kubernetes-services',
      kubernetes_sd_configs: [
        {
          role: 'service',
        },
      ],
      metrics_path: '/probe',
      params: {
        module: [
          'http_2xx',
        ],
      },
      relabel_configs: [
        {
          source_labels: [
            '__address__',
          ],
          target_label: '__param_target',
        },
        {
          replacement: 'blackbox-exporter:9115',
          target_label: '__address__',
        },
        {
          source_labels: [
            '__param_target',
          ],
          target_label: 'instance',
        },
        {
          action: 'labelmap',
          regex: '__meta_kubernetes_service_label_(.+)',
        },
        {
          source_labels: [
            '__meta_kubernetes_namespace',
          ],
          target_label: 'kubernetes_namespace',
        },
        {
          source_labels: [
            '__meta_kubernetes_service_name',
          ],
          target_label: 'kubernetes_name',
        },
      ],
    },
    {
      job_name: 'kubernetes-ingresses',
      kubernetes_sd_configs: [
        {
          role: 'ingress',
        },
      ],
      metrics_path: '/probe',
      params: {
        module: [
          'http_2xx',
        ],
      },
      relabel_configs: [
        {
          regex: '(.+);(.+);(.+)',
          replacement: '${1}://${2}${3}',
          source_labels: [
            '__meta_kubernetes_ingress_scheme',
            '__address__',
            '__meta_kubernetes_ingress_path',
          ],
          target_label: '__param_target',
        },
        {
          replacement: 'blackbox-exporter:9115',
          target_label: '__address__',
        },
        {
          source_labels: [
            '__param_target',
          ],
          target_label: 'instance',
        },
        {
          action: 'labelmap',
          regex: '__meta_kubernetes_ingress_label_(.+)',
        },
        {
          source_labels: [
            '__meta_kubernetes_namespace',
          ],
          target_label: 'kubernetes_namespace',
        },
        {
          source_labels: [
            '__meta_kubernetes_ingress_name',
          ],
          target_label: 'kubernetes_name',
        },
      ],
    },
    {
      job_name: 'kubernetes-pods',
      kubernetes_sd_configs: [
        {
          role: 'pod',
        },
      ],
      relabel_configs: [
        {
          action: 'keep',
          regex: 'true',
          source_labels: [ '__meta_kubernetes_service_annotation_prometheus_io_scrape' ],
        },
        {
          action: 'labelmap',
          regex: '__meta_kubernetes_pod_label_(.+)',
        },
        // Rename jobs to be <namespace>/<name, from pod name label>
        {
          source_labels: ['__meta_kubernetes_namespace', '__meta_kubernetes_pod_label_name'],
          action: 'replace',
          separator: '/',
          target_label: 'job',
          replacement: '$1',
        },

        // But also include the namespace as a separate label, for routing alerts
        {
          source_labels: ['__meta_kubernetes_namespace'],
          action: 'replace',
          target_label: 'namespace',
        },

        // Rename instances to be the pod name
        {
          source_labels: ['__meta_kubernetes_pod_name'],
          action: 'replace',
          target_label: 'instance',
        },

        {
          regex: '__meta_kubernetes_pod_annotation_prometheus_io_param_(.+)',
          action: 'labelmap',
          replacement: '__param_$1',
        },
      ],
    },
  ],
}
