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

#
# complement with the placeholder trusted hals
#
WITH_FAKE_HWRNG ?= true
WITH_FAKE_HWKEY ?= true
WITH_FAKE_KEYBOX ?= true

# Storage should send error reports to the metrics service
STORAGE_ENABLE_ERROR_REPORTING ?= true
STORAGE_AIDL_ENABLED ?= true

include project/vm-arm64-test-inc.mk

TRUSTY_BUILTIN_USER_TASKS += \
	trusty/user/app/storage \
	trusty/user/app/sample/hwaes \
	trusty/user/app/sample/hwbcc \
	trusty/user/app/sample/hwcrypto \
	trusty/user/app/sample/hwcryptohal/server/app \
	trusty/user/app/sample/hwwsk \
	trusty/user/base/app/system_state_server_static \
