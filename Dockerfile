FROM ubuntu:22.04 AS mold
ARG DEBIAN_FRONTEND=noninteractive
ARG DEBIAN_PRIORITY=critical
RUN apt-get update -qq && \
    apt-get -o "APT::Get::Always-Include-Phased-Updates=true" -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" dist-upgrade -qq && \
    apt-get install --no-install-recommends ca-certificates curl wget git jq gawk -qq
COPY docker/docker.list /etc/apt/sources.list.d/docker.list
COPY docker/docker.gpg /etc/apt/keyrings/docker.gpg
RUN apt-get update -qq && \
    apt-get install --no-install-recommends docker-ce-cli docker-buildx-plugin -qq && \
    apt-get clean && \
    find /var/lib/apt/lists/ -type f -delete
COPY --chmod=755 tools/ /usr/local/bin
FROM scratch
COPY --from=mold / /
ENTRYPOINT ["/.entrypoint/docker-shell"]
CMD ["bash"]
