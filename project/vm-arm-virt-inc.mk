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

# release build
DEBUG ?= 1
UBSAN_ENABLED ?= false
RELEASE_BUILD ?= true
SYMTAB_ENABLED ?= false

# no placeholder hals by default
WITH_FAKE_HWRNG ?= false
WITH_FAKE_HWKEY ?= false
WITH_FAKE_KEYBOX ?= false

USE_SYSTEM_BINDER := true

include project/generic-arm-virt-inc.mk
include project/generic-arm-tz-inc.mk

