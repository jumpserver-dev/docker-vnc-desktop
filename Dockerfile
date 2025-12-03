
FROM debian:bookworm AS tigervnc-build
ARG DEBIAN_FRONTEND=noninteractive
ARG TIGERVNC_VERSION="1.15.0+dfsg-2"

RUN set -ex \
    && echo "deb-src http://deb.debian.org/debian bookworm main" >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        devscripts \
        equivs \
        dpkg-dev \
        ca-certificates \
        debian-archive-keyring \
        debian-keyring \
        gnupg \
        wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

RUN set -ex \
    && apt-get update \
    && dget https://deb.debian.org/debian/pool/main/t/tigervnc/tigervnc_${TIGERVNC_VERSION}.dsc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/tigervnc-1.15.0+dfsg

# Install xorg-server-source from sid to satisfy >= 2:21.1.10 without upgrading the base
RUN set -ex \
    && echo "deb http://deb.debian.org/debian sid main" > /etc/apt/sources.list.d/sid.list \
    && printf "Package: *\nPin: release a=unstable\nPin-Priority: 50\n" > /etc/apt/preferences.d/limit-sid \
    && apt-get update \
    && apt-get install -y -t sid xorg-server-source=2:21.1.12-1 || apt-get install -y -t sid xorg-server-source \
    && rm -f /etc/apt/sources.list.d/sid.list /etc/apt/preferences.d/limit-sid \
    && apt-get update \
    && apt-get build-dep -y . \
    && rm -rf /var/lib/apt/lists/*

RUN set -ex \
    && dpkg-buildpackage -b -uc -us

FROM python:3.12-slim-bookworm
ARG TARGETARCH
ARG TIGERVNC_VERSION="1.15.0+dfsg-2"

ARG DEPENDENCIES="                \
    ca-certificates               \
    dbus-x11                      \
    fonts-wqy-microhei            \
    gnupg2                        \
    ibus                          \
    ibus-pinyin                   \
    iso-codes                     \
    libffi-dev                    \
    libgbm-dev                    \
    libnss3                       \
    libssl-dev                    \
    locales                       \
    netcat-openbsd                \
    pulseaudio                    \
    unzip                         \
    wget                          \
    autocutsel                    \
    procps                        \
    openbox                       \
    obconf                        \
    tint2                         \
    menu                          \
    openssh-client                \
    openssh-server                \
    python3-tk                    \
    xauth                         \
    libfile-readbackwards-perl    \
    xdg-user-dirs" 

RUN set -ex \
    &&  sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/debian.sources

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=app-apt \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=app-apt \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && apt-get update \
    && apt-get install -y --no-install-recommends ${DEPENDENCIES} \
    && echo "no" | dpkg-reconfigure dash \
    && echo "zh_CN.UTF-8" | dpkg-reconfigure locales \
    && sed -i "s@# export @export @g" ~/.bashrc \
    && sed -i "s@# alias @alias @g" ~/.bashrc \
    && chmod +x /dev/shm \
    && mkdir -p /var/run/sshd \
    && mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

COPY --from=tigervnc-build /usr/src/*.deb /tmp/tigervnc-src/

RUN set -ex \
    && case "${TARGETARCH}" in \
        amd64) DEB_ARCH="amd64" ;; \
        arm64) DEB_ARCH="arm64" ;; \
        *) echo "Unsupported TARGETARCH ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && mkdir -p /tmp/tigervnc && cd /tmp/tigervnc \
    && cp /tmp/tigervnc-src/*_${DEB_ARCH}.deb . \
    && dpkg -i ./*.deb || (apt-get update && apt-get install -y -f) \
    && cd /opt \
    && rm -rf /tmp/tigervnc \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN set -ex \
    && python3 -m venv /opt/py3

ENV PATH=/opt/py3/bin:$PATH \
    GTK_IM_MODULE="ibus" \
    XMODIFIERS="@im=ibus" \
    QT_IM_MODULE="ibus"

WORKDIR /opt

COPY app /opt/app
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY config/dconf /root/.config/dconf
COPY openbox /root/.config/openbox
COPY tint2 /root/.config/tint2

EXPOSE 22 5900
CMD ["bash", "/usr/local/bin/entrypoint.sh"]
