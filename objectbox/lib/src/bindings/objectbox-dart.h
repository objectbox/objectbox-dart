/*
 * Copyright 2021 ObjectBox Ltd. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef OBJECTBOX_DART_H
#define OBJECTBOX_DART_H

#include <stdint.h>

#include "objectbox.h"

#ifdef __cplusplus
extern "C" {
#endif

//----------------------------------------------
// Dart-specific binding
//
// Following section provides [Dart](https://dart.dev) specific async callbacks integration.
// These functions are only used internally by [objectbox-dart](https://github.com/objectbox/objectbox-dart) binding.
// In short - instead of issuing callbacks from background threads, their messages are sent to Dart over NativePorts.
//----------------------------------------------

/// Initializes Dart API - call before any other obx_dart_* functions.
obx_err obx_dart_init_api(void* data);

/// @see obx_observe()
/// Note: use obx_observer_close() to free unassign the observer and free resources after you're done with it
OBX_observer* obx_dart_observe(OBX_store* store, int64_t native_port);

// @see obx_observe_single_type()
OBX_observer* obx_dart_observe_single_type(OBX_store* store, obx_schema_id type_id, int64_t native_port);

// Note: use OBX_dart_sync_listener_close() to unassign the listener and free native resources
struct OBX_dart_sync_listener;
typedef struct OBX_dart_sync_listener OBX_dart_sync_listener;

/// @param listener may be NULL
obx_err obx_dart_sync_listener_close(OBX_dart_sync_listener* listener);

// @see obx_sync_listener_connect()
OBX_dart_sync_listener* obx_dart_sync_listener_connect(OBX_sync* sync, int64_t native_port);

/// @see obx_sync_listener_disconnect()
OBX_dart_sync_listener* obx_dart_sync_listener_disconnect(OBX_sync* sync, int64_t native_port);

/// @see obx_sync_listener_login()
OBX_dart_sync_listener* obx_dart_sync_listener_login(OBX_sync* sync, int64_t native_port);

/// @see obx_sync_listener_login_failure()
OBX_dart_sync_listener* obx_dart_sync_listener_login_failure(OBX_sync* sync, int64_t native_port);

/// @see obx_sync_listener_complete()
OBX_dart_sync_listener* obx_dart_sync_listener_complete(OBX_sync* sync, int64_t native_port);

/// @see obx_sync_listener_change()
OBX_dart_sync_listener* obx_dart_sync_listener_change(OBX_sync* sync, int64_t native_port);

#ifdef __cplusplus
}
#endif

#endif  // OBJECTBOX_DART_H
