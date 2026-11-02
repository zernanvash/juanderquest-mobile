import '../../core/pixel/pixel_art.dart';

sealed class Celebration {
  const Celebration();
}

class QuestComplete extends Celebration {
  const QuestComplete({required this.questTitle, required this.reward});

  final String questTitle;
  final int reward; // mJDQ
}

class LevelUp extends Celebration {
  const LevelUp({required this.fromLevel, required this.toLevel});

  final int fromLevel;
  final int toLevel;
}

class StampEarned extends Celebration {
  const StampEarned({required this.stampName, required this.stamp});

  final String stampName;
  final PixelArt stamp;
}
