// lib/core/widgets/progress_indicator_helper.dart
import 'package:flutter/material.dart';
import '../../theming/colors.dart';

class ProgressDialogHelper {
  /// API mới khuyên dùng
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: LoadingImage()),
    );
  }

  /// Giữ tương thích với những chỗ đang gọi tên cũ
  static Future<void> showProgressIndicator(BuildContext context) {
    return show(context);
  }
}

/// Adapter giữ tương thích ngược với code cũ:
/// ProgressIndicaror.showProgressIndicator(context)
class ProgressIndicaror {
  static Future<void> showProgressIndicator(BuildContext context) {
    return ProgressDialogHelper.show(context);
  }
}

/// Hình loading tuỳ chọn; fallback CircularProgressIndicator nếu thiếu asset
class LoadingImage extends StatelessWidget {
  const LoadingImage({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/loading.gif',
      width: 80,
      height: 80,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return const CircularProgressIndicator(
          color: ColorsManager.mainBlue,
        );
      },
    );
  }
}
