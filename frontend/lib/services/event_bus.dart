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

  void emit(AppEvent e) => _ctrl.add(e);

  void emitSuccess(String message, {Map<String, dynamic>? payload, String? id}) {
    emit(AppEvent(id: id ?? DateTime.now().microsecondsSinceEpoch.toString(), type: AppEventType.success, message: message, payload: payload));
  }

  void emitError(String message, {Map<String, dynamic>? payload, String? id}) {
    emit(AppEvent(id: id ?? DateTime.now().microsecondsSinceEpoch.toString(), type: AppEventType.error, message: message, payload: payload));
  }

  void emitInfo(String message, {Map<String, dynamic>? payload, String? id}) {
    emit(AppEvent(id: id ?? DateTime.now().microsecondsSinceEpoch.toString(), type: AppEventType.info, message: message, payload: payload));
  }

  void dispose() {
    _ctrl.close();
  }
}
