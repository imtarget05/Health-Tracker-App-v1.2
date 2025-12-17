import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

class ProfileSyncService {
  ProfileSyncService._privateConstructor();
  static final ProfileSyncService instance = ProfileSyncService._privateConstructor();

  static const _boxName = 'profile_sync_queue';
  Box<dynamic>? _box;
  bool _initialized = false;
  bool _flushing = false;
  // Notify UI about queue length
  final queueCount = ValueNotifier<int>(0);

  Future<void> init() async {
    if (_initialized) return;
    // init Hive
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    // init firebase if needed
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
    } catch (_) {}
    _initialized = true;
  _updateQueueCount();
    debugPrint('ProfileSync: initialized, queue=${_box?.length ?? 0}');
    // try to flush any pending items
    unawaited(_flushQueue());
  }

  Future<void> saveProfilePartial(Map<String, dynamic> data) async {
    await init();
    // attach timestamp
    final item = {
      'data': data,
      'createdAt': DateTime.now().toIso8601String(),
    };

    // Try immediate write if user signed in
    final user = FirebaseAuth.instance.currentUser;
    var immediateFailedDueToPermissionDenied = false;
    if (user != null) {
      try {
        final db = FirebaseFirestore.instance;
        final doc = db.collection('users').doc(user.uid);
        debugPrint('ProfileSync: immediate save for ${user.uid}, data: $data');
        await doc.set(data, SetOptions(merge: true));
        debugPrint('ProfileSync: immediate save successful for ${user.uid}');
        return;
      } catch (e) {
        debugPrint('ProfileSync: immediate save failed for ${user.uid}: $e');
        // If the failure is permission-denied, avoid immediately retrying flush
        if (e is FirebaseException && e.code == 'permission-denied') {
          immediateFailedDueToPermissionDenied = true;
        }
        // fall through to enqueue
      }
    }

    // enqueue for later
    if (_box == null) {
      debugPrint('ProfileSync: box is null when enqueuing; initializing and retrying');
      await init();
    }
    await _box!.add(jsonEncode(item));
    _updateQueueCount();
    debugPrint('ProfileSync: enqueued item, queue=${_box?.length ?? 0}');
    // attempt flush in background unless immediate save failed due to permission issues
    if (!immediateFailedDueToPermissionDenied) {
      unawaited(_flushQueue());
    } else {
      debugPrint('ProfileSync: skipping immediate flush due to permission-denied');
    }
  }

  /// Return queued items as decoded list
  List<Map<String, dynamic>> readQueue() {
    if (!_initialized || _box == null) return [];
    return _box!.values.map((e) {
      try {
        return Map<String, dynamic>.from(jsonDecode(e as String));
      } catch (_) {
        return <String, dynamic>{};
      }
    }).toList();
  }

  Future<void> clearQueue() async {
    if (!_initialized || _box == null) return;
    await _box!.clear();
  _updateQueueCount();
  }

  /// Public retry trigger
  Future<void> retryQueue() async => _flushQueue();

  Future<void> _flushQueue() async {
    if (_flushing) return;
    _flushing = true;
    try {
      if (!_initialized) await init();
      final box = _box!;
      int attempt = 0;
      while (box.isNotEmpty) {
        final raw = box.getAt(0) as String;
        final Map<String, dynamic> item = jsonDecode(raw) as Map<String, dynamic>;
        final data = Map<String, dynamic>.from(item['data'] ?? {});

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          // cannot write until user signs in
          debugPrint('ProfileSync: cannot flush because no user signed in; stopping');
          break;
        }

        try {
          final db = FirebaseFirestore.instance;
          final doc = db.collection('users').doc(user.uid);
          debugPrint('ProfileSync: flushing item for user ${user.uid}: $data');
          await doc.set(data, SetOptions(merge: true));
          // remove item on success
          await box.deleteAt(0);
          _updateQueueCount();
          debugPrint('ProfileSync: flushed item successfully, queue=${box.length}');
          attempt = 0; // reset backoff
        } catch (e) {
          debugPrint('ProfileSync: flush attempt failed: $e');
          // If the error is permission-denied, stop retrying for now and leave
          // the item in the queue. Backend/server is expected to reconcile user
          // profiles when client writes are disallowed by security rules.
          if (e is FirebaseException && e.code == 'permission-denied') {
            debugPrint('ProfileSync: permission-denied while flushing; aborting retries');
            break;
          }
          attempt += 1;
          final backoff = Duration(seconds: (2 << (attempt > 6 ? 6 : attempt)));
          await Future.delayed(backoff);
          // retry loop
        }
      }
    } finally {
      _flushing = false;
    }
  }

  void _updateQueueCount() {
    if (!_initialized || _box == null) {
      queueCount.value = 0;
      return;
    }
    queueCount.value = _box!.length;
  }
}
