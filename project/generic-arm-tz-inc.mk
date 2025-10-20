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

# The virtio-msg vsock device needs to receive FF-A messages so it's only
# included if lib/sm is built with the FF-A loop to do so.
ifeq (true,$(call TOBOOL,$(LIB_SM_WITH_FFA_LOOP)))
VSOCK_WITH_VIRTIO_MSG_DEVICE ?= true
endif

include project/generic-arm-inc.mk
