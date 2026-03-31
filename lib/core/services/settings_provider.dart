import 'package:flutter/material.dart';
import '../objectbox/entities.dart';
import '../objectbox/objectbox_store.dart';

class SettingsProvider extends ChangeNotifier {
  final _store = ObjectBoxStore.instance;
  AppSettingsEntity? _settings;

  AppSettingsEntity get settings {
    if (_settings == null) {
      final all = _store.appSettings.getAll();
      _settings = all.isNotEmpty ? all.first : AppSettingsEntity();
    }
    return _settings!;
  }

  bool get isProvisioned => settings.isProvisioned;

  Future<void> setProvisioned(bool value, {String? by}) async {
    final s = settings;
    s.isProvisioned = value;
    if (by != null) s.provisionedBy = by;
    s.updatedAt = DateTime.now();
    _store.appSettings.put(s);
    _settings = s;
    notifyListeners();
  }

  void refresh() {
    _settings = null;
    notifyListeners();
  }
}
