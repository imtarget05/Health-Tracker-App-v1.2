import 'package:best_flutter_ui_templates/fitness_app/ui_view/wave_view.dart';
import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:best_flutter_ui_templates/main.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/diary.dart';
import '../../services/diary_service.dart';

class WaterView extends StatefulWidget {
  const WaterView(
      {super.key, this.mainScreenAnimationController, this.mainScreenAnimation});

  final AnimationController? mainScreenAnimationController;
  final Animation<double>? mainScreenAnimation;

  @override
  State<WaterView> createState() => _WaterViewState();
}

class _WaterViewState extends State<WaterView> with TickerProviderStateMixin {
  Future<bool> getData() async {
    await Future<dynamic>.delayed(const Duration(milliseconds: 50));
    return true;
  }

  late AnimationController waterController;
  late Animation<double> waterAnimation;
  double currentAmount = 0; // inf (backed by Firestore)
  int dailyGoal = 3500; // default daily goal (ml)
  late DiaryService diaryService;
  StreamSubscription<Diary?>? _diarySub;
  StreamSubscription<User?>? _authSub;

  void increaseWater() {
    // Use DiaryService transaction to increment water by 100ml
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final scaffold = ScaffoldMessenger.of(context);
    diaryService.incrementWater(DateTime.now(), 100).catchError((e) {
      scaffold.showSnackBar(const SnackBar(content: Text('Failed to add water')));
    });
  }

  void decreaseWater() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final scaffold = ScaffoldMessenger.of(context);
    diaryService.incrementWater(DateTime.now(), -100).catchError((e) {
      scaffold.showSnackBar(const SnackBar(content: Text('Failed to remove water')));
    });
  }

  double get percentageValue {
  return (dailyGoal == 0) ? 0 : (currentAmount / dailyGoal) * 100;
  }

  @override
  void initState() {
    super.initState();

  waterController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    waterAnimation = Tween<double>(begin: 0, end: 2100).animate(
      CurvedAnimation(parent: waterController, curve: Curves.easeOut),
    )..addListener(() {
      setState(() {
        currentAmount = waterAnimation.value;
      });
    });

    waterController.forward();

    // Initialize DiaryService when auth state available
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      // always cancel previous diary subscription when auth changes
      _diarySub?.cancel();
      if (user != null) {
        diaryService = DiaryService(FirebaseFirestore.instance, user.uid);
        // protect the stream from throwing unhandled exceptions by handling errors
        final safeStream = diaryService.streamDiary(DateTime.now()).handleError((e) {
          debugPrint('WaterView: diary stream error (handleError): $e');
          // swallow errors here; we'll also report via onError below
        });

        _diarySub = safeStream.listen((d) {
          if (d != null) {
            if (!mounted) return;
            setState(() {
              currentAmount = d.water?.consumedMl.toDouble() ?? currentAmount;
              dailyGoal = d.water?.dailyGoalMl ?? dailyGoal;
            });
          }
        }, onError: (e) {
          // catch permission-denied and other errors from the listen
          debugPrint('WaterView: diary listen error: $e');
          if (!mounted) return;
          // reset to safe defaults so UI remains stable
          setState(() {
            currentAmount = 0;
            dailyGoal = 3500;
          });
        });
      } else {
        // no user -> reset values and avoid subscribing
        if (!mounted) return;
        setState(() {
          currentAmount = 0;
          dailyGoal = 3500;
        });
      }
    }, onError: (e) {
      debugPrint('WaterView: authStateChanges error: $e');
      // keep UI stable on auth stream errors
    });
  }
  @override
  void dispose() {
    waterController.dispose();
    _diarySub?.cancel();
  _authSub?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.mainScreenAnimationController!,
      builder: (BuildContext context, Widget? child) {
        return FadeTransition(
          opacity: widget.mainScreenAnimation!,
          child: Transform(
            transform: Matrix4.translationValues(
                0.0, 30 * (1.0 - widget.mainScreenAnimation!.value), 0.0),
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 24, right: 24, top: 16, bottom: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: FitnessAppTheme.white,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8.0),
                      bottomLeft: Radius.circular(8.0),
                      bottomRight: Radius.circular(8.0),
                      topRight: Radius.circular(68.0)),
                  boxShadow: <BoxShadow>[
          BoxShadow(
            color: FitnessAppTheme.grey.withAlpha((0.2 * 255).round()),
            offset: const Offset(1.1, 1.1),
            blurRadius: 10.0),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                      top: 16, left: 16, right: 16, bottom: 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 4, bottom: 3),
                                      child: Text(
                                        currentAmount.toInt().toString(),
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
                                        'ml',
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
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 4, top: 2, bottom: 14),
                                  child: Text(
                                    'of daily goal 3.5L',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: FitnessAppTheme.fontName,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      letterSpacing: 0.0,
                                      color: FitnessAppTheme.darkText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 4, right: 4, top: 8, bottom: 16),
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  color: FitnessAppTheme.background,
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(4.0)),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: <Widget>[
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Icon(
                                          Icons.access_time,
                                          color: FitnessAppTheme.grey
                                              .withAlpha((0.5 * 255).round()),
                                          size: 16,
                                        ),
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 4.0),
                                        child: Text(
                                          'Last drink 8:26 AM',
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
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: <Widget>[
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Image.asset(
                                              'assets/fitness_app/bell.png'),
                                        ),
                                        Flexible(
                                          child: Text(
                                            'Your bottle is empty, refill it!.',
                                            textAlign: TextAlign.start,
                                            style: TextStyle(
                                              fontFamily:
                                                  FitnessAppTheme.fontName,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                              letterSpacing: 0.0,
                                              color: HexColor('#F65283'),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            GestureDetector(
                              onTap: increaseWater,
                              child:
                                Container(
                                  decoration: BoxDecoration(
                                    color: FitnessAppTheme.nearlyWhite,
                                    shape: BoxShape.circle,
                                    boxShadow: <BoxShadow>[
                            BoxShadow(
                                        color: FitnessAppTheme.nearlyDarkBlue
                                          .withAlpha((0.4 * 255).round()),
                                          offset: const Offset(4.0, 4.0),
                                          blurRadius: 8.0),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Icon(
                                      Icons.add,
                                      color: FitnessAppTheme.nearlyDarkBlue,
                                      size: 24,
                                    ),
                                  ),
                                ),
                            ),
                            const SizedBox(
                              height: 28,
                            ),
                            GestureDetector(
                              onTap: decreaseWater,
                              child:
                                Container(
                                  decoration: BoxDecoration(
                                    color: FitnessAppTheme.nearlyWhite,
                                    shape: BoxShape.circle,
                                    boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: FitnessAppTheme.nearlyDarkBlue
                        .withAlpha((0.4 * 255).round()),
                                          offset: const Offset(4.0, 4.0),
                                          blurRadius: 8.0),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Icon(
                                      Icons.remove,
                                      color: FitnessAppTheme.nearlyDarkBlue,
                                      size: 24,
                                    ),
                                  ),
                                ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 16, right: 8, top: 16),
                        child: Container(
                          width: 60,
                          height: 160,
                          decoration: BoxDecoration(
                            color: HexColor('#E8EDFE'),
                            borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(80.0),
                                bottomLeft: Radius.circular(80.0),
                                bottomRight: Radius.circular(80.0),
                                topRight: Radius.circular(80.0)),
                            boxShadow: <BoxShadow>[
                BoxShadow(
                  color: FitnessAppTheme.grey.withAlpha((0.4 * 255).round()),
                  offset: const Offset(2, 2),
                  blurRadius: 4),
                            ],
                          ),
                          child: WaveView(
                            percentageValue: (dailyGoal == 0) ? 0 : (currentAmount / dailyGoal) * 100,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
