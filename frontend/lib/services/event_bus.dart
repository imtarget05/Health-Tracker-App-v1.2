import 'dart:async';

/// Simple application-wide event model for toasts and other global UI events.
enum AppEventType { success, error, info, warning }

class AppEvent {
  final String id;
  final AppEventType type;
  final String message;
  final Map<String, dynamic>? payload;

  AppEvent({
    required this.id,
    required this.type,
    required this.message,
    this.payload,
  });
}

/// A tiny event-bus singleton used across the app. Any layer may call
/// `EventBus.instance.emit*` to emit an event. The toast overlay listens to
/// `EventBus.instance.stream` and shows toasts automatically.
class EventBus {
  EventBus._internal();
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  static EventBus get instance => _instance;

  final StreamController<AppEvent> _ctrl = StreamController<AppEvent>.broadcast();
  Stream<AppEvent> get stream => _ctrl.stream;

  // Simple dedupe map to avoid spamming identical events within a short window
  final Map<String, DateTime> _recent = {};

  void emit(AppEvent e) {
    final key = '${e.type}:${e.message}';
    final now = DateTime.now();
    final last = _recent[key];
    if (last != null && now.difference(last).inSeconds < 3) {
      // suppress duplicates within 3 seconds
      return;
    }
    _recent[key] = now;
    // trim old entries occasionally
    if (_recent.length > 100) {
      final cutoff = now.subtract(const Duration(seconds: 30));
      _recent.removeWhere((_, v) => v.isBefore(cutoff));
    }
    _ctrl.add(e);
  }

  void emitSuccess(String message, {Map<String, dynamic>? payload, String? id}) {
    emit(AppEvent(id: id ?? DateTime.now().microsecondsSinceEpoch.toString(), type: AppEventType.success, message: message, payload: payload));
  }

  void emitError(String message, {Map<String, dynamic>? payload, String? id}) {
    // Emit the message exactly as provided. We previously sanitised noisy
    // platform error strings into a friendly message, but that made debugging
    // registration issues difficult; sanitizer was removed per project decision.
    emit(AppEvent(id: id ?? DateTime.now().microsecondsSinceEpoch.toString(), type: AppEventType.error, message: message, payload: payload));
  }

  // Basic heuristic sanitizer for common network-related error messages.
  // Keeps non-network messages unchanged.
  // Sanitizer removed — errors are emitted raw so callers can decide how to present them.

  void emitInfo(String message, {Map<String, dynamic>? payload, String? id}) {
    emit(AppEvent(id: id ?? DateTime.now().microsecondsSinceEpoch.toString(), type: AppEventType.info, message: message, payload: payload));
  }

  /// Emit a notification arrival event. Listeners may use this to insert
  /// the notification into visible lists (e.g. NotificationScreen).
  void emitNotification(Map<String, dynamic> notification, {String? id}) {
    emit(AppEvent(id: id ?? 'notification-${DateTime.now().microsecondsSinceEpoch}', type: AppEventType.info, message: 'new-notification', payload: notification));
  }

  /// Emit a lightweight profile-updated event so listeners (screens) can refresh.
  void emitProfileUpdated(Map<String, dynamic> payload, {String? id}) {
    emit(AppEvent(id: id ?? 'profile-${DateTime.now().microsecondsSinceEpoch}', type: AppEventType.info, message: 'profile-updated', payload: payload));
  }

  void dispose() {
    _ctrl.close();
  }
}
