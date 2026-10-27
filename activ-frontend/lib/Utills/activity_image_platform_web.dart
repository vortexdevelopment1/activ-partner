import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const _database = 'activ_partner_activity_images';
const _store = 'images';

Future<web.IDBDatabase> _open() {
  final done = Completer<web.IDBDatabase>();
  final request = web.window.indexedDB!.open(_database, 1);
  request.onupgradeneeded = ((web.Event _) {
    final database = request.result as web.IDBDatabase;
    if (database.objectStoreNames.length == 0) database.createObjectStore(_store);
  }).toJS;
  request.onsuccess = ((web.Event _) {
    if (!done.isCompleted) done.complete(request.result as web.IDBDatabase);
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!done.isCompleted) done.completeError(request.error ?? 'IndexedDB open failed');
  }).toJS;
  return done.future;
}

Future<void> _complete(web.IDBTransaction transaction) {
  final done = Completer<void>();
  transaction.oncomplete = ((web.Event _) {
    if (!done.isCompleted) done.complete();
  }).toJS;
  transaction.onerror = ((web.Event _) {
    if (!done.isCompleted) done.completeError('IndexedDB transaction failed');
  }).toJS;
  transaction.onabort = ((web.Event _) {
    if (!done.isCompleted) done.completeError('IndexedDB transaction aborted');
  }).toJS;
  return done.future;
}

String _key(String draftId, String imageId) => '$draftId::$imageId';

Future<void> persistImageBytes({
  required String draftId,
  required String imageId,
  required Uint8List bytes,
  required String name,
  required String mimeType,
}) async {
  final database = await _open();
  final transaction = database.transaction(_store.toJS, 'readwrite');
  final completion = _complete(transaction);
  transaction.objectStore(_store).put(<String, Object?>{
    'bytes': base64Encode(bytes), 'name': name, 'mimeType': mimeType,
    'updatedAt': DateTime.now().toIso8601String(),
  }.jsify(), _key(draftId, imageId).toJS);
  await completion;
}

Future<Uint8List?> readImageBytes({
  required String draftId,
  required String imageId,
}) async {
  final database = await _open();
  final transaction = database.transaction(_store.toJS, 'readonly');
  final completion = _complete(transaction);
  final request = transaction.objectStore(_store).get(_key(draftId, imageId).toJS);
  final result = await _requestResult(request);
  await completion;
  final value = result.dartify();
  if (value is! Map) return null;
  try { return Uint8List.fromList(base64Decode(value['bytes'].toString())); } catch (_) { return null; }
}

Future<JSAny?> _requestResult(web.IDBRequest request) {
  final done = Completer<JSAny?>();
  request.onsuccess = ((web.Event _) {
    if (!done.isCompleted) done.complete(request.result);
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!done.isCompleted) done.completeError(request.error ?? 'IndexedDB request failed');
  }).toJS;
  return done.future;
}
