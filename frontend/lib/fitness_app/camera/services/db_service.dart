import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// 'package:path' not used here; removed to silence analyzer
import '../models/scan_result.dart';

class DBService {
  static const _boxName = 'scan_history';
  // notifier increments when the scan_history changes so UI can refresh
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static Future<void> init() async {
    await Hive.openBox<ScanResult>(_boxName);
  }

  static Future<void> addResult(ScanResult result) async {
    final box = Hive.box<ScanResult>(_boxName);
    await box.add(result);
  notifier.value++;
  debugPrint('DBService: addResult -> box.len=${box.length}');
  }

  static List<ScanResult> getAllResults() {
    final box = Hive.box<ScanResult>(_boxName);
  debugPrint('DBService: getAllResults -> box.len=${box.length}');
  // Return newest-first so UI can show most recent scans at the top.
  final list = box.values.toList();
  return list.reversed.toList();
  }

  static Future<void> markSynced(int index) async {
    final box = Hive.box<ScanResult>(_boxName);
    final result = box.getAt(index);
    if (result != null) {
      result.synced = true;
      await result.save();
  notifier.value++;
    }
  }

  static Future<void> deleteResult(int index) async {
    final box = Hive.box<ScanResult>(_boxName);
    await box.deleteAt(index);
  notifier.value++;
  }

  /// Try to repair ScanResult.imagePath values when files exist under
  /// application documents/scan_history but the stored path points to a
  /// removed temp location (common if earlier saves didn't persist local).
  static Future<void> repairMissingPaths() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final historyDir = Directory('${appDir.path}/scan_history');
      if (!await historyDir.exists()) return;
      final allFiles = historyDir.listSync().whereType<File>().toList();
      // Only consider common image file extensions when repairing image paths
      final allowedExt = <String>{'.jpg', '.jpeg', '.png', '.heic', '.webp'};
      final files = allFiles.where((f) {
        final name = f.path.toLowerCase();
        return allowedExt.any((ext) => name.endsWith(ext));
      }).toList();
      if (files.isEmpty) return;

      final box = Hive.box<ScanResult>(_boxName);
      for (int i = 0; i < box.length; i++) {
        final item = box.getAt(i);
        if (item == null) continue;
        final img = File(item.imagePath);
        if (await img.exists()) continue; // already valid

        // Find candidate files by timestamp proximity
        final DateTime ts = item.timestamp;
        File? best;
        Duration? bestDiff;
        for (final f in files) {
          final stat = f.statSync();
          final diff = stat.modified.difference(ts).abs();
          if (best == null || diff < (bestDiff ?? Duration(days: 365))) {
            best = f;
            bestDiff = diff;
          }
        }
        if (best != null && bestDiff != null && bestDiff.inMinutes <= 5) {
          // Update path and persist
          item.imagePath = best.path;
          await item.save();
          debugPrint('DBService: repaired image path for item[$i] -> ${best.path}');
        }
      }
      notifier.value++;
    } catch (e) {
      debugPrint('DBService: repairMissingPaths failed: $e');
    }
  }
}
