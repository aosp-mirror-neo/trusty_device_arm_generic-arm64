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

include project/vm-arm-virt-test-inc.mk

# the test_os VM does not include any TAs by default
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

