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

include $(CLEAR_VARS)
LOCAL_IS_HOST_MODULE := true
LOCAL_SRC_FILES := rpm/qemu-android
LOCAL_MODULE := $(notdir $(LOCAL_SRC_FILES))
LOCAL_MODULE_TAGS := debug
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_POST_INSTALL_CMD := $(hide) sed -i "s|CMDLINE|$(BOARD_KERNEL_CMDLINE)|" $(HOST_OUT_EXECUTABLES)/$(LOCAL_MODULE)
include $(BUILD_PREBUILT)

VER ?= $$(date +"%F")

# use squashfs for iso, unless explictly disabled
ifneq ($(USE_SQUASHFS),0)
MKSQUASHFS := $(MAKE_SQUASHFS)

define build-squashfs-target
	$(hide) $(MKSQUASHFS) $(1) $(2) -noappend -comp gzip
endef
endif

initrd_dir := $(LOCAL_PATH)/initrd
initrd_bin := \
	$(initrd_dir)/init \
	$(wildcard $(initrd_dir)/*/*)

systemimg  := $(PRODUCT_OUT)/system.$(if $(MKSQUASHFS),sfs,img)
$(if $(MKSQUASHFS),$(systemimg): | $(MKSQUASHFS))

INITRD_RAMDISK := $(PRODUCT_OUT)/initrd.img
$(INITRD_RAMDISK): $(initrd_bin) $(systemimg) $(TARGET_INITRD_SCRIPTS) | $(ACP) $(MKBOOTFS)
	rm -rf $(TARGET_INSTALLER_OUT)
	$(ACP) -pr $(initrd_dir) $(TARGET_INSTALLER_OUT)
	$(if $(TARGET_INITRD_SCRIPTS),$(ACP) -p $(TARGET_INITRD_SCRIPTS) $(TARGET_INSTALLER_OUT)/scripts)
	ln -s /bin/ld-linux.so.2 $(TARGET_INSTALLER_OUT)/lib
	mkdir -p $(addprefix $(TARGET_INSTALLER_OUT)/,android iso mnt proc sys tmp sfs hd)
	echo "VER=$(VER)" > $(TARGET_INSTALLER_OUT)/scripts/00-ver
	$(if $(INSTALL_PREFIX),echo "INSTALL_PREFIX=$(INSTALL_PREFIX)" >> $(TARGET_INSTALLER_OUT)/scripts/00-ver)
	$(if $(PREV_VERS),echo "PREV_VERS=\"$(PREV_VERS)\"" >> $(TARGET_INSTALLER_OUT)/scripts/00-ver)
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

rpm: $(wildcard $(LOCAL_PATH)/rpm/*) $(BUILT_IMG)
	@echo ----- Making an rpm ------
	OUT=$(abspath $(PRODUCT_OUT)); mkdir -p $$OUT/rpm/BUILD; rm -rf $$OUT/rpm/RPMS/*; $(ACP) $< $$OUT; \
	rpmbuild -bb --target=$(if $(filter x86,$(TARGET_ARCH)),i686,x86_64) -D"cmdline $(BOARD_KERNEL_CMDLINE)" \
		-D"_topdir $$OUT/rpm" -D"_sourcedir $$OUT" -D"systemimg $(notdir $(systemimg))" -D"ver $(VER)" \
		$(if $(BUILD_NAME_VARIANT),-D"name $(BUILD_NAME_VARIANT)") \
		-D"install_prefix $(if $(INSTALL_PREFIX),$(INSTALL_PREFIX),android-$(VER))" $(filter %.spec,$^); \
	mv $$OUT/rpm/RPMS/*/*.rpm $$OUT

.PHONY: iso_img usb_img efi_img rpm
iso_img: $(ISO_IMAGE)
usb_img: $(ISO_IMAGE)
efi_img: $(ISO_IMAGE)

endif
