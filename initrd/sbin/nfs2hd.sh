#!/bin/busybox sh
#
# By Roger Ye <shugaoye@yahoo.com>
#
# Last updated 2016/08/29
#
# License: GNU Public License
#

X86VBOX_SRC=/mnt$SRC
X86VBOX_DST=/hd$SRC

mount /dev/sda1 /hd
cp $X86VBOX_SRC/initrd.img $X86VBOX_DST/initrd.img
cp $X86VBOX_SRC/ramdisk.img $X86VBOX_DST/ramdisk.img
cp $X86VBOX_SRC/kernel $X86VBOX_DST/kernel
rm -rf $X86VBOX_DST/system
cp -a $X86VBOX_SRC/system $X86VBOX_DST/

sync