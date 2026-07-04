FROM ubuntu:26.04

ARG USERNAME=ubuntu
ARG PYTHON_311_VERSION=3.11.15

ENV DEBIAN_FRONTEND=noninteractive
ENV USERNAME=${USERNAME}
ENV USER_HOME=/home/${USERNAME}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        openssh-server \
        ca-certificates \
        curl \
        ffmpeg \
        fonts-liberation \
        fonts-noto-color-emoji \
        fonts-unifont \
        git \
        libbz2-dev \
        libatk-bridge2.0-0t64 \
        libatk1.0-0t64 \
        libatspi2.0-0t64 \
        libcairo-gobject2 \
        libcups2t64 \
        libffi-dev \
        libgdbm-dev \
        libgtk-3-0t64 \
        liblzma-dev \
        libncursesw5-dev \
        libnspr4 \
        libnss3 \
        libreadline-dev \
        libsqlite3-dev \
        libssl-dev \
        libxcomposite1 \
        libxcursor1 \
        libxdamage1 \
        libxi6 \
        libxrandr2 \
        libxshmfence1 \
        libxss1 \
        python3 \
        python3-dev \
        python3-pip \
        python3-venv \
        ripgrep \
        sudo \
        uuid-dev \
        xz-utils \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && printf '%s\n' \
        'Types: deb' \
        'URIs: https://download.docker.com/linux/ubuntu' \
        "Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")" \
        'Components: stable' \
        "Architectures: $(dpkg --print-architecture)" \
        'Signed-By: /etc/apt/keyrings/docker.asc' \
        > /etc/apt/sources.list.d/docker.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        docker-buildx-plugin \
        docker-ce-cli \
        docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://www.python.org/ftp/python/${PYTHON_311_VERSION}/Python-${PYTHON_311_VERSION}.tar.xz" -o /tmp/Python-${PYTHON_311_VERSION}.tar.xz \
    && mkdir -p /tmp/python-build /opt/python/3.11 \
    && tar -xf /tmp/Python-${PYTHON_311_VERSION}.tar.xz -C /tmp/python-build --strip-components=1 \
    && cd /tmp/python-build \
    && ./configure \
        --prefix=/opt/python/3.11 \
        --with-ensurepip=install \
    && make -j"$(nproc)" \
    && make altinstall \
    && ln -sf /opt/python/3.11/bin/python3.11 /usr/local/bin/python3.11 \
    && ln -sf /opt/python/3.11/bin/pip3.11 /usr/local/bin/pip3.11 \
    && rm -rf /tmp/python-build /tmp/Python-${PYTHON_311_VERSION}.tar.xz

ENV NVM_DIR=/usr/local/nvm
ENV NODE_VERSION=24
ENV NODE_DEPS_TIMEOUT=1800
ENV NPM_CONFIG_FETCH_RETRIES=5
ENV NPM_CONFIG_FETCH_RETRY_MINTIMEOUT=20000
ENV NPM_CONFIG_FETCH_RETRY_MAXTIMEOUT=120000
ENV PLAYWRIGHT_HOST_PLATFORM_OVERRIDE=ubuntu24.04-x64

RUN mkdir -p "${NVM_DIR}" \
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
    && . "${NVM_DIR}/nvm.sh" \
    && nvm install "${NODE_VERSION}" \
    && nvm alias default "${NODE_VERSION}" \
    && nvm use default \
    && ln -sf "${NVM_DIR}/versions/node/$(nvm version "${NODE_VERSION}")/bin/node" /usr/local/bin/node \
    && ln -sf "${NVM_DIR}/versions/node/$(nvm version "${NODE_VERSION}")/bin/npm" /usr/local/bin/npm \
    && ln -sf "${NVM_DIR}/versions/node/$(nvm version "${NODE_VERSION}")/bin/npx" /usr/local/bin/npx \
    && ln -sf "${NVM_DIR}/versions/node/$(nvm version "${NODE_VERSION}")/bin/corepack" /usr/local/bin/corepack \
    && printf '%s\n' \
        'export NVM_DIR=/usr/local/nvm' \
        'export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"' \
        > /etc/profile.d/nvm.sh

ENV PATH=${USER_HOME}/.npm-global/bin:${USER_HOME}/.local/bin:${PATH}

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
