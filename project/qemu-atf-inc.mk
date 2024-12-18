#
# Copyright (c) 2015-2018, Google, Inc. All rights reserved
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

#
#  This makefile containts rules for  building ATF image for Trusty.
#  It is expected that it will be included by the project that requres ATF
#  support and the caller will configure the following variables:
#
#      ATF_ROOT       - Root of arm-trusted-firmware project
#      ATF_BUILD_BASE - location that will be used to store temp files and
#                       build results.
#      ATF_PLAT       - ATF platform to build
#      ATF_DEBUG      - ATF debug level
#      ATF_WITH_TRUSTY_GENERIC_SERVICES - Add Trusty generic services
#      ATF_TOOLCHAIN_PREFIX - AArch64 toolchain to use for building ATF
#
#  The following variable is returned to the caller:
#      ATF_OUT_DIR    - Directory containing ATF images
#      ATF_BUILD_BASE - location that will be used to store temp files and
#                       build results.
#
#

# set location of resulting ATF image
ifneq ($(ATF_DEBUG), 0)
ATF_OUT_DIR := $(ATF_BUILD_BASE)/$(ATF_PLAT)/debug
else
ATF_OUT_DIR:=$(ATF_BUILD_BASE)/$(ATF_PLAT)/release
endif
ATF_BIN := $(ATF_OUT_DIR)/bl31.bin

ATF_WITH_TRUSTY_GENERIC_SERVICES ?= false

ifeq (true,$(call TOBOOL,$(HAFNIUM)))
ATF_MAKE_ARGS := SPD=spmd
ATF_MAKE_ARGS += SPMD_SPM_AT_SEL2=1
ATF_MAKE_ARGS += BL32=$(BL32_BIN)
ATF_MAKE_ARGS += BL33=$(TEST_RUNNER_BIN)
ATF_MAKE_ARGS += SP_LAYOUT_FILE=$(HAFNIUM_OUT_DIR)/sp_layout.json
ATF_MAKE_ARGS += QEMU_TOS_FW_CONFIG_DTS=$(HAFNIUM_OUT_DIR)/tos_fw_config.dts
ATF_MAKE_ARGS += QEMU_TB_FW_CONFIG_DTS=$(HAFNIUM_OUT_DIR)/tb_fw_config.dts
# Symlink the Hafnium DTBs to where ATF will look for them.
HAFNIUM_DTBS := tb_fw_config.dtb tos_fw_config.dtb
HAFNIUM_DTBS_SRCS := $(addprefix $(ATF_OUT_DIR)/fdts/, $(HAFNIUM_DTBS))
$(HAFNIUM_DTBS_SRCS): $(ATF_BIN)
HAFNIUM_DTBS_OUT := $(addprefix $(ATF_OUT_DIR)/, $(HAFNIUM_DTBS))
$(HAFNIUM_DTBS_OUT): $(ATF_OUT_DIR)/%.dtb: $(ATF_OUT_DIR)/fdts/%.dtb
	ln -sf $< $@
EXTRA_BUILDDEPS += $(HAFNIUM_DTBS_OUT)
else
ATF_MAKE_ARGS := SPD=trusty
ATF_MAKE_ARGS += SPMD_SPM_AT_SEL2=0
endif
ATF_MAKE_ARGS += CC=$(CLANG_BINDIR)/clang
ATF_MAKE_ARGS += DTC=$(TRUSTY_TOP)/prebuilts/misc/linux-x86/dtc/dtc
ATF_MAKE_ARGS += CROSS_COMPILE=$(ATF_TOOLCHAIN_PREFIX)
ATF_MAKE_ARGS += PLAT=$(ATF_PLAT)
ATF_MAKE_ARGS += DEBUG=$(ATF_DEBUG)
ATF_MAKE_ARGS += BUILD_BASE=$(ATF_BUILD_BASE)
ATF_MAKE_ARGS += QEMU_USE_GIC_DRIVER=QEMU_GICV$(GIC_VERSION)
ATF_MAKE_ARGS += CTX_INCLUDE_FPREGS=1
# On aarch32, we skip EL2, see 27d8e1e75a2f45d7c23
ifeq (true,$(call TOBOOL,$(KERNEL_32BIT)))
ATF_MAKE_ARGS += INIT_UNUSED_NS_EL2=1
endif

ifeq (true,$(call TOBOOL,$(ATF_WITH_TRUSTY_GENERIC_SERVICES)))
ATF_MAKE_ARGS += TRUSTY_SPD_WITH_GENERIC_SERVICES=1
endif

$(ATF_BIN): ATF_ROOT:=$(ATF_ROOT)
$(ATF_BIN): ATF_MAKE_ARGS:=$(ATF_MAKE_ARGS)
$(ATF_BIN): .PHONY
	$(MAKE) -C $(ATF_ROOT) $(ATF_MAKE_ARGS) all sp

# Add ATF_BIN to the list of project dependencies
EXTRA_BUILDDEPS += $(ATF_BIN)

ATF_ROOT:=
ATF_PLAT:=
ATF_DEBUG:=
ATF_WITH_TRUSTY_GENERIC_SERVICES:=
ATF_TOOLCHAIN_PREFIX:=
ATF_BIN:=
ATF_MAKE_ARGS:=
