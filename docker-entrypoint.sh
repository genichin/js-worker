#!/bin/sh
set -eu

USER_NAME="${USERNAME:-ubuntu}"
USER_HOME="${USER_HOME:-/home/${USER_NAME}}"
DEFAULTS_DIR="/opt/ubuntu-home-defaults"

mkdir -p "${USER_HOME}"

if [ -d "${DEFAULTS_DIR}" ] && ! find "${USER_HOME}" -mindepth 1 -maxdepth 1 | read -r _; then
    cp -a "${DEFAULTS_DIR}/." "${USER_HOME}/"
fi

mkdir -p "${USER_HOME}/.npm-global" "${USER_HOME}/.local/bin"

if [ ! -f "${USER_HOME}/.npmrc" ]; then
    printf '%s\n' "prefix=${USER_HOME}/.npm-global" > "${USER_HOME}/.npmrc"
fi

if [ -d "${USER_HOME}/.ssh" ]; then
    chmod 700 "${USER_HOME}/.ssh"
fi

if [ -f "${USER_HOME}/.ssh/authorized_keys" ]; then
    chmod 600 "${USER_HOME}/.ssh/authorized_keys"
fi

if [ -S /var/run/docker.sock ]; then
    DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"
    DOCKER_GROUP="$(getent group "${DOCKER_GID}" | cut -d: -f1 || true)"

    if [ -z "${DOCKER_GROUP}" ]; then
        DOCKER_GROUP="docker-host-${DOCKER_GID}"
        groupadd -g "${DOCKER_GID}" "${DOCKER_GROUP}" 2>/dev/null || true
        DOCKER_GROUP="$(getent group "${DOCKER_GID}" | cut -d: -f1 || true)"
    fi

    if [ -n "${DOCKER_GROUP}" ]; then
        usermod -aG "${DOCKER_GROUP}" "${USER_NAME}" 2>/dev/null || true
    fi
fi

mkdir -p /run/cron
cron

chown -R "${USER_NAME}:${USER_NAME}" "${USER_HOME}" 2>/dev/null || true

exec "$@"
