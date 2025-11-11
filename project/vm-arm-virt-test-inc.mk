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


USE_SYSTEM_BINDER := true
DICE_PROFILE_FOR_OPEN_DICE := android
MAP_DT_DATA_TO_USERSPACE := true
WITH_FAKE_HWRNG ?= true
WITH_FAKE_HWKEY ?= true
WITH_FAKE_KEYBOX ?= true

include project/generic-arm-virt-inc.mk
include project/generic-arm-tz-test-inc.mk
