class DailyQuest {
  const DailyQuest({
    required this.id,
    required this.title,
    required this.goal,
    required this.progress,
    required this.points,
    required this.claimed,
  });

  final String id;
  final String title;
  final int goal;
  final int progress;
  final int points;
  final bool claimed;

  bool get completed => progress >= goal;

  factory DailyQuest.fromJson(Map<String, dynamic> json) {
    return DailyQuest(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Quest',
      goal: _asInt(json['goal'], 1),
      progress: _asInt(json['progress'], 0),
      points: _asInt(json['points'], 0),
      claimed: json['claimed'] == true || json['claimed'] == 'true',
    );
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class DailyQuestBoard {
  const DailyQuestBoard({this.quests = const [], this.points = 0});

  final List<DailyQuest> quests;
  final int points;

  /// One shared reward meter: five steps unlock one spendable Direct Request.
  /// Active foreground time adds one step every 45 minutes; completed quests
  /// can also contribute to this same progress meter.
  static const pointsNeeded = 5;

  double get progressPercent => (points / pointsNeeded).clamp(0, 1).toDouble();
}
