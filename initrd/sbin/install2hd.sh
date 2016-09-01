#!/bin/busybox sh
#
# By Roger Ye <shugaoye@yahoo.com>
#
# Last updated 2016/08/29
#
# License: GNU Public License
#
# This script is used to install the build to harddisk or flash parition.
#

export X86IMAGE_SRC=/mnt$SRC
export X86IMAGE_DST=/hd$SRC

mount /dev/sda1 /hd
rm -rf $X86IMAGE_DST/system.img $X86IMAGE_DST/initrd.img $X86IMAGE_DST/ramdisk.img $X86IMAGE_DST/kernel
ls $X86IMAGE_DST
cp $X86IMAGE_SRC/initrd.img $X86IMAGE_DST/initrd.img
cp $X86IMAGE_SRC/ramdisk.img $X86IMAGE_DST/ramdisk.img
cp $X86IMAGE_SRC/kernel $X86IMAGE_DST/kernel
cp $X86IMAGE_SRC/system.img $X86IMAGE_DST/system.img
echo "Upgraded successfully."
ls $X86IMAGE_DST

sync
