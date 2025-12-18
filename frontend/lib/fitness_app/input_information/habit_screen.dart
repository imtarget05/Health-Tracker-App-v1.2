import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:best_flutter_ui_templates/services/event_bus.dart';

import '../../firebase_options.dart';

import '../fitness_app_theme.dart';
import '../ui_view/input_view.dart';
import '../fitness_app_home_screen.dart';

class HabitScreen extends StatefulWidget {
  const HabitScreen({super.key});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen>
    with TickerProviderStateMixin {

  late AnimationController animationController;
  Animation<double>? topBarAnimation;

  List<Widget> listViews = <Widget>[];
  final ScrollController scrollController = ScrollController();
  double topBarOpacity = 0.0;

  DateTime selectedDate = DateTime.now();
  final TextEditingController sleepController = TextEditingController();
  final TextEditingController exerciseController = TextEditingController();
  final TextEditingController waterController = TextEditingController();

  @override
  void initState() {
    animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    topBarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0, 0.5, curve: Curves.fastOutSlowIn),
      ),
    );

    addAllListData();

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
    sleepController.dispose();
    exerciseController.dispose();
    waterController.dispose();
    animationController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void addAllListData() {
    const int count = 4;
    // Sleep hours: open a slider bottom sheet to pick hours (0-12)
    listViews.add(
      InputView(
        animation: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animationController,
            curve: Interval((1 / count) * 1, 1.0, curve: Curves.fastOutSlowIn),
          ),
        ),
        animationController: animationController,
        title: "How Many Hours Do You Sleep A Day?",
        hint: "Enter your sleep time...",
        controller: sleepController,
        isNumber: false,
        readOnly: true,
        onTap: () async {
          double value = 8.0;
          try {
            value = double.parse(sleepController.text);
          } catch (_) {}
          await showModalBottomSheet(
            context: context,
            builder: (ctx) {
              return StatefulBuilder(builder: (ctx2, setState2) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Select sleep hours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Slider(
                        min: 0,
                        max: 12,
                        divisions: 24,
                        value: value,
                        label: '${value.toStringAsFixed(1)} h',
                        onChanged: (v) => setState2(() => value = v),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${value.toStringAsFixed(1)} hours'),
                          ElevatedButton(
                            onPressed: () {
                              sleepController.text = value.toStringAsFixed(1);
                              Navigator.of(ctx).pop();
                            },
                            child: Text('Confirm'),
                          )
                        ],
                      ),
                    ],
                  ),
                );
              });
            },
          );
        },
      ),
    );

    // Exercise: open choices modal allowing custom input
    listViews.add(
      InputView(
        animation: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animationController,
            curve: Interval((1 / count) * 2, 1.0, curve: Curves.fastOutSlowIn),
          ),
        ),
        animationController: animationController,
        title: "Your Favourite Exercise",
        hint: "Enter your exercise...",
        controller: exerciseController,
        isNumber: false,
        readOnly: true,
        onTap: () async {
          final options = ['Running', 'Cycling', 'Swimming', 'Gym', 'Yoga', 'Other'];
          String? selected = exerciseController.text.isNotEmpty ? exerciseController.text : null;
          await showModalBottomSheet(
            context: context,
            builder: (ctx) {
              return StatefulBuilder(builder: (ctx2, setState2) {
                String custom = '';
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Select your favourite exercise', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ...options.map((o) => RadioListTile<String>(
                        title: Text(o),
                        value: o,
                        groupValue: selected,
                        onChanged: (v) {
                          if (v == null) return;
                          if (v == 'Other') {
                            // show dialog to input custom
                            showDialog(
                              context: ctx2,
                              builder: (dctx) {
                                return AlertDialog(
                                  title: Text('Enter custom exercise'),
                                  content: TextField(
                                    onChanged: (t) => custom = t,
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(dctx).pop(), child: Text('Cancel')),
                                    TextButton(onPressed: () {
                                      if (custom.trim().isNotEmpty) {
                                        exerciseController.text = custom.trim();
                                        Navigator.of(dctx).pop();
                                        Navigator.of(ctx).pop();
                                      }
                                    }, child: Text('OK')),
                                  ],
                                );
                              }
                            );
                          } else {
                            setState2(() => selected = v);
                            exerciseController.text = v;
                            Navigator.of(ctx).pop();
                          }
                        },
                      )),
                    ],
                  ),
                );
              });
            },
          );
        },
      ),
    );

    // Water: numeric input with unit suffix (ml)
    listViews.add(
      InputView(
        animation: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animationController,
            curve: Interval((1 / count) * 3, 1.0, curve: Curves.fastOutSlowIn),
          ),
        ),
        animationController: animationController,
        title: "How Much Water Do You Drink A Day?",
  hint: "Enter your amount of water...",
  controller: waterController,
  isNumber: true,
  suffixText: 'ml',
      ),
    );

  }

  Future<bool> getData() async {
    await Future<dynamic>.delayed(const Duration(milliseconds: 50));
    return true;
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
            SizedBox(height: MediaQuery.of(context).padding.bottom),

            Positioned(
              bottom: 40,
              left: 32,
              right: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text("Back", style: TextStyle(color: FitnessAppTheme.white, fontSize: 16),),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FitnessAppTheme.nearlyDarkBlue,
                      padding: EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32)),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // validate
                      final navigator = Navigator.of(context);

                      final sleep = double.tryParse(sleepController.text);
                      final water = int.tryParse(waterController.text);
                      final exercise = exerciseController.text.trim();

                      if (sleep == null || sleep < 0 || sleep > 24) {
                        EventBus.instance.emitError('Please choose a valid sleep hours (0-24).');
                        return;
                      }
                      if (exercise.isEmpty) {
                        EventBus.instance.emitError('Please select your favourite exercise.');
                        return;
                      }
                      if (water == null || water <= 0) {
                        EventBus.instance.emitError('Please enter amount of water in ml.');
                        return;
                      }

                      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

                      try {
                        if (Firebase.apps.isEmpty) {
                          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
                        }

                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          navigator.pop();
                          EventBus.instance.emitError('Not signed in to Firebase.');
                          return;
                        }

                        final db = FirebaseFirestore.instance;
                        final uid = user.uid;
                        final doc = db.collection('users').doc(uid);

                        final payload = {
                          'habit': {
                            'sleepHours': sleep,
                            'exercise': exercise,
                            'waterMl': water,
                            'updatedAt': DateTime.now().toIso8601String(),
                          }
                        };

                        await doc.set(payload, SetOptions(merge: true));

                        navigator.pop();
                        EventBus.instance.emitSuccess('Saved habit info');
                        navigator.push(MaterialPageRoute(builder: (_) => FitnessAppHomeScreen()));
                      } catch (e, st) {
                        navigator.pop();
                        EventBus.instance.emitError('Failed to save: $e');
                        // ignore: avoid_print
                        print(st);
                      }
                    },
                    child: Text("Next", style: TextStyle(color: FitnessAppTheme.white, fontSize: 16),),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FitnessAppTheme.nearlyDarkBlue,
                      padding: EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32)),
                    ),
                  ),
                ],
              ),
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
        if (!snapshot.hasData) return const SizedBox();

        return ListView.builder(
          controller: scrollController,
          padding: EdgeInsets.only(
            top: AppBar().preferredSize.height +
                MediaQuery.of(context).padding.top +
                24,
          ),
          itemCount: listViews.length,
          itemBuilder: (BuildContext context, int index) {
            animationController.forward();
            return listViews[index];
          },
        );
      },
    );
  }

  Widget getAppBarUI() {
    return Column(
      children: <Widget>[
        AnimatedBuilder(
          animation: animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: topBarAnimation!,
              child: Transform(
                transform: Matrix4.translationValues(
                  0.0,
                  30 * (1.0 - topBarAnimation!.value),
                  0.0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: FitnessAppTheme.white.withAlpha((topBarOpacity * 255).round()),
                    borderRadius:
                    const BorderRadius.only(bottomLeft: Radius.circular(32.0)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color:
                        FitnessAppTheme.grey.withAlpha(((0.4 * topBarOpacity) * 255).round()),
                        offset: const Offset(1.1, 1.1),
                        blurRadius: 10.0,
                      ),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      SizedBox(height: MediaQuery.of(context).padding.top),
                      Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16 - 8.0 * topBarOpacity,
                          bottom: 12 - 8.0 * topBarOpacity,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Habit',
                                style: TextStyle(
                                  fontFamily: FitnessAppTheme.fontName,
                                  fontWeight: FontWeight.w700,
                                  fontSize:
                                  22 + 6 - 6 * topBarOpacity,
                                  letterSpacing: 1.2,
                                  color: FitnessAppTheme.darkerText,
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
