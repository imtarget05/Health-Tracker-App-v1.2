// Utility to aggregate per-slot nutrition totals from a list of sidecar maps.

Map<String, Map<String, int>> aggregateSlotNutrition(List<Map<String, dynamic>> sidecars) {
  final Map<String, Map<String, int>> totals = {
    'breakfast': {'calories': 0, 'carbs': 0, 'protein': 0, 'fat': 0},
    'lunch': {'calories': 0, 'carbs': 0, 'protein': 0, 'fat': 0},
    'snack': {'calories': 0, 'carbs': 0, 'protein': 0, 'fat': 0},
    'dinner': {'calories': 0, 'carbs': 0, 'protein': 0, 'fat': 0},
  };

  for (final s in sidecars) {
    try {
      final slot = s['slot'] as String?;
      if (slot == null || !totals.containsKey(slot)) continue;
      final total = s['totalNutrition'] as Map<String, dynamic>?;
      if (total == null) continue;
      final c = (total['calories'] is num) ? (total['calories'] as num).toInt() : 0;
      final carbs = (total['carbs'] is num) ? (total['carbs'] as num).toInt() : 0;
      final protein = (total['protein'] is num) ? (total['protein'] as num).toInt() : 0;
      final fat = (total['fat'] is num) ? (total['fat'] as num).toInt() : 0;
      totals[slot]!['calories'] = totals[slot]!['calories']! + c;
      totals[slot]!['carbs'] = totals[slot]!['carbs']! + carbs;
      totals[slot]!['protein'] = totals[slot]!['protein']! + protein;
      totals[slot]!['fat'] = totals[slot]!['fat']! + fat;
    } catch (_) {
      // ignore malformed entries
    }
  }

  return totals;
}
