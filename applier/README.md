# Applies
The applier converges a Kubernetes cluster to the desired state.

# Naming all the things
## Site
- everything that is been deployed at some site/home/company
- consists of several stacks

Examples:
- fish's home


## Stack
- set of applications fullfilling a single purpose

Examples:
- Monitoring
- Minecraft
- Home Automation

## Application
- a service / application and all dependencies like database setup, ingress
  configuration, configmaps

Examples:
- Prometheus
- Papermc
- Overviewer

#

# Conventions
- lib/ contains reusable anythings (FIXME: Distinguish between mixins and
  opinionated apps)
- site/ contains site specific configuration (FIXME: there should be something
  like a stack)

# Brainstorming
```
[my weird home cluster]--[fish stack 1.0]--+- Prometheus
                          |\
                          |\ Grafana
                          |\ Home-Assistant
                          |\ SabNZB (or torrent by disabled)\
```
- Where disable torrent? config of fish stack? Mixin in weird home cluster?
