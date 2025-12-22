import 'package:best_flutter_ui_templates/fitness_app/ui_view/body_measurement.dart';
import 'package:best_flutter_ui_templates/fitness_app/ui_view/glass_view.dart';
import 'package:best_flutter_ui_templates/fitness_app/ui_view/mediterranean_diet_view.dart';
import 'package:best_flutter_ui_templates/fitness_app/ui_view/title_view.dart';
import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:best_flutter_ui_templates/fitness_app/my_diary/meals_list_view.dart';
import 'package:best_flutter_ui_templates/fitness_app/my_diary/water_view.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore_for_file: unused_field
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import '../../models/diary.dart';
import '../../services/diary_service.dart';
import '../camera/services/db_service.dart';

class MyDiaryScreen extends StatefulWidget {
  const MyDiaryScreen({super.key, this.animationController});

  final AnimationController? animationController;
  @override
  State<MyDiaryScreen> createState() => _MyDiaryScreenState();
}

class _MyDiaryScreenState extends State<MyDiaryScreen>
    with TickerProviderStateMixin {
  Animation<double>? topBarAnimation;

  List<Widget> listViews = <Widget>[];
  final ScrollController scrollController = ScrollController();
  double topBarOpacity = 0.0;

  DateTime selectedDate = DateTime.now();
  Diary? currentDiary;
  DiaryService? diaryService;
  StreamSubscription<Diary?>? _diarySub;
  // auth subscription handled inline; remove unused field to silence analyzer
  StreamSubscription<User?>? _authSub;
  Map<String, dynamic>? currentProfile;
  // Notifier to propagate in-place profile updates to child widgets
  ValueNotifier<Map<String, dynamic>>? profileNotifier;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  Map<String, Map<String, int>>? localSlotTotals;
  VoidCallback? _dbNotifierListener;


  @override
  void initState() {
    topBarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: widget.animationController!,
            curve: Interval(0, 0.5, curve: Curves.fastOutSlowIn)));
    addAllListData();
    // compute local slot totals initially
    _computeLocalSlotTotals();
    // listen for DBService changes to recompute
    try {
      _dbNotifierListener = () async {
        await _computeLocalSlotTotals();
        if (mounted) {
          setState(() {
            listViews.clear();
            addAllListData();
          });
        }
      };
      DBService.notifier.addListener(_dbNotifierListener!);
    } catch (_) {}
    // subscribe to auth changes and diary stream for selectedDate
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _diarySub?.cancel();
      _profileSub?.cancel();
      if (user != null) {
        diaryService = DiaryService(FirebaseFirestore.instance, user.uid);
        // subscribe to profile document for fallback values
        try {
          final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
          _profileSub = docRef.snapshots().listen((snap) {
            if (!mounted) return;
            setState(() {
              currentProfile = snap.data();
              // initialize or update notifier
              if (profileNotifier == null) profileNotifier = ValueNotifier<Map<String, dynamic>>(currentProfile ?? <String, dynamic>{});
              else profileNotifier!.value = currentProfile ?? <String, dynamic>{};
              // also rebuild listViews so children get the new profile
              listViews.clear();
              addAllListData();
            });
          }, onError: (e) {
            debugPrint('MyDiaryScreen: profile stream error: $e');
          });
        } catch (e) {
          debugPrint('MyDiaryScreen: subscribe profile failed: $e');
        }
        _diarySub = diaryService!.streamDiary(selectedDate).listen((d) {
          setState(() {
            currentDiary = d;
            // rebuild listViews to pass diary to children
            listViews.clear();
            addAllListData();
          });
        }, onError: (e) {
          debugPrint('MyDiaryScreen: diary stream error: $e');
        });
      } else {
        setState(() {
          currentDiary = null;
          currentProfile = null;
          listViews.clear();
          addAllListData();
        });
      }
    });

    scrollController.addListener(() {
      if (scrollController.offset >= 24) {
        if (topBarOpacity != 1.0) {
          setState(() {
            topBarOpacity = 1.0;
          });
        }
      } else if (scrollController.offset <= 24 &&
          scrollController.offset >= 0) {
        if (topBarOpacity != scrollController.offset / 24) {
          setState(() {
            topBarOpacity = scrollController.offset / 24;
          });
        }
      } else if (scrollController.offset <= 0) {
        if (topBarOpacity != 0.0) {
          setState(() {
            topBarOpacity = 0.0;
          });
        }
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _diarySub?.cancel();
    _profileSub?.cancel();
    _authSub?.cancel();
    if (_dbNotifierListener != null) {
      DBService.notifier.removeListener(_dbNotifierListener!);
    }
    profileNotifier?.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _computeLocalSlotTotals() async {
    final Map<String, Map<String, int>> totals = {
      'breakfast': {'calories': 0, 'carbs': 0, 'protein': 0, 'fat': 0},
      'lunch': {'calories': 0, 'carbs': 0, 'protein': 0, 'fat': 0},
      'snack': {'calories': 0, 'carbs': 0, 'protein': 0, 'fat': 0},
      'dinner': {'calories': 0, 'carbs': 0, 'protein': 0, 'fat': 0},
    };
    try {
      final items = DBService.getAllResults();
      // Define day window that starts at 21:00 of the previous calendar day
      // and ends at 21:00 of the selectedDate. Scans whose timestamps fall
      // within [dayStart, dayEnd) are counted for the selectedDate.
      final DateTime dayEnd = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 21);
      final DateTime dayStart = dayEnd.subtract(const Duration(hours: 24));

      for (final it in items) {
        try {
          // Use ScanResult.timestamp to filter by our day window
          final ts = it.timestamp;
          if (ts.isBefore(dayStart) || !ts.isBefore(dayEnd)) continue;

          // try to read sidecar JSON path permutations
          final side = await _readSidecarForPath(it.imagePath);
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
    // update state so UI reflects the new aggregated totals
    localSlotTotals = totals;
    if (mounted) setState(() {});
    // Also mirror total calories into the user's profile document so profile UI can show it
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        int totalCalories = 0;
        for (final s in totals.keys) {
          totalCalories += totals[s]?['calories'] ?? 0;
        }
        final profileDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        profileDoc.set({'profile': {'calories': totalCalories}, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Failed to mirror calories to profile: $e');
    }
  }

  // helper to locate sidecar JSON on disk for a given image path
  Future<Map<String, dynamic>?> _readSidecarForPath(String imagePath) async {
    try {
      final f = File(imagePath);
      if (!await f.exists()) return null;
      final dir = f.parent;
      final base = p.basenameWithoutExtension(f.path);
      final candidates = [
        p.join(dir.path, '$base.json'),
        p.join(dir.path, '$base.jpg.json'),
        p.join(dir.path, '$base.jpeg.json'),
        p.join(dir.path, '$base.png.json'),
      ];
      for (final c in candidates) {
        final fc = File(c);
        if (await fc.exists()) {
          final txt = await fc.readAsString();
          return jsonDecode(txt) as Map<String, dynamic>;
        }
      }
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
      for (final fc in files) {
        if (p.basenameWithoutExtension(fc.path) == base) {
          final txt = await fc.readAsString();
          return jsonDecode(txt) as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }

  void addAllListData() {
    const int count = 9;

    listViews.add(
      TitleView(
        titleTxt: 'Mediterranean diet',
        subTxt: 'Details',
        animation: Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
            parent: widget.animationController!,
            curve:
                Interval((1 / count) * 0, 1.0, curve: Curves.fastOutSlowIn))),
        animationController: widget.animationController!,
      ),
    );
    listViews.add(
      MediterranesnDietView(
        animation: Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
            parent: widget.animationController!,
            curve:
                Interval((1 / count) * 1, 1.0, curve: Curves.fastOutSlowIn))),
        animationController: widget.animationController!,
  diary: currentDiary,
  profile: currentProfile,
  profileNotifier: profileNotifier,
  localSlotTotals: localSlotTotals,
      ),
    );
    listViews.add(
      TitleView(
        titleTxt: 'Meals today',
        subTxt: 'Customize',
        animation: Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
            parent: widget.animationController!,
            curve:
                Interval((1 / count) * 2, 1.0, curve: Curves.fastOutSlowIn))),
        animationController: widget.animationController!,
      ),
    );

    listViews.add(
      MealsListView(
        diary: currentDiary,
        profile: currentProfile,
        localSlotTotals: localSlotTotals,
        mainScreenAnimationController: widget.animationController,
        mainScreenAnimation: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: widget.animationController!,
            curve: Interval((1 / count) * 3, 1.0, curve: Curves.fastOutSlowIn),
          ),
        ),
      ),
    );

    listViews.add(
      TitleView(
        titleTxt: 'Body measurement',
        subTxt: 'Today',
        animation: Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
            parent: widget.animationController!,
            curve:
                Interval((1 / count) * 4, 1.0, curve: Curves.fastOutSlowIn))),
        animationController: widget.animationController!,
      ),
    );

    listViews.add(
      BodyMeasurementView(
        animation: Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
            parent: widget.animationController!,
            curve:
                Interval((1 / count) * 5, 1.0, curve: Curves.fastOutSlowIn))),
    animationController: widget.animationController!,
  diary: currentDiary,
  profile: currentProfile,
  // pass notifier so the BodyMeasurementView can recompute estimates when profile updates
  // (e.g., birthdate/age/sex updated in profile)
  // If profileNotifier is null, the view still uses profile fallback.
  // Use profileNotifier?.value to stay in sync.
  // Note: BodyMeasurementView doesn't yet accept profileNotifier; it will pick profile via pv() and diary.
      ),
    );
    listViews.add(
      TitleView(
        titleTxt: 'Water',
        subTxt: 'Aqua SmartBottle',
        animation: Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
            parent: widget.animationController!,
            curve:
                Interval((1 / count) * 6, 1.0, curve: Curves.fastOutSlowIn))),
        animationController: widget.animationController!,
      ),
    );

    listViews.add(
      WaterView(
        mainScreenAnimation: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
                parent: widget.animationController!,
                curve: Interval((1 / count) * 7, 1.0,
                    curve: Curves.fastOutSlowIn))),
    mainScreenAnimationController: widget.animationController!,
    diary: currentDiary,
    profile: currentProfile,
    profileNotifier: profileNotifier,
      ),
    );
    listViews.add(
      GlassView(
          animation: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                  parent: widget.animationController!,
                  curve: Interval((1 / count) * 8, 1.0,
                      curve: Curves.fastOutSlowIn))),
          animationController: widget.animationController!),
    );
  }

  Future<bool> getData() async {
    await Future<dynamic>.delayed(const Duration(milliseconds: 50));
    return true;
  }

  String _monthName(int month) {
    const List<String> months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FitnessAppTheme.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: <Widget>[
            getMainListViewUI(),
            getAppBarUI(),
            SizedBox(
              height: MediaQuery.of(context).padding.bottom,
            )
          ],
        ),
      ),
    );
  }

  Widget getMainListViewUI() {
    return FutureBuilder<bool>(
      future: getData(),
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        } else {
          return ListView.builder(
            controller: scrollController,
        padding: EdgeInsets.only(
          top: AppBar().preferredSize.height +
            MediaQuery.of(context).padding.top +
            24,
          // extra bottom padding to ensure cards don't underlap the bottom nav
          bottom: 92 + MediaQuery.of(context).padding.bottom,
        ),
            itemCount: listViews.length,
            scrollDirection: Axis.vertical,
            itemBuilder: (BuildContext context, int index) {
              widget.animationController?.forward();
              return listViews[index];
            },
          );
        }
      },
    );
  }

  Widget getAppBarUI() {
    return Column(
      children: <Widget>[
        AnimatedBuilder(
          animation: widget.animationController!,
          builder: (BuildContext context, Widget? child) {
            return FadeTransition(
              opacity: topBarAnimation!,
              child: Transform(
                transform: Matrix4.translationValues(
                    0.0, 30 * (1.0 - topBarAnimation!.value), 0.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: FitnessAppTheme.white.withAlpha((topBarOpacity * 255).round()),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32.0),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                          color: FitnessAppTheme.grey
                              .withAlpha(((0.4 * topBarOpacity) * 255).round()),
                          offset: const Offset(1.1, 1.1),
                          blurRadius: 10.0),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      SizedBox(
                        height: MediaQuery.of(context).padding.top,
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16 - 8.0 * topBarOpacity,
                            bottom: 12 - 8.0 * topBarOpacity),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  'My Diary',
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    fontFamily: FitnessAppTheme.fontName,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22 + 6 - 6 * topBarOpacity,
                                    letterSpacing: 1.2,
                                    color: FitnessAppTheme.darkerText,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 38,
                              width: 38,
                              child: InkWell(
                                highlightColor: Colors.transparent,
                                borderRadius: const BorderRadius.all(
                                    Radius.circular(32.0)),
                                onTap: () {
                                  setState(() {
                                    selectedDate = selectedDate.subtract(const Duration(days: 1));
                                  });
                                },
                                child: Center(
                                  child: Icon(
                                    Icons.keyboard_arrow_left,
                                    color: FitnessAppTheme.grey,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  builder: (BuildContext context, Widget? child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: FitnessAppTheme.nearlyBlue,
                                          onPrimary: Colors.white,
                                          onSurface: FitnessAppTheme.darkerText,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );

                                if (picked != null) {
                                  setState(() {
                                    selectedDate = picked;
                                  });
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8, right: 8),
                                child: Row(
                                  children: <Widget>[
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Icon(
                                        Icons.calendar_today,
                                        color: FitnessAppTheme.grey,
                                        size: 18,
                                      ),
                                    ),
                                    Text(
                                      '${selectedDate.day} ${_monthName(selectedDate.month)}',
                                      textAlign: TextAlign.left,
                                      style: TextStyle(
                                        fontFamily: FitnessAppTheme.fontName,
                                        fontWeight: FontWeight.normal,
                                        fontSize: 18,
                                        letterSpacing: -0.2,
                                        color: FitnessAppTheme.darkerText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 38,
                              width: 38,
                              child: InkWell(
                                highlightColor: Colors.transparent,
                                borderRadius: const BorderRadius.all(
                                    Radius.circular(32.0)),
                                onTap: () {
                                  setState(() {
                                    selectedDate = selectedDate.add(const Duration(days: 1));
                                  });
                                },
                                child: Center(
                                  child: Icon(
                                    Icons.keyboard_arrow_right,
                                    color: FitnessAppTheme.grey,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        )
      ],
    );
  }
}
