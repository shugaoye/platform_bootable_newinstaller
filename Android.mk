# Copyright 2009-2014, The Android-x86 Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ifneq ($(filter x86%,$(TARGET_ARCH)),)
LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE := edit_mbr
LOCAL_SRC_FILES := editdisklbl/editdisklbl.c
LOCAL_CFLAGS := -O2 -g -W -Wall -Werror# -D_LARGEFILE64_SOURCE
LOCAL_STATIC_LIBRARIES := libdiskconfig_host libcutils liblog
edit_mbr := $(HOST_OUT_EXECUTABLES)/$(LOCAL_MODULE)
include $(BUILD_HOST_EXECUTABLE)

VER ?= x86emu_ch07

# use squashfs for iso, unless explictly disabled
ifneq ($(USE_SQUASHFS),0)
MKSQUASHFS = $(shell which mksquashfs)

define build-squashfs-target
	$(if $(shell $(MKSQUASHFS) -version | grep "version [0-3].[0-9]"),\
		$(error Your mksquashfs is too old to work with kernel 2.6.29. Please upgrade to squashfs-tools 4.0))
	$(hide) $(MKSQUASHFS) $(1) $(2) -noappend
endef
endif

initrd_dir := $(LOCAL_PATH)/initrd
initrd_bin := \
	$(initrd_dir)/init \
	$(wildcard $(initrd_dir)/*/*)

systemimg  := $(PRODUCT_OUT)/system.$(if $(MKSQUASHFS),sfs,img)

INITRD_RAMDISK := $(PRODUCT_OUT)/initrd.img
$(INITRD_RAMDISK): $(initrd_bin) $(systemimg) $(TARGET_INITRD_SCRIPTS) | $(ACP) $(MKBOOTFS)
	rm -rf $(TARGET_INSTALLER_OUT)
	$(ACP) -pr $(initrd_dir) $(TARGET_INSTALLER_OUT)
	$(if $(TARGET_INITRD_SCRIPTS),$(ACP) -p $(TARGET_INITRD_SCRIPTS) $(TARGET_INSTALLER_OUT)/scripts)
	ln -s /bin/ld-linux.so.2 $(TARGET_INSTALLER_OUT)/lib
	mkdir -p $(addprefix $(TARGET_INSTALLER_OUT)/,android iso mnt proc sys tmp sfs hd)
	echo "VER=$(VER)" > $(TARGET_INSTALLER_OUT)/scripts/00-ver
	$(MKBOOTFS) $(TARGET_INSTALLER_OUT) | gzip -9 > $@

INSTALL_RAMDISK := $(PRODUCT_OUT)/install.img
$(INSTALL_RAMDISK): $(wildcard $(LOCAL_PATH)/install/*/* $(LOCAL_PATH)/install/*/*/*/*) | $(MKBOOTFS)
	$(if $(TARGET_INSTALL_SCRIPTS),$(ACP) -p $(TARGET_INSTALL_SCRIPTS) $(TARGET_INSTALLER_OUT)/scripts)
	$(MKBOOTFS) $(dir $(dir $(<D))) | gzip -9 > $@

boot_dir := $(PRODUCT_OUT)/boot
$(boot_dir): $(shell find $(LOCAL_PATH)/boot -type f | sort -r) $(systemimg) $(INSTALL_RAMDISK) $(GENERIC_X86_CONFIG_MK) | $(ACP)
	$(hide) rm -rf $@
	$(ACP) -pr $(dir $(<D)) $@
	$(ACP) -pr $(dir $(<D))../install/grub2/efi $@

BUILT_IMG := $(addprefix $(PRODUCT_OUT)/,ramdisk.img initrd.img install.img) $(systemimg)
BUILT_IMG += $(if $(TARGET_PREBUILT_KERNEL),$(TARGET_PREBUILT_KERNEL),$(PRODUCT_OUT)/kernel)

ISO_IMAGE := $(PRODUCT_OUT)/$(TARGET_PRODUCT).iso
$(ISO_IMAGE): $(boot_dir) $(BUILT_IMG)
	@echo ----- Making iso image ------
	$(hide) sed -i "s|\(Installation CD\)\(.*\)|\1 $(VER)|; s|CMDLINE|$(BOARD_KERNEL_CMDLINE)|" $</isolinux/isolinux.cfg
	$(hide) sed -i "s|VER|$(VER)|; s|CMDLINE|$(BOARD_KERNEL_CMDLINE)|" $</boot/grub/grub.cfg
	genisoimage -vJURT -b isolinux/isolinux.bin -c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
		-input-charset utf-8 -V "Android-x86 LiveCD" -o $@ $^
	$(hide) isohybrid --uefi $@ || echo -e "isohybrid not found.\nInstall syslinux 4.0 or higher if you want to build a usb bootable iso."
	@echo -e "\n\n$@ is built successfully.\n\n"

# Note: requires dosfstools
EFI_IMAGE := $(PRODUCT_OUT)/$(TARGET_PRODUCT).img
ESP_LAYOUT := $(LOCAL_PATH)/editdisklbl/esp_layout.conf
$(EFI_IMAGE): $(wildcard $(LOCAL_PATH)/boot/boot/*/*) $(BUILT_IMG) $(ESP_LAYOUT) | $(edit_mbr)
	$(hide) sed "s|VER|$(VER)|; s|CMDLINE|$(BOARD_KERNEL_CMDLINE)|" $(<D)/grub.cfg > $(@D)/grub.cfg
	$(hide) size=0; \
	for s in `du -sk $^ | awk '{print $$1}'`; do \
		size=$$(($$size+$$s)); \
        done; \
	size=$$(($$(($$(($$(($$(($$size + $$(($$size / 100)))) - 1)) / 32)) + 1)) * 32)); \
	rm -f $@.fat; mkdosfs -n Android-x86 -C $@.fat $$size
	$(hide) mcopy -Qsi $@.fat $(<D)/../../../install/grub2/efi $(BUILT_IMG) ::
	$(hide) mmd -i $@.fat ::boot; mmd -i $@.fat ::boot/grub
	$(hide) mcopy -Qoi $@.fat $(@D)/grub.cfg ::boot/grub
	$(hide) cat /dev/null > $@; $(edit_mbr) -l $(ESP_LAYOUT) -i $@ esp=$@.fat
	$(hide) rm -f $@.fat

.PHONY: iso_img usb_img efi_img initrd
iso_img: $(ISO_IMAGE)
usb_img: $(ISO_IMAGE)
efi_img: $(EFI_IMAGE)
initrd:  $(BUILT_IMG)
qcow2_img: $(BUILT_IMG)
	qemu-img convert -c -f raw -O qcow2 $(PRODUCT_OUT)/system.img $(PRODUCT_OUT)/system-qcow2.img

