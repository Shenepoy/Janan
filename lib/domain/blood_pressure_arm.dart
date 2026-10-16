/// Arm used for an individual blood pressure measurement.
enum BloodPressureArm {
  /// The cuff was used on the left arm.
  left,

  /// The cuff was used on the right arm.
  right,

  /// The user recorded that the arm is unknown.
  ///
  /// `null` is reserved for a reading where no arm has been set.
  unknown;

  /// Decode a stored value, leaving unrecognized legacy values unset.
  static BloodPressureArm? fromStorage(Object? value) => switch (value) {
    'left' => BloodPressureArm.left,
    'right' => BloodPressureArm.right,
    'unknown' => BloodPressureArm.unknown,
    _ => null,
  };
}

/// Where a blood pressure reading entered Janan.
enum BloodPressureRecordSource {
  /// Typed by the user.
  manual,

  /// Received from a Bluetooth blood pressure device.
  bluetooth,

  /// Imported from Health Connect.
  healthConnect,

  /// Imported from a file or another database.
  imported,

  /// Existing data whose source was not recorded.
  unknown;

  /// Decode a stored value, treating missing values as legacy data.
  static BloodPressureRecordSource fromStorage(Object? value) =>
      values.firstWhere(
        (source) => source.name == value,
        orElse: () => BloodPressureRecordSource.unknown,
      );

  /// Whether the home table can offer the inline side assignment control.
  bool get isBluetoothDevice => this == BloodPressureRecordSource.bluetooth;
}
