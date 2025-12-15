import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _avatarCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _avatarCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
  // Validate form safely: avoid using `!` on currentState which may be null
  if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bạn chưa đăng nhập')));
      return;
    }

    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{};
      if (_nameCtrl.text.trim().isNotEmpty) data['profile.name'] = _nameCtrl.text.trim();
      if (_avatarCtrl.text.trim().isNotEmpty) data['profile.avatar'] = _avatarCtrl.text.trim();
      if (_weightCtrl.text.trim().isNotEmpty) data['profile.weight'] = double.tryParse(_weightCtrl.text.trim());
      if (_heightCtrl.text.trim().isNotEmpty) data['profile.height'] = double.tryParse(_heightCtrl.text.trim());
      data['lastUpdated'] = FieldValue.serverTimestamp();

      // Convert dotted keys into nested map for merge
      final Map<String, dynamic> payload = {};
      data.forEach((k, v) {
        if (k.contains('.')) {
          final parts = k.split('.');
          payload.putIfAbsent(parts[0], () => {});
          payload[parts[0]][parts[1]] = v;
        } else {
          payload[k] = v;
        }
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(payload, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, st) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi lưu: $e')));
      debugPrint('EditProfile save error: $e\n$st');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh hồ sơ')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Tên'),
                  validator: (v) => null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _avatarCtrl,
                  decoration: const InputDecoration(labelText: 'Avatar (URL)'),
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final uri = Uri.tryParse(v);
                      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return 'URL không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _weightCtrl,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cân nặng (kg)'),
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final n = double.tryParse(v);
                      if (n == null || n <= 0 || n > 500) return 'Cân nặng không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Chiều cao (cm)'),
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final n = double.tryParse(v);
                      if (n == null || n <= 0 || n > 300) return 'Chiều cao không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const CircularProgressIndicator.adaptive() : const Text('Lưu'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
