FROM debian:bullseye

RUN useradd -m user -u 1000 && \
  echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/disable-sandbox && \
  apt-get -qy update && \
  apt-get -qy install curl default-jre-headless pass apache2-utils && \
  curl -Lsfo /usr/lib/sjsonnet.jar "https://github.com/databricks/sjsonnet/releases/download/0.4.2/sjsonnet.jar" && \
  printf '#!/bin/sh\nexec java -jar /usr/lib/sjsonnet.jar "$@"\n' | \
    install -m755 /dev/stdin /usr/bin/jsonnet && \
  curl -Lsf "https://github.com/jsonnet-bundler/jsonnet-bundler/releases/download/v0.4.0/jb-linux-amd64" | \
    install -m755 /dev/stdin /usr/bin/jb && \
  curl -Lsf https://dl.k8s.io/release/v1.23.0/bin/linux/amd64/kubectl | \
    install -m755 /dev/stdin /usr/bin/kubectl

USER user
