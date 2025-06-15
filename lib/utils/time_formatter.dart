import 'package:intl/intl.dart';

/// Utility class for consistent time formatting across the app
/// All times are displayed in Philippines time zone (UTC+8) with 12-hour format
class TimeFormatter {
  // Philippines is UTC+8 
  static const int philippinesUtcOffset = 8;
  
  /// Converts UTC DateTime to Philippines time (UTC+8)
  static DateTime toPhilippineTime(DateTime utcDateTime) {
    return utcDateTime.add(Duration(hours: philippinesUtcOffset));
  }
  
  /// Format date and time for Philippines timezone in 12-hour format
  /// Example: "Dec 15, 2024 2:30:45 PM"
  static String formatDateTime(DateTime utcDateTime) {
    final philippineTime = toPhilippineTime(utcDateTime);
    return DateFormat('MMM dd, yyyy h:mm:ss a').format(philippineTime);
  }
  
  /// Format date only for Philippines timezone
  /// Example: "Dec 15, 2024"
  static String formatDate(DateTime utcDateTime) {
    final philippineTime = toPhilippineTime(utcDateTime);
    return DateFormat('MMM dd, yyyy').format(philippineTime);
  }
  
  /// Format time only in 12-hour format
  /// Example: "2:30:45 PM"
  static String formatTime(DateTime utcDateTime) {
    final philippineTime = toPhilippineTime(utcDateTime);
    return DateFormat('h:mm:ss a').format(philippineTime);
  }
  
  /// Format short time without seconds
  /// Example: "2:30 PM"
  static String formatShortTime(DateTime utcDateTime) {
    final philippineTime = toPhilippineTime(utcDateTime);
    return DateFormat('h:mm a').format(philippineTime);
  }
  
  /// Format compact date and time for list items
  /// Example: "Dec 15, 2:30 PM"
  static String formatCompactDateTime(DateTime utcDateTime) {
    final philippineTime = toPhilippineTime(utcDateTime);
    return DateFormat('MMM dd, h:mm a').format(philippineTime);
  }
  
  /// Format for device cards showing last seen time
  /// Example: "Dec 15, 2:30 PM"
  static String formatLastSeen(DateTime utcDateTime) {
    final philippineTime = toPhilippineTime(utcDateTime);
    return DateFormat('MMM dd, h:mm a').format(philippineTime);
  }
  
  /// Get current Philippines time
  static DateTime getCurrentPhilippineTime() {
    return toPhilippineTime(DateTime.now().toUtc());
  }
  
  /// Get time ago string (relative time) - updates in real-time
  static String getTimeAgo(DateTime utcDateTime) {
    final now = DateTime.now().toUtc();
    final difference = now.difference(utcDateTime);

    if (difference.inSeconds < 30) {
      return 'Just now';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
} 