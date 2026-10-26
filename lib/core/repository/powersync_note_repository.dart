import 'dart:async';

import 'package:blood_pressure_app/core/database/health_write.dart';
import 'package:blood_pressure_app/core/repository/observe_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:uuid/uuid.dart';

/// PowerSync implementation of [NoteRepository].
class PowerSyncNoteRepository extends NoteRepository {
  PowerSyncNoteRepository(this._db);

  final SqliteWriteContext _db;
  final _uuid = const Uuid();
  final _controller = StreamController<Note?>.broadcast();

  @override
  Future<void> add(Note note) async {
    if (note.note == null && note.color == null) {
      assert(false, 'Attempting to store a note without content and color');
      return;
    }
    await writeHealthTransaction(_db, (tx) async {
      final timeSec = note.time.secondsSinceEpoch;
      final existing = await tx.getAll(
        note.id == null
            ? 'SELECT id FROM notes WHERE timestamp_unix_s = ?'
            : 'SELECT id FROM notes WHERE id = ?',
        [note.id ?? timeSec],
      );
      if (existing.isEmpty) {
        await tx.execute(
          'INSERT INTO notes (id, timestamp_unix_s, note, color) VALUES (?, ?, ?, ?)',
          [note.id ?? _uuid.v4(), timeSec, note.note, note.color],
        );
      } else {
        await tx.execute(
          'UPDATE notes SET note = ?, color = ?, timestamp_unix_s = ? WHERE id = ?',
          [note.note, note.color, timeSec, existing.first['id']],
        );
      }
    });
    _controller.add(note);
  }

  @override
  Future<List<Note>> get(DateRange range) async {
    final result = await _db.getAll(
      'SELECT id, timestamp_unix_s, note, color FROM notes '
      'WHERE timestamp_unix_s BETWEEN ? AND ? '
      'AND (note IS NOT NULL OR color IS NOT NULL)',
      [range.startStamp, range.endStamp],
    );
    return [
      for (final row in result)
        Note(
          id: row['id'] as String,
          time: DateTimeS.fromSecondsSinceEpoch(row['timestamp_unix_s'] as int),
          note: row['note'] as String?,
          color: _decodeInt(row['color']),
        ),
    ];
  }

  @override
  Future<void> remove(Note value) async {
    await writeHealthTransaction(_db, (tx) async {
      await tx.execute(
        value.id == null
            ? 'DELETE FROM notes WHERE timestamp_unix_s = ?'
            : 'DELETE FROM notes WHERE id = ?',
        [value.id ?? value.time.secondsSinceEpoch],
      );
    });
    _controller.add(null);
  }

  /// Publishes a committed write performed by the entry transaction coordinator.
  void notifyExternalWrite() => _controller.add(null);

  @override
  Stream<Note?> subscribe() =>
      observeRepository(_db, 'notes', _controller.stream);

  int? _decodeInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
