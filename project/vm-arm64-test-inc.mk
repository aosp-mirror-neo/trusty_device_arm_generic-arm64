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
TRUSTY_VM_ENABLE_AUTHMGR_VIA_VSOCK ?= true
# Enable Connecting to a remote(TZ) Tipc Port via a vsock port
# (for raw vsock testing)
TRUSTY_VM_ENABLE_TIPC_PORT_VIA_VSOCK ?= true

# Host to VM target ports
# Enable Vintf TA for vts_treble_vintf_trusted_hal_test
TRUSTY_VM_INCLUDE_VINTF_TA ?= true

# HwCrypto operations are currently not mandatory, so this flag is used to indicate if we should
# run the tests
HWCRYPTO_EXCLUDE_SYMMETRIC_OPERATION_TESTS ?= true

# This VM contains both authmgr_be_lib tests and tests that depend on a
# functioning authmgr-fe. The trusty authmgr-be implementation prevents
# two different connections from the same VM attempting to authenticate.
# We get around this by running authmgr-be tests before any tests that
# depend on authmgr-fe and configuring authmgr-fe to defer pVM authentication
# until the first request for an authorized connection to a trusted HAL.
AUTHMGRFE_LAZY_PHASE_1 ?= true

# the AuthMgrFE shall enable the remote accessor
# feature for secure storage, hwcrypto and device state
AUTHMGRFE_ACCESSOR_DEVICESTATE ?= true
AUTHMGRFE_ACCESSOR_STORAGE ?= true
AUTHMGRFE_ACCESSOR_HWCRYPTO ?= true

#
# include list of test TAs for the Trusted HALs
#

# vsock low-level ipc tests
TRUSTY_USER_TESTS := \
	trusty/user/base/lib/tipc/test/main \
	trusty/user/base/lib/tipc/test/srv \


TRUSTY_RUST_USER_TESTS := \
	trusty/user/app/authmgr/authmgr-fe \
	trusty/user/app/sample/hwcryptokey-test \
	trusty/user/app/storage/test/storage-unittest-aidl \
	trusty/user/app/storage/test/storage-unittest-aidl/ns \
	trusty/user/app/authmgr/authmgr-be/lib \


TRUSTY_BUILTIN_USER_TASKS := \
	trusty/user/app/sample/vintf/app \
	trusty/user/app/authmgr/authmgr-fe/app \
	$(TRUSTY_RUST_USER_TESTS) \

