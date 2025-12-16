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

QEMU_TRUSTY_PROJECT := generic-arm64-test-debug

# Enable BTI
KERNEL_BTI_ENABLED ?= true

# D-cache lines are 64 bytes on QEMU arm64
GLOBAL_DEFINES += CACHE_LINE=64

# Enable STORAGE_EXTERNAL_SUPER_BLOCK_MAC (without TP) for one qemu build
SECURE_STORAGE_USE_TDP := true
STORAGE_EXTERNAL_SUPER_BLOCK_MAC := trusty/user/app/storage/rpmb_super_block_mac
STORAGE_HAS_RPMB := false
STORAGE_USE_EARLY_TDP := true

# Disable STORAGE_SUPPORT_STAGE_DURING_UDC for one qemu build
STORAGE_SUPPORT_STAGE_DURING_UDC := false

include project/debugging-inc.mk
include project/qemu-inc.mk
