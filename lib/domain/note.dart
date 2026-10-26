/// Supporting information left by the enduser.
class Note {
  /// Create supporting information from the enduser.
  const Note({this.id, required this.time, this.note, this.color});

  /// Stable storage identity; absent only for new or legacy imported records.
  final String? id;

  /// Timestamp when the note was taken.
  final DateTime time;

  /// Content of the note.
  final String? note;

  /// ARGB color in number format.
  final int? color;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          time == other.time &&
          note == other.note &&
          color == other.color;

  @override
  int get hashCode => Object.hash(time, note, color);
}
