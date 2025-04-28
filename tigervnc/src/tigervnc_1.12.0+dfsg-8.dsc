Format: 3.0 (quilt)
Source: tigervnc
Binary: tigervnc-common, tigervnc-tools, tigervnc-scraping-server, tigervnc-standalone-server, tigervnc-xorg-extension, tigervnc-viewer
Architecture: any
Version: 1.12.0+dfsg-8
Maintainer: TigerVNC Packaging Team <pkg-tigervnc-devel@lists.alioth.debian.org>
Uploaders:  Joachim Falk <joachim.falk@gmx.de>, Mike Gabriel <sunweaver@debian.org>, Yaroslav Halchenko <debian@onerussian.com>, Ola Lundqvist <opal@debian.org>, Antoni Villalonga <antoni@friki.cat>
Homepage: http://www.tigervnc.org
Standards-Version: 4.6.2
Vcs-Browser: https://salsa.debian.org/debian-remote-team/tigervnc
Vcs-Git: https://salsa.debian.org/debian-remote-team/tigervnc.git
Build-Depends: debhelper-compat (= 12), cmake (>= 2.8), gettext, zlib1g-dev, libjpeg-dev, libgnutls28-dev, libpam0g-dev, libxft-dev, libxcursor-dev, libxrandr-dev, libxdamage-dev, libwrap0-dev, libfltk1.3-dev (>= 1.3.3), xorg-server-source (>= 2:21), xserver-xorg-dev, appstream, po-debconf, quilt, pkg-config, bison, flex, xutils-dev (>= 1:7.6+4), xfonts-utils (>= 1:7.5+1), x11proto-dev (>= 2021.5), xtrans-dev (>= 1.3.5), libxau-dev (>= 1:1.0.5-2), libxcvt-dev, libxdmcp-dev (>= 1:0.99.1), libxfont-dev (>= 1:2.0.1), libxkbfile-dev (>= 1:0.99.1), libpixman-1-dev (>= 0.27.2), libpciaccess-dev (>= 0.12.901), libgcrypt-dev, nettle-dev, libudev-dev (>= 151-3) [linux-any], libselinux1-dev (>= 2.0.80) [linux-any], libaudit-dev [linux-any], libdrm-dev (>= 2.4.107-5~) [!hurd-i386], libgl-dev (>= 1.3.2), mesa-common-dev, libunwind-dev [amd64 arm64 armel armhf hppa i386 ia64 mips64 mips64el mipsel powerpc powerpcspe ppc64 ppc64el sh4], libxmuu-dev (>= 1:0.99.1), libxext-dev (>= 1:0.99.1), libx11-dev (>= 2:1.6), libxrender-dev (>= 1:0.9.0), libxi-dev (>= 2:1.8), libxpm-dev (>= 1:3.5.3), libxaw7-dev (>= 1:0.99.1), libxt-dev (>= 1:0.99.1), libxmu-dev (>= 1:0.99.1), libxtst-dev (>= 1:0.99.1), libxres-dev (>= 1:0.99.1), libxfixes-dev (>= 1:3.0.0), libxv-dev, libxinerama-dev, libxshmfence-dev (>= 1.1) [!hurd-i386], libepoxy-dev [linux-any kfreebsd-any], libegl-dev (>= 1.3.2) [linux-any kfreebsd-any], libgbm-dev (>= 10.2) [linux-any kfreebsd-any], xkb-data, x11-xkb-utils, libbsd-dev, libdbus-1-dev (>= 1.0) [linux-any], libsystemd-dev [linux-any]
Package-List:
 tigervnc-common deb x11 optional arch=any
 tigervnc-scraping-server deb x11 optional arch=any
 tigervnc-standalone-server deb x11 optional arch=any
 tigervnc-tools deb x11 optional arch=any
 tigervnc-viewer deb x11 optional arch=any
 tigervnc-xorg-extension deb x11 optional arch=any
Checksums-Sha1:
 d86d7cbfbfd3415e13b1edf0dcbff00122a9718f 1021752 tigervnc_1.12.0+dfsg.orig.tar.xz
 81d7a01d55b6a809472e9f6de318b502113c9708 640540 tigervnc_1.12.0+dfsg-8.debian.tar.xz
Checksums-Sha256:
 f2bbcfc8b54feee8116c2e039a34461d3d59d7fde149aa28b44df79af1b26bb1 1021752 tigervnc_1.12.0+dfsg.orig.tar.xz
 b5789ed5bcd9704f79dfc6579aa5c9c052bbb0e164d82e6e7f779a5d78382ac5 640540 tigervnc_1.12.0+dfsg-8.debian.tar.xz
Files:
 e223912d646a7ac5e0918a1df1609789 1021752 tigervnc_1.12.0+dfsg.orig.tar.xz
 4d5196aa614a7288bac424a6d0e21436 640540 tigervnc_1.12.0+dfsg-8.debian.tar.xz
