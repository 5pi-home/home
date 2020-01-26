FROM ubuntu:18.04

RUN apt-get -qy update && \
  apt-get -qy install curl git make

COPY files/ /
ENV PATH=$PATH:/dest/bin
RUN /build /dest
VOLUME /dest
COPY static/ /dest/out/

ENTRYPOINT [ "/apply", "/dest/out" ]
