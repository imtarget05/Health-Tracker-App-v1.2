import 'package:cloud_firestore/cloud_firestore.dart';

class Weight {
  final double valueKg;
  final Timestamp recordedAt;
  final String source;

  Weight({required this.valueKg, required this.recordedAt, this.source = 'manual'});

  Map<String, dynamic> toMap() => {
        'valueKg': valueKg,
        'recordedAt': recordedAt,
        'source': source,
      };

  factory Weight.fromMap(Map<String, dynamic> m) => Weight(
        valueKg: (m['valueKg'] as num).toDouble(),
        recordedAt: m['recordedAt'] as Timestamp,
        source: m['source'] as String? ?? 'manual',
      );
}

class BodyMeasurements {
  final double heightCm;
  final double bmi;
  final double bodyFatPercent;
  final Timestamp recordedAt;

  BodyMeasurements({required this.heightCm, required this.bmi, required this.bodyFatPercent, required this.recordedAt});

  Map<String, dynamic> toMap() => {
        'heightCm': heightCm,
        'bmi': bmi,
        'bodyFatPercent': bodyFatPercent,
        'recordedAt': recordedAt,
      };

  factory BodyMeasurements.fromMap(Map<String, dynamic> m) => BodyMeasurements(
        heightCm: (m['heightCm'] as num).toDouble(),
        bmi: (m['bmi'] as num).toDouble(),
        bodyFatPercent: (m['bodyFatPercent'] as num).toDouble(),
        recordedAt: m['recordedAt'] as Timestamp,
      );
}

class Water {
  final int consumedMl;
  final int dailyGoalMl;
  final Timestamp lastDrinkAt;

  Water({required this.consumedMl, required this.dailyGoalMl, required this.lastDrinkAt});

  Map<String, dynamic> toMap() => {
        'consumedMl': consumedMl,
        'dailyGoalMl': dailyGoalMl,
        'lastDrinkAt': lastDrinkAt,
      };

  factory Water.fromMap(Map<String, dynamic> m) => Water(
        consumedMl: (m['consumedMl'] as num).toInt(),
        dailyGoalMl: (m['dailyGoalMl'] as num).toInt(),
        lastDrinkAt: m['lastDrinkAt'] as Timestamp,
      );
}

class Meal {
  final String id;
  final String type;
  final String name;
  final int kcal;
  final int carbsG;
  final int proteinG;
  final int fatG;
  final List<String> items;
  final Timestamp createdAt;

  Meal({required this.id, required this.type, required this.name, required this.kcal, required this.carbsG, required this.proteinG, required this.fatG, required this.items, required this.createdAt});

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'name': name,
        'kcal': kcal,
        'carbsG': carbsG,
        'proteinG': proteinG,
        'fatG': fatG,
        'items': items,
        'createdAt': createdAt,
      };

  factory Meal.fromMap(Map<String, dynamic> m) => Meal(
        id: m['id'] as String,
        type: m['type'] as String,
        name: m['name'] as String,
        kcal: (m['kcal'] as num).toInt(),
        carbsG: (m['carbsG'] as num).toInt(),
        proteinG: (m['proteinG'] as num).toInt(),
        fatG: (m['fatG'] as num).toInt(),
        items: List<String>.from(m['items'] ?? []),
        createdAt: m['createdAt'] as Timestamp,
      );
}

class MacrosSummary {
  final int carbsLeftG;
  final int proteinLeftG;
  final int fatLeftG;

  MacrosSummary({required this.carbsLeftG, required this.proteinLeftG, required this.fatLeftG});

  Map<String, dynamic> toMap() => {
        'carbsLeftG': carbsLeftG,
        'proteinLeftG': proteinLeftG,
        'fatLeftG': fatLeftG,
      };

  factory MacrosSummary.fromMap(Map<String, dynamic> m) => MacrosSummary(
        carbsLeftG: (m['carbsLeftG'] as num).toInt(),
        proteinLeftG: (m['proteinLeftG'] as num).toInt(),
        fatLeftG: (m['fatLeftG'] as num).toInt(),
      );
}

class Diary {
  final String id; // yyyy-MM-dd
  final Timestamp date;
  final String dietPlan;
  final Weight? weight;
  final BodyMeasurements? bodyMeasurements;
  final Water? water;
  final List<Meal> meals;
  final MacrosSummary? macrosSummary;
  final Timestamp updatedAt;

  Diary({required this.id, required this.date, required this.dietPlan, this.weight, this.bodyMeasurements, this.water, this.meals = const [], this.macrosSummary, required this.updatedAt});

  Map<String, dynamic> toMap() => {
        'date': date,
        'dietPlan': dietPlan,
        'weight': weight?.toMap(),
        'bodyMeasurements': bodyMeasurements?.toMap(),
        'water': water?.toMap(),
        'meals': meals.map((m) => m.toMap()).toList(),
        'macrosSummary': macrosSummary?.toMap(),
        'updatedAt': updatedAt,
      };

  factory Diary.fromMap(String id, Map<String, dynamic> m) => Diary(
        id: id,
        date: m['date'] as Timestamp,
        dietPlan: m['dietPlan'] as String? ?? '',
        weight: m['weight'] != null ? Weight.fromMap(Map<String, dynamic>.from(m['weight'])) : null,
        bodyMeasurements: m['bodyMeasurements'] != null ? BodyMeasurements.fromMap(Map<String, dynamic>.from(m['bodyMeasurements'])) : null,
        water: m['water'] != null ? Water.fromMap(Map<String, dynamic>.from(m['water'])) : null,
        meals: (m['meals'] as List<dynamic>?)?.map((e) => Meal.fromMap(Map<String, dynamic>.from(e))).toList() ?? [],
        macrosSummary: m['macrosSummary'] != null ? MacrosSummary.fromMap(Map<String, dynamic>.from(m['macrosSummary'])) : null,
        updatedAt: m['updatedAt'] as Timestamp? ?? Timestamp.now(),
      );
}
