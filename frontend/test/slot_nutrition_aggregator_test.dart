import 'package:flutter_test/flutter_test.dart';
import 'package:best_flutter_ui_templates/utils/slot_nutrition_aggregator.dart';

void main() {
  test('empty list returns zeroed totals', () {
    final res = aggregateSlotNutrition([]);
    expect(res['breakfast']!['calories'], 0);
    expect(res['lunch']!['carbs'], 0);
    expect(res['snack']!['protein'], 0);
    expect(res['dinner']!['fat'], 0);
  });

  test('aggregates multiple sidecars correctly', () {
    final sidecars = [
      {
        'slot': 'breakfast',
        'totalNutrition': {'calories': 200, 'carbs': 30, 'protein': 10, 'fat': 5}
      },
      {
        'slot': 'breakfast',
        'totalNutrition': {'calories': 150, 'carbs': 20, 'protein': 8, 'fat': 3}
      },
      {
        'slot': 'lunch',
        'totalNutrition': {'calories': 500, 'carbs': 60, 'protein': 25, 'fat': 20}
      },
      {
        'slot': 'none',
        'totalNutrition': {'calories': 100, 'carbs': 10, 'protein': 4, 'fat': 2}
      },
    ];

    final res = aggregateSlotNutrition(sidecars);
    expect(res['breakfast']!['calories'], 350);
    expect(res['breakfast']!['carbs'], 50);
    expect(res['breakfast']!['protein'], 18);
    expect(res['breakfast']!['fat'], 8);

    expect(res['lunch']!['calories'], 500);
    expect(res['lunch']!['protein'], 25);

    // none should be ignored
    expect(res['snack']!['calories'], 0);
  });
}
