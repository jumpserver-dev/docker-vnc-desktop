
FROM python:3.12-slim-bookworm
ARG TARGETARCH

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
    && rm -f /etc/apt/apt.conf.d/docker-clean \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && apt-get update \
    && apt-get install -y --no-install-recommends ${DEPENDENCIES} \
    && apt-get build-dep -y --no-install-recommends tigervnc-standalone-server \
    && echo "no" | dpkg-reconfigure dash \
    && echo "zh_CN.UTF-8" | dpkg-reconfigure locales \
    && sed -i "s@# export @export @g" ~/.bashrc \
    && sed -i "s@# alias @alias @g" ~/.bashrc \
    && chmod +x /dev/shm \
    && mkdir -p /var/run/sshd \
    && mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

COPY tigervnc/debian/bookworm/linux_${TARGETARCH} /tmp/linux_${TARGETARCH}
RUN set -ex \
    && cd /tmp/linux_${TARGETARCH} \
    && bash build.sh \
    && rm -rf /tmp/linux_${TARGETARCH}

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