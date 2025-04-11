#
# Copyright (c) 2019, Google, Inc. All rights reserved
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

# Inputs:
# LINUX_ARCH contains the architecture to build for (Global)
# ANDROID_HOST_BINDIR is the path to the Android host binaries
# ANDROID_RAMDISK is the path to the Android ramdisk.img
#
# Outputs:
# LINUX_BUILD_DIR contains the path to the built linux kernel sources
# LINUX_IMAGE path of the final linux image target
# LINUX_RAMDISK_IMAGE path of the final ramdisk image

# This Makefile will build the Linux kernel with our configuration.

LINUX_PREBUILTS_VERSION := 6.12
LINUX_PREBUILTS_IMAGE := \
	kernel/prebuilts/${LINUX_PREBUILTS_VERSION}/${LINUX_ARCH}/kernel-${LINUX_PREBUILTS_VERSION}
LINUX_PREBUILTS_MODULES_DIRS := \
	kernel/prebuilts/$(LINUX_PREBUILTS_VERSION)/arm64 \
	kernel/prebuilts/common-modules/trusty/$(LINUX_PREBUILTS_VERSION)/arm64 \
	kernel/prebuilts/common-modules/virtual-device/$(LINUX_PREBUILTS_VERSION)/arm64 \

LINUX_BUILD_DIR := $(abspath $(BUILDDIR)/linux-build)
ifndef LINUX_ARCH
	$(error LINUX_ARCH must be specified)
endif

LINUX_IMAGE := $(LINUX_BUILD_DIR)/arch/$(LINUX_ARCH)/boot/Image
LINUX_MODULES_LOAD := $(TRUSTY_TOP)/trusty/device/arm/generic-arm64/project/linux/modules.load
LINUX_MODULES_STAGING_DIR := $(abspath $(BUILDDIR)/linux-modules-staging)
LINUX_RAMDISK_IMAGE := $(abspath $(BUILDDIR)/ramdisk.img)
LINUX_PREBUILTS_MODULES := \
	$(foreach d,$(LINUX_PREBUILTS_MODULES_DIRS),$(wildcard $(d)/*.ko))

# Put all the paths prepended to $PATH in one variable
$(LINUX_RAMDISK_IMAGE): EXTRA_PATHS := $(PATH_TOOLS_BINDIR):$(BUILDTOOLS_BINDIR):$(LINUX_BUILD_TOOLS)/bin:$(ANDROID_HOST_BINDIR)
$(LINUX_RAMDISK_IMAGE): LINUX_MODULES_STAGING_DIR := $(LINUX_MODULES_STAGING_DIR)
$(LINUX_RAMDISK_IMAGE): REPLACE_RAMDISK_MODULES := $(PY3) trusty/host/common/scripts/replace_ramdisk_modules/replace_ramdisk_modules.py
$(LINUX_RAMDISK_IMAGE): ANDROID_RAMDISK := $(ANDROID_RAMDISK)
$(LINUX_RAMDISK_IMAGE): LINUX_MODULES_LOAD := $(LINUX_MODULES_LOAD)
$(LINUX_RAMDISK_IMAGE): LINUX_PREBUILTS_MODULES := $(LINUX_PREBUILTS_MODULES)
$(LINUX_RAMDISK_IMAGE): $(LINUX_PREBUILTS_MODULES) $(LINUX_MODULES_LOAD)
	@echo building Linux ramdisk
	@rm -rf $(LINUX_MODULES_STAGING_DIR)
	@mkdir -p $(LINUX_MODULES_STAGING_DIR)
	@cp -n -t $(LINUX_MODULES_STAGING_DIR) $(LINUX_PREBUILTS_MODULES)
	PATH=$(EXTRA_PATHS):$(PATH) $(REPLACE_RAMDISK_MODULES) --android-ramdisk $(ANDROID_RAMDISK) --kernel-ramdisk $(LINUX_MODULES_STAGING_DIR) --output-ramdisk $@ --override-modules-load $(LINUX_MODULES_LOAD)

$(LINUX_BUILD_DIR): $(LINUX_PREBUILTS_IMAGE)
	@echo copying Linux prebuilts
	@rm -rf $@
	@$(MKDIR)

$(LINUX_IMAGE): $(LINUX_BUILD_DIR)
	@mkdir -p $(@D)
	@cp -r ${LINUX_PREBUILTS_IMAGE} $@

# Add LINUX_IMAGE to the list of project dependencies
EXTRA_BUILDDEPS += $(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE)

LINUX_MODULES_STAGING_DIR :=
LINUX_MODULES_LOAD :=
LINUX_PREBUILTS_MODULES :=
LINUX_PREBUILTS_MODULES_DIRS :=
