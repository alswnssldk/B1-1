FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       acl \
       bc \
       cron \
       gawk \
       iproute2 \
       logrotate \
       openssh-server \
       procps \
       sudo \
       ufw \
       util-linux \
    && mkdir -p /run/sshd \
    && rm -rf /var/lib/apt/lists/*

COPY scripts/container-entrypoint.sh /usr/local/bin/container-entrypoint.sh
RUN chmod 755 /usr/local/bin/container-entrypoint.sh

WORKDIR /mission
ENTRYPOINT ["/usr/local/bin/container-entrypoint.sh"]
