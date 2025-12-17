
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../services/backend_api.dart';
import '../../services/auth_storage.dart';
import '../../services/profile_sync_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  File? _avatar;
  String? profilePicUrl;
  String name = '';
  String username = '';
  String email = 'target@example.com';
  int? age = 20;
  String? gender = 'Male';
  int? idealWeightKg = 70;
  String? deadline = '2024-12-31';
  String? trainingIntensity = 'Medium';
  String? dietPlan = 'Balanced';
  // new water-related fields
  int? dailyWaterMl = 2000;
  List<String>? drinkingTimes = <String>['08:00', '12:00', '18:00'];
  bool? deadlineCompleted = false;
  double? weightKg = 70.0;
  double? heightCm = 170.0;
  String goal = 'Maintain';
  String phone = '+84 900000000';
  bool _loading = false;

  final ImagePicker _picker = ImagePicker();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _originalProfile;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _remoteProfileSub;

  @override
  void initState() {
    super.initState();
  _loadProfile();
  }

  @override
  void dispose() {
    _remoteProfileSub?.cancel();
    super.dispose();
  }

  Future<void> _mergeQueuedProfileData() async {
    try {
      final items = ProfileSyncService.instance.readQueue();
      if (items.isEmpty) return;

      // Find last queued profile partial. Items are decoded map with 'data' and 'createdAt'.
      Map<String, dynamic>? lastProfile;
      for (final it in items) {
        if (it is Map<String, dynamic>) {
          // item may be { 'data': { ... }, 'createdAt': ... }
          if (it.containsKey('data') && it['data'] is Map) {
            final d = Map<String, dynamic>.from(it['data'] as Map);
            // older code stored profile under 'profile' key, otherwise data may be the partial itself
            if (d.containsKey('profile') && d['profile'] is Map) {
              lastProfile = Map<String, dynamic>.from(d['profile'] as Map);
            } else {
              lastProfile = Map<String, dynamic>.from(d);
            }
          } else {
            // defensive: item might itself be the partial map
            lastProfile = Map<String, dynamic>.from(it);
          }
        }
      }

      if (lastProfile == null) return;

      setState(() {
  // prefer 'name' from input_information, fall back to 'fullName'
  name = (lastProfile!['name'] ?? lastProfile['fullName'] ?? name) as String;
  username = (lastProfile['username'] ?? username) as String;
        weightKg = lastProfile['weightKg'] != null ? (lastProfile['weightKg'] as num).toDouble() : weightKg;
        heightCm = lastProfile['heightCm'] != null ? (lastProfile['heightCm'] as num).toDouble() : heightCm;
        goal = (lastProfile['goal'] ?? goal) as String;
        phone = (lastProfile['phone'] ?? phone) as String;
  // link removed
        age = lastProfile['age'] != null ? (lastProfile['age'] as num).toInt() : age;
        gender = (lastProfile['gender'] ?? gender) as String?;
        idealWeightKg = lastProfile['idealWeightKg'] != null ? (lastProfile['idealWeightKg'] as num).toInt() : idealWeightKg;
        deadline = (lastProfile['deadline'] ?? deadline) as String?;
        trainingIntensity = (lastProfile['trainingIntensity'] ?? trainingIntensity) as String?;
        dietPlan = (lastProfile['dietPlan'] ?? dietPlan) as String?;
        // water fields
        dailyWaterMl = lastProfile['dailyWaterMl'] != null ? (lastProfile['dailyWaterMl'] as num).toInt() : dailyWaterMl;
        if (lastProfile['drinkingTimes'] is List) {
          drinkingTimes = List<String>.from(lastProfile['drinkingTimes'] as List);
        }
        deadlineCompleted = lastProfile['deadlineCompleted'] != null ? (lastProfile['deadlineCompleted'] as bool) : deadlineCompleted;
      });
    } catch (e) {
      debugPrint('EditProfile: merge queued failed: $e');
    }
  }

  Future<void> _saveProfile() async {
  if (_loading) return;
  final user = _auth.currentUser;
    if (user == null) {
  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Người dùng chưa đăng nhập')));
      return;
    }

    setState(() => _loading = true);

    // If user picked a new avatar file, attempt upload first (backend-first)
    final jwt = AuthStorage.token;
    if (_avatar != null && jwt != null) {
      try {
  final uploadResp = await BackendApi.uploadFile(jwt: jwt, endpointPath: '/upload/avatar', filePath: _avatar!.path, fieldName: 'file');
        final imageUrl = uploadResp['imageUrl'] as String?;
        if (imageUrl != null) {
          profilePicUrl = imageUrl;
        }
      } catch (e) {
        debugPrint('EditProfile: avatar upload failed: $e');
        // continue without avatar URL; user can retry by saving again
      }
    }

    // Build only changed fields to avoid duplicate writes
    final updateData = <String, dynamic>{};
    void putIfChanged(String key, dynamic value) {
      final orig = _originalProfile != null ? _originalProfile![key] : null;
      // normalize num types
      if (value is double || value is int) {
        if (orig is num) {
          if (orig.toDouble() != (value as num).toDouble()) updateData[key] = value;
        } else {
          updateData[key] = value;
        }
      } else {
        if ((orig == null && (value != null && value.toString().isNotEmpty)) || (orig != null && orig.toString() != (value ?? '').toString())) {
          updateData[key] = value;
        }
      }
    }

  putIfChanged('fullName', name);
  putIfChanged('username', username);
    putIfChanged('weightKg', weightKg);
    putIfChanged('heightCm', heightCm);
    putIfChanged('goal', goal);
  putIfChanged('phone', phone);
    // profilePic
    putIfChanged('profilePic', profilePicUrl);
  // include onboarding/input_information fields (saved only on bottom save)
  putIfChanged('age', age);
  putIfChanged('gender', gender);
  putIfChanged('idealWeightKg', idealWeightKg);
  putIfChanged('deadline', deadline);
  putIfChanged('trainingIntensity', trainingIntensity);
  putIfChanged('dietPlan', dietPlan);
  // water related
  putIfChanged('dailyWaterMl', dailyWaterMl);
  // store drinkingTimes as list
  putIfChanged('drinkingTimes', drinkingTimes);
  putIfChanged('deadlineCompleted', deadlineCompleted);
    if (updateData.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không có thay đổi để lưu')));
      setState(() => _loading = false);
      return;
    }
    updateData['updatedAt'] = DateTime.now().toIso8601String();

  // Try backend first using saved JWT from AuthStorage
    // Basic validation
    if (name.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên')));
      setState(() => _loading = false);
      return;
    }

    try {
  if (jwt != null) {
        final base = dotenv.env['BACKEND_URL'] ?? 'http://localhost:8080';
        final url = Uri.parse('$base/auth/update-profile');
        final resp = await http.put(url,
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $jwt'}, body: json.encode(updateData));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          // update local original snapshot
          _originalProfile ??= {};
          _originalProfile!.addAll(updateData);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật hồ sơ thành công')));
          setState(() => _loading = false);
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
      }
    } catch (e) {
      // ignore and fallback to client write
    }

    // Fallback: client-side Firestore update (merge)
    try {
  final docRef = _firestore.collection('users').doc(user.uid);
  // Mirror some keys into a nested `profile` map so screens that read `data['profile']` (ProfileScreen) see updates.
  final payload = Map<String, dynamic>.from(updateData);
  final Map<String, dynamic> profileMap = {};
  // if we have an original nested profile, start from that
  if (_originalProfile != null && _originalProfile!['profile'] is Map) {
    profileMap.addAll(Map<String, dynamic>.from(_originalProfile!['profile'] as Map));
  }
  const mirrorKeys = [
    'profilePic', 'fullName', 'name', 'displayName', 'weightKg', 'heightCm', 'email', 'username', 'age', 'gender', 'dailyWaterMl', 'drinkingTimes', 'deadlineCompleted'
  ];
  for (final k in mirrorKeys) {
    if (updateData.containsKey(k)) profileMap[k] = updateData[k];
  }
  if (profileMap.isNotEmpty) payload['profile'] = profileMap;

  await docRef.set(payload, SetOptions(merge: true));
  // merge into original
  _originalProfile ??= {};
  _originalProfile!.addAll(updateData);
  // also keep nested profile snapshot up-to-date in memory
  if (_originalProfile!['profile'] is! Map) _originalProfile!['profile'] = {};
  if (_originalProfile!['profile'] is Map) {
    final p = Map<String, dynamic>.from(_originalProfile!['profile'] as Map);
    for (final k in profileMap.keys) p[k] = profileMap[k];
    _originalProfile!['profile'] = p;
  }
  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật hồ sơ thành công (lưu cục bộ)')));
  if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể lưu hồ sơ')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _avatar = File(image.path);
        profilePicUrl = null;
      });
    }
  }
  // removed unused helper to reduce redundancy; avatar upload happens during final save

  Future<void> _editField({
    required String title,
    required String initialValue,
    required Function(String) onSave,
  }) async {
    final controller = TextEditingController(text: initialValue);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    onSave(controller.text);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Lưu'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = Map<String, dynamic>.from(doc.data()!);
        // store original snapshot for change detection
        _originalProfile = Map<String, dynamic>.from(data);
        setState(() {
          name = (data['name'] ?? data['fullName'] ?? name) as String;
          // derive username from auth email local part when available
          if (user.email != null && user.email!.contains('@')) {
            username = user.email!.split('@').first;
          } else {
            username = (data['username'] ?? username) as String;
          }
          // prefer auth email first then stored email
          email = (user.email ?? (data['email'] ?? email)) as String;
          weightKg = data['weightKg'] != null ? (data['weightKg'] as num).toDouble() : weightKg;
          heightCm = data['heightCm'] != null ? (data['heightCm'] as num).toDouble() : heightCm;
          goal = (data['goal'] ?? goal) as String;
          phone = (data['phone'] ?? user.phoneNumber ?? phone) as String;
          // link removed
          profilePicUrl = (data['profilePic'] ?? '') as String?;
          // also handle other input_information keys
          // age, gender, idealWeightKg, deadline, trainingIntensity, dietPlan
          // these will be merged into UI when present via _mergeQueuedProfileData
          if (profilePicUrl != null && profilePicUrl!.isNotEmpty) {
            _avatar = null; // keep avatar file null so CircleAvatar uses NetworkImage below
          }
        });
      }
    } catch (e) {
      // ignore, keep defaults
    }
    // Merge any queued partial onboarding/profile data
    await _mergeQueuedProfileData();

    // Subscribe to remote profile doc to reflect changes made elsewhere (e.g., ProfileScreen avatar pick)
    try {
      _remoteProfileSub?.cancel();
      final docRef = _firestore.collection('users').doc(user.uid);
      _remoteProfileSub = docRef.snapshots().listen((snap) {
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>?;
        if (data == null) return;
        final remoteProfile = (data['profile'] as Map<String, dynamic>?) ?? {};
        final remotePic = remoteProfile['profilePic'] ?? data['profilePic'] ?? '';
        if (remotePic != null && remotePic is String) {
          // don't overwrite a locally-picked avatar file preview
          if (_avatar == null && remotePic.isNotEmpty) {
            setState(() => profilePicUrl = remotePic);
            // also merge into original snapshot so putIfChanged sees the remote value
            _originalProfile ??= {};
            _originalProfile!['profilePic'] = remotePic;
            if (_originalProfile!['profile'] is! Map) _originalProfile!['profile'] = {};
            if (_originalProfile!['profile'] is Map) {
              final p = Map<String, dynamic>.from(_originalProfile!['profile'] as Map);
              p['profilePic'] = remotePic;
              _originalProfile!['profile'] = p;
            }
          }
        }
      }, onError: (e) {
        debugPrint('EditProfile: remote profile listen error: $e');
      });
    } catch (e) {
      debugPrint('EditProfile: subscribe remote profile failed: $e');
    }
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text('Sửa hồ sơ', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            /// Avatar
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: _avatar != null
                      ? FileImage(_avatar!)
                      : (profilePicUrl != null && profilePicUrl!.isNotEmpty
                          ? NetworkImage(profilePicUrl!)
                          : NetworkImage('https://i.pravatar.cc/300')) as ImageProvider,
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.black.withAlpha((0.25 * 255).round()),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _pickAvatar,
                      customBorder: const CircleBorder(),
                      child: const Icon(Icons.camera_alt, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            TextButton(onPressed: _pickAvatar, child: const Text('Edit avatar')),

            const SizedBox(height: 16),

            _Section(children: [

              _Item(
                label: 'Name',
                value: name,
                onTap: () => _editField(
                  title: 'Name',
                  initialValue: name,
                  onSave: (v) => setState(() => name = v),
                ),
              ),
              _Item(
                label: 'Username',
                value: username,
                onTap: () => _editField(
                  title: 'Username',
                  initialValue: username,
                  onSave: (v) => setState(() => username = v),
                ),
              ),
            ]),

            const SizedBox(height: 16),

  const SizedBox(height: 12),
            _Section(title: 'Your information', children: [
              _Item(
                // Bio item removed
                label: 'Weight',
                value: weightKg != null ? '${weightKg!.toStringAsFixed(1)} kg' : '—',
                onTap: () => _editField(
                  title: 'Weight (kg)',
                  initialValue: weightKg?.toString() ?? '',
                  onSave: (v) => setState(() {
                    final n = double.tryParse(v.replaceAll(',', '.'));
                    if (n != null) weightKg = n;
                  }),
                ),
              ),
              _Item(
                label: 'Age',
                value: age != null ? age.toString() : '—',
                onTap: () => _editField(
                  title: 'Age',
                  initialValue: age?.toString() ?? '',
                  onSave: (v) => setState(() {
                    final n = int.tryParse(v);
                    if (n != null) age = n;
                  }),
                ),
              ),
              _Item(
                label: 'Gender',
                value: gender ?? '—',
                onTap: () => _editField(
                  title: 'Gender',
                  initialValue: gender ?? '',
                  onSave: (v) => setState(() => gender = v),
                ),
              ),
              _Item(
                label: 'Height',
                value: heightCm != null ? '${heightCm!.toStringAsFixed(0)} cm' : '—',
                onTap: () => _editField(
                  title: 'Height (cm)',
                  initialValue: heightCm?.toString() ?? '',
                  onSave: (v) => setState(() {
                    final n = double.tryParse(v.replaceAll(',', '.'));
                    if (n != null) heightCm = n;
                  }),
                ),
              ),
              _Item(
                label: 'Goal',
                value: goal,
                onTap: () => _editField(
                  title: 'Goal',
                  initialValue: goal,
                  onSave: (v) => setState(() => goal = v),
                ),
              ),
                  _Item(
                    label: 'Daily water',
                    value: dailyWaterMl != null ? '${dailyWaterMl} ml' : '—',
                    onTap: () => _editField(
                      title: 'Daily water (ml)',
                      initialValue: dailyWaterMl?.toString() ?? '',
                      onSave: (v) => setState(() {
                        final n = int.tryParse(v.replaceAll(',', ''));
                        if (n != null) dailyWaterMl = n;
                      }),
                    ),
                  ),
                  _Item(
                    label: 'Drinking times',
                    value: (drinkingTimes != null && drinkingTimes!.isNotEmpty) ? drinkingTimes!.join(', ') : '—',
                    onTap: () async {
                      // quick inline editor that accepts comma-separated times
                      await _editField(
                        title: 'Drinking times (comma separated, e.g. 08:00,12:00)',
                        initialValue: drinkingTimes?.join(',') ?? '',
                        onSave: (v) => setState(() {
                          final parts = v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                          drinkingTimes = parts.cast<String>();
                        }),
                      );
                    },
                  ),
                  _Item(
                    label: 'Deadline completed',
                    value: (deadlineCompleted ?? false) ? 'Yes' : 'No',
                    onTap: () => setState(() => deadlineCompleted = !(deadlineCompleted ?? false)),
                  ),
              _Item(
                label: 'Ideal weight',
                value: idealWeightKg != null ? '${idealWeightKg} kg' : '—',
                onTap: () => _editField(
                  title: 'Ideal weight (kg)',
                  initialValue: idealWeightKg?.toString() ?? '',
                  onSave: (v) => setState(() {
                    final n = int.tryParse(v);
                    if (n != null) idealWeightKg = n;
                  }),
                ),
              ),
              _Item(
                label: 'Deadline',
                value: deadline ?? '—',
                onTap: () => _editField(
                  title: 'Deadline',
                  initialValue: deadline ?? '',
                  onSave: (v) => setState(() => deadline = v),
                ),
              ),
              _Item(
                label: 'Training intensity',
                value: trainingIntensity ?? '—',
                onTap: () => _editField(
                  title: 'Training intensity',
                  initialValue: trainingIntensity ?? '',
                  onSave: (v) => setState(() => trainingIntensity = v),
                ),
              ),
              _Item(
                label: 'Diet plan',
                value: dietPlan ?? '—',
                onTap: () => _editField(
                  title: 'Diet plan',
                  initialValue: dietPlan ?? '',
                  onSave: (v) => setState(() => dietPlan = v),
                ),
              ),
              // Link removed
            ]),

            const SizedBox(height: 16),

            _Section(title: 'Contact', children: [
              _Item(
                label: 'Email',
                value: email,
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: email));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép email')));
                  },
                ),
                onTap: () => _editField(
                  title: 'Email',
                  initialValue: email,
                  onSave: (v) => setState(() => email = v),
                ),
              ),
              _Item(
                label: 'Phone',
                value: phone,
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: phone));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép số điện thoại')));
                  },
                ),
                onTap: () => _editField(
                  title: 'Phone',
                  initialValue: phone,
                  onSave: (v) => setState(() => phone = v),
                ),
              ),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : () async {
                await _saveProfile();
              },
              child: _loading
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 12),
                      Text('Đang lưu...', style: TextStyle(color: Colors.white)),
                    ])
                  : const Text('Save', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _Section({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(title!, style: TextStyle(color: Colors.grey.shade600)),
        ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(children: children),
      ),
    ]);
  }
}

class _Item extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;

  const _Item({
    required this.label,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
          trailing ?? const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}

// Backwards-compatible wrapper used by other parts of the app.
class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context) => const EditProfileScreen();
}
