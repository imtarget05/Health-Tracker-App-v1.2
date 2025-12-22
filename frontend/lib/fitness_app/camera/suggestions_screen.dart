import 'package:flutter/material.dart';
import 'services/suggestion_service.dart';
import 'package:intl/intl.dart';
import '../../models/diary.dart';
import 'package:best_flutter_ui_templates/services/event_bus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/diary_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = SuggestionService.getAll();
    setState(() => _items = all);
  }

  Future<void> _assign(int index, String slot) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final item = _items[index];
    final nutrition = Map<String, dynamic>.from(item['nutrition'] ?? {});
    final mealMap = {
      'id': 'suggestion-${item['ts'] ?? DateTime.now().millisecondsSinceEpoch}',
      'type': slot,
      'name': item['name'] ?? 'Food',
      'kcal': (nutrition['calories'] is num) ? (nutrition['calories'] as num).toInt() : 0,
      'carbsG': (nutrition['carbs'] is num) ? (nutrition['carbs'] as num).toInt() : 0,
      'proteinG': (nutrition['protein'] is num) ? (nutrition['protein'] as num).toInt() : 0,
      'fatG': (nutrition['fat'] is num) ? (nutrition['fat'] as num).toInt() : 0,
      'items': [],
      'createdAt': FieldValue.serverTimestamp(),
    };
    final diary = DiaryService(FirebaseFirestore.instance, user.uid);
    try {
      await diary.addMeal(DateTime.now(), Meal.fromMap(Map<String, dynamic>.from(mealMap)));
      // remove suggestion after assigning
      await SuggestionService.deleteAt(index);
      await _load();
    } catch (e) {
      // Permission-denied or other Firestore errors should not crash the UI.
      if (e is FirebaseException && e.code == 'permission-denied') {
        // Inform the user the assignment couldn't be saved server-side.
        // Still remove the suggestion so UI remains tidy.
        await SuggestionService.deleteAt(index);
        await _load();
  EventBus.instance.emitInfo('Cannot save meal to Firestore (permission denied). Suggestion removed locally.');
      } else {
  final raw = e.toString();
  debugPrint('Suggestions: assign failed raw: $raw');
  EventBus.instance.emitError('Không thể gán đề xuất. Vui lòng thử lại.');
      }
    }
  }

  Future<void> _delete(int index) async {
    await SuggestionService.deleteAt(index);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suggestions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              await SuggestionService.clearAll();
              await _load();
            },
          )
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: Text('No suggestions'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final it = _items[i];
                final ts = (it['ts'] != null) ? DateTime.fromMillisecondsSinceEpoch(it['ts']) : DateTime.now();
                final nutrit = Map<String, dynamic>.from(it['nutrition'] ?? {});
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it['name'] ?? it['rawName'] ?? 'Food', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(DateFormat.yMMMd().add_jm().format(ts), style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, children: [
                          if (nutrit['calories'] != null) Chip(label: Text('Cal: ${nutrit['calories']}')),
                          if (nutrit['protein'] != null) Chip(label: Text('Protein: ${nutrit['protein']}g')),
                          if (nutrit['fat'] != null) Chip(label: Text('Fat: ${nutrit['fat']}g')),
                          if (nutrit['carbs'] != null) Chip(label: Text('Carbs: ${nutrit['carbs']}g')),
                        ]),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                await _assign(i, 'breakfast');
                              },
                              child: const Text('Assign Breakfast'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                await _assign(i, 'lunch');
                              },
                              child: const Text('Assign Lunch'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                await _assign(i, 'dinner');
                              },
                              child: const Text('Assign Dinner'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () async {
                                await _delete(i);
                              },
                              child: const Text('Delete'),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
