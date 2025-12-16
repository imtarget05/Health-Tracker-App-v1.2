
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  File? _avatar;
  String name = 'Target';
  String username = 'imtarget05';
  String email = 'target@example.com';
  double? weightKg = 70.0;
  double? heightCm = 170.0;
  String goal = 'Maintain';
  String phone = '+84 900000000';
  String bio = 'Life';
  String? link;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAvatar() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _avatar = File(image.path);
      });
    }
  }

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
                      : const NetworkImage('https://i.pravatar.cc/300') as ImageProvider,
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

            _Section(title: 'Your information', children: [
              _Item(
                label: 'Bio',
                value: bio,
                onTap: () => _editField(
                  title: 'Bio',
                  initialValue: bio,
                  onSave: (v) => setState(() => bio = v),
                ),
              ),
              _Item(
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
                label: 'Link',
                value: link ?? 'Add link',
                trailing: link != null
                    ? IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: link!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã sao chép liên kết')),
                          );
                        },
                      )
                    : null,
                onTap: () => _editField(
                  title: 'Link',
                  initialValue: link ?? '',
                  onSave: (v) => setState(() => link = v),
                ),
              ),
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
