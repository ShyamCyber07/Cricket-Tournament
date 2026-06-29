import 'dart:async';

class AppEventBus {
  static final AppEventBus _instance = AppEventBus._internal();
  factory AppEventBus() => _instance;
  AppEventBus._internal();

  final _streamController = StreamController<AppEvent>.broadcast();

  Stream<AppEvent> get on => _streamController.stream;

  void fire(AppEvent event) {
    _streamController.add(event);
  }
}

abstract class AppEvent {}

class NotificationRefreshedEvent extends AppEvent {}
class TeamRefreshedEvent extends AppEvent {}
