# Applies
The applier converges a Kubernetes cluster to the desired state.


# Conventions
- `_config` is used for configuration

## Site: root level
- everything that is been deployed at some site/home/company
- consists of several stacks
- yields a map with filename and yaml manifest as string
Examples:
- fish's home: `./5pi-home.jsonnet`


## Stack
- set of applications fullfilling a single purpose
- yields a map with application name and application

Examples:
- Monitoring: `./stacks/monitoring.jsonnet`
- Home Automation: `./stacks/home-automation.jsonnet`
- Minecraft

## Application
- a service / application and all dependencies like database setup, ingress
  configuration, configmaps

Examples:
- Prometheus: `./apps/prometheus`
- home-assistant: `./apps/home_assistant`

# Example hierarchy
```
<5pi-home> +--[zfs]---(zfs-local-pv)
           |    +---- (zfs-storage-classes)
           +--[monitoring]--(prometheus)
           |       +--------(grafana)
           |       +--------(node-exporter)
           |       +--------(blackbox-exporter)
           +--[home-automation]--(home-assistant)
                   +-------------(zwave2mqtt)
```
- `<>` site
- `[]` stack
- `()` app
