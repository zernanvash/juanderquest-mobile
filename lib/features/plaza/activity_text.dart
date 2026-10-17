import 'plaza_models.dart';

class FormattedActivity {
  final String sentence;
  final String? pointsBadge;
  final String? badgeIcon;

  const FormattedActivity({
    required this.sentence,
    this.pointsBadge,
    this.badgeIcon,
  });
}

FormattedActivity formatActivityText(ActivityItemModel activity) {
  final actor = activity.actorName;
  final subject = activity.subjectTitle.isNotEmpty ? activity.subjectTitle : 'a destination';
  final payload = activity.payload;

  switch (activity.verb) {
    case 'quest_completed':
      final pts = payload['points'] != null ? '+${payload['points']} pts' : null;
      return FormattedActivity(
        sentence: '$actor completed $subject',
        pointsBadge: pts,
      );
    case 'trail_completed':
      return FormattedActivity(sentence: '$actor finished the $subject trail');
    case 'town_completed':
      return FormattedActivity(sentence: '$actor completed every Eco-Quest in $subject 🎉');
    case 'badge_earned':
      final icon = payload['icon']?.toString() ?? '🏅';
      return FormattedActivity(
        sentence: '$actor earned the $subject badge $icon',
        badgeIcon: icon,
      );
    case 'level_up':
      final level = payload['level'] ?? 1;
      final title = payload['title'] != null ? ' · ${payload['title']}' : '';
      return FormattedActivity(sentence: '$actor reached Level $level$title');
    case 'streak_milestone':
      final rounds = payload['rounds'] ?? 4;
      return FormattedActivity(sentence: '$actor voted in $rounds JuanChoice rounds in a row 🔥');
    case 'rank_top10':
      final rank = payload['rank'] != null ? '(#${payload['rank']})' : 'top 10';
      return FormattedActivity(sentence: '$actor entered this week\'s top 10 $rank');
    case 'weekly_champion':
      final place = payload['place'] ?? 1;
      final week = payload['week_id'] ?? 'this week';
      if (place == 1) {
        return FormattedActivity(sentence: '$actor is the Weekly Champion of $week 🏆');
      }
      return FormattedActivity(sentence: '$actor finished #$place in $week');
    case 'spot_posted':
      return FormattedActivity(sentence: '$actor shared a new spot: $subject');
    case 'first_photo':
      return FormattedActivity(sentence: '$actor added the first photo of $subject 📸');
    case 'juanchoice_voted':
      return FormattedActivity(sentence: '$actor voted in JuanChoice');
    case 'quiz_aced':
      final score = payload['score'] ?? 5;
      final max = payload['max_score'] ?? 5;
      return FormattedActivity(sentence: '$actor aced the $subject quiz ($score/$max)');
    default:
      return FormattedActivity(sentence: '$actor explored $subject');
  }
}
