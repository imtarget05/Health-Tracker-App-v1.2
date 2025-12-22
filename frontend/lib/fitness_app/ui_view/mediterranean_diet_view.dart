import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:best_flutter_ui_templates/main.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
// Removed unused imports (io/convert/path_provider) after refactor

class MediterranesnDietView extends StatefulWidget {
  final AnimationController? animationController;
  final Animation<double>? animation;
  final dynamic diary; // pass Diary? but avoid importing model here to reduce coupling
  final Map<String, dynamic>? profile;
  // Optional notifier that parents can use to notify in-place profile updates.
  // If provided, the widget will prefer `profileNotifier.value` over `profile`.
  final ValueNotifier<Map<String, dynamic>>? profileNotifier;
  final Map<String, Map<String, int>>? localSlotTotals;

  const MediterranesnDietView(
      {super.key, this.animationController, this.animation, this.diary, this.profile, this.localSlotTotals, this.profileNotifier});

  @override
  _MediterranesnDietViewState createState() => _MediterranesnDietViewState();
}

class _MediterranesnDietViewState extends State<MediterranesnDietView> {
  VoidCallback? _notifierListener;

  @override
  void initState() {
    super.initState();
    if (widget.profileNotifier != null) {
      _notifierListener = () {
        // notifier changed; rebuild to reflect updated profile value
        if (mounted) setState(() {});
      };
      widget.profileNotifier!.addListener(_notifierListener!);
    }
  }
  @override
  void didUpdateWidget(covariant MediterranesnDietView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the notifier instance changed, rewire listener
    if (oldWidget.profileNotifier != widget.profileNotifier) {
      if (oldWidget.profileNotifier != null && _notifierListener != null) {
        oldWidget.profileNotifier!.removeListener(_notifierListener!);
      }
      if (widget.profileNotifier != null) {
        _notifierListener ??= () {
          if (mounted) setState(() {});
        };
        widget.profileNotifier!.addListener(_notifierListener!);
      }
    }
    try {
      // If profile reference changed or key deadline fields changed, trigger rebuild
      final oldProfile = oldWidget.profile;
      final newProfile = widget.profile;
      // extract raw deadline values (any type) from top-level or nested profile
      dynamic oldDeadlineRaw;
      dynamic newDeadlineRaw;
      if (oldProfile != null) {
        if (oldProfile.containsKey('deadline')) oldDeadlineRaw = oldProfile['deadline'];
        else if (oldProfile['profile'] is Map && (oldProfile['profile'] as Map).containsKey('deadline')) oldDeadlineRaw = (oldProfile['profile'] as Map)['deadline'];
      }
      if (newProfile != null) {
        if (newProfile.containsKey('deadline')) newDeadlineRaw = newProfile['deadline'];
        else if (newProfile['profile'] is Map && (newProfile['profile'] as Map).containsKey('deadline')) newDeadlineRaw = (newProfile['profile'] as Map)['deadline'];
      }
      final oldDaysLeft = oldProfile != null && (oldProfile['deadlineDaysLeft'] != null || (oldProfile['profile'] is Map && oldProfile['profile']['deadlineDaysLeft'] != null));
      final newDaysLeft = newProfile != null && (newProfile['deadlineDaysLeft'] != null || (newProfile['profile'] is Map && newProfile['profile']['deadlineDaysLeft'] != null));
      if (oldWidget.profile != widget.profile || oldDeadlineRaw?.toString() != newDeadlineRaw?.toString() || oldDaysLeft != newDaysLeft) {
        setState(() {});
      }
    } catch (_) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (widget.profileNotifier != null && _notifierListener != null) {
      widget.profileNotifier!.removeListener(_notifierListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animationController!,
      builder: (BuildContext context, Widget? child) {
  // compute days progress for circular arc. Animate the ring from empty to current progress using the provided animation.
  // Support both top-level fields and nested `profile` map created by some writes.
  // prepare nested profile map and a safe accessor pv(key) -> first top-level then nested
  final Map<String, dynamic>? profile = widget.profileNotifier?.value ?? widget.profile;
  final dynamic rawNested = (profile != null) ? profile['profile'] : null;
  // Local aliases for convenience in State (widget fields must be accessed via `widget.`)
  final dynamic diary = widget.diary;
  final Map<String, Map<String, int>>? localSlotTotals = widget.localSlotTotals;
  final Map<String, dynamic>? nested = (rawNested is Map) ? Map<String, dynamic>.from(rawNested) : null;
  dynamic pv(String key) {
    if (profile != null && profile!.containsKey(key)) return profile![key];
    if (nested != null && nested.containsKey(key)) return nested[key];
    return null;
  }

  int? initialDaysFromProfile;
  int? daysLeftFromProfile;
  if (pv('deadlineInitialDays') != null) {
    initialDaysFromProfile = (pv('deadlineInitialDays') as num).toInt();
  }
  // Compute daysLeft from explicit deadline if possible and infer an initial span
  try {
    final rawDeadline = pv('deadline');
    DateTime? parsedDeadline;
    if (rawDeadline != null) {
      if (rawDeadline is String) parsedDeadline = DateTime.tryParse(rawDeadline);
      else if (rawDeadline is DateTime) parsedDeadline = rawDeadline;
      else {
        try { if (rawDeadline.toDate != null) parsedDeadline = rawDeadline.toDate(); } catch (_) {}
      }
    }
    if (parsedDeadline != null) {
      final today = DateTime.now();
      final todayDateOnly = DateTime(today.year, today.month, today.day);
      // days left is difference from today to deadline (non-negative)
      final remaining = parsedDeadline.difference(todayDateOnly).inDays;
      daysLeftFromProfile = remaining >= 0 ? remaining : 0;

      // infer an initial span: prefer explicit deadlineStart or createdAt if available
      DateTime? startDate;
      final rawStart = pv('deadlineStart') ?? pv('createdAt') ?? pv('startDate');
      if (rawStart != null) {
        if (rawStart is String) startDate = DateTime.tryParse(rawStart);
        else if (rawStart is DateTime) startDate = rawStart;
        else {
          try { if (rawStart.toDate != null) startDate = rawStart.toDate(); } catch (_) {}
        }
      }
      if (startDate != null) {
        final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
        final totalSpan = parsedDeadline.difference(startDateOnly).inDays;
        if (totalSpan > 0) initialDaysFromProfile ??= totalSpan;
      }
    } else {
      // fallback: if deadline provided as numeric daysLeft directly
      final rawDead = pv('deadline');
      if (rawDead is num) daysLeftFromProfile = rawDead.toInt();
    }
  } catch (_) {}

  final int initialDays = (initialDaysFromProfile != null && initialDaysFromProfile! > 0) ? initialDaysFromProfile! : 12;
  final int daysLeft = (daysLeftFromProfile != null) ? daysLeftFromProfile! : (initialDays - (initialDays * (1 - widget.animation!.value)).toInt());
  // progress: fraction of days used (0.0 .. 1.0). When daysLeft decreases, progress increases.
  final double progress = (initialDays > 0) ? ((initialDays - daysLeft) / initialDays.toDouble()) : widget.animation!.value;
  final double progressClamped = progress.isFinite ? progress.clamp(0.0, 1.0) : widget.animation!.value;
  // sweepDegrees is how many degrees the arc should cover. We animate from 0 -> sweepDegrees.
  final double sweepDegrees = (progressClamped * 360.0);
  final double angle = sweepDegrees * widget.animation!.value; // animated sweep in degrees

  // compute consumed macros across diary.meals (move out of widget tree)
  int carbsConsumedTotal = 0;
  int proteinConsumedTotal = 0;
  int fatConsumedTotal = 0;
  if (diary != null && diary.meals != null) {
    for (var m in diary.meals) {
      try {
        if (m.carbsG != null) carbsConsumedTotal += (m.carbsG as num).toInt();
        if (m.proteinG != null) proteinConsumedTotal += (m.proteinG as num).toInt();
        if (m.fatG != null) fatConsumedTotal += (m.fatG as num).toInt();
      } catch (_) {}
    }
    } else if (localSlotTotals != null) {
    // Sum across all slots from local aggregated totals
    for (final slot in ['breakfast', 'lunch', 'snack', 'dinner']) {
      try {
        carbsConsumedTotal += ((localSlotTotals[slot]?['carbs'] ?? 0) as num).toInt();
        proteinConsumedTotal += ((localSlotTotals[slot]?['protein'] ?? 0) as num).toInt();
        fatConsumedTotal += ((localSlotTotals[slot]?['fat'] ?? 0) as num).toInt();
      } catch (_) {}
    }
  }

        return FadeTransition(
          opacity: widget.animation!,
          child: Transform(
            transform: Matrix4.translationValues(
                0.0, 30 * (1.0 - widget.animation!.value), 0.0),
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 24, right: 24, top: 16, bottom: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: FitnessAppTheme.white,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8.0),
                      bottomLeft: Radius.circular(8.0),
                      bottomRight: Radius.circular(8.0),
                      topRight: Radius.circular(68.0)),
                  boxShadow: <BoxShadow>[
          BoxShadow(
            color: FitnessAppTheme.grey.withAlpha((0.2 * 255).round()),
                        offset: Offset(1.1, 1.1),
                        blurRadius: 10.0),
                  ],
                ),
                    child: Column(
                  children: <Widget>[
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 16, left: 16, right: 16),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8, right: 8, top: 4),
                              child: Column(
                                children: <Widget>[
                                  // intentionally hide the verbose "no diary meals" message — prefer a cleaner UI
                                  Row(
                                    children: <Widget>[
                                      Container(
                                        height: 48,
                                        width: 2,
                                        decoration: BoxDecoration(
                      color: HexColor('#87A0E5')
                        .withAlpha((0.5 * 255).round()),
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(4.0)),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 4, bottom: 2),
                                              child: Text(
                                                'Weight',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontFamily:
                                                      FitnessAppTheme.fontName,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 16,
                                                  letterSpacing: -0.1,
                          color: FitnessAppTheme.grey
                            .withAlpha((0.5 * 255).round()),
                                                ),
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: <Widget>[
                                                SizedBox(
                                                  width: 28,
                                                  height: 28,
                                                  child: Image.asset(
                                                      "assets/fitness_app/eaten.png"),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.only(
                                                      left: 4, bottom: 3),
                                                  child: Text(
                                                    // show target weight in Mediterranean view (idealWeightKg),
                                                    // fallback to profile.weightKg or diary.weight if ideal not set
                                                    (() {
                                                      if (pv('idealWeightKg') != null) {
                                                        final raw = pv('idealWeightKg');
                                                        final v = raw is num ? raw.toInt() : int.tryParse(raw.toString()) ?? 0;
                                                        return v.toString();
                                                      }
                                                      if (diary != null && diary.weight != null) return diary.weight!.valueKg.toStringAsFixed(0);
                                                      if (pv('weightKg') != null) return (pv('weightKg') is num ? (pv('weightKg') as num).toStringAsFixed(0) : pv('weightKg').toString());
                                                      return '${(67 * widget.animation!.value).toInt()}';
                                                    })(),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontFamily:
                                                          FitnessAppTheme.fontName,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 16,
                                                      color: FitnessAppTheme.darkerText,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.only(
                                                      left: 4, bottom: 3),
                                                  child: Text(
                                                    'Kg',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontFamily:
                                                          FitnessAppTheme.fontName,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12,
                                                      letterSpacing: -0.2,
                            color: FitnessAppTheme.grey
                              .withAlpha((0.5 * 255).round()),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                  SizedBox(
                                    height: 8,
                                  ),
                                  Row(
                                    children: <Widget>[
                                      Container(
                                        height: 48,
                                        width: 2,
                                        decoration: BoxDecoration(
                      color: HexColor('#F56E98')
                        .withAlpha((0.5 * 255).round()),
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(4.0)),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 4, bottom: 2),
                                              child: Text(
                                                'Physical Condition',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontFamily:
                                                      FitnessAppTheme.fontName,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 16,
                                                  letterSpacing: -0.1,
                                                      color: FitnessAppTheme.grey
                                                      .withAlpha((0.5 * 255).round()),
                                                ),
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: <Widget>[
                                                SizedBox(
                                                  width: 28,
                                                  height: 28,
                                                  child: Image.asset(
                                                      "assets/fitness_app/burned.png"),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 4, bottom: 3),
                                                  child: Text(
                                                    // show target BMI computed from idealWeightKg and heightCm when available
                                                    (() {
                                                      // try idealWeightKg (top-level or nested) and heightCm
                                                      double? idealKg;
                                                      double? heightCmVal;
                                                      if (pv('idealWeightKg') != null) idealKg = (pv('idealWeightKg') as num).toDouble();
                                                      if (pv('heightCm') != null) heightCmVal = (pv('heightCm') as num).toDouble();
                                                      if (idealKg != null && heightCmVal != null && heightCmVal > 0) {
                                                        final h = heightCmVal / 100.0;
                                                        final bmi = idealKg / (h * h);
                                                        return bmi.toStringAsFixed(1);
                                                      }
                                                      // fallback: if diary has current BMI, still show it as secondary fallback
                                                      if (diary != null && diary.bodyMeasurements != null) return (diary.bodyMeasurements!.bmi).toStringAsFixed(1);
                                                      return '${(28 * widget.animation!.value).toInt()}';
                                                    })(),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontFamily:
                                                          FitnessAppTheme
                                                              .fontName,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 16,
                                                      color: FitnessAppTheme
                                                          .darkerText,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 8, bottom: 3),
                                                  child: Text(
                                                    'BMI',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontFamily:
                                                          FitnessAppTheme
                                                              .fontName,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12,
                                                      letterSpacing: -0.2,
                            color: FitnessAppTheme
                              .grey
                              .withAlpha((0.5 * 255).round()),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          ],
                                        ),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Center(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: FitnessAppTheme.white,
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(100.0),
                                        ),
                      border: Border.all(
                      width: 4,
                      color: FitnessAppTheme
                        .nearlyDarkBlue
                        .withAlpha((0.2 * 255).round())),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: <Widget>[
                      Text(
                        // show daysLeft computed above (animated via widget.animation)
                        daysLeft.toString(),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily:
                                                  FitnessAppTheme.fontName,
                                              fontWeight: FontWeight.normal,
                                              fontSize: 24,
                                              letterSpacing: 0.0,
                                              color: FitnessAppTheme
                                                  .nearlyDarkBlue,
                                            ),
                                          ),
                                          Text(
                                            'Days left',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily:
                                                  FitnessAppTheme.fontName,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              letterSpacing: 0.0,
                        color: FitnessAppTheme.grey
                          .withAlpha((0.5 * 255).round()),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: CustomPaint(
                                      painter: CurvePainter(
                                          colors: [
                                            FitnessAppTheme.nearlyDarkBlue,
                                            HexColor("#8A98E8"),
                                            HexColor("#8A98E8")
                                          ],
                                          angle: angle),
                                      child: SizedBox(
                                        width: 108,
                                        height: 108,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 24, right: 24, top: 8, bottom: 8),
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: FitnessAppTheme.background,
                          borderRadius: BorderRadius.all(Radius.circular(4.0)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 24, right: 24, top: 8, bottom: 16),
                      child: Row(
                        children: <Widget>[
                          // macros totals are precomputed above

                          // compute macros left: prefer diary.macrosSummary if available
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Carbs',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: FitnessAppTheme.fontName,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                    letterSpacing: -0.2,
                                    color: FitnessAppTheme.darkText,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Builder(builder: (context) {
                                    // use precomputed carbsConsumedTotal
                                    final carbsConsumed = carbsConsumedTotal;

                                    // compute width percentage; if goal known, show remaining portion
                                    double percent = 0.0;
                                    // If macrosSummary exists, we don't have total goal fields here, so show a neutral bar.
                                    percent = (diary != null && diary.macrosSummary != null) ? widget.animation!.value : (widget.animation!.value);

                                    final barWidth = (percent * 70).clamp(4.0, 70.0);

                                    return Column(children: [
                                      Container(
                                        height: 4,
                                        width: 70,
                                        decoration: BoxDecoration(
                                          color: HexColor('#87A0E5').withAlpha((0.2 * 255).round()),
                                          borderRadius: BorderRadius.all(Radius.circular(4.0)),
                                        ),
                                        child: Row(children: [
                                          Container(
                                            width: barWidth,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(colors: [HexColor('#87A0E5'), HexColor('#87A0E5').withAlpha((0.5 * 255).round())]),
                                              borderRadius: BorderRadius.all(Radius.circular(4.0)),
                                            ),
                                          )
                                        ]),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                      diary != null && diary.macrosSummary != null
                        ? '${carbsConsumed}g consumed • ${diary.macrosSummary!.carbsLeftG}g left'
                        : '${carbsConsumed}g consumed',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: FitnessAppTheme.fontName,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: FitnessAppTheme.grey.withAlpha((0.5 * 255).round()),
                                          ),
                                        ),
                                      ),
                                    ]);
                                  }),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Protein',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: FitnessAppTheme.fontName,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                        letterSpacing: -0.2,
                                        color: FitnessAppTheme.darkText,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Builder(builder: (context) {
                                        final proteinConsumed = proteinConsumedTotal;

                                        double percent = 0.0;
                                        percent = (diary != null && diary.macrosSummary != null) ? widget.animationController!.value : widget.animationController!.value;

                                        final barWidth = (percent * 70).clamp(4.0, 70.0);

                                        return Column(children: [
                                          Container(
                                            height: 4,
                                            width: 70,
                                            decoration: BoxDecoration(
                                              color: HexColor('#F56E98').withAlpha((0.2 * 255).round()),
                                              borderRadius: BorderRadius.all(Radius.circular(4.0)),
                                            ),
                                            child: Row(children: [
                                              Container(
                                                width: barWidth,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(colors: [HexColor('#F56E98').withAlpha((0.1 * 255).round()), HexColor('#F56E98')]),
                                                  borderRadius: BorderRadius.all(Radius.circular(4.0)),
                                                ),
                                              ),
                                            ]),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(
                                              diary != null && diary.macrosSummary != null
                                                  ? '${proteinConsumed}g consumed • ${diary.macrosSummary!.proteinLeftG}g left'
                                                  : '${proteinConsumed}g consumed',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontFamily: FitnessAppTheme.fontName,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                color: FitnessAppTheme.grey.withAlpha((0.5 * 255).round()),
                                              ),
                                            ),
                                          ),
                                        ]);
                                      }),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Fat',
                                      style: TextStyle(
                                        fontFamily: FitnessAppTheme.fontName,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                        letterSpacing: -0.2,
                                        color: FitnessAppTheme.darkText,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          right: 0, top: 4),
                                      child: Container(
                                        height: 4,
                                        width: 70,
                                        decoration: BoxDecoration(
                      color: HexColor('#F1B440')
                        .withAlpha((0.2 * 255).round()),
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(4.0)),
                                        ),
                                        child: Row(
                                          children: <Widget>[
                                            Container(
                        width: ((70 / 2.5) *
                          widget.animationController!.value),
                                              height: 4,
                                              decoration: BoxDecoration(
                                                gradient:
                                                    LinearGradient(colors: [
                          HexColor('#F1B440')
                            .withAlpha((0.1 * 255).round()),
                                                  HexColor('#F1B440'),
                                                ]),
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(4.0)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Builder(builder: (context) {
                                        final fatConsumed = fatConsumedTotal;

                                        final fatText = diary != null && diary.macrosSummary != null
                                            ? '${fatConsumed}g consumed • ${diary.macrosSummary!.fatLeftG}g left'
                                            : '${fatConsumed}g consumed';

                                        return Column(
                                          children: [
                                            Text(
                                              fatText,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontFamily: FitnessAppTheme.fontName,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                color: FitnessAppTheme.grey.withAlpha((0.5 * 255).round()),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CurvePainter extends CustomPainter {
  final double? angle;
  final List<Color>? colors;

  CurvePainter({this.colors, this.angle = 140});

  @override
  void paint(Canvas canvas, Size size) {
    List<Color> colorsList = [];
    if (colors != null) {
      colorsList = colors ?? [];
    } else {
      colorsList.addAll([Colors.white, Colors.white]);
    }

  // Interpret `angle` as sweep degrees (0..360). We draw the arc starting at the
  // right (0 degrees) and sweep counter-clockwise (negative sweep) so it appears
  // to run from right -> left as progress increases.
  final center = Offset(size.width / 2, size.height / 2);
  final radius = math.min(size.width / 2, size.height / 2) - (22 / 2);

    final double startDeg = 0.0; // start at right (0 degrees)
    final double sweepDeg = -(angle ?? 0.0); // negative to draw counter-clockwise
    final double start = degreeToRadians(startDeg);
    final double sweep = degreeToRadians(sweepDeg);

    // shadow/back arcs with increasing blur widths for subtle glow
    final shadowColors = [Colors.grey.withAlpha((0.25 * 255).round()), Colors.grey.withAlpha((0.18 * 255).round()), Colors.grey.withAlpha((0.12 * 255).round())];
    final shadowWidths = [20.0, 16.0, 12.0];
    for (int i = 0; i < shadowColors.length; i++) {
      final p = Paint()
        ..color = shadowColors[i]
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = shadowWidths[i];
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, p);
    }

    final rect = Rect.fromLTWH(0.0, 0.0, size.width, size.width);
    final gradient = SweepGradient(
      startAngle: degreeToRadians(startDeg),
      endAngle: degreeToRadians(startDeg) + 2 * math.pi,
      tileMode: TileMode.clamp,
      colors: colorsList,
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);

  final cPaint = Paint()..color = Colors.white..strokeWidth = 2.5;
  // draw knob at arc end: rotate canvas to end angle and draw small circle
  canvas.save();
  canvas.translate(center.dx, center.dy);
  // end angle in radians = start + sweep
  canvas.rotate(start + sweep + degreeToRadians(2));
  canvas.translate(0.0, -radius + 14 / 2);
  canvas.drawCircle(Offset(0, 0), 14 / 5, cPaint);
  canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

  double degreeToRadians(double degree) {
    return (math.pi / 180) * degree;
  }

}
