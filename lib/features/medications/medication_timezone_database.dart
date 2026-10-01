import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

/// Initializes the IANA database used by local medication reminders.
void initializeMedicationTimezoneDatabase() {
  timezone_data.initializeTimeZones();
}

/// Resolves an Android timezone identifier for scheduled reminders.
timezone.Location medicationTimezone(String identifier) =>
    timezone.getLocation(identifier);
