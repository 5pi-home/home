FROM debian:bullseye

RUN useradd -m user -u 1000 && \
  echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/disable-sandbox && \
  apt-get -qy update && \
  apt-get -qy install curl default-jre-headless pass && \
  curl -Lsfo /usr/lib/sjsonnet.jar "https://github.com/databricks/sjsonnet/releases/download/0.4.2/sjsonnet.jar" && \
  printf '#!/bin/sh\nexec java -jar /usr/lib/sjsonnet.jar "$@"\n' | install -m755 /dev/stdin /usr/bin/jsonnet

USER user
