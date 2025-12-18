import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
// path_provider not required in this file
import '../camera/models/scan_result.dart';
import '../camera/services/db_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ScanResult> _items = [];
  late final VoidCallback _notifierListener;

  @override
  void initState() {
    super.initState();
    _load();
    _notifierListener = () {
      // reload when DBService notifies
      _load();
    };
    // subscribe
    try {
      DBService.notifier.addListener(_notifierListener);
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ensure initial load in case notifier triggered before init
    _load();
  }

  Future<void> _load() async {
    final list = DBService.getAllResults();
    setState(() => _items = list);
  }

  Future<Map<String, dynamic>?> _readSidecar(ScanResult item) async {
    try {
      final img = File(item.imagePath);
      if (!await img.exists()) return null;

      // possible sidecar locations:
      // {imageId}.json OR sameName.jpg.json OR imagePath.replaceAll('.jpg', '.json')
      final dir = img.parent;
      final base = p.basenameWithoutExtension(img.path);
      final candidates = [
        p.join(dir.path, '$base.json'),
        p.join(dir.path, '${base}.jpg.json'),
        p.join(dir.path, '${base}.jpeg.json'),
        p.join(dir.path, '${base}.png.json'),
      ];
      for (final c in candidates) {
        final f = File(c);
        if (await f.exists()) {
          final txt = await f.readAsString();
          return jsonDecode(txt) as Map<String, dynamic>;
        }
      }

      // fallback: try to find any .json file with same prefix
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
      for (final f in files) {
        if (p.basenameWithoutExtension(f.path) == base) {
          final txt = await f.readAsString();
          return jsonDecode(txt) as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }

  Widget _buildPredictionCard(Map<String, dynamic> resp) {
    final main = resp['mainFood'] as Map<String, dynamic>?;
    final total = resp['totalNutrition'] as Map<String, dynamic>?;
    final portion = main != null ? (main['portion_g'] ?? null) : null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prediction', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(main != null ? (main['food'] ?? 'Unknown') : 'Unknown', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            if (portion != null) Text('Portion: ${portion} g'),
            const SizedBox(height: 8),
            if (total != null)
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (total['calories'] != null) Chip(label: Text('Cal: ${total['calories']}')),
                  if (total['protein'] != null) Chip(label: Text('Protein: ${total['protein']}g')),
                  if (total['fat'] != null) Chip(label: Text('Fat: ${total['fat']}g')),
                  if (total['carbs'] != null) Chip(label: Text('Carbs: ${total['carbs']}g')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(),
          ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'No scan history yet. Tap the camera and Submit to add entries.\n\n(If you recently submitted, try the refresh button)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _items.length,
              itemBuilder: (context, index) {
          final item = _items[index];
          return FutureBuilder<Map<String, dynamic>?>(
            future: _readSidecar(item),
            builder: (context, snap) {
              final side = snap.data;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: InkWell(
                  onTap: () async {
                    if (!mounted) return;
                    if (side != null) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.file(File(item.imagePath), height: 160, fit: BoxFit.cover),
                                const SizedBox(height: 8),
                                 _buildPredictionCard(side),
                              ],
                            ),
                          ),
                        ),
                      );
                    } else {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.file(File(item.imagePath), height: 160, fit: BoxFit.cover),
                              const SizedBox(height: 8),
                              Text(item.predictedClass),
                              Text('Confidence: ${(item.confidence * 100).toStringAsFixed(1)}%'),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        // circular avatar / image
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[200],
                            image: File(item.imagePath).existsSync()
                                ? DecorationImage(image: FileImage(File(item.imagePath)), fit: BoxFit.cover)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // main text + chips
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(item.predictedClass, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                                  // confidence small
                                  Text('${(item.confidence * 100).toStringAsFixed(1)}%', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (side != null && side['totalNutrition'] != null)
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      if (side['totalNutrition']['calories'] != null)
                                        Padding(padding: const EdgeInsets.only(right: 6), child: Chip(label: Text('Cal: ${side['totalNutrition']['calories']}'))),
                                      if (side['totalNutrition']['protein'] != null)
                                        Padding(padding: const EdgeInsets.only(right: 6), child: Chip(label: Text('Protein: ${side['totalNutrition']['protein']}g'))),
                                      if (side['totalNutrition']['fat'] != null)
                                        Padding(padding: const EdgeInsets.only(right: 6), child: Chip(label: Text('Fat: ${side['totalNutrition']['fat']}g'))),
                                      if (side['totalNutrition']['carbs'] != null)
                                        Padding(padding: const EdgeInsets.only(right: 6), child: Chip(label: Text('Carbs: ${side['totalNutrition']['carbs']}g'))),
                                    ],
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    try {
      DBService.notifier.removeListener(_notifierListener);
    } catch (_) {}
    super.dispose();
  }
}
