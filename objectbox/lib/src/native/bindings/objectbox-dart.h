/*
 * Copyright 2021-2023 ObjectBox Ltd. All rights reserved.
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

#include "dart_api.h"
#include "objectbox-sync.h"

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
OBX_C_API obx_err obx_dart_init_api(void* data);

/// @see obx_observe()
/// Note: use obx_observer_close() to free unassign the observer and free resources after you're done with it
OBX_C_API OBX_observer* obx_dart_observe(OBX_store* store, int64_t native_port);

// @see obx_observe_single_type()
OBX_C_API OBX_observer* obx_dart_observe_single_type(OBX_store* store, obx_schema_id type_id, int64_t native_port);

// Note: use OBX_dart_sync_listener_close() to unassign the listener and free native resources
struct OBX_dart_sync_listener;
typedef struct OBX_dart_sync_listener OBX_dart_sync_listener;

/// @param listener may be NULL
OBX_C_API obx_err obx_dart_sync_listener_close(OBX_dart_sync_listener* listener);

// @see obx_sync_listener_connect()
OBX_C_API OBX_dart_sync_listener* obx_dart_sync_listener_connect(OBX_sync* sync, int64_t native_port);

/// @see obx_sync_listener_disconnect()
OBX_C_API OBX_dart_sync_listener* obx_dart_sync_listener_disconnect(OBX_sync* sync, int64_t native_port);

/// @see obx_sync_listener_login()
OBX_C_API OBX_dart_sync_listener* obx_dart_sync_listener_login(OBX_sync* sync, int64_t native_port);

/// @see obx_sync_listener_login_failure()
OBX_C_API OBX_dart_sync_listener* obx_dart_sync_listener_login_failure(OBX_sync* sync, int64_t native_port);

/// @see obx_sync_listener_complete()
OBX_C_API OBX_dart_sync_listener* obx_dart_sync_listener_complete(OBX_sync* sync, int64_t native_port);

/// @see obx_sync_listener_change()
OBX_C_API OBX_dart_sync_listener* obx_dart_sync_listener_change(OBX_sync* sync, int64_t native_port);

/// @see obx_sync_listener_server_time()
OBX_C_API OBX_dart_sync_listener* obx_dart_sync_listener_server_time(OBX_sync* sync, int64_t native_port);

/// @see obx_async_put_object()
OBX_C_API obx_id obx_dart_async_put_object(OBX_async* async, int64_t native_port, void* data, size_t size,
                                           OBXPutMode mode);

struct OBX_dart_stream;
typedef struct OBX_dart_stream OBX_dart_stream;

OBX_C_API obx_err obx_dart_stream_close(OBX_dart_stream* stream);

/// @see obx_dart_stream_query_find
OBX_C_API OBX_dart_stream* obx_dart_query_find(OBX_query* query, int64_t native_port);

OBX_C_API OBX_dart_stream* obx_dart_query_find_ptr(OBX_query* query, int64_t native_port);

struct OBX_dart_finalizer;
typedef struct OBX_dart_finalizer OBX_dart_finalizer;

/// A function to clean up native resources. Must be a c-function (non-throwing). The returned error is ignored.
/// e.g. obx_query_close(), obx_store_close(), ...
typedef obx_err obx_dart_closer(void* native_object);

/// Attaches a finalizer (destructor) to be called when the given object is garbage-collected.
/// @param dart_object marks the object owning the native pointer
/// @param native_object is the native pointer to be freed
/// @param closer is the function that frees native_object
/// @param native_object_size is an allocated size estimate - can be used by a the Dart garbage collector to prioritize
/// @return a finalizer freed automatically when the GC finalizer runs (or manually by obx_dart_detach_finalizer())
/// @return NULL if the finalizer couldn't be attached, in which case the caller is responsible for running the closer
OBX_C_API OBX_dart_finalizer* obx_dart_attach_finalizer(Dart_Handle dart_object, obx_dart_closer* closer,
                                                        void* native_object, size_t native_object_size);

/// Detach the finalizer preliminarily, without executing its "closer"
OBX_C_API obx_err obx_dart_detach_finalizer(OBX_dart_finalizer* finalizer, Dart_Handle dart_object);

#ifdef __cplusplus
}
#endif

#endif  // OBJECTBOX_DART_H
