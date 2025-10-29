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


INCLUDE_CMD_PROCESSOR ?= true

INCLUDE_MEM_SHARE ?= true

VSOCK_WITH_VIRTIO_MSG_DRIVER ?= false

MODULES += \
	trusty/kernel/experimental/services/dmaimporter \
	trusty/user/base/experimental/interface/dmaimporter \

# builtin TAs
TRUSTY_BUILTIN_USER_TASKS := \
	trusty/user/app/sample/cmd_processor_test/c_app \
	trusty/user/app/authmgr/authmgr-fe/app \
	trusty/user/base/app/device_tree \

ifeq (true,$(call TOBOOL,$(USER_COVERAGE_ENABLED)))
TRUSTY_ALL_USER_TASKS += \
	trusty/user/base/app/coverage \

endif

ifeq (true,$(call TOBOOL,$(UNITTEST_COVERAGE_ENABLED)))
TRUSTY_ALL_USER_TASKS += \
	trusty/user/base/app/line-coverage \

endif
