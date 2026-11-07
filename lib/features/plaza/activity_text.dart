import 'plaza_models.dart';

String humanizeSlug(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  final withSpaces = trimmed.replaceAll(RegExp(r'[_]+'), ' ').trim();
  if (withSpaces.isEmpty) return '';
  return withSpaces.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((word) {
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

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
  final rawSubject = activity.subjectTitle.isNotEmpty ? activity.subjectTitle : 'a destination';
  final subject = humanizeSlug(rawSubject);
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
      final rawIcon = payload['icon']?.toString() ?? '🏅';
      final icon = humanizeSlug(rawIcon);
      return FormattedActivity(
        sentence: '$actor earned the $subject badge $icon',
        badgeIcon: icon,
      );
    case 'level_up':
      final level = payload['level'] ?? 1;
      final rawTitle = payload['title']?.toString();
      final title = rawTitle != null ? ' · ${humanizeSlug(rawTitle)}' : '';
      return FormattedActivity(sentence: '$actor reached Level $level$title');
    case 'streak_milestone':
      final rounds = payload['rounds'] ?? 4;
      return FormattedActivity(sentence: '$actor voted in $rounds JuanChoice rounds in a row 🔥');
    case 'rank_top10':
      final rank = payload['rank'] != null ? '(#${payload['rank']})' : 'top 10';
      return FormattedActivity(sentence: '$actor entered this week\'s top 10 $rank');
    case 'weekly_champion':
      final place = payload['place'] ?? 1;
      final rawWeek = payload['week_id']?.toString() ?? 'this week';
      final week = humanizeSlug(rawWeek);
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
