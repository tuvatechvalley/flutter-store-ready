import 'package:material_ui/material_ui.dart';

/// Locale-aware date formatting through the Material localizations that are
/// already loaded (no extra dependency).
String formatDate(BuildContext context, DateTime date) {
  final local = date.toLocal();
  final m = MaterialLocalizations.of(context);
  return '${m.formatMediumDate(local)} '
      '${m.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}
