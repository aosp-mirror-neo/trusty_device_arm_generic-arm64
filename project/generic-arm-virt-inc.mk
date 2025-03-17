# Copyright (C) 2023 The Android Open Source Project
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

ARM64_BOOT_PROTOCOL := X0_DTB

# Derive RPMB key using HKDF
WITH_HKDF_RPMB_KEY ?= true

# Always allow provisioning for emulator builds
STATIC_SYSTEM_STATE_FLAG_PROVISIONING_ALLOWED := 1

LIB_SM_ENABLED := false
WITH_TRUSTY_VIRTIO_IPC_DEV := false

# Disable for quicker boot since the uart output is much slower than the smc to el3
GENERIC_ARM64_DEBUG := UART

GIC_VERSION := 3
# TODO(b/383197438): Disable SMP until we have code to enable secondary CPUs
SMP_MAX_CPUS := 1
GLOBAL_DEFINES += ARM_GIC_SELECTED_IRQ_GROUP=GRP1NS
TIMER_ARM_GENERIC_SELECTED ?= CNTV

# Enable MMIO guard
MMIO_GUARD_ENABLED ?= true

TRUSTY_VM_GUEST := true
GLOBAL_DEFINES += TRUSTY_VM_GUEST=1
