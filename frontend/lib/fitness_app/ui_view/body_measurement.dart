import 'dart:async';

import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:flutter/material.dart';

class BodyMeasurementView extends StatefulWidget {
  final AnimationController? animationController;
  final Animation<double>? animation;
  final dynamic diary;
  final Map<String, dynamic>? profile;

  const BodyMeasurementView({super.key, this.animationController, this.animation, this.diary, this.profile});

  @override
  State<BodyMeasurementView> createState() => _BodyMeasurementViewState();
}

class _BodyMeasurementViewState extends State<BodyMeasurementView> with TickerProviderStateMixin {
  late DateTime currentTime;
  late Timer timer;
  String? _lastBodyFatDisplay;
  String? _lastBodyFatSource;

  @override
  void initState() {
    super.initState();
    currentTime = DateTime.now();

    // Cập nhật mỗi phút
    timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      setState(() {
        currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');

    // Nếu muốn định dạng 12h AM/PM
    final isPM = hour >= 12;
    final hour12 = hour > 12 ? hour - 12 : hour;
    final suffix = isPM ? 'PM' : 'AM';

    return '$hour12:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animationController!,
      builder: (BuildContext context, Widget? child) {
        // prepare nested profile map and a safe accessor pv(key) -> first top-level then nested
        final dynamic rawNested = (widget.profile != null) ? widget.profile!['profile'] : null;
        final Map<String, dynamic>? nested = (rawNested is Map) ? Map<String, dynamic>.from(rawNested) : null;
        dynamic pv(String key) {
          if (widget.profile != null && widget.profile!.containsKey(key)) return widget.profile![key];
          if (nested != null && nested.containsKey(key)) return nested[key];
          return null;
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
                          const EdgeInsets.only(top: 16, left: 16, right: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 4, bottom: 8, top: 16),
                            child: Text(
                              'Weight',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: FitnessAppTheme.fontName,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                  letterSpacing: -0.1,
                                  color: FitnessAppTheme.darkText),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 4, bottom: 3),
                                    child: Text(
                    widget.diary != null && widget.diary.weight != null
                      ? widget.diary.weight!.valueKg.toStringAsFixed(0)
                      : (widget.profile != null && widget.profile!['weightKg'] != null)
                        ? (widget.profile!['weightKg'] is num ? (widget.profile!['weightKg'] as num).toStringAsFixed(0) : widget.profile!['weightKg'].toString())
                        : '67', // fallback
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: FitnessAppTheme.fontName,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 32,
                                        color: FitnessAppTheme.nearlyDarkBlue,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 8, bottom: 8),
                                    child: Text(
                                      'Kg',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: FitnessAppTheme.fontName,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 18,
                                        letterSpacing: -0.2,
                                        color: FitnessAppTheme.nearlyDarkBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Icon(
                                        Icons.access_time,
                                        color: FitnessAppTheme.grey
                                            .withAlpha((0.5 * 255).round()),
                                        size: 16,
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 4.0),
                                        child: Text(
                                          'Today ${_formatCurrentTime()}',
                                          textAlign: TextAlign.center,
                      style: TextStyle(
                      fontFamily:
                        FitnessAppTheme.fontName,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      letterSpacing: 0.0,
                      color: FitnessAppTheme.grey
                        .withAlpha((0.5 * 255).round()),
                      ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 4, bottom: 14),
                                    child: Text(
                                      'InBody SmartScale',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: FitnessAppTheme.fontName,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                        letterSpacing: 0.0,
                                        color: FitnessAppTheme.nearlyDarkBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            ],
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
                          // Compute body fat and BMI area
                          Padding(
                            padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 16),
                            child: Row(
                              children: <Widget>[
                                // Height
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        widget.diary != null && widget.diary.bodyMeasurements != null
                                            ? '${widget.diary.bodyMeasurements!.heightCm.toStringAsFixed(0)} cm'
                                            : (widget.profile != null && widget.profile!['heightCm'] != null)
                                                ? '${(widget.profile!['heightCm'] as num).toStringAsFixed(0)} cm'
                                                : '185 cm',
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
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          'Height',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: FitnessAppTheme.fontName,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: FitnessAppTheme.grey.withAlpha((0.5 * 255).round()),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // BMI
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: <Widget>[
                                      Builder(builder: (ctx) {
                                        double? diaryBmi;
                                        if (widget.diary != null && widget.diary.bodyMeasurements != null) {
                                          diaryBmi = (widget.diary.bodyMeasurements!.bmi as num?)?.toDouble();
                                        }

                                        double? profileBmi;
                                        try {
                                          final ph = pv('heightCm');
                                          final pw = pv('weightKg');
                                          if (ph != null && pw != null) {
                                            final h = (ph is num ? ph.toDouble() : double.parse(ph.toString())) / 100.0;
                                            final w = (pw is num ? pw.toDouble() : double.parse(pw.toString()));
                                            if (h > 0) profileBmi = w / (h * h);
                                          }
                                        } catch (_) {}

                                        double? bmiVal = diaryBmi ?? profileBmi;
                                        String bmiText = bmiVal != null ? bmiVal.toStringAsFixed(1) : '\u2014';
                                        String category = '—';
                                        if (bmiVal != null) {
                                          if (bmiVal < 18.5) category = 'Underweight';
                                          else if (bmiVal < 25.0) category = 'Normal';
                                          else if (bmiVal < 30.0) category = 'Overweight';
                                          else category = 'Obese';
                                        }

                                        return Column(
                                          children: [
                                            Text(
                                              '$bmiText BMI',
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
                                              padding: const EdgeInsets.only(top: 6),
                                              child: Text(
                                                category,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontFamily: FitnessAppTheme.fontName,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                  color: FitnessAppTheme.grey.withAlpha((0.5 * 255).round()),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ),

                                // Body fat
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: <Widget>[
                                      Builder(builder: (ctx) {
                                        String bodyFatDisplay = '\u2014';
                                        String bodyFatSource = 'none';
                                        try {
                                          if (widget.diary != null && widget.diary.bodyMeasurements != null) {
                                            final v = widget.diary.bodyMeasurements!.bodyFatPercent;
                                            if (v is num && v > 0) {
                                              bodyFatDisplay = '${v.toStringAsFixed(0)}%';
                                              bodyFatSource = 'diary';
                                            }
                                          }
                                        } catch (_) {}

                                        if (bodyFatSource == 'none') {
                                          try {
                                            final pvVal = pv('bodyFatPercent');
                                            if (pvVal != null) {
                                              if (pvVal is num && pvVal > 0) {
                                                bodyFatDisplay = '${pvVal.toStringAsFixed(0)}%';
                                                bodyFatSource = 'profile';
                                              } else {
                                                final s = pvVal.toString().replaceAll('%', '').trim();
                                                final parsed = double.tryParse(s);
                                                if (parsed != null && parsed > 0) {
                                                  bodyFatDisplay = '${parsed.toStringAsFixed(0)}%';
                                                  bodyFatSource = 'profile-parsed';
                                                }
                                              }
                                            }
                                          } catch (_) {}
                                        }

                                        if (bodyFatSource == 'none') {
                                          try {
                                            double? bmiForEstimate;
                                            if (widget.diary != null && widget.diary.bodyMeasurements != null) bmiForEstimate = (widget.diary.bodyMeasurements!.bmi as num?)?.toDouble();
                                            if (bmiForEstimate == null) {
                                              final ph = pv('heightCm');
                                              final pw = pv('weightKg');
                                              if (ph != null && pw != null) {
                                                final h = (ph is num ? ph.toDouble() : double.parse(ph.toString())) / 100.0;
                                                final w = (pw is num ? pw.toDouble() : double.parse(pw.toString()));
                                                if (h > 0) bmiForEstimate = w / (h * h);
                                              }
                                            }

                                            int ageVal = 30;
                                            final a = pv('age');
                                            if (a is num) ageVal = (a as num).toInt();
                                            else if (a is String) ageVal = int.tryParse(a) ?? ageVal;
                                            else {
                                              final bd = pv('birthdate') ?? pv('dob');
                                              if (bd is String) {
                                                final dt = DateTime.tryParse(bd);
                                                if (dt != null) {
                                                  final now = DateTime.now();
                                                  ageVal = now.year - dt.year - ((now.month < dt.month || (now.month == dt.month && now.day < dt.day)) ? 1 : 0);
                                                }
                                              }
                                            }

                                            int sexFlag = 1;
                                            final s = pv('sex') ?? pv('gender');
                                            if (s is String) {
                                              final sl = s.toLowerCase();
                                              if (sl.startsWith('m')) sexFlag = 1;
                                              else if (sl.startsWith('f')) sexFlag = 0;
                                            } else if (s is num) {
                                              sexFlag = (s as num).toInt();
                                            }

                                            if (bmiForEstimate != null) {
                                              final est = (1.2 * bmiForEstimate) + (0.23 * ageVal) - (10.8 * sexFlag) - 5.4;
                                              if (est.isFinite) {
                                                bodyFatDisplay = '${est.toStringAsFixed(0)}%';
                                                bodyFatSource = 'estimate';
                                              }
                                            }
                                          } catch (_) {}
                                        }

                                        // Only print when the displayed value or source changes to reduce log spam
                                        if (_lastBodyFatDisplay != bodyFatDisplay || _lastBodyFatSource != bodyFatSource) {
                                          _lastBodyFatDisplay = bodyFatDisplay;
                                          _lastBodyFatSource = bodyFatSource;
                                          // include some diagnostics to help trace dynamic vs static values
                                          String diag = 'BodyMeasurement changed: display=$bodyFatDisplay source=$bodyFatSource';
                                          try {
                                            final diaryBmi = (widget.diary != null && widget.diary.bodyMeasurements != null) ? (widget.diary.bodyMeasurements!.bmi?.toString() ?? '<null>') : '<no-diary-bmi>';
                                            final profBmi = (() {
                                              try {
                                                final ph = pv('heightCm');
                                                final pw = pv('weightKg');
                                                if (ph != null && pw != null) return '${ph}/${pw}';
                                              } catch (_) {}
                                              return '<no-profile-bmi-inputs>';
                                            })();
                                            diag = '$diag | diaryBmi=$diaryBmi profileInput=$profBmi';
                                          } catch (_) {}
                                          debugPrint(diag);
                                        }
                                        return Column(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: <Widget>[
                                            Text(
                                              bodyFatDisplay,
                                              style: TextStyle(
                                                fontFamily: FitnessAppTheme.fontName,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 16,
                                                letterSpacing: -0.2,
                                                color: FitnessAppTheme.darkText,
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(top: 6),
                                              child: Text(
                                                'Body fat',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontFamily: FitnessAppTheme.fontName,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                  color: FitnessAppTheme.grey.withAlpha((0.5 * 255).round()),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ),
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
