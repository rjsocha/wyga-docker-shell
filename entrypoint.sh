#!/bin/sh
set -eu

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- docker "$@"
fi

# if our command is a valid Docker subcommand, let's invoke it through Docker instead
# (this allows for "docker run docker ps", etc)
if docker help "$1" > /dev/null 2>&1; then
	set -- docker "$@"
fi

_should_tls() {
	[ -n "${DOCKER_TLS_CERTDIR:-}" ] \
	&& [ -s "$DOCKER_TLS_CERTDIR/client/ca.pem" ] \
	&& [ -s "$DOCKER_TLS_CERTDIR/client/cert.pem" ] \
	&& [ -s "$DOCKER_TLS_CERTDIR/client/key.pem" ]
}

# if we have no DOCKER_HOST but we do have the default Unix socket (standard or rootless), use it explicitly
if [ -z "${DOCKER_HOST:-}" ] && [ -S /var/run/docker.sock ]; then
	export DOCKER_HOST=unix:///var/run/docker.sock
elif [ -z "${DOCKER_HOST:-}" ] && XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" && [ -S "$XDG_RUNTIME_DIR/docker.sock" ]; then
	export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
fi

# if DOCKER_HOST isn't set (no custom setting, no default socket), let's set it to a sane remote value
if [ -z "${DOCKER_HOST:-}" ]; then
	if _should_tls || [ -n "${DOCKER_TLS_VERIFY:-}" ]; then
		export DOCKER_HOST='tcp://docker:2376'
	else
		export DOCKER_HOST='tcp://docker:2375'
	fi
fi
if [ "${DOCKER_HOST#tcp:}" != "$DOCKER_HOST" ] \
	&& [ -z "${DOCKER_TLS_VERIFY:-}" ] \
	&& [ -z "${DOCKER_CERT_PATH:-}" ] \
	&& _should_tls \
; then
	export DOCKER_TLS_VERIFY=1
	export DOCKER_CERT_PATH="$DOCKER_TLS_CERTDIR/client"
fi

if [ -n "${DOCKER_CREATE_CONTEXT:-}" ] && [ -n "${DOCKER_CERT_PATH:-}" ] && [ -n "${DOCKER_HOST:-}" ]
then
  if ! docker context inspect dind &>/dev/null
  then
    SAVE_DOCKER_HOST="${DOCKER_HOST}"
    SAVE_DOCKER_CERT_PATH="${DOCKER_CERT_PATH}"
    SAVE_DOCKER_TLS_VERIFY="${DOCKER_TLS_VERIFY:-}"
    SAVE_DOCKER_TLS_CERTDIR="${DOCKER_TLS_CERTDIR:-}"
    unset DOCKER_HOST
    unset DOCKER_CERT_PATH
    unset DOCKER_TLS_VERIFY
    unset DOCKER_TLS_CERTDIR
    docker context create dind --docker "host=${SAVE_DOCKER_HOST},ca=${SAVE_DOCKER_CERT_PATH}/ca.pem,cert=${SAVE_DOCKER_CERT_PATH}/cert.pem,key=${SAVE_DOCKER_CERT_PATH}/key.pem"
    docker context use dind
  fi
fi
exec "$@"
