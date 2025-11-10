# Copyright (C) 2025 The Android Open Source Project
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

include project/vm-arm-virt-inc.mk

# VM to TZ initiator ports
# Enable Connecting to a remote(TZ) AuthMgrAuthorization service via a vsock port
TRUSTY_VM_ENABLE_AUTHMGR_VIA_VSOCK := true
# Enable Connecting to a remote(TZ) Tipc Port via a vsock port
# (for raw vsock testing)
TRUSTY_VM_ENABLE_TIPC_PORT_VIA_VSOCK := true

# Host to VM target ports
# enable keymint target port
TRUSTY_VM_INCLUDE_KEYMINT ?= true

# enable gatekeeper target port
TRUSTY_VM_INCLUDE_GATEKEEPER ?= true

# Trusted HAL for hardware crypto key and secure storage in KeyMint
KEYMINT_WITH_TRUSTED_HAL ?= true

# TODO(b/453412413): allow keymint HAL to provision keymint until
# the dedicated front-end is in place
KEYMINT_PROVISIONING_VIA_HAL ?= true

# the AuthMgrFE shall enable the remote accessor
# feature for secure storage, hwcrypto and device state
AUTHMGRFE_ACCESSOR_DEVICESTATE ?= true
AUTHMGRFE_ACCESSOR_STORAGE ?= true
AUTHMGRFE_ACCESSOR_HWCRYPTO ?= true

# builtin TAs
TRUSTY_BUILTIN_USER_TASKS := \
	trusty/user/app/authmgr/authmgr-fe/app \
	trusty/user/app/gatekeeper \
	trusty/user/app/keymint/security_vm_app \
	trusty/user/base/app/device_tree \

ifeq (true,$(call TOBOOL,$(USER_COVERAGE_ENABLED)))
TRUSTY_ALL_USER_TASKS += \
	trusty/user/base/app/coverage \

endif

ifeq (true,$(call TOBOOL,$(UNITTEST_COVERAGE_ENABLED)))
TRUSTY_ALL_USER_TASKS += \
	trusty/user/base/app/line-coverage \

endif
