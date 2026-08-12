import 'dart:core';

/// Utilitaires pour le formatage des dates
class DateUtils {
  /// Formate une date en format court (jj/mm/aaaa)
  static String formatDateShort(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
           '${date.month.toString().padLeft(2, '0')}/'
           '${date.year}';
  }

  /// Formate une date avec l'heure (jj/mm/aaaa hh:mm)
  static String formatDateWithTime(DateTime date) {
    return '${formatDateShort(date)} '
           '${date.hour.toString().padLeft(2, '0')}:'
           '${date.minute.toString().padLeft(2, '0')}';
  }

  /// Formate une date en format relatif (ex: "Il y a 2 heures")
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) return 'Hier';
      if (difference.inDays < 7) return 'Il y a ${difference.inDays} jours';
      return formatDateShort(date);
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} min';
    } else {
      return 'À l\'instant';
    }
  }

  /// Vérifie si une date est aujourd'hui
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day && 
           date.month == now.month && 
           date.year == now.year;
  }

  /// Vérifie si une date est hier
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.day == yesterday.day && 
           date.month == yesterday.month && 
           date.year == yesterday.year;
  }
}
