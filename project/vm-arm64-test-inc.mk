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

# Enable vsock port forwarder
# TODO: make this option explicit with TRUSTY_VM_INCLUDE_PORT_FORWARDER
TEST_BUILD := true

# Enable Vintf TA for vts_treble_vintf_trusted_hal_test
TRUSTY_VM_INCLUDE_VINTF_TA := true

# This VM contains both authmgr_be_lib tests and tests that depend on a
# functioning authmgr-fe. The trusty authmgr-be implementation prevents
# two different connections from the same VM attempting to authenticate.
# We get around this by running authmgr-be tests before any tests that
# depend on authmgr-fe and configuring authmgr-fe to defer pVM authentication
# until the first request for an authorized connection to a trusted HAL.
AUTHMGRFE_LAZY_PHASE_1 := true

#
# include list of test TAs for the Trusted HALs
#
TRUSTY_RUST_USER_TESTS := \
	trusty/user/app/authmgr/authmgr-fe \
	trusty/user/app/sample/hwcryptokey-test \
	trusty/user/app/storage/test/storage-unittest-aidl \
	trusty/user/app/storage/test/storage-unittest-aidl/ns \
	trusty/user/app/authmgr/authmgr-be/lib \

# the test-vm does not include any TAs by default
# (except for the test TAs that are included by virt-test-inc.mk)
#
# tests in Trusty are mostly declared as TRUSTY_LOADABLE_USER_TESTS,
# they also are included by default as builtin apps
# (unless the top-level makefile initializes TRUSTY_BUILTIN_USER_TESTS,
#  see documentation in trusty/kernel/app/trusty/user-tasks.mk)
#
# for virt payload, loadable TAs are generally not applicable
# (apploader interface is not a stable ABI yet).
# So apploader should generally be disabled.
#
# the Trusty build system however makes it complicated to disable
# apploader service while still declaring tests as loadable.
# as a short-term workaround, the test-vm will include apploader service
# TODO(b/) evolve `trusty/kernel/app/trusty/user-tasks.mk` to support
# disabling apploader service and rebalancing loadable test as builtin tests
TRUSTY_BUILTIN_USER_TASKS := \
	trusty/user/base/app/apploader \
	trusty/user/app/authmgr/authmgr-fe/app \

ifeq (true,$(call TOBOOL,$(USER_COVERAGE_ENABLED)))
TRUSTY_ALL_USER_TASKS += \
	trusty/user/base/app/coverage \

endif

ifeq (true,$(call TOBOOL,$(UNITTEST_COVERAGE_ENABLED)))
TRUSTY_ALL_USER_TASKS += \
	trusty/user/base/app/line-coverage \

endif

