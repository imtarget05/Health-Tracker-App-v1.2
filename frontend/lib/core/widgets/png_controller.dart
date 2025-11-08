import 'package:flutter/material.dart';

/// Một "controller" giả lập thay thế cho RiveController cũ.
/// Dùng để hiển thị hình tĩnh thay cho animation.
class PngControllerHelper {
  static final PngControllerHelper _instance = PngControllerHelper._internal();

  factory PngControllerHelper() => _instance;

  PngControllerHelper._internal();

  /// Ảnh hiển thị (mặc định là doctor.png)
  Image? _pngImage;

  /// Gọi hàm này để preload ảnh trước khi dùng (giống preload Rive)
  Future<void> preloadPngFile(String assetPath) async {
    _pngImage = Image.asset(assetPath, fit: BoxFit.contain);
    debugPrint("✅ PNG preloaded: $assetPath");
  }

  /// Lấy widget ảnh (thay cho artboard Rive)
  Widget getImageWidget({double? height}) {
    if (_pngImage == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: height ?? 180,
      child: _pngImage,
    );
  }

  /// Giải phóng nếu cần
  void dispose() {
    _pngImage = null;
  }
}
