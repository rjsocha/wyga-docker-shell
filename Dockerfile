FROM ubuntu:22.04 AS mold
ARG DEBIAN_FRONTEND=noninteractive
ARG DEBIAN_PRIORITY=critical
RUN apt-get update -qq && \
    apt-get -o "APT::Get::Always-Include-Phased-Updates=true" -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" dist-upgrade -qq && \
    apt-get install ca-certificates curl gnupg wget git jq python3-minimal gawk vim-tiny python-is-python3 --no-install-recommends -qq && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update -qq && \
    apt-get install docker-ce-cli docker-buildx-plugin docker-compose-plugin -qq && \
    apt-get clean && \
    find /var/lib/apt/lists/ -type f -delete
COPY --chmod=755 entrypoint.sh /.entrypoint/docker-shell
FROM scratch
COPY --from=mold / /
ENTRYPOINT ["/.entrypoint/docker-shell"]
CMD ["bash"]
