# syntax=docker/dockerfile:1.7

# Synced from the upstream build repositories by scripts/update-upstreams.sh.
ARG DOTNET_IMAGE=mcr.microsoft.com/dotnet/aspnet:8.0.24-jammy-amd64
ARG EASYBOT_COMMIT=8856378ab618570bef44f1df0ca0d287c342cc9c
ARG CHROME_VERSION=142.0.7444.59
ARG NAPCAT_DOCKER_COMMIT=14e01082da84ebe53b339be1121c89aa3105843d
ARG NAPCAT_VERSION=v4.18.9
ARG QQ_DOWNLOAD_ID=f9cbaab2
ARG QQ_VERSION=3.2.28-48517

FROM ${DOTNET_IMAGE}

ARG EASYBOT_COMMIT
ARG CHROME_VERSION
ARG NAPCAT_DOCKER_COMMIT
ARG NAPCAT_VERSION
ARG QQ_DOWNLOAD_ID
ARG QQ_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    EASYBOT_ENABLE_DOCKER_MODE=true \
    ASPNETCORE_ENVIRONMENT=Production \
    Kestrel__Endpoints__web_api__Url=http://+:5000 \
    ServerOptions__Host=0.0.0.0

# Combined dependency set from easybot-docker/full and NapCat-Docker/base.
# Package availability is defined by the locked Ubuntu-based .NET image.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dbus-user-session \
        ffmpeg \
        fontconfig \
        fonts-arphic-ukai \
        fonts-arphic-uming \
        fonts-noto-cjk \
        fonts-noto-cjk-extra \
        fonts-noto-color-emoji \
        fonts-wqy-microhei \
        fonts-wqy-zenhei \
        gnutls-bin \
        gosu \
        jq \
        libappindicator3-1 \
        libasound2 \
        libatspi2.0-0 \
        libatk-bridge2.0-0 \
        libatk1.0-0 \
        libcairo2 \
        libcups2 \
        libdbus-1-3 \
        libexpat1 \
        libfontconfig1 \
        libgbm1 \
        libglib2.0-0 \
        libglib2.0-dev \
        libgtk-3-0 \
        libnotify4 \
        libnspr4 \
        libnss3 \
        libpango-1.0-0 \
        libpangocairo-1.0-0 \
        libsecret-1-0 \
        libx11-6 \
        libx11-xcb1 \
        libxcb1 \
        libxcomposite1 \
        libxcursor1 \
        libxdamage1 \
        libxext6 \
        libxfixes3 \
        libxi6 \
        libxrandr2 \
        libxrender1 \
        libxss1 \
        libxtst6 \
        procps \
        tini \
        tzdata \
        unzip \
        xdg-utils \
        xvfb \
    && fc-cache -f \
    && ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime \
    && printf '%s\n' "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    mkdir -p /opt/easybot /tmp/easybot-source; \
    curl --fail --location --retry 4 --retry-all-errors \
        "https://github.com/easybot-team/easybot-docker/archive/${EASYBOT_COMMIT}.tar.gz" \
        --output /tmp/easybot.tar.gz; \
    tar -xzf /tmp/easybot.tar.gz -C /tmp/easybot-source --strip-components=1; \
    cp -a /tmp/easybot-source/boot/stable/. /opt/easybot/; \
    test -f /opt/easybot/EasyBot; \
    chmod 0755 /opt/easybot/EasyBot; \
    mkdir -p /opt/easybot/appdata /opt/easybot/logs; \
    printf '{}\n' > /opt/easybot/appdata/appsettings.json; \
    chmod 0777 /opt/easybot/appdata /opt/easybot/logs; \
    chmod 0666 /opt/easybot/appdata/appsettings.json; \
    rm -rf /tmp/easybot-source /tmp/easybot.tar.gz

RUN set -eux; \
    chrome_dir="/opt/easybot/PuppeteerSharp/ChromeHeadlessShell/Linux-${CHROME_VERSION}"; \
    mkdir -p "$chrome_dir"; \
    curl --fail --location --retry 4 --retry-all-errors \
        "https://registry.npmmirror.com/-/binary/chrome-for-testing/${CHROME_VERSION}/linux64/chrome-headless-shell-linux64.zip" \
        --output /tmp/chrome-headless-shell.zip; \
    unzip -q /tmp/chrome-headless-shell.zip -d "$chrome_dir"; \
    test -x "$chrome_dir/chrome-headless-shell-linux64/chrome-headless-shell"; \
    rm -f /tmp/chrome-headless-shell.zip

RUN set -eux; \
    useradd --no-log-init --home-dir /app napcat; \
    mkdir -p /app /tmp/napcat-docker-source; \
    curl --fail --location --retry 4 --retry-all-errors \
        "https://github.com/NapNeko/NapCat-Docker/archive/${NAPCAT_DOCKER_COMMIT}.tar.gz" \
        --output /tmp/napcat-docker.tar.gz; \
    tar -xzf /tmp/napcat-docker.tar.gz -C /tmp/napcat-docker-source --strip-components=1; \
    cp /tmp/napcat-docker-source/entrypoint.sh /app/entrypoint.sh; \
    cp -a /tmp/napcat-docker-source/templates /app/templates; \
    curl --fail --location --retry 4 --retry-all-errors \
        "https://github.com/NapNeko/NapCatQQ/releases/download/${NAPCAT_VERSION}/NapCat.Shell.zip" \
        --output /app/NapCat.Shell.zip; \
    curl --fail --location --retry 5 --retry-all-errors \
        "https://dldir1v6.qq.com/qqfile/qq/QQNT/${QQ_DOWNLOAD_ID}/linuxqq_${QQ_VERSION}_amd64.deb" \
        --output /tmp/linuxqq.deb; \
    dpkg -i --force-depends /tmp/linuxqq.deb; \
    test -x /opt/QQ/qq; \
    chmod 0755 /app/entrypoint.sh; \
    printf '%s\n' "(async () => {await import('file:///app/napcat/napcat.mjs');})();" \
        > /opt/QQ/resources/app/loadNapCat.js; \
    sed -i 's|"main": "[^"]*"|"main": "./loadNapCat.js"|' /opt/QQ/resources/app/package.json; \
    rm -rf /tmp/napcat-docker-source /tmp/napcat-docker.tar.gz /tmp/linuxqq.deb

COPY scripts/entrypoint.sh /usr/local/bin/easybot-napcat-entrypoint

RUN chmod 0755 /usr/local/bin/easybot-napcat-entrypoint

WORKDIR /app

VOLUME ["/app/napcat/config", "/app/.config/QQ", "/opt/easybot/appdata", "/opt/easybot/logs"]

EXPOSE 5000 26990 6099 3000 3001

STOPSIGNAL SIGTERM

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD test -s /run/easybot-napcat/easybot.pid \
        && test -s /run/easybot-napcat/napcat.pid \
        && kill -0 "$(cat /run/easybot-napcat/easybot.pid)" \
        && kill -0 "$(cat /run/easybot-napcat/napcat.pid)"

ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/easybot-napcat-entrypoint"]
