FROM ubuntu:18.04

ENV KUBECTL_VERSION=1.17.2
ENV JSONNET_VERSION=0.14.0
ENV JB_VERSION=0.2.0
ENV KUBERNETS_MIXIN_VERSION=0.3
ENV KUBECTL_URL=https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl
ENV JSONNET_URL=https://github.com/google/jsonnet/releases/download/v${JSONNET_VERSION}/jsonnet-bin-v${JSONNET_VERSION}-linux.tar.gz
ENV JB_URL=https://github.com/jsonnet-bundler/jsonnet-bundler/releases/download/v${JB_VERSION}/jb-linux-amd64

RUN apt-get -qy update && \
  apt-get -qy install curl git make && \
  curl -Lsfo bin/kubectl "$KUBECTL_URL" && \
  chmod a+x bin/kubectl && \
  curl -Lsf "$JSONNET_URL" | tar -C /usr/bin/ -xzvf - && \
  curl -Lsfo /usr/bin/jb "$JB_URL" && \
  chmod a+x /usr/bin/jb
COPY jsonnetfile*.json /app/
WORKDIR /app
RUN jb install
COPY . /app

ENTRYPOINT [ "/app/apply" ]
