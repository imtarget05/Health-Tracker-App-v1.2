import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore_for_file: deprecated_member_use
import 'package:best_flutter_ui_templates/services/event_bus.dart';

import '../../firebase_options.dart';
import '../../services/profile_sync_service.dart';
import '../../services/pending_signup.dart';
import '../../services/auth_storage.dart';
import '../../services/backend_api.dart';

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
  bool _checkingProfile = true;

  @override
  void initState() {
    animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

  // If user already has habit info in Firestore, skip this screen and go to home.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        }
      } catch (_) {}
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final data = doc.data();
          if (data != null && data['habit'] != null) {
            // Already configured, navigate to home
            if (mounted) {
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => FitnessAppHomeScreen()));
        return;
            }
          }
        } catch (_) {}
      }
    // finished checking; allow UI to render
    if (mounted) setState(() => _checkingProfile = false);
    });

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
    if (_checkingProfile) {
      return Container(
        color: FitnessAppTheme.background,
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FitnessAppTheme.nearlyDarkBlue,
                      padding: EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32)),
                    ),
                    child: Text("Back", style: TextStyle(color: FitnessAppTheme.white, fontSize: 16),),
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
                        final payload = {
                          'habit': {
                            'sleepHours': sleep,
                            'exercise': exercise,
                            'waterMl': water,
                            'updatedAt': DateTime.now().toIso8601String(),
                          }
                        };

                        if (user == null) {
                          // If there's a pending signup (user previously attempted
                          // registration but createUser failed due to network), try to
                          // finalize it now before enqueuing profile data. This helps
                          // avoid the UX where the app showed success but no account
                          // exists in Firebase.
                          final pending = PendingSignup.peek();
                          if (pending != null) {
                            try {
                              // Try to create or sign in the Firebase user now.
                              try {
                                await FirebaseAuth.instance.createUserWithEmailAndPassword(
                                  email: pending['email'] ?? '',
                                  password: pending['password'] ?? '',
                                );
                              } on FirebaseAuthException catch (e) {
                                if (e.code == 'email-already-in-use' || e.code == 'email-already-exists') {
                                  await FirebaseAuth.instance.signInWithEmailAndPassword(
                                    email: pending['email'] ?? '',
                                    password: pending['password'] ?? '',
                                  );
                                } else {
                                  // If still failing due to network or other transient
                                  // conditions, leave pending signup for later and fall
                                  // back to enqueuing the profile.
                                  debugPrint('HabitScreen: finalize pending signup failed: $e');
                                }
                              }
                            } catch (e) {
                              debugPrint('HabitScreen: error while finalizing pending signup: $e');
                            }

                            // Re-check user after attempted finalization
                            final after = FirebaseAuth.instance.currentUser;
                            if (after != null) {
                              // User is now signed in; continue to immediate save flow
                              try {
                                final db2 = FirebaseFirestore.instance;
                                final doc2 = db2.collection('users').doc(after.uid);

                                // infer name/username from email and merge habit into profile
                                final currentEmailAfter = FirebaseAuth.instance.currentUser?.email ?? pending?['email'] ?? '';
                                String inferredNameAfter = '';
                                String inferredUsernameAfter = '';
                                try {
                                  if (currentEmailAfter.isNotEmpty) {
                                    final parts = currentEmailAfter.split('@');
                                    inferredUsernameAfter = parts.first;
                                    inferredNameAfter = inferredUsernameAfter.replaceAll(RegExp(r'[\._\d]+'), ' ').trim();
                                    if (inferredNameAfter.isEmpty) inferredNameAfter = inferredUsernameAfter;
                                  }
                                } catch (_) {}

                                // Merge any queued partial profile data (from Welcome/Future screens)
                                final queued = ProfileSyncService.instance.readQueue();
                                final Map<String, dynamic> mergedProfileAfter = {
                                  'fullName': inferredNameAfter,
                                  'username': inferredUsernameAfter,
                                };
                                for (final item in queued) {
                                  try {
                                    final data = Map<String, dynamic>.from(item['data'] ?? {});
                                    if (data.containsKey('profile') && data['profile'] is Map) {
                                      mergedProfileAfter.addAll(Map<String, dynamic>.from(data['profile']));
                                    }
                                  } catch (_) {}
                                }

                                final docUpdate = {
                                  'habit': payload['habit'],
                                  'updatedAt': DateTime.now().toIso8601String(),
                                  'profile': mergedProfileAfter,
                                };

                                await doc2.set(docUpdate, SetOptions(merge: true));
                                // trigger queued flush
                                try { await ProfileSyncService.instance.retryQueue(); } catch (_) {}
                                navigator.pop();
                                EventBus.instance.emitSuccess('Saved habit info');

                                // consume pending signup now that backend account exists
                                PendingSignup.consume();

                                // Attempt deferred backend signup if registration was started earlier
                                try {
                                  final p = PendingSignup.consume();
                                  if (p != null) {
                                    final res = await BackendApi.signup(
                                      fullName: p['fullName'] ?? '',
                                      email: p['email'] ?? '',
                                      password: p['password'] ?? '',
                                      phone: p['phone'],
                                    );
                                    final backendToken = res != null && res['token'] != null ? res['token'] as String? : null;
                                    final custom = res != null && res['firebaseCustomToken'] != null ? res['firebaseCustomToken'] as String? : null;
                                    if (custom != null) {
                                      try {
                                        await FirebaseAuth.instance.signInWithCustomToken(custom);
                                      } catch (e) {
                                        debugPrint('HabitScreen: signInWithCustomToken failed: $e');
                                      }
                                    }
                                    if (backendToken != null) {
                                      AuthStorage.saveToken(backendToken);
                                    }
                                  }
                                } catch (e, st) {
                                  EventBus.instance.emitError('Unable to complete backend registration. Your profile will be saved locally.');
                                  if (kDebugMode) debugPrint('HabitScreen: backend signup failed: $e\n$st');
                                }

                                navigator.pushReplacement(MaterialPageRoute(builder: (_) => FitnessAppHomeScreen()));
                                return;
                              } catch (e, st) {
                                debugPrint('HabitScreen: failed to save after finalizing signup: $e\n$st');
                                // fall-through to enqueue below
                              }
                            }
                          }

                          // Not signed in: enqueue the profile partial for later sync
                          try {
                            await ProfileSyncService.instance.saveProfilePartial(payload);
                            navigator.pop();
                            EventBus.instance.emitInfo('Saved locally and will sync after sign-in.');
                            // Proceed into the app even if not signed in so user can continue
                            navigator.pushReplacement(MaterialPageRoute(builder: (_) => const FitnessAppHomeScreen()));
                          } catch (e) {
                            navigator.pop();
                            EventBus.instance.emitError('Not signed in to Firebase.');
                          }
                          return;
                        }

                        final db = FirebaseFirestore.instance;
                        final uid = user.uid;
                        final doc = db.collection('users').doc(uid);

                        // Build profile updates: name from email (before @), username from email prefix
                        final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';
                        String inferredName = '';
                        String inferredUsername = '';
                        try {
                          if (currentEmail.isNotEmpty) {
                            final parts = currentEmail.split('@');
                            inferredUsername = parts.first;
                            // Create a nicer display name from the local part by replacing dots/underscores/numbers
                            inferredName = inferredUsername.replaceAll(RegExp(r'[\._\d]+'), ' ').trim();
                            if (inferredName.isEmpty) inferredName = inferredUsername;
                          }
                        } catch (_) {}

                        // Merge any queued partial profile data (weight/height/ideal/deadline)
                        final queued = ProfileSyncService.instance.readQueue();
                        final Map<String, dynamic> mergedProfile = {
                          'fullName': inferredName,
                          'username': inferredUsername,
                        };
                        for (final item in queued) {
                          try {
                            final data = Map<String, dynamic>.from(item['data'] ?? {});
                            if (data.containsKey('profile') && data['profile'] is Map) {
                              mergedProfile.addAll(Map<String, dynamic>.from(data['profile']));
                            }
                          } catch (_) {}
                        }

                        final profileUpdate = {
                          'habit': payload['habit'],
                          'updatedAt': DateTime.now().toIso8601String(),
                          'profile': mergedProfile,
                        };

                        // Merge the profile update into user doc
                        await doc.set(profileUpdate, SetOptions(merge: true));

                        // Trigger any queued sync now that user is signed in
                        try { await ProfileSyncService.instance.retryQueue(); } catch (_) {}

                        navigator.pop();
                        EventBus.instance.emitSuccess('Saved habit info');

                        // Attempt deferred backend signup if registration was started earlier
                        final pending = PendingSignup.consume();
                        if (pending != null) {
                          try {
                            final res = await BackendApi.signup(
                              fullName: pending['fullName'] ?? '',
                              email: pending['email'] ?? '',
                              password: pending['password'] ?? '',
                              phone: pending['phone'],
                            );

                            final backendToken = res != null && res['token'] != null ? res['token'] as String? : null;
                            final custom = res != null && res['firebaseCustomToken'] != null ? res['firebaseCustomToken'] as String? : null;
                            if (custom != null) {
                              try {
                                await FirebaseAuth.instance.signInWithCustomToken(custom);
                              } catch (e) {
                                debugPrint('HabitScreen: signInWithCustomToken failed: $e');
                              }
                            }
                            if (backendToken != null) {
                              AuthStorage.saveToken(backendToken);
                            }
                          } catch (e, st) {
                            // Report a friendly user-facing message and keep raw error in debug logs
                                  EventBus.instance.emitError('Unable to complete backend registration. Your profile will be saved locally.');
                            if (kDebugMode) debugPrint('HabitScreen: backend signup failed: $e\n$st');
                          }
                        }

                        navigator.pushReplacement(MaterialPageRoute(builder: (_) => FitnessAppHomeScreen()));
                      } catch (e, st) {
                        navigator.pop();
                        EventBus.instance.emitError('Unable to save data. Please check your connection and try again.');
                        if (kDebugMode) debugPrint('HabitScreen: failed to save: $e\n$st');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FitnessAppTheme.nearlyDarkBlue,
                      padding: EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32)),
                    ),
                    child: Text("Next", style: TextStyle(color: FitnessAppTheme.white, fontSize: 16),),
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
