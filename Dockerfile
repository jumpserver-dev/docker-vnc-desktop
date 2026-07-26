FROM debian:trixie-slim AS tigervnc-build

ARG TIGERVNC_VERSION="1.16.2"
ARG TIGERVNC_DEBIAN_REVISION="1ubuntu1"
ARG TIGERVNC_SOURCE_URL="https://downloads.sourceforge.net/project/tigervnc/stable/1.16.2/ubuntu-24.04LTS/source"
ARG TIGERVNC_DSC_SHA256="e2072e0530f0589e697b147e606007c92f4b79f7f680baa5b389842e6d9a0ec6"
ARG TIGERVNC_ORIG_SHA256="d8252655ae7a4c556e7dcd0808fa012433266c199ceebf9c113de655fbf73e66"
ARG TIGERVNC_DEBIAN_SHA256="64b1778768436e0f3089f4652f999d438f6ac01b7eef26a6682ab356cc1c2b80"

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dpkg-dev \
        patch \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

RUN set -eux \
    && dsc_file="tigervnc_${TIGERVNC_VERSION}-${TIGERVNC_DEBIAN_REVISION}.dsc" \
    && orig_file="tigervnc_${TIGERVNC_VERSION}.orig.tar.gz" \
    && debian_file="tigervnc_${TIGERVNC_VERSION}-${TIGERVNC_DEBIAN_REVISION}.debian.tar.gz" \
    && curl -fL --retry 5 --retry-all-errors -o "${dsc_file}" "${TIGERVNC_SOURCE_URL}/${dsc_file}" \
    && curl -fL --retry 5 --retry-all-errors -o "${orig_file}" "${TIGERVNC_SOURCE_URL}/${orig_file}" \
    && curl -fL --retry 5 --retry-all-errors -o "${debian_file}" "${TIGERVNC_SOURCE_URL}/${debian_file}" \
    && echo "${TIGERVNC_DSC_SHA256}  ${dsc_file}" | sha256sum -c - \
    && echo "${TIGERVNC_ORIG_SHA256}  ${orig_file}" | sha256sum -c - \
    && echo "${TIGERVNC_DEBIAN_SHA256}  ${debian_file}" | sha256sum -c - \
    && dpkg-source -x "${dsc_file}" "tigervnc-${TIGERVNC_VERSION}"

WORKDIR /usr/src/tigervnc-${TIGERVNC_VERSION}

# The upstream Ubuntu package uses Ubuntu-specific dependency names. Replace
# them with their Debian trixie equivalents before resolving build dependencies.
RUN set -eux \
    && sed -i \
        -e 's/libjpeg-turbo8-dev/libjpeg-dev/' \
        -e '/openjdk-8-jdk,/d' \
        debian/control \
    && apt-get update \
    && apt-get build-dep -y --no-install-recommends . \
    && rm -rf /var/lib/apt/lists/*

COPY patches/tigervnc-legacy-clipboard-utf8.patch /tmp/tigervnc-legacy-clipboard-utf8.patch

RUN set -eux \
    && patch --batch --forward -p1 < /tmp/tigervnc-legacy-clipboard-utf8.patch

RUN set -eux \
    && DEB_BUILD_OPTIONS="parallel=$(nproc) nocheck" dpkg-buildpackage -b -us -uc


FROM python:3.12-slim-trixie

ENV DEBIAN_FRONTEND=noninteractive

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

COPY --from=tigervnc-build /usr/src/tigervncserver_*.deb /tmp/tigervncserver.deb

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=app-apt \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=app-apt \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && apt-get update \
    && apt-get install -y --no-install-recommends ${DEPENDENCIES} /tmp/tigervncserver.deb \
    && echo "no" | dpkg-reconfigure dash \
    && sed -i 's/^# *\(zh_CN.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
    && locale-gen \
    && sed -i "s@# export @export @g" ~/.bashrc \
    && sed -i "s@# alias @alias @g" ~/.bashrc \
    && chmod +x /dev/shm \
    && mkdir -p /var/run/sshd \
    && mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix \
    && rm -f /tmp/tigervncserver.deb \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*


RUN set -ex \
    && python3 -m venv /opt/py3

ENV PATH=/opt/py3/bin:$PATH \
    LANG="zh_CN.UTF-8" \
    LC_ALL="zh_CN.UTF-8" \
    GTK_IM_MODULE="ibus" \
    XMODIFIERS="@im=ibus" \
    QT_IM_MODULE="ibus"

WORKDIR /opt

COPY app /opt/app
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY vnc-session.sh /usr/local/bin/vnc-session.sh
COPY config/dconf /root/.config/dconf
COPY openbox /root/.config/openbox
COPY tint2 /root/.config/tint2

RUN chmod 0755 /usr/local/bin/entrypoint.sh /usr/local/bin/vnc-session.sh

EXPOSE 22 5900
CMD ["bash", "/usr/local/bin/entrypoint.sh"]
