import 'package:best_flutter_ui_templates/fitness_app/ui_view/title_view.dart';
import 'package:best_flutter_ui_templates/fitness_app/profile/widgets/profile_goals.dart';
import 'package:best_flutter_ui_templates/fitness_app/profile/widgets/profile_header.dart';
import 'package:best_flutter_ui_templates/fitness_app/profile/widgets/profile_state.dart';
import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../services/profile_sync_service.dart';
import '../../services/auth_storage.dart';
import 'package:best_flutter_ui_templates/services/event_bus.dart';
import '../flutter_login/login.dart';
import 'edit_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.animationController});

  final AnimationController? animationController;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _topBarAnimation;
  final ScrollController _scrollController = ScrollController();
  double topBarOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = widget.animationController ?? AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _topBarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.fastOutSlowIn)),
    );
    _scrollController.addListener(_scrollControllerListenerSetup);
  }

  void _scrollControllerListenerSetup() {
    final offset = _scroll_controller_offsetSafe();
    if (offset >= 24) {
      if (topBarOpacity != 1.0) setState(() => topBarOpacity = 1.0);
    } else if (topBarOpacity != 0.0) {
      setState(() => topBarOpacity = 0.0);
    }
  }

  double _scroll_controller_offsetSafe() {
    try {
      return _scroll_controller_exists() ? _scrollController.offset : 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  bool _scroll_controller_exists() => _scrollController.hasClients;

  @override
  void dispose() {
    _scrollController.dispose();
    if (widget.animationController == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FitnessAppTheme.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: <Widget>[
            _buildMainListView(context),
            _buildAppBar(context),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildMainListView(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Vui lòng đăng nhập'));

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    // Guard the stream so Firestore permission errors don't crash the app.
    final safeStream = docRef.snapshots().handleError((e) {
      debugPrint('ProfileScreen: snapshots stream error: $e');
    });

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: safeStream,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Không thể tải hồ sơ: ${snap.error}'));
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snap.hasData || snap.data == null || !snap.data!.exists) return const Center(child: Text('Chưa có dữ liệu hồ sơ'));

        final data = snap.data!.data() ?? {};
        final profile = (data['profile'] as Map<String, dynamic>?) ?? {};
  final dailyWaterMl = profile['dailyWaterMl'] is num ? (profile['dailyWaterMl'] as num).toInt() : null;
  final drinkingTimes = profile['drinkingTimes'] is List ? List<String>.from(profile['drinkingTimes'] as List) : <String>[];
        final name = profile['fullName'] ?? profile['displayName'] ?? profile['name'] ?? '';
        final email = profile['email'] ?? '';
        final avatar = profile['profilePic'] ?? profile['photoURL'] ?? '';
        final calories = (profile['calories'] != null) ? '${profile['calories']} kcal' : '—';
        final weight = (profile['weightKg'] != null) ? '${profile['weightKg']} kg' : (profile['weight'] != null ? '${profile['weight']} kg' : '—');
        final height = (profile['heightCm'] != null) ? '${profile['heightCm']} cm' : (profile['height'] != null ? '${profile['height']} cm' : '—');
        final weightKg = (profile['weightKg'] is num) ? (profile['weightKg'] as num).toDouble() : (profile['weight'] is num ? (profile['weight'] as num).toDouble() : null);
        final heightCm = (profile['heightCm'] is num) ? (profile['heightCm'] as num).toDouble() : (profile['height'] is num ? (profile['height'] as num).toDouble() : null);
        DateTime? lastUpdated;
        if (snap.data!.data()!.containsKey('lastUpdated')) {
          final t = snap.data!['lastUpdated'];
          if (t is Timestamp) lastUpdated = t.toDate();
        }
        final goals = (data['goals'] is List) ? List<String>.from(data['goals']) : <String>[];

        return ListView(
          controller: _scrollController,
          padding: EdgeInsets.only(
            top: AppBar().preferredSize.height + MediaQuery.of(context).padding.top + 24,
            bottom: 62 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            TitleView(titleTxt: 'Bạn', animation: AlwaysStoppedAnimation(1.0), animationController: _controller),
            ProfileHeader(
              imageUrl: avatar,
              name: name,
              email: email,
              weightKg: weightKg,
              heightCm: heightCm,
              dailyWaterMl: dailyWaterMl,
              drinkingTimes: drinkingTimes,
              lastUpdated: lastUpdated,
              animation: AlwaysStoppedAnimation(1.0),
              animationController: _controller,
              onEdit: () async {
                if (!mounted) return;
                final navigator = Navigator.of(context);
                final saved = await navigator.push<bool>(MaterialPageRoute(builder: (_) => const EditProfilePage()));
                if (!mounted) return;
                if (saved == true) EventBus.instance.emitSuccess('Hồ sơ đã được cập nhật');
              },
              onLogout: () async {
                final navigator = Navigator.of(context);
                await FirebaseAuth.instance.signOut();
                AuthStorage.clear();
                if (!mounted) return;
                EventBus.instance.emitInfo('Đã đăng xuất');
                navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
              },
              onPickAvatar: () async {
                try {
                  final picker = ImagePicker();
                  final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                  if (file == null) return;
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  // Upload to Firebase Storage
                  final storageRef = FirebaseStorage.instance.ref().child('avatars').child(user.uid).child('${DateTime.now().millisecondsSinceEpoch}.jpg');
                  await storageRef.putFile(File(file.path));
                  final downloadUrl = await storageRef.getDownloadURL();

                  final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
                  final payload = {'profile': {'profilePic': downloadUrl}, 'lastUpdated': FieldValue.serverTimestamp()};
                  await doc.set(payload, SetOptions(merge: true));
                  if (!mounted) return;
                  EventBus.instance.emitSuccess('Ảnh đại diện đã được cập nhật');
                } catch (e) {
                  if (mounted) EventBus.instance.emitError('Không thể cập nhật ảnh: $e');
                }
              },
            ),
            TitleView(titleTxt: 'Thống kê', animation: AlwaysStoppedAnimation(1.0), animationController: _controller),
            ProfileStatsCard(animation: AlwaysStoppedAnimation(1.0), animationController: _controller, calories: calories, weight: weight, height: height),
            // add drinking times as an informal goal entry if present
            ProfileGoalCard(animation: AlwaysStoppedAnimation(1.0), animationController: _controller, goals: ([...goals]..addAll(drinkingTimes.isNotEmpty ? ['Drinking times: ${drinkingTimes.join(', ')}'] : []))),
          ],
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Column(
      children: <Widget>[
        AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return FadeTransition(
              opacity: _topBarAnimation,
              child: Transform(
                transform: Matrix4.translationValues(0.0, 30 * (1.0 - _topBarAnimation.value), 0.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: FitnessAppTheme.white.withAlpha((topBarOpacity * 255).round()),
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32.0)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: FitnessAppTheme.grey.withAlpha(((0.4 * topBarOpacity) * 255).round()), offset: const Offset(1.1, 1.1), blurRadius: 10.0),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      SizedBox(height: MediaQuery.of(context).padding.top),
                      Padding(
                        padding: EdgeInsets.only(left: 16, right: 16, top: 16 - 8.0 * topBarOpacity, bottom: 12 - 8.0 * topBarOpacity),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  'Hồ sơ của bạn',
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
                            IconButton(
                              icon: const Icon(Icons.edit),
                              color: FitnessAppTheme.darkerText,
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final saved = await navigator.push<bool>(MaterialPageRoute(builder: (_) => const EditProfilePage()));
                                if (!mounted) return;
                                if (saved == true) EventBus.instance.emitSuccess('Hồ sơ đã được cập nhật');
                              },
                            ),
                            ValueListenableBuilder<int>(
                              valueListenable: ProfileSyncService.instance.queueCount,
                              builder: (context, count, child) {
                                return IconButton(
                                  icon: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      const Icon(Icons.sync),
                                      if (count > 0)
                                        Positioned(
                                          right: -6,
                                          top: -6,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                            child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                                          ),
                                        ),
                                    ],
                                  ),
                                  color: FitnessAppTheme.darkerText,
                                  onPressed: () => Navigator.of(context).pushNamed('profile-sync-debug'),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout),
                              color: FitnessAppTheme.darkerText,
                              onPressed: () async {
                                final navigator = Navigator.of(context);
                                final shouldLogout = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Xác nhận đăng xuất'),
                                    content: const Text('Bạn có chắc muốn đăng xuất không?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
                                      TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Đăng xuất')),
                                    ],
                                  ),
                                );
                                if (!mounted) return;
                                if (shouldLogout == true) navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
                              },
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

