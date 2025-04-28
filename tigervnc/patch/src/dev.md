apt-get install build-essential devscripts debhelper dh-make fakeroot



dpkg-source -x tigervnc_1.12.0+dfsg-8.dsc


mk-build-deps -i -r -t "apt-get -y" tigervnc_1.12.0+dfsg-8.dsc



dpkg-buildpackage -us -uc