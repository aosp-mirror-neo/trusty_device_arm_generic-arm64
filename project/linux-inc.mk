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
# ANDROID_RAMDISK is the path to the Android ramdisk.img
#
# Outputs:
# LINUX_BUILD_DIR contains the path to the built linux kernel sources
# LINUX_IMAGE path of the final linux image target

# This Makefile will build the Linux kernel with our configuration.

LINUX_PREBUILTS_VERSION := 6.12
LINUX_PREBUILTS_IMAGE := \
	kernel/prebuilts/${LINUX_PREBUILTS_VERSION}/${LINUX_ARCH}/kernel-${LINUX_PREBUILTS_VERSION}

LINUX_BUILD_DIR := $(abspath $(BUILDDIR)/linux-build)
ifndef LINUX_ARCH
	$(error LINUX_ARCH must be specified)
endif

LINUX_IMAGE := $(LINUX_BUILD_DIR)/arch/$(LINUX_ARCH)/boot/Image
LINUX_RAMDISK_IMAGE :=
LINUX_MODULES_LOAD := $(TRUSTY_TOP)/trusty/device/arm/generic-arm64/project/linux/modules.load
ifeq (0,1) # Disabled temporarily
LINUX_MODULES_STAGING_DIR := $(abspath $(BUILDDIR)/linux-modules-staging)
LINUX_RAMDISK_IMAGE := $(abspath $(BUILDDIR)/ramdisk.img)

# Put all the paths prepended to $PATH in one variable
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): EXTRA_PATHS := $(CLANG_BINDIR):$(PATH_TOOLS_BINDIR):$(BUILDTOOLS_BINDIR):$(LINUX_BUILD_TOOLS)/bin

$(LINUX_RAMDISK_IMAGE): LINUX_MODULES_STAGING_DIR := $(LINUX_MODULES_STAGING_DIR)
$(LINUX_RAMDISK_IMAGE): LINUX_TRUSTY_MODULES_MAKEFILE_DIR := $(LINUX_TRUSTY_MODULES_COPY_DIR)/drivers/trusty
$(LINUX_RAMDISK_IMAGE): TRUSTY_MODULES_ORDER_HASH := $(shell echo "${LINUX_TRUSTY_MODULES_MAKEFILE_DIR}" | $(PATH_TOOLS_BINDIR)/md5sum -b)
$(LINUX_RAMDISK_IMAGE): REPLACE_RAMDISK_MODULES := $(PY3) trusty/host/common/scripts/replace_ramdisk_modules/replace_ramdisk_modules.py
$(LINUX_RAMDISK_IMAGE): ANDROID_RAMDISK := $(ANDROID_RAMDISK)
$(LINUX_RAMDISK_IMAGE): LINUX_MODULES_LOAD := $(LINUX_MODULES_LOAD)
$(LINUX_RAMDISK_IMAGE): $(LINUX_IMAGE) $(LINUX_TRUSTY_MODULES_COPY_FILES) $(LINUX_TRUSTY_MODULES_KCONFIG_EXT) $(LINUX_MODULES_LOAD)
	@echo building Linux ramdisk
	@rm -rf $(LINUX_MODULES_STAGING_DIR)
	PATH=$(EXTRA_PATHS):$(PATH) $(MAKE) $(LINUX_MAKE_ARGS) modules_install
	PATH=$(EXTRA_PATHS):$(PATH) $(MAKE) $(LINUX_MAKE_ARGS) M=$(LINUX_TRUSTY_MODULES_MAKEFILE_DIR) modules
	PATH=$(EXTRA_PATHS):$(PATH) $(MAKE) $(LINUX_MAKE_ARGS) M=$(LINUX_TRUSTY_MODULES_MAKEFILE_DIR) modules_install
	PATH=$(EXTRA_PATHS):$(PATH) $(REPLACE_RAMDISK_MODULES) --android-ramdisk $(ANDROID_RAMDISK) --kernel-ramdisk $(LINUX_MODULES_STAGING_DIR) --output-ramdisk $@ --override-modules-load $(LINUX_MODULES_LOAD) --check-modules-order --extra-modules-order "modules.order.$(TRUSTY_MODULES_ORDER_HASH)"

endif # Disabled

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
