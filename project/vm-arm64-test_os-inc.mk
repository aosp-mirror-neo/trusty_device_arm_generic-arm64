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

# the test_os VM is expected to be used for Trusty OS testing
# as well as SEE HAL testing in standalone (i.e. with local SEE HAL services).
#
# include with the placeholder trusted hals
#
WITH_FAKE_HWRNG ?= true
WITH_FAKE_HWKEY ?= true
WITH_FAKE_KEYBOX ?= true

# Derive RPMB key using HKDF
WITH_HKDF_RPMB_KEY ?= true

STORAGE_ENABLE_ERROR_REPORTING ?= true
STORAGE_AIDL_ENABLED ?= true

# when placeholder trusted hals are included,
# the AuthMgrFE shall not enable the remote accessor
# feature for secure storage, hwcrypto or device state
AUTHMGRFE_ACCESSOR_DEVICESTATE ?= false
AUTHMGRFE_ACCESSOR_STORAGE ?= false
AUTHMGRFE_ACCESSOR_HWCRYPTO ?= false
TRUSTY_VM_ENABLE_AUTHMGR_VIA_VSOCK ?= false
TRUSTY_VM_ENABLE_TIPC_PORT_VIA_VSOCK ?= false

include project/vm-arm-virt-test-inc.mk

# TRUSTY_BUILTIN_USER_TASKS := \
# 	trusty/user/base/app/apploader \

TRUSTY_BUILTIN_USER_TASKS += \
	trusty/user/app/sample/devicestatehal/server/app \
	trusty/user/app/authmgr/authmgr-be/app \
	trusty/user/app/sample/hwaes \
	trusty/user/app/sample/hwcrypto \
	trusty/user/app/sample/hwcryptohal/server/app \
	trusty/user/app/storage \
	trusty/user/base/app/metrics \
	trusty/user/base/app/system_state_server_static \

# In the placeholder-trusted-hal configuration, the guest VM includes both
# AuthMgrFE and AuthMgrBE TAs, which connect directly, and not via virtio over
# FFA. In the case of a direct connection, AuthMgrBE receives a UUID as the
# ClientIdentifier, instead of a FFA VM-ID which it would receive in the case
# where the client connects via virtio over FFA. If it receives a UUID when this
# flag is enabled, the  AuthMgrBE extracts the first 16 bits of the UUID as
# a mock transport id (a.k.a VM-ID).
AUTHMGR_MOCK_TRANSPORT_ID := true
