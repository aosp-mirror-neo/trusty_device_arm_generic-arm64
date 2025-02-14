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

ifeq (,$(wildcard $(LINUX_PREBUILTS_IMAGE)))
ifeq ($(LINUX_ARCH),arm)
LINUX_CLANG_TRIPLE := $(LINUX_ARCH)-linux-gnueabi-
else
LINUX_CLANG_TRIPLE := $(LINUX_ARCH)-linux-gnu-
endif

LINUX_SRC := $(call FIND_EXTERNAL,linux)
LINUX_CONFIG_DIR = $(LINUX_SRC)/arch/$(LINUX_ARCH)/configs
LINUX_TMP_DEFCONFIG := $(LINUX_CONFIG_DIR)/tmp_defconfig

# Check if the Linux sources have the Trusty drivers in-tree
LINUX_TRUSTY_INTREE := $(wildcard $(LINUX_SRC)/drivers/trusty)

# Preserve compatibility with architectures without GKI
ifeq (,$(wildcard $(LINUX_CONFIG_DIR)/gki_defconfig))
LINUX_DEFCONFIG_FRAGMENTS := \
	$(LINUX_CONFIG_DIR)/trusty_qemu_defconfig \

else
LINUX_DEFCONFIG_FRAGMENTS := \
	$(LINUX_CONFIG_DIR)/gki_defconfig \
	$(if $(LINUX_TRUSTY_INTREE),$(LINUX_CONFIG_DIR)/trusty_qemu_defconfig.fragment) \

endif

ifeq (,$(LINUX_TRUSTY_INTREE))
LINUX_DEFCONFIG_FRAGMENTS += \
	linux/common-modules/trusty/system_heap.fragment \
	linux/common-modules/trusty/trusty_defconfig.fragment \
	linux/common-modules/trusty/trusty_virtio_poll_vqueues.fragment \
	linux/common-modules/virtual-device/aarch64.fragment \
	linux/common-modules/virtual-device/virtual_device_core.fragment \

ifeq (true,$(call TOBOOL,$(LIB_SM_WITH_FFA_LOOP)))
LINUX_ENABLE_FFA_TRANSPORT ?= true
LINUX_ENABLE_SMC_TRANSPORT ?= false
else
LINUX_ENABLE_FFA_TRANSPORT ?= false
LINUX_ENABLE_SMC_TRANSPORT ?= true
endif

ifeq (true,$(call TOBOOL,$(LINUX_ENABLE_FFA_TRANSPORT)))
LINUX_DEFCONFIG_FRAGMENTS += \
	linux/common-modules/trusty/arm_ffa.fragment \

endif
ifeq (false,$(call TOBOOL,$(LINUX_ENABLE_SMC_TRANSPORT)))
LINUX_DEFCONFIG_FRAGMENTS += \
	linux/common-modules/trusty/disable_smc_transport.fragment \

endif
endif

$(LINUX_TMP_DEFCONFIG): LINUX_SRC := $(LINUX_SRC)
$(LINUX_TMP_DEFCONFIG): $(LINUX_DEFCONFIG_FRAGMENTS)
	KCONFIG_CONFIG="$@" $(LINUX_SRC)/scripts/kconfig/merge_config.sh -m -r $^

# tmp_defconfig lives in the source tree,
# so we should delete it after we're done
.INTERMEDIATE: $(LINUX_TMP_DEFCONFIG)

LINUX_MODULES_LOAD := $(TRUSTY_TOP)/trusty/device/arm/generic-arm64/project/modules.load

ifeq (,$(LINUX_TRUSTY_INTREE))
# Make a copy of common-modules/trusty because the kernel build system
# creates files directly in the directory passed to M=
LINUX_TRUSTY_MODULES_SRC_DIR := linux/common-modules/trusty
LINUX_TRUSTY_MODULES_COPY_DIR := $(abspath $(BUILDDIR)/linux-trusty-modules)
LINUX_TRUSTY_MODULES_SRC_FILES := $(shell find $(LINUX_TRUSTY_MODULES_SRC_DIR) -type f)
LINUX_TRUSTY_MODULES_COPY_FILES := $(patsubst $(LINUX_TRUSTY_MODULES_SRC_DIR)/%,$(LINUX_TRUSTY_MODULES_COPY_DIR)/%,$(LINUX_TRUSTY_MODULES_SRC_FILES))
$(LINUX_TRUSTY_MODULES_COPY_FILES): $(LINUX_TRUSTY_MODULES_COPY_DIR)/%: $(LINUX_TRUSTY_MODULES_SRC_DIR)/%
	@$(MKDIR)
	@cp $< $@

# For now, symlink the Trusty module Kconfig into Kconfig.ext
# The kernel will import the latter into its build.
LINUX_KCONFIG_EXT_PREFIX := $(LINUX_TRUSTY_MODULES_COPY_DIR)/
LINUX_TRUSTY_MODULES_KCONFIG_EXT := $(LINUX_TRUSTY_MODULES_COPY_DIR)/Kconfig.ext
$(LINUX_TRUSTY_MODULES_KCONFIG_EXT): $(LINUX_TRUSTY_MODULES_COPY_DIR)/drivers/trusty/Kconfig
	@ln -srf $< $@

LINUX_MODULES_STAGING_DIR := $(abspath $(BUILDDIR)/linux-modules-staging)
LINUX_RAMDISK_IMAGE := $(abspath $(BUILDDIR)/ramdisk.img)
endif # LINUX_TRUSTY_INTREE

$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_TMP_DEFCONFIG := $(LINUX_TMP_DEFCONFIG)
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): PATH_TOOLS_BINDIR := $(PATH_TOOLS_BINDIR)
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_BUILD_TOOLS := $(LINUX_BUILD_TOOLS)
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS := -C $(LINUX_SRC)
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += O=$(LINUX_BUILD_DIR)
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += ARCH=$(LINUX_ARCH)

# Preserve compatibility with older linux kernel
ifeq (,$(wildcard $(LINUX_SRC)/Documentation/kbuild/llvm.rst))
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): CLANG_BINDIR := $(CLANG_BINDIR)
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += CROSS_COMPILE=$(ARCH_$(LINUX_ARCH)_TOOLCHAIN_PREFIX)
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += CC=$(CLANG_BINDIR)/clang
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += LD=$(CLANG_BINDIR)/ld.lld
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += CLANG_TRIPLE=$(LINUX_CLANG_TRIPLE)
else
# Newer linux kernel versions need a newer toolchain (optionally specified in
# LINUX_CLANG_BINDIR) than the older linux kernel needs or supports.
LINUX_CLANG_BINDIR ?= $(CLANG_BINDIR)
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): CLANG_BINDIR := $(LINUX_CLANG_BINDIR)
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += CROSS_COMPILE=$(LINUX_CLANG_TRIPLE)
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += LLVM=1
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += LLVM_IAS=1
endif

$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += LEX=$(BUILDTOOLS_BINDIR)/flex
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += YACC=$(BUILDTOOLS_BINDIR)/bison
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += BISON_PKGDATADIR=$(BUILDTOOLS_COMMON)/bison
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += HOSTCFLAGS="-isystem$(LINUX_BUILD_TOOLS)/include"
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += HOSTLDFLAGS="-L$(LINUX_BUILD_TOOLS)/lib64 -rpath $(LINUX_BUILD_TOOLS)/lib64"
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += LIBCLANG_PATH=$(LINUX_CLANG_BINDIR)/../lib/libclang.so

$(LINUX_IMAGE): $(LINUX_TMP_DEFCONFIG)
	PATH=$(CLANG_BINDIR):$(PATH_TOOLS_BINDIR):$(PATH) $(MAKE) $(LINUX_MAKE_ARGS) $(notdir $(LINUX_TMP_DEFCONFIG))
	PATH=$(CLANG_BINDIR):$(PATH_TOOLS_BINDIR):$(PATH) $(MAKE) $(LINUX_MAKE_ARGS)

ifneq (,$(LINUX_RAMDISK_IMAGE))
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += INSTALL_MOD_PATH=$(LINUX_MODULES_STAGING_DIR)
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += INSTALL_MOD_DIR=trusty
$(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE): LINUX_MAKE_ARGS += KCONFIG_EXT_PREFIX=$(LINUX_KCONFIG_EXT_PREFIX)

$(LINUX_RAMDISK_IMAGE): LINUX_MODULES_STAGING_DIR := $(LINUX_MODULES_STAGING_DIR)
$(LINUX_RAMDISK_IMAGE): LINUX_TRUSTY_MODULES_MAKEFILE_DIR := $(LINUX_TRUSTY_MODULES_COPY_DIR)/drivers/trusty
$(LINUX_RAMDISK_IMAGE): TRUSTY_MODULES_ORDER_HASH := $(shell echo "${LINUX_TRUSTY_MODULES_MAKEFILE_DIR}" | $(PATH_TOOLS_BINDIR)/md5sum -b)
$(LINUX_RAMDISK_IMAGE): BUILDTOOLS_BINDIR := $(BUILDTOOLS_BINDIR)
$(LINUX_RAMDISK_IMAGE): REPLACE_RAMDISK_MODULES := $(PY3) trusty/host/common/scripts/replace_ramdisk_modules/replace_ramdisk_modules.py
$(LINUX_RAMDISK_IMAGE): ANDROID_RAMDISK := trusty/prebuilts/aosp/android/out/target/product/trusty/ramdisk.img
$(LINUX_RAMDISK_IMAGE): LINUX_MODULES_LOAD := $(LINUX_MODULES_LOAD)
$(LINUX_RAMDISK_IMAGE): $(LINUX_IMAGE) $(LINUX_TRUSTY_MODULES_COPY_FILES) $(LINUX_TRUSTY_MODULES_KCONFIG_EXT) $(LINUX_MODULES_LOAD)
	@echo building Linux ramdisk
	@rm -rf $(LINUX_MODULES_STAGING_DIR)
	PATH=$(CLANG_BINDIR):$(PATH_TOOLS_BINDIR):$(PATH) $(MAKE) $(LINUX_MAKE_ARGS) modules_install
	PATH=$(CLANG_BINDIR):$(PATH_TOOLS_BINDIR):$(PATH) $(MAKE) $(LINUX_MAKE_ARGS) M=$(LINUX_TRUSTY_MODULES_MAKEFILE_DIR) modules
	PATH=$(CLANG_BINDIR):$(PATH_TOOLS_BINDIR):$(PATH) $(MAKE) $(LINUX_MAKE_ARGS) M=$(LINUX_TRUSTY_MODULES_MAKEFILE_DIR) modules_install
	PATH=$(BUILDTOOLS_BINDIR):$(LINUX_BUILD_TOOLS)/bin:$(PATH) $(REPLACE_RAMDISK_MODULES) --android-ramdisk $(ANDROID_RAMDISK) --kernel-ramdisk $(LINUX_MODULES_STAGING_DIR) --output-ramdisk $@ --override-modules-load $(LINUX_MODULES_LOAD) --check-modules-order --extra-modules-order "modules.order.$(TRUSTY_MODULES_ORDER_HASH)"

endif # LINUX_RAMDISK_IMAGE
else
$(LINUX_BUILD_DIR): $(LINUX_PREBUILTS_IMAGE)
	@echo copying Linux prebuilts
	@rm -rf $@
	@$(MKDIR)

$(LINUX_IMAGE): $(LINUX_BUILD_DIR)
	@mkdir -p $(@D)
	@cp -r ${LINUX_PREBUILTS_IMAGE} $@

endif

# Add LINUX_IMAGE to the list of project dependencies
EXTRA_BUILDDEPS += $(LINUX_IMAGE) $(LINUX_RAMDISK_IMAGE)

LINUX_DEFCONFIG_FRAGMENTS :=
LINUX_TMP_DEFCONFIG :=
LINUX_CONFIG_DIR :=
LINUX_SRC :=
LINUX_CLANG_TRIPLE :=
LINUX_TRUSTY_INTREE :=
LINUX_TRUSTY_MODULES_SRC_DIR :=
LINUX_TRUSTY_MODULES_COPY_DIR :=
LINUX_TRUSTY_MODULES_SRC_FILES :=
LINUX_TRUSTY_MODULES_COPY_FILES :=
LINUX_KCONFIG_EXT_PREFIX :=
LINUX_TRUSTY_MODULES_KCONFIG_EXT :=
LINUX_MODULES_STAGING_DIR :=
LINUX_MODULES_LOAD :=
LINUX_ENABLE_FFA_TRANSPORT :=
LINUX_ENABLE_SMC_TRANSPORT :=
