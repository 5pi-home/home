local app = import '../app/main.libsonnet';

local prometheus = app.new("prometheus", "prometheus", "prometheus/prometheus:v2.15.2", 9090);

[
  prometheus.deployment +
    app.withVolumeHostMount("data", "/prometheus", "/data/prometheus"),
  prometheus.service
]
