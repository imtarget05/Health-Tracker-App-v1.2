import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/diary.dart';

class DiaryService {
  final FirebaseFirestore _db;
  final String uid;

  DiaryService(this._db, this.uid);

  String _docIdForDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  CollectionReference get _userDiaries => _db.collection('users').doc(uid).collection('diaries');

  Future<Diary?> getDiary(DateTime date) async {
    final id = _docIdForDate(date);
    final snap = await _userDiaries.doc(id).get();
    if (!snap.exists) return null;
    return Diary.fromMap(id, snap.data() as Map<String, dynamic>);
  }

  Stream<Diary?> streamDiary(DateTime date) {
    final id = _docIdForDate(date);
    return _userDiaries.doc(id).snapshots().map((snap) => snap.exists ? Diary.fromMap(id, snap.data() as Map<String, dynamic>) : null);
  }

  Future<void> setDiary(Diary diary) async {
    await _userDiaries.doc(diary.id).set(diary.toMap(), SetOptions(merge: true));
  }

  Future<void> updateWeight(DateTime date, double kg, {String source = 'manual'}) async {
    final id = _docIdForDate(date);
    final weightMap = {
      'valueKg': kg,
      'recordedAt': Timestamp.now(),
      'source': source,
    };
    await _userDiaries.doc(id).set({
      'weight': weightMap,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addMeal(DateTime date, Meal meal) async {
    final id = _docIdForDate(date);
    final docRef = _userDiaries.doc(id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.exists ? Map<String, dynamic>.from(snap.data() as Map<String, dynamic>) : {};
      final meals = (data['meals'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      meals.add(meal.toMap());
      tx.set(docRef, {
        'meals': meals,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> incrementWater(DateTime date, int deltaMl) async {
    final id = _docIdForDate(date);
    final docRef = _userDiaries.doc(id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.exists ? Map<String, dynamic>.from(snap.data() as Map<String, dynamic>) : {};
      final current = (data['water'] != null && data['water']['consumedMl'] != null) ? (data['water']['consumedMl'] as num).toInt() : 0;
      final newVal = current + deltaMl;
      final waterMap = {
        'consumedMl': newVal,
        'dailyGoalMl': data['water'] != null && data['water']['dailyGoalMl'] != null ? (data['water']['dailyGoalMl'] as num).toInt() : 2000,
        'lastDrinkAt': Timestamp.now(),
      };
      tx.set(docRef, {
        'water': waterMap,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> setDailyWaterGoal(DateTime date, int goalMl) async {
    final id = _docIdForDate(date);
    await _userDiaries.doc(id).set({
      'water': {'dailyGoalMl': goalMl},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
