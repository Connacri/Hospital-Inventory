// lib/core/sync/base_repository.dart
// ══════════════════════════════════════════════════════════════════════════════
// BASE REPOSITORY — Pattern générique : local-first + émission sync events
// Toutes les lectures = ObjectBox. Toutes les écritures = ObjectBox + SyncBus
// ══════════════════════════════════════════════════════════════════════════════

import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

import '../services/device_info_service.dart';
import '../sync/sync_engine.dart';

abstract class BaseRepository<T> {
  final Box<T> box;
  final String tableName;

  static const _uuid = Uuid();

  BaseRepository({required this.box, required this.tableName});

  // ── Méthodes abstraites à implémenter par chaque repository ──
  String getUuid(T entity);
  void setUuid(T entity, String uuid);
  void setCreatedAt(T entity, DateTime dt);
  void setUpdatedAt(T entity, DateTime dt);
  void setSyncStatus(T entity, String status);
  void setDeviceId(T entity, String deviceId);
  void markDeleted(T entity);
  String getSyncStatus(T entity);
  DateTime getUpdatedAt(T entity);
  Map<String, dynamic> toMap(T entity);

  // ── WRITE : Local first → puis événement sync ──

  Future<T> insert(T entity) async {
    if (getUuid(entity).isEmpty) {
      setUuid(entity, _uuid.v4());
    }
    final now = DateTime.now();
    setCreatedAt(entity, now);
    setUpdatedAt(entity, now);
    setSyncStatus(entity, 'synced');
    setDeviceId(entity, DeviceInfoService.id);

    box.put(entity);
    _emitEvent(entity, CrudOperation.insert);
    return entity;
  }

  Future<T> update(T entity) async {
    setUpdatedAt(entity, DateTime.now());
    setSyncStatus(entity, 'synced');
    setDeviceId(entity, DeviceInfoService.id);

    box.put(entity);
    _emitEvent(entity, CrudOperation.update);
    return entity;
  }

  Future<void> delete(String uuid) async {
    final entity = getByUuid(uuid);
    if (entity == null) return;

    markDeleted(entity);
    setUpdatedAt(entity, DateTime.now());
    setSyncStatus(entity, 'synced');
    setDeviceId(entity, DeviceInfoService.id);

    box.put(entity);
    _emitEvent(entity, CrudOperation.delete);
  }

  // ── READ : 100% ObjectBox ──

  T? getByUuid(String uuid);

  List<T> getAll() {
    return box.getAll();
  }

  // ── Émettre événement vers SyncWorker ──
  void _emitEvent(T entity, CrudOperation op) {
    SyncEventBus.instance.emit(
      SyncEvent(
        tableName: tableName,
        recordUuid: getUuid(entity),
        operation: op,
        payload: toMap(entity),
      ),
    );
  }
}
