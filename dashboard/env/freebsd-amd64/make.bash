#!/bin/bash
# Copyright 2015 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Only tested on Ubuntu 14.04.
# Requires packages: qemu expect mkisofs

set -e -x
readonly VERSION=10.1
readonly IMAGE=freebsd-${VERSION:?}-amd64-gce.tar.gz

if ! [ -e FreeBSD-${VERSION:?}-RELEASE-amd64.raw ]; then
  curl -O ftp://ftp.freebsd.org/pub/FreeBSD/releases/VM-IMAGES/${VERSION:?}-RELEASE/amd64/Latest/FreeBSD-${VERSION:?}-RELEASE-amd64.raw.xz
  xz -d FreeBSD-${VERSION:?}-RELEASE-amd64.raw.xz
fi

cp FreeBSD-${VERSION:?}-RELEASE-amd64.raw disk.raw

mkdir -p iso/etc

cat >iso/install.sh <<EOF
set -x
find /mnt/
cp /mnt/etc/rc.local /etc/rc.local
cp /mnt/etc/rc.conf /etc/rc.conf
EOF

cat >iso/etc/rc.conf <<EOF
hostname="buildlet"
EOF

cat >iso/etc/rc.local <<EOF
(
  set -x
  PATH=/bin:/usr/bin:/usr/local/bin
  echo "starting buildlet script"
  netstat -rn
  cat /etc/resolv.conf
  dig metadata.google.internal
  (
    set -e
    export PATH="\$PATH:/usr/local/bin"
    /usr/local/bin/curl -o /buildlet \$(/usr/local/bin/curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/buildlet-binary-url)
    chmod +x /buildlet
    exec /buildlet
  )
  echo "giving up"
  sleep 10
  poweroff
)
EOF

mkisofs -r -o config.iso iso/
# TODO(wathiede): remove sleep
sleep 2

# TODO(wathiede): set serial output so we can track boot on GCE.
expect <<EOF
set timeout 600
spawn qemu-system-x86_64 -display curses -smp 2 -drive if=virtio,file=disk.raw -cdrom config.iso -net nic,model=virtio -net user

# Speed-up boot by going in to single user mode.
expect "Welcome to FreeBSD"
sleep 2
send "\n"

expect "login:"
sleep 1
send "root\n"

expect "root@:~ # "
sleep 1
send "dhclient vtnet0\n"

expect "root@:~ # "
sleep 1
send "pkg install bash curl git\n"

expect "Do you want to fetch and install it now"
sleep 1
send "y\n"

expect "Proceed with this action"
sleep 1
send "y\n"

expect "root@:~ # "
sleep 1
send "mount -urw /\n"

expect "root@:~ # "
sleep 1
send "mount_cd9660 /dev/cd0 /mnt\nsh /mnt/install.sh\n"

expect "root@:~ # "
sleep 1
send "poweroff\n"
expect "All buffers synced."
EOF

# Create Compute Engine disk image.
echo "Archiving disk.raw as ${IMAGE:?}... (this may take a while)"
tar -Szcf ${IMAGE:?} disk.raw

echo "Done. GCE image is ${IMAGE:?}"
