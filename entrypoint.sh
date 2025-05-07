#!/usr/bin/env bash

# Default configurations
SCREEN_WIDTH=${JUMPSERVER_WIDTH:-1280}
SCREEN_HEIGHT=${JUMPSERVER_HEIGHT:-800}
GEOMETRY="${SCREEN_WIDTH}""x""${SCREEN_HEIGHT}"
DEPTH="${JUMPSERVER_DEPTH:-24}"
DPI="${JUMPSERVER_DPI:-96}"

# Set VNC password
if [ -z "${JMS_VNC_PASSWORD}" ]; then
    JMS_VNC_PASSWORD=$(head -c100 < /dev/urandom | base64 | tr -dc A-Za-z0-9 | head -c 8; echo)
    echo "Generated VNC password: ${JMS_VNC_PASSWORD}"
fi

# Create jumpserver user if not exists
if ! id jumpserver &>/dev/null; then
    groupadd -r jumpserver
    useradd -r -g jumpserver -d /home/jumpserver -s /bin/bash -m jumpserver
fi

echo "jumpserver:${JMS_VNC_PASSWORD}" | chpasswd

# Store VNC password
mkdir -p /home/jumpserver/.vnc
echo "${JMS_VNC_PASSWORD}" | vncpasswd -f > /home/jumpserver/.vnc/passwd
chmod 600 /home/jumpserver/.vnc/passwd
chown -R jumpserver:jumpserver /home/jumpserver/.vnc

mkdir -p /tmp/jumpserver/download
chown -R jumpserver:jumpserver /tmp/jumpserver/download

mkdir -p /home/jumpserver/.config
cp -rp /root/.config/* /home/jumpserver/.config/
chown -R jumpserver:jumpserver /home/jumpserver/.config

/usr/sbin/sshd
# Configure xstartup for IME and clipboard support
cat > /home/jumpserver/.vnc/xstartup  <<EOF
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
LANG=C xdg-user-dirs-update --force
# Start DBus
dbus-launch --exit-with-session &
export DISPLAY=:0
# Start iBus for Chinese input
export XMODIFIERS="@im=ibus"
export GTK_IM_MODULE="ibus"
export QT_IM_MODULE="ibus"

export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export CHROME_DISABLE_GPU=1


export XDG_SESSION_TYPE=x11
export WINDOW_MANAGER=openbox


# Window manager
openbox-session &

# Wait for window manager
sleep 2


# ibus-daemon -drx

# # Start clipboard manager
# autocutsel -fork
# autocutsel -selection PRIMARY -fork

exec /opt/py3/bin/python /opt/app/main.py
EOF
chmod +x /home/jumpserver/.vnc/xstartup
chown jumpserver:jumpserver /home/jumpserver/.vnc/xstartup

# Start TigerVNC server with clipboard support
exec su - jumpserver -c "export JMS_TOKEN=${JMS_TOKEN} && \
     export HOME=/home/jumpserver && \
    /usr/bin/vncserver :0 \
    -geometry ${GEOMETRY} \
    -depth ${DEPTH} \
    -dpi ${DPI} \
    -localhost no \
    -passwd /home/jumpserver/.vnc/passwd \
    -fg \
    -SecurityTypes VncAuth \
    $@"