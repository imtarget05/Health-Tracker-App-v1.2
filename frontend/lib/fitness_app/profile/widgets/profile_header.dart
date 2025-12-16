import 'package:flutter/material.dart';

import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';

class ProfileHeader extends StatefulWidget {
  final String? imageUrl;
  final String? name;
  final String? email;
  final double? weightKg;
  final double? heightCm;
  final DateTime? lastUpdated;
  final Animation<double> animation;
  final AnimationController animationController;
  final VoidCallback? onLogout;
  final VoidCallback? onEdit;
  final VoidCallback? onPickAvatar;

  const ProfileHeader({
    super.key,
    this.imageUrl,
    this.name,
    this.email,
    this.weightKg,
    this.heightCm,
    this.lastUpdated,
    required this.animation,
    required this.animationController,
  this.onLogout,
  this.onEdit,
  this.onPickAvatar,
  });

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  bool _useImperial = false;

  String _formatWeight() {
    if (widget.weightKg == null) return '—';
    final kg = widget.weightKg!;
    if (!_useImperial) return '${kg.toStringAsFixed(1)} kg';
    final lb = kg * 2.20462;
    return '${lb.toStringAsFixed(1)} lb';
  }

  String _formatHeight() {
    if (widget.heightCm == null) return '—';
    final cm = widget.heightCm!;
    if (!_useImperial) return '${cm.toStringAsFixed(0)} cm';
    final inches = cm / 2.54;
    final ft = inches ~/ 12;
    final inchRem = (inches % 12).round();
    return '${ft}ft ${inchRem}in';
  }

  String _formatLastUpdated() {
    if (widget.lastUpdated == null) return '';
    final now = DateTime.now();
    final diff = now.difference(widget.lastUpdated!);
    if (diff.inMinutes < 1) return 'Cập nhật: vừa xong';
    if (diff.inHours < 1) return 'Cập nhật: ${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return 'Cập nhật: ${diff.inHours} giờ trước';
    return 'Cập nhật: ${diff.inDays} ngày trước';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: widget.animation,
          child: Transform(
            transform: Matrix4.translationValues(0.0, 30 * (1.0 - widget.animation.value), 0.0),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FitnessAppTheme.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(0, 3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar / URL (constrained) with pick handler
                      GestureDetector(
                        onTap: widget.onPickAvatar,
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipOval(
                                child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                                    ? Image.network(
                                        widget.imageUrl!,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, obj, st) => Container(
                                          width: 72,
                                          height: 72,
                                          color: Colors.grey[300],
                                          child: Icon(Icons.person, size: 36),
                                        ),
                                      )
                                    : Container(
                                        width: 72,
                                        height: 72,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.person, size: 36),
                                      ),
                              ),
                              // If no avatar, show small + overlay
                              if (widget.imageUrl == null || widget.imageUrl!.isEmpty)
                                Positioned(
                                    child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha((0.9 * 255).round()),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add, size: 18, color: Colors.black54),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Name + Email (constrained to avoid overflow)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.name ?? 'Chưa có tên',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.email ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Edit and logout buttons + unit toggle (constrained so Row cannot overflow)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 20,
                              tooltip: 'Edit profile',
                              onPressed: widget.onEdit,
                              icon: const Icon(Icons.edit, color: Colors.black54),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 20,
                              tooltip: 'Logout',
                              onPressed: widget.onLogout,
                              icon: const Icon(Icons.logout, color: Colors.black54),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 20,
                              tooltip: _useImperial ? 'Imperial' : 'Metric',
                              onPressed: () => setState(() => _useImperial = !_useImperial),
                              icon: Icon(_useImperial ? Icons.straighten : Icons.height),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_formatWeight(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            const Text('Cân nặng', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_formatHeight(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            const Text('Chiều cao', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_formatLastUpdated(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            const Text('Cập nhật', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
