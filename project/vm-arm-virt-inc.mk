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

# This keeps trusty is VMs in sync with the latest
# Android Profile for DICE. This is required since
# profile versions for each cert in a DICE chain must
# be of greater than or equal version to their parent.
# pvmfw uses the latest android profile for DICE and
# launches trusty in protected VMs, so we match that
# version.
DICE_PROFILE_FOR_OPEN_DICE := android

# When running trusty as a VM guest, it's likely we'll
# want the DICE handover passed into user space. This
# is only relevant for protected VMs, but fails
# gracefully if the handover is not present in the
# device tree, so we set it for all VM projects.
MAP_DT_DATA_TO_USERSPACE ?= true

include project/generic-arm-virt-inc.mk
include project/generic-arm-tz-inc.mk

