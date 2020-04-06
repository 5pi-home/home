{
  rule_files: [
    '/etc/prometheus/*.rules.yaml'
  ],
  scrape_configs: [
    {
      bearer_token_file: '/var/run/secrets/kubernetes.io/serviceaccount/token',
      job_name: 'kubernetes-apiserver',
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
      job_name: 'kubernetes-nodes',
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
      job_name: 'kubernetes-cadvisor',
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
