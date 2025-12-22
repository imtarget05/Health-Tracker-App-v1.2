 import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:best_flutter_ui_templates/services/event_bus.dart';

/// A lightweight toast overlay widget that listens to [EventBus.instance.stream]
/// and shows a small toast card anchored to the top-right (matches screenshot style).
class GlobalToast extends StatefulWidget {
  final Widget child;
  const GlobalToast({super.key, required this.child});

  @override
  State<GlobalToast> createState() => _GlobalToastState();
}

class _GlobalToastState extends State<GlobalToast> with TickerProviderStateMixin {
  StreamSubscription? _sub;
  AppEvent? _current;
  Timer? _timer;
  late final AnimationController _entranceController;
  late final Animation<Offset> _entranceOffset;
  late final AnimationController _progressController; // drives the 4s shrinking bar

  @override
  void initState() {
    super.initState();
    _sub = EventBus.instance.stream.listen(_onEvent);
    // Slide in from right and slightly from above, end on a small positive y to give a "drop" feel.
  _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  _entranceOffset = Tween<Offset>(begin: const Offset(0.9, -0.32), end: const Offset(0.0, 0.02)).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack));

  _progressController = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  }

  void _onEvent(AppEvent e) {
  // debug log so developers can see events arriving in DevTools/console when testing.
  // Guard with kDebugMode to avoid printing in production builds.
  // ignore: avoid_print
  if (kDebugMode) debugPrint('GlobalToast received event: ${e.type} -> ${e.message}');
    // Replace current toast immediately with new one
    _timer?.cancel();
    setState(() {
      _current = e;
    });
    // start entrance animation
    try {
      _entranceController.forward(from: 0.0);
    } catch (_) {}

    // start 4s progress
    _progressController.stop();
    _progressController.reset();
    _progressController.forward();

    _timer = Timer(const Duration(seconds: 4), () {
      setState(() {
        _current = null;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
  try { _entranceController.dispose(); } catch (_) {}
  try { _progressController.dispose(); } catch (_) {}
    super.dispose();
  }

  Color _colorFor(AppEventType t) {
    switch (t) {
      case AppEventType.success:
        return Colors.green[700]!;
      case AppEventType.error:
        return Colors.red[700]!;
      case AppEventType.warning:
        return Colors.orange[800]!;
      case AppEventType.info:
        return Colors.blueGrey[800]!;
    }
  // no-op: all AppEventType values handled above
  }

  IconData _iconFor(AppEventType t) {
    switch (t) {
      case AppEventType.success:
        return Icons.check_circle;
      case AppEventType.error:
        return Icons.error;
      case AppEventType.warning:
        return Icons.warning;
      case AppEventType.info:
        return Icons.info;
    }
  // no-op: all AppEventType values handled above
  }

  @override
  Widget build(BuildContext context) {
    // Use a non-directional Alignment so this widget does not require a
    // surrounding Directionality (the app's MaterialApp provides one below
    // but GlobalToast is mounted above it). This avoids the runtime error
    // about missing Directionality when the toast overlay is shown.
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        widget.child,
        // top-right anchored toast
        if (_current != null)
          Positioned(
            top: 24,
            right: 16,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildToast(context, _current!),
            ),
          ),
      ],
    );
  }

  Widget _buildToast(BuildContext context, AppEvent e) {
    final color = _colorFor(e.type);
    // Ensure Icon/Text inside the toast have an ambient text direction even
    // when GlobalToast is mounted above MaterialApp. Wrapping the toast
    // subtree with Directionality avoids multiple runtime exceptions seen
    // when the overlay shows before the app's WidgetsApp/MaterialApp provides
    // a Directionality.
    // Progress bar shrinks from right -> left as _progressController.value goes 0->1
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SlideTransition(
        position: _entranceOffset,
        child: Material(
          key: ValueKey(e.id),
          elevation: 6,
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((0.45 * 255).round()), // translucent background
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color, width: 3),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_iconFor(e.type), color: color),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        e.message,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        // dismiss early
                        _timer?.cancel();
                        _progressController.stop();
                        setState(() {
                          _current = null;
                        });
                      },
                      child: Icon(Icons.close, color: Colors.white70, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // shrinking progress bar anchored to right
                SizedBox(
                  height: 6,
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        final factor = 1.0 - _progressController.value.clamp(0.0, 1.0);
                        return FractionallySizedBox(
                          widthFactor: factor,
                          alignment: Alignment.centerRight,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.green.shade400,
                                  Colors.green.shade800,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
