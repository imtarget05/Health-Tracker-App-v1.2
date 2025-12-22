import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
// path_provider not required in this file
import '../camera/models/scan_result.dart';
import '../camera/services/db_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/diary_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ScanResult> _items = [];
  late final VoidCallback _notifierListener;
  Map<String, dynamic>? _todayDiaryMap;
  Map<String, dynamic>? _profileMap;

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
    // attempt to load today's diary and profile if user is signed in
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final diaryService = DiaryService(FirebaseFirestore.instance, user.uid);
        final d = await diaryService.getDiary(DateTime.now());
        if (d != null) _todayDiaryMap = d.toMap();
        // basic profile stored under users/{uid}/profile or similar; try profiles collection
        // try common locations for profile document
        final profilesSnap = await FirebaseFirestore.instance.collection('profiles').doc(user.uid).get();
        if (profilesSnap.exists) {
          _profileMap = Map<String, dynamic>.from(profilesSnap.data() ?? {});
        } else {
          final userProfileSnap = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('meta').doc('profile').get();
          if (userProfileSnap.exists) _profileMap = Map<String, dynamic>.from(userProfileSnap.data() ?? {});
        }
        // trigger rebuild
        setState(() {});
      }
    } catch (_) {}
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
          p.join(dir.path, '$base.jpg.json'),
          p.join(dir.path, '$base.jpeg.json'),
          p.join(dir.path, '$base.png.json'),
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

  /// Aggregate nutrition totals from local sidecar JSONs grouped by slot.
  Future<Map<String, Map<String, int>>> _aggregateSlotNutrition() async {
    final Map<String, Map<String, int>> totals = {
      'breakfast': {'calories': 0, 'carbs': 0, 'protein': 0, 'fat': 0},
      'lunch': {'calories': 0, 'carbs': 0, 'protein': 0, 'fat': 0},
      'snack': {'calories': 0, 'carbs': 0, 'protein': 0, 'fat': 0},
      'dinner': {'calories': 0, 'carbs': 0, 'protein': 0, 'fat': 0},
    };
    try {
      final items = DBService.getAllResults();
      for (final it in items) {
        try {
          final side = await _readSidecar(it);
          if (side == null) continue;
          final slot = side['slot'] as String?;
          if (slot == null || !totals.containsKey(slot)) continue;
          final total = side['totalNutrition'] as Map<String, dynamic>?;
          if (total == null) continue;
          final c = (total['calories'] is num) ? (total['calories'] as num).toInt() : 0;
          final carbs = (total['carbs'] is num) ? (total['carbs'] as num).toInt() : 0;
          final protein = (total['protein'] is num) ? (total['protein'] as num).toInt() : 0;
          final fat = (total['fat'] is num) ? (total['fat'] as num).toInt() : 0;
          totals[slot]!['calories'] = totals[slot]!['calories']! + c;
          totals[slot]!['carbs'] = totals[slot]!['carbs']! + carbs;
          totals[slot]!['protein'] = totals[slot]!['protein']! + protein;
          totals[slot]!['fat'] = totals[slot]!['fat']! + fat;
        } catch (_) {}
      }
    } catch (_) {}
    return totals;
  }

  Widget _buildSlotChip(Map<String, dynamic>? side) {
    final slot = side != null && side['slot'] != null ? (side['slot'] as String) : null;
    if (slot == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Chip(label: Text(slot[0].toUpperCase() + slot.substring(1))),
    );
  }

  // placeholder: not currently referenced from the UI
  // ignore: unused_element
  Future<Map<String, dynamic>> _computeDailyProposal() async {
    // compute today's totals from Firestore diary if available; otherwise return empty
    try {
      // placeholder - app-level auth needed here
      // If the app has a profile stream elsewhere, that component already shows totals; history provides simple proposal
    } catch (_) {}
    return {};
  }

  Widget _buildPredictionCard(Map<String, dynamic> resp) {
    final main = resp['mainFood'] as Map<String, dynamic>?;
    final total = resp['totalNutrition'] as Map<String, dynamic>?;
  final portion = main != null ? main['portion_g'] : null;
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
            if (portion != null) Text('Portion: $portion g'),
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
      body: Column(
        children: [
          // proposal card
          FutureBuilder<Map<String, Map<String, int>>>(
            future: _aggregateSlotNutrition(),
            builder: (context, snap) {
              final slotTotals = snap.data ?? {'breakfast': {'calories':0}, 'lunch': {'calories':0}, 'snack': {'calories':0}, 'dinner': {'calories':0}};
              // compute totals from diary meals first (take precedence)
              final perSlotTotals = <String, int>{'breakfast': 0, 'lunch': 0, 'snack': 0, 'dinner': 0};
              int consumed = 0;
              if (_todayDiaryMap != null && _todayDiaryMap!['meals'] != null) {
                final meals = List.from(_todayDiaryMap!['meals'] as List);
                for (final m in meals) {
                  try {
                    final kcal = (m['kcal'] as num).toInt();
                    consumed += kcal;
                    if (m['type'] != null && perSlotTotals.containsKey(m['type'])) {
                      perSlotTotals[m['type']] = perSlotTotals[m['type']]! + kcal;
                    }
                  } catch (_) {}
                }
              } else {
                // no diary meals: use local slotTotals aggregated from sidecars
                for (final s in ['breakfast','lunch','snack','dinner']) {
                  try {
                    perSlotTotals[s] = slotTotals[s]?['calories'] ?? 0;
                    consumed += perSlotTotals[s]!;
                  } catch (_) {
                    perSlotTotals[s] = 0;
                  }
                }
              }

              final target = _profileMap != null && _profileMap!['targetCaloriesPerDay'] != null ? (_profileMap!['targetCaloriesPerDay'] as num).toInt() : null;
              if (target == null) return const SizedBox.shrink();
              final remaining = target - consumed;
              final slots = ['breakfast', 'lunch', 'snack', 'dinner'];
              final remainSlots = slots.where((s) => perSlotTotals[s] == 0).toList();
              final perSlotSuggested = remainSlots.isEmpty ? 0 : (remaining ~/ remainSlots.length);

              return Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily proposal', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                                Text('Target: $target kcal  •  Consumed: $consumed kcal  •  Remaining: $remaining kcal'),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        for (final s in slots) Chip(label: Text('${s[0].toUpperCase() + s.substring(1)}: ${perSlotTotals[s]} kcal')),
                      ]),
                      const SizedBox(height: 8),
                      Text('Suggested allocation for remaining slots:', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, children: remainSlots.map((s) => Chip(label: Text('${s[0].toUpperCase() + s.substring(1)}: ~$perSlotSuggested kcal'))).toList()),
                    ],
                  ),
                ),
              );
            },
          ),

          Expanded(
            child: _items.isEmpty
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
                                          _buildSlotChip(side),
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
          ),
        ],
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
