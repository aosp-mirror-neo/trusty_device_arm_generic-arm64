# Copyright (C) 2018 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

PROJECT_QEMU_INC_LOCAL_DIR := $(GET_LOCAL_DIR)

ifeq (true,$(call TOBOOL,$(PACKAGE_TRUSTY_IMAGES_ONLY)))
PACKAGE_TRUSTY_IMAGES := true
endif

APPLOADER_ALLOW_NS_CONNECT := true

# Include Secretkeeper TA
SECRETKEEPER_ENABLED := true

# All qemu-generic-arm64* builds default to SPMC_EL=3
# while the arm32 builds use the SPD because both
# Hafnium and EL3 SPMC only support AArch64.
ifneq ($(filter generic-arm64%,$(QEMU_TRUSTY_PROJECT)),)
SPMC_EL ?= 3
endif

ifneq ($(SPMC_EL),)
LIB_SM_WITH_FFA_LOOP := true
GENERIC_ARM64_DEBUG := FFA

# Merge FIQ-IRQ to keep the FF-A implementation simpler
ARM_MERGE_FIQ_IRQ := true

# TF-A on qemu sets PLATFORM_CORE_COUNT=32 and requires that the
# SP manifest specifies that exact number of execution contexts
SMP_MAX_CPUS := 32
SMP_CPU_CLUSTER_SHIFT := 4
endif

include project/$(QEMU_TRUSTY_PROJECT).mk

# limit physical memory to 29 bits to make the mapping
# as small as possible while covering the entire kernel plus
# enough pages for the page tables for the initial mappings
GLOBAL_DEFINES += MMU_IDENT_SIZE_SHIFT=29

# Qemu statically built with glibc<2.29 uses a syscall to implement
# clock_gettime instead of the VDSO, which makes the calls much slower
APP_TIMERTEST_MAX_CLOCK_PERIOD := 2000

# Derive RPMB key using HKDF
WITH_HKDF_RPMB_KEY ?= true

# Always allow provisioning for emulator builds
STATIC_SYSTEM_STATE_FLAG_PROVISIONING_ALLOWED := 1

# Emulator builds are unlocked by default. qemu-generic-arm32-test-debug
# overrides this to ensure that we have at least one target that tests with app
# loading locked.
STATIC_SYSTEM_STATE_FLAG_APP_LOADING_UNLOCKED ?= 1

MODULES += \
	trusty/user/app/storage/rpmb_dev \

RPMB_DEV := $(BUILDDIR)/host_tools/rpmb_dev

# Enable unittests that should only run in the emulator
STORAGE_UNITTEST_ON_EMULATOR := true

PROJECT_KEYS_DIR := $(PROJECT_QEMU_INC_LOCAL_DIR)/keys

APPLOADER_SIGN_PRIVATE_KEY_0_FILE := \
	$(PROJECT_KEYS_DIR)/apploader_sign_test_private_key_0.der

APPLOADER_SIGN_PUBLIC_KEY_0_FILE := \
	$(PROJECT_KEYS_DIR)/apploader_sign_test_public_key_0.der

APPLOADER_SIGN_PRIVATE_KEY_1_FILE := \
	$(PROJECT_KEYS_DIR)/apploader_sign_test_private_key_1.der

APPLOADER_SIGN_PUBLIC_KEY_1_FILE := \
	$(PROJECT_KEYS_DIR)/apploader_sign_test_public_key_1.der

# Key ID 1 should only be allowed if SYSTEM_STATE_FLAG_APP_LOADING_UNLOCKED is
# true
APPLOADER_SIGN_KEY_1_UNLOCKED_ONLY := true

# The default signing key is key 0, but each application
# can specify a different key identifier
APPLOADER_SIGN_KEY_ID ?= 0

# Treat key slot 1 as a dev key by default. In tests this key is only expected
# to be enabled if SYSTEM_STATE_FLAG_APP_LOADING_UNLOCKED is true.
APPLOADER_SIGN_UNLOCKED_KEY_ID ?= 1

APPLOADER_ENCRYPT_KEY_0_FILE := \
	$(PROJECT_KEYS_DIR)/apploader_encrypt_test_key_0.bin

LK_BIN := $(BUILDDIR)/lk.bin

EXTRA_BUILDRULES += external/trusty/bootloader/test-runner/test-runner-inc.mk
TEST_RUNNER_BIN := $(BUILDDIR)/test-runner/external/trusty/bootloader/test-runner/test-runner.bin

ifeq (true,$(call TOBOOL,$(HAFNIUM)))
HAFNIUM_PLATFORM := secure_qemu_aarch64
include external/hafnium/rules.mk
BL32_BIN := $(HAFNIUM_BIN)
else
BL32_BIN := $(LK_BIN)
endif

ATF_DEBUG := 1
ATF_PLAT := qemu
ATF_WITH_TRUSTY_GENERIC_SERVICES := true
ATF_BUILD_BASE := $(abspath $(BUILDDIR)/atf)
ATF_TOOLCHAIN_PREFIX := $(ARCH_arm64_TOOLCHAIN_PREFIX)
ATF_ROOT := $(call FIND_EXTERNAL,arm-trusted-firmware)
include project/qemu-atf-inc.mk

# Try using the qemu from the prebuilts
QEMU_BUILD_BASE := $(abspath $(BUILDDIR)/qemu-build)
QEMU_ARCH := aarch64
QEMU_PREBUILTS_DIR ?= prebuilts/android-emulator/trusty-x86_64
QEMU_PREBUILTS := $(wildcard $(QEMU_PREBUILTS_DIR))

ifeq (,$(QEMU_PREBUILTS))
# No prebuilts, build qemu from source
QEMU_ROOT := $(call FIND_EXTERNAL,qemu)
QEMU_TARGET := aarch64-softmmu,arm-softmmu
include project/qemu-qemu-inc.mk
else
# We have prebuilts, copy them into the build directory
QEMU_BIN := $(QEMU_BUILD_BASE)/bin/qemu-system-$(QEMU_ARCH)

# The qemu prebuilts now contain an Android.bp file.
# We do not want it in the build directory because Soong reads it.
$(QEMU_BUILD_BASE): $(QEMU_PREBUILTS)
	@echo creating qemu output directory
	@rm -rf $@
	@cp -r $< $@
	@rm -f $@/Android.bp

# The binary is inside the build directory, so create
# an empty dependency between them
$(QEMU_BIN): $(QEMU_BUILD_BASE)
	@echo creating qemu binary

EXTRA_BUILDDEPS += $(QEMU_BUILD_BASE) $(QEMU_BIN)
endif

ifneq (true,$(call TOBOOL,$(PACKAGE_TRUSTY_IMAGES_ONLY)))
LINUX_ARCH ?= arm64
include project/linux-inc.mk
endif

RUN_SCRIPT := $(BUILDDIR)/run
STOP_SCRIPT := $(BUILDDIR)/stop
ALLOC_ADB_PORTS_PY := $(BUILDDIR)/alloc_adb_ports.py
HOST_COMMANDS_OUT_DIR := $(BUILDDIR)/host_commands
QEMU_PY := $(BUILDDIR)/qemu.py
QEMU_ERROR_PY := $(BUILDDIR)/qemu_error.py
QEMU_OPTIONS_PY := $(BUILDDIR)/qemu_options.py
QEMU_LLDB_SUPPORT_PY := $(BUILDDIR)/lldb_support.py
QEMU_LLDBINIT := $(BUILDDIR)/lldbinit
PY3_CMD := $(BUILDDIR)/py3-cmd
RUN_PY := $(BUILDDIR)/run.py

$(ATF_OUT_DIR):
	mkdir -p $@

# ATF built binaries
ATF_BIN := $(ATF_OUT_DIR)/bl31.bin
ATF_EXTRA_BINS += \
	$(ATF_OUT_DIR)/bl1.bin \
	$(ATF_OUT_DIR)/bl2.bin \

# For ATF bootloader semihosting calls, bl32 and bl33 need to be in place
ATF_SYMLINKS := \
	$(ATF_OUT_DIR)/bl32.bin \
	$(ATF_OUT_DIR)/bl33.bin \
	$(EXTRA_ATF_SYMLINKS) \

$(ATF_OUT_DIR)/bl32.bin: BUILDDIR := $(BUILDDIR)
$(ATF_OUT_DIR)/bl32.bin: ATF_OUT_DIR := $(ATF_OUT_DIR)
$(ATF_OUT_DIR)/bl32.bin: $(BL32_BIN) $(ATF_OUT_DIR)
	$(NOECHO)ln -rsf $< $@

$(ATF_OUT_DIR)/bl33.bin: BUILDDIR := $(BUILDDIR)
$(ATF_OUT_DIR)/bl33.bin: ATF_OUT_DIR := $(ATF_OUT_DIR)
$(ATF_OUT_DIR)/bl33.bin: $(TEST_RUNNER_BIN) $(ATF_OUT_DIR)
	$(NOECHO)ln -rsf $< $@

ATF_GENERATED_FILES := \
	$(ATF_OUT_DIR)/RPMB_DATA \
	$(ATF_OUT_DIR)/metadata.img \

$(ATF_OUT_DIR)/RPMB_DATA: ATF_OUT_DIR := $(ATF_OUT_DIR)
$(ATF_OUT_DIR)/RPMB_DATA: $(RPMB_DEV)
	@echo Initialize rpmb device
	$< --dev $(ATF_OUT_DIR)/RPMB_DATA --init --size 2048

# Save the android src paths in order to rebuild the world if they change.
ANDROID_OUT_BUILD_DIR_DEFINES := ANDROID_BUILD_ARTIFACTS=\"$(subst $(SPACE),_,$(ANDROID_BUILD_ARTIFACTS))\"
ANDROID_OUT_BUILD_DIR_DEFINES += ANDROID_BUILD_TOP=\"$(subst $(SPACE),_,$(ANDROID_BUILD_TOP))\"

ANDROID_OUT_BUILD_DIR_CONFIG = $(BUILDDIR)/aosp/android.config

$(ANDROID_OUT_BUILD_DIR_CONFIG): ANDROID_OUT_BUILD_DIR_DEFINES := $(ANDROID_OUT_BUILD_DIR_DEFINES)
$(ANDROID_OUT_BUILD_DIR_CONFIG): configheader
	@$(call INFO_DONE,android build,generating config file,$@)
	@$(call MAKECONFIGHEADER,$@,ANDROID_OUT_BUILD_DIR_DEFINES)

ifeq (true,$(call TOBOOL,$(PACKAGE_TRUSTY_IMAGES_ONLY)))
ANDROID_OUT_SRC_DIR :=
ANDROID_OUT_SRC_FILES :=
ANDROID_OUT_FILES :=
else

# List of files we need from Android
ANDROID_OUT_FILES := \
	out/host/linux-x86/bin/adb \
	out/host/linux-x86/bin/mke2fs \
	out/target/product/trusty/ramdisk.img \
	out/target/product/trusty/system.img \
	out/target/product/trusty/vendor.img \
	out/target/product/trusty/userdata.img \
	out/target/product/trusty/data/nativetest64 \

ifneq (,$(ANDROID_BUILD_ARTIFACTS))
# Unpack and use build artifacts if requested (e.g. for a chained build).
$(info Using android ANDROID_BUILD_ARTIFACTS at $(ANDROID_BUILD_ARTIFACTS))

ANDROID_OUT_SRC_DIR := $(BUILDDIR)/aosp/unpacked_android_artifacts

# TODO: The result here gets copied to ANDROID_OUT_BUILD_DIR later. It might
# be simpler to run the unpack script in the prebuilt case as well and skip
# the extra copy step.
ANDROID_OUT_SRC_FILES := $(addprefix $(ANDROID_OUT_SRC_DIR)/,$(ANDROID_OUT_FILES))
$(ANDROID_OUT_SRC_DIR) $(ANDROID_OUT_SRC_FILES) &: ANDROID_OUT_SRC_DIR := $(ANDROID_OUT_SRC_DIR)
$(ANDROID_OUT_SRC_DIR) $(ANDROID_OUT_SRC_FILES) &: $(ANDROID_BUILD_ARTIFACTS) $(ANDROID_OUT_BUILD_DIR_CONFIG)
	@echo unpacking $< to $(ANDROID_OUT_SRC_DIR)
	@rm -rf $(ANDROID_OUT_SRC_DIR)
	trusty/prebuilts/aosp/unpack.py -o $(ANDROID_OUT_SRC_DIR) -a $<

else ifneq (,$(ANDROID_BUILD_TOP))
# We are building Trusty inside an Android environment,
# which means we can use a fresh Android build instead of prebuilts
ANDROID_OUT_SRC_DIR := $(ANDROID_BUILD_TOP)
$(info Using android ANDROID_BUILD_TOP at $(ANDROID_BUILD_TOP))
else
# Use unpacked prebuilt out dir if build artifacts are not specified and
# ANDROID_BUILD_TOP was not set
$(info Using android prebuilts)
ANDROID_OUT_SRC_DIR := trusty/prebuilts/aosp/android
endif
ANDROID_OUT_SRC_FILES := $(addprefix $(ANDROID_OUT_SRC_DIR)/,$(ANDROID_OUT_FILES))
endif

MKE2FS ?= $(ANDROID_OUT_SRC_DIR)/out/host/linux-x86/bin/mke2fs
$(ATF_OUT_DIR)/metadata.img: MKE2FS := $(MKE2FS)
$(ATF_OUT_DIR)/metadata.img: | $(ANDROID_OUT_SRC_DIR)
	@echo Create metadata.img
	MKE2FS_CONFIG= $(MKE2FS) -t ext4 -F $@ -O has_journal,extent,huge_file,dir_nlink,extra_isize,uninit_bg 16m

QEMU_SCRIPTS := \
	$(ALLOC_ADB_PORTS_PY) \
	$(HOST_COMMANDS_OUT_DIR) \
	$(QEMU_PY) \
	$(QEMU_ERROR_PY) \
	$(QEMU_OPTIONS_PY) \
	$(QEMU_LLDB_SUPPORT_PY) \
	$(QEMU_LLDBINIT) \
	$(RUN_PY) \

$(QEMU_SCRIPTS): .PHONY
EXTRA_BUILDDEPS += $(QEMU_SCRIPTS)

# Copied so that the resulting build tree contains all files needed to run
$(ALLOC_ADB_PORTS_PY): $(PROJECT_QEMU_INC_LOCAL_DIR)/qemu/alloc_adb_ports.py
	@echo copying $@
	@cp $< $@

# Copied so that the resulting build tree contains all files needed to run
$(HOST_COMMANDS_OUT_DIR): $(PROJECT_QEMU_INC_LOCAL_DIR)/host_commands
	@echo copying $@
	@rm -rf $@
	@cp -a $< $@

# Copied so that the resulting build tree contains all files needed to run
$(QEMU_PY): $(PROJECT_QEMU_INC_LOCAL_DIR)/qemu/qemu.py
	@echo copying $@
	@cp $< $@

# Copied so that the resulting build tree contains all files needed to run
$(QEMU_ERROR_PY): $(PROJECT_QEMU_INC_LOCAL_DIR)/qemu/qemu_error.py
	@echo copying $@
	@cp $< $@

# Script used to generate qemu architecture options. Need to specify qemu
# options file name since different projects use different python script
$(QEMU_OPTIONS_PY): $(PROJECT_QEMU_INC_LOCAL_DIR)/qemu/qemu_arm64_options.py
	@echo copying $@
	@cp $< $@

# Script used in LLDB for setting breakpoints adjusted for KASLR and ASLR
$(QEMU_LLDB_SUPPORT_PY): $(PROJECT_QEMU_INC_LOCAL_DIR)/qemu/lldb_support.py
	@echo copying $@
	@cp $< $@

# Companion script to lldb_support.py that contains LLDB commands
$(QEMU_LLDBINIT): $(PROJECT_QEMU_INC_LOCAL_DIR)/qemu/lldbinit
	@echo copying $@
	@cp $< $@

# Python version of the run shell script which can be imported by other Python
# scripts for more granular control over how tests share emulator instances.
# It serves as a wrapper around qemu.py which defaults the config.
$(RUN_PY): $(PROJECT_QEMU_INC_LOCAL_DIR)/qemu/run.py
	@echo copying $@
	@cp $< $@

# Copy prebuilt hermetic Python 3 command into the build directory so that the
# build does not rely on the host having Python 3 installed. Hermetic python 3
# contains the standard library so this is all we need to run the qemu scripts
$(PY3_CMD): $(BUILDTOOLS_BINDIR)/py3-cmd
	@echo copying $@
	@$(MKDIR)
	@cp $< $@

EXTRA_BUILDDEPS += $(PY3_CMD)

# Copy Android prebuilts into the build directory so that the build does not
# depend on any files in the source tree. We want to package the build artifacts
# without any dependencies on the sources.
# Because files in the prebuilts directory are not writeable the directory must
# be cleared before copying in the fresh content. `rm -rf` is used to accomplish
# this because it bypasses writing un-writeable files in addition to bringing
# the target directory to the same state as with a clean build.
ifeq (true,$(call TOBOOL,$(PACKAGE_TRUSTY_IMAGES_ONLY)))
ANDROID_OUT_BUILD_DIR :=

else
ANDROID_OUT_BUILD_DIR := $(BUILDDIR)/aosp/android

endif

ANDROID_OUT_IMAGE_DIR := $(ANDROID_OUT_BUILD_DIR)/out/target/product/trusty
ANDROID_OUT_ADB_PATH := $(ANDROID_OUT_BUILD_DIR)/out/host/linux-x86/bin/adb

# Copy the files listed in ANDROID_OUT_FILES from ANDROID_OUT_SRC_DIR into
# ANDROID_OUT_BUILD_DIR preserving the directory structure relative to the
# top-level ANDROID_OUT_SRC_DIR directory
$(ANDROID_OUT_BUILD_DIR): ANDROID_OUT_SRC_DIR := $(ANDROID_OUT_SRC_DIR)
$(ANDROID_OUT_BUILD_DIR): ANDROID_OUT_IMAGE_DIR := $(ANDROID_OUT_IMAGE_DIR)
$(ANDROID_OUT_BUILD_DIR): ANDROID_OUT_FILES := $(ANDROID_OUT_FILES)
$(ANDROID_OUT_BUILD_DIR): LINUX_RAMDISK_IMAGE := $(LINUX_RAMDISK_IMAGE)
$(ANDROID_OUT_BUILD_DIR): RAMDISK_CP := $(if $(LINUX_RAMDISK_IMAGE),cp,/bin/true)
$(ANDROID_OUT_BUILD_DIR): $(ANDROID_OUT_SRC_FILES) $(LINUX_RAMDISK_IMAGE) $(ANDROID_OUT_BUILD_DIR_CONFIG)
	@echo creating Android output directory
	@rm -rf $@
	@mkdir -p $@
	@cd $(ANDROID_OUT_SRC_DIR) && cp -r --parents -t $@ $(ANDROID_OUT_FILES)
	@$(RAMDISK_CP) $(LINUX_RAMDISK_IMAGE) $(ANDROID_OUT_IMAGE_DIR)/ramdisk.img

EXTRA_BUILDDEPS += $(ANDROID_OUT_BUILD_DIR)

ifeq (true,$(call TOBOOL,$(PACKAGE_TRUSTY_IMAGES_ONLY)))
QEMU_CONFIG :=

else
QEMU_CONFIG := $(BUILDDIR)/config.json

endif

# Save variables to a json file to export paths known to the build system to
# the test system
$(QEMU_CONFIG): QEMU_BIN := $(subst $(BUILDDIR)/,,$(QEMU_BIN))
$(QEMU_CONFIG): EXTRA_QEMU_FLAGS := ["-machine", "gic-version=$(GIC_VERSION)"]
$(QEMU_CONFIG): ATF_OUT_DIR := $(subst $(BUILDDIR)/,,$(ATF_OUT_DIR))
$(QEMU_CONFIG): LINUX_BUILD_DIR := $(subst $(BUILDDIR)/,,$(LINUX_BUILD_DIR))
$(QEMU_CONFIG): LINUX_ARCH := $(LINUX_ARCH)
$(QEMU_CONFIG): ANDROID_OUT_IMAGE_DIR := $(subst $(BUILDDIR)/,,$(ANDROID_OUT_IMAGE_DIR))
$(QEMU_CONFIG): ANDROID_OUT_ADB_PATH := $(subst $(BUILDDIR)/,,$(ANDROID_OUT_ADB_PATH))
$(QEMU_CONFIG): RPMB_DEV := $(subst $(BUILDDIR)/,,$(RPMB_DEV))
$(QEMU_CONFIG): $(ATF_OUT_COPIED_FILES) $(ATF_SYMLINKS) $(ATF_GENERATED_FILES)
	@echo generating $@
	@echo '{ "linux": "$(LINUX_BUILD_DIR)",' > $@
	@echo '  "linux_arch": "$(LINUX_ARCH)",' >> $@
	@echo '  "initrd": "$(ANDROID_OUT_IMAGE_DIR)/ramdisk.img",' >> $@
	@echo '  "atf": "$(ATF_OUT_DIR)", ' >> $@
	@echo '  "qemu": "$(QEMU_BIN)", ' >> $@
	@echo '  "extra_qemu_flags": $(EXTRA_QEMU_FLAGS), ' >> $@
	@echo '  "android_image_dir": "$(ANDROID_OUT_IMAGE_DIR)", ' >> $@
	@echo '  "adb": "$(ANDROID_OUT_ADB_PATH)", ' >> $@
	@echo '  "rpmbd": "$(RPMB_DEV)", ' >> $@
	@echo '  "arch": "$(ARCH)" }' >> $@

EXTRA_BUILDDEPS += $(QEMU_CONFIG)

# The original run shell script was replaced by run.py. Create symlink to
# preserve backwards compatibility.
$(RUN_SCRIPT): $(RUN_PY)
	@echo creating $@
	@ln -sf $(abspath $<) $@

EXTRA_BUILDDEPS += $(RUN_SCRIPT)

# Create a script to stop all stale emulators.
$(STOP_SCRIPT):
	@echo generating $@
	@echo "#!/bin/sh" >$@
	@echo 'killall qemu-system-aarch64' >>$@
	@chmod +x $@

EXTRA_BUILDDEPS += $(STOP_SCRIPT)

ifeq (true,$(call TOBOOL,$(PACKAGE_QEMU_TRUSTY)))

# Files & directories to copy into QEMU package archive
QEMU_PACKAGE_FILES := \
	$(OUTBIN) $(QEMU_SCRIPTS) $(PY3_CMD) $(QEMU_CONFIG) $(RPMB_DEV) \
	$(RUN_SCRIPT) $(STOP_SCRIPT) \
	$(QEMU_BIN) $(ATF_BIN) $(ATF_SYMLINKS) \
	$(ATF_GENERATED_FILES) \
	$(ATF_OUT_COPIED_FILES) \
	$(LINUX_IMAGE) \

ifneq (true,$(call TOBOOL,$(PACKAGE_QEMU_WITHOUT_ANDROID)))
# The Android prebuilts are pretty large and not all users need them
QEMU_PACKAGE_FILES += $(ANDROID_OUT_BUILD_DIR)
endif

# Other files/directories that should be included in the package but which are
# not make targets and therefore cannot be pre-requisites. The target that
# creates these files must be in the QEMU_PACKAGE_FILES variable.
QEMU_PACKAGE_EXTRA_FILES := \
	$(LINUX_BUILD_DIR)/scripts \
	$(QEMU_BUILD_BASE) $(ATF_EXTRA_BINS) \

QEMU_PACKAGE_ARCHIVE := $(BUILDDIR)/trusty_qemu_package.zip

include project/qemu-package-inc.mk
endif

ifeq (true,$(call TOBOOL,$(PACKAGE_TRUSTY_IMAGES)))

# Files & directories to copy into Trusty image archive for use with QEMU
# emulator. This does not include the QEMU emulator itself, which is located in
# prebuilts/android-emulator/trusty-x86_64/ and part of the trusty qemu device
# host package built in AOSP.
QEMU_PACKAGE_FILES := \
	$(OUTBIN) $(QEMU_SCRIPTS) $(PY3_CMD) \
	$(STOP_SCRIPT) \
	$(ATF_BIN) $(ATF_SYMLINKS) $(TEST_RUNNER_BIN) \
	$(ATF_GENERATED_FILES) \
	$(ATF_OUT_COPIED_FILES) \

# Other files/directories that should be included in the package but which are
# not make targets and therefore cannot be pre-requisites. The target that
# creates these files must be in the QEMU_PACKAGE_FILES variable.
QEMU_PACKAGE_EXTRA_FILES := \
	$(ATF_EXTRA_BINS) \

QEMU_PACKAGE_ARCHIVE := $(BUILDDIR)/trusty_image_package.tar.gz

include project/qemu-package-inc.mk
endif

ANDROID_OUT_FILES :=
ANDROID_OUT_BUILD_DIR :=
ANDROID_OUT_BUILD_DIR_CONFIG :=
ANDROID_OUT_BUILD_DIR_DEFINES :=
ANDROID_OUT_SRC_DIR :=
ANDROID_OUT_SRC_FILES :=
ATF_BIN :=
ATF_BUILD_BASE :=
ATF_EXTRA_BINS :=
ATF_OUT_COPIED_FILES :=
ATF_OUT_DIR :=
ATF_RELATIVE_TO_BUILD_BASE :=
ATF_SYMLINKS :=
EXTRA_ATF_SYMLINKS :=
HAFNIUM_BIN :=
LINUX_ARCH :=
LINUX_BUILD_DIR :=
LINUX_IMAGE :=
LINUX_RAMDISK_IMAGE :=
RUN_SCRIPT :=
TEST_RUNNER_BIN :=
QEMU_BIN :=
QEMU_BUILD_BASE :=
QEMU_CONFIG :=
QEMU_ERROR_PY :=
QEMU_OPTIONS_PY :=
QEMU_LLDB_SUPPORT_PY :=
QEMU_LLDBINIT :=
QEMU_PREBUILTS :=
QEMU_PY :=
QEMU_SCRIPTS :=
PY3_CMD :=
RUN_PY :=
