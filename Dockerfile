FROM ubuntu:26.04

ARG USERNAME=ubuntu

ENV DEBIAN_FRONTEND=noninteractive
ENV USERNAME=${USERNAME}
ENV USER_HOME=/home/${USERNAME}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-server \
        ca-certificates \
        python3 \
        python3-pip \
        sudo \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/sshd \
    && if id "${USERNAME}" >/dev/null 2>&1; then \
        usermod -d "/home/${USERNAME}" -s /bin/bash "${USERNAME}" && mkdir -p "/home/${USERNAME}"; \
    else \
        useradd -m -s /bin/bash "${USERNAME}"; \
    fi \
    && chown "${USERNAME}:${USERNAME}" "/home/${USERNAME}" \
    && passwd -l "${USERNAME}" \
    && usermod -aG sudo "${USERNAME}" \
    && mkdir -p /etc/ssh/sshd_config.d \
    && printf '%s\n' \
        'PasswordAuthentication no' \
        'KbdInteractiveAuthentication no' \
        'PubkeyAuthentication yes' \
        'AuthorizedKeysFile .ssh/authorized_keys' \
        'StrictModes no' \
        'PermitRootLogin no' \
        > /etc/ssh/sshd_config.d/99-js-worker.conf \
    && sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config

RUN mkdir -p /opt/ubuntu-home-defaults \
    && cp -a /etc/skel/. /opt/ubuntu-home-defaults/ \
    && cp -an "${USER_HOME}/." /opt/ubuntu-home-defaults/ \
    && chown -R root:root /opt/ubuntu-home-defaults

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh

EXPOSE 22

VOLUME ["/home/ubuntu"]

WORKDIR /home/ubuntu

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
