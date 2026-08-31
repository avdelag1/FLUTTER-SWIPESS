class SubscriptionCountdownParts {
  const SubscriptionCountdownParts({
    required this.months,
    required this.days,
    required this.hours,
    required this.expired,
  });

  final int months;
  final int days;
  final int hours;
  final bool expired;

  String get compactLabel {
    if (expired) return 'ENDED';
    return '$months MO · $days D · $hours HR';
  }

  String get sentenceLabel {
    if (expired) return 'Your access window has ended.';
    final monthPart = months == 1 ? '1 month' : '$months months';
    final dayPart = days == 1 ? '1 day' : '$days days';
    final hourPart = hours == 1 ? '1 hour' : '$hours hours';
    return '$monthPart, $dayPart, $hourPart remaining';
  }
}

SubscriptionCountdownParts subscriptionCountdownParts(DateTime? endsAt) {
  if (endsAt == null) {
    return const SubscriptionCountdownParts(
      months: 0,
      days: 0,
      hours: 0,
      expired: true,
    );
  }

  final now = DateTime.now().toUtc();
  final end = endsAt.toUtc();
  if (!end.isAfter(now)) {
    return const SubscriptionCountdownParts(
      months: 0,
      days: 0,
      hours: 0,
      expired: true,
    );
  }

  var cursor = DateTime.utc(now.year, now.month, now.day, now.hour);
  var months = 0;
  while (months < 120) {
    final nextMonth = DateTime.utc(cursor.year, cursor.month + 1, cursor.day, cursor.hour);
    if (!nextMonth.isBefore(end)) break;
    months++;
    cursor = nextMonth;
  }

  final remaining = end.difference(cursor);
  return SubscriptionCountdownParts(
    months: months,
    days: remaining.inDays,
    hours: remaining.inHours.remainder(24),
    expired: false,
  );
}
