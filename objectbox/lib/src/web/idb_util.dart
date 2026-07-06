// Small promise-style wrapper around IndexedDB via package:web, shared by the
// web implementation of Store/Box. Kept intentionally minimal: only what the
// engine needs (open with upgrade, batched read/write transactions).
// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../common.dart';

/// Completes with the request result, or errors with an [ObjectBoxException].
Future<T> idbRequest<T extends JSAny?>(web.IDBRequest request) {
  final completer = Completer<T>.sync();
  request.onsuccess = ((web.Event event) {
    completer.complete(request.result as T);
  }).toJS;
  request.onerror = ((web.Event event) {
    completer.completeError(ObjectBoxException(
        'IndexedDB request failed: ${request.error?.message ?? 'unknown'}'));
  }).toJS;
  return completer.future;
}

/// Completes when the transaction is complete, errors on abort/error.
Future<void> idbTransactionDone(web.IDBTransaction transaction) {
  final completer = Completer<void>.sync();
  transaction.oncomplete = ((web.Event event) {
    completer.complete();
  }).toJS;
  transaction.onerror = ((web.Event event) {
    if (!completer.isCompleted) {
      completer.completeError(ObjectBoxException(
          'IndexedDB transaction failed: ${transaction.error?.message ?? 'unknown'}'));
    }
  }).toJS;
  transaction.onabort = ((web.Event event) {
    if (!completer.isCompleted) {
      completer.completeError(
          ObjectBoxException('IndexedDB transaction was aborted'));
    }
  }).toJS;
  return completer.future;
}

/// Opens [name], creating/upgrading object stores so that all [storeNames]
/// exist. Uses the "open without version, then reopen with version+1 if
/// stores are missing" dance so it works with any pre-existing version.
Future<web.IDBDatabase> idbOpen(String name, List<String> storeNames) async {
  final factory = web.window.indexedDB;

  Future<web.IDBDatabase> open(int? version) {
    final request =
        version == null ? factory.open(name) : factory.open(name, version);
    request.onupgradeneeded = ((web.IDBVersionChangeEvent event) {
      final db = request.result as web.IDBDatabase;
      for (final storeName in storeNames) {
        if (!db.objectStoreNames.contains(storeName)) {
          db.createObjectStore(storeName);
        }
      }
    }).toJS;
    return idbRequest<JSAny?>(request).then((_) {
      final db = request.result as web.IDBDatabase;
      return db;
    });
  }

  var db = await open(null);
  final missing =
      storeNames.any((storeName) => !db.objectStoreNames.contains(storeName));
  if (missing) {
    final newVersion = db.version + 1;
    db.close();
    db = await open(newVersion);
  }
  return db;
}

/// Reads all (key, value) pairs of an object store.
Future<List<(int, JSAny?)>> idbReadAll(
    web.IDBDatabase db, String storeName) async {
  final transaction = db.transaction(storeName.toJS, 'readonly');
  final store = transaction.objectStore(storeName);
  final keys = await idbRequest<JSArray>(store.getAllKeys());
  final values = await idbRequest<JSArray>(store.getAll());
  final keysDart = keys.toDart;
  final valuesDart = values.toDart;
  final result = <(int, JSAny?)>[];
  for (var i = 0; i < keysDart.length; i++) {
    result.add(((keysDart[i] as JSNumber).toDartInt, valuesDart[i]));
  }
  return result;
}

/// Like [idbReadAll] but for stores with string keys.
Future<List<(String, JSAny?)>> idbReadAllStringKeys(
    web.IDBDatabase db, String storeName) async {
  final transaction = db.transaction(storeName.toJS, 'readonly');
  final store = transaction.objectStore(storeName);
  final keys = await idbRequest<JSArray>(store.getAllKeys());
  final values = await idbRequest<JSArray>(store.getAll());
  final keysDart = keys.toDart;
  final valuesDart = values.toDart;
  final result = <(String, JSAny?)>[];
  for (var i = 0; i < keysDart.length; i++) {
    result.add(((keysDart[i] as JSString).toDart, valuesDart[i]));
  }
  return result;
}
