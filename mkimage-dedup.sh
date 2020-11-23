#!/bin/bash

if [ "$(whoami)" != "root" ] ; then
	exec sudo bash "$0" "$@"
fi

set -e -x

source ./config

rm -f $IMG
truncate -s $IMGSIZE $IMG

sfdisk -W always $IMG <<EOF
label: dos
label-id: 0x12345678
unit: sectors
sector-size: 512

4M,196M,L,*
200M,,L
EOF

L=`losetup -P --show -f $IMG`

mkfs.btrfs ${L}p2

mkdir -p m
mount -o compress-force=zstd:4 ${L}p2 m

for ddir in distros/*
do
	test -f $ddir/config || continue
	name=${ddir#distros/}
	btrfs subvolume create m/$name
	specs="$specs m/$name:$ddir/rootfs.tar.zst"
done

./tools/extract $specs

./mkimage-apply-fixes.sh

umount m
losetup -d "$L"

./mkimage-boot.sh
