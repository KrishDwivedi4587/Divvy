import 'package:intl/intl.dart';

/// A short date for lists: "Today", "Yesterday", "14 Nov", or "14 Nov 2025"
/// once it is from a different year.
String friendlyDate(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat(date.year == now.year ? 'd MMM' : 'd MMM y').format(date);
}

/// A full date for detail screens: "14 November 2026".
String fullDate(DateTime date) => DateFormat('d MMMM y').format(date);

/// A greeting for the home screen from the hour of the day.
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Good evening';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "just now", "5 min ago", "3 h ago", or the date.
String timeAgo(DateTime at, DateTime now) {
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return friendlyDate(at, now);
}
