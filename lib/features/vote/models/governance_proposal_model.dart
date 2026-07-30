class GovernanceProposalModel {
  final String id;
  final String title;
  final String locationName;
  final String category;
  final String description;
  final String status;
  final String submittedById;
  final String submittedByName;
  final int yesVotes;
  final int noVotes;
  final int yesWeightMjdq;
  final int noWeightMjdq;
  final int totalVoters;
  final int bondMjdq;
  final int escrowedMjdq;
  final String? votingEndsAt;

  GovernanceProposalModel({
    required this.id,
    required this.title,
    required this.locationName,
    required this.category,
    required this.description,
    required this.status,
    required this.submittedById,
    required this.submittedByName,
    required this.yesVotes,
    required this.noVotes,
    required this.yesWeightMjdq,
    required this.noWeightMjdq,
    required this.totalVoters,
    required this.bondMjdq,
    required this.escrowedMjdq,
    this.votingEndsAt,
  });

  factory GovernanceProposalModel.fromJson(Map<String, dynamic> json) {
    return GovernanceProposalModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      locationName: json['location_name'] as String? ?? json['location'] as String? ?? '',
      category: json['category'] as String? ?? 'eco',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'voting',
      submittedById: json['submitted_by_id'] as String? ?? '',
      submittedByName: json['submitted_by_name'] as String? ?? 'Community Member',
      yesVotes: (json['yes_votes'] as num?)?.toInt() ?? (json['votes'] as num?)?.toInt() ?? 0,
      noVotes: (json['no_votes'] as num?)?.toInt() ?? 0,
      yesWeightMjdq: (json['yes_weight_mjdq'] as num?)?.toInt() ?? 0,
      noWeightMjdq: (json['no_weight_mjdq'] as num?)?.toInt() ?? 0,
      totalVoters: (json['total_voters'] as num?)?.toInt() ?? 0,
      bondMjdq: (json['bond_mjdq'] as num?)?.toInt() ?? 0,
      escrowedMjdq: (json['escrowed_mjdq'] as num?)?.toInt() ?? 0,
      votingEndsAt: json['voting_ends_at'] as String?,
    );
  }

  int get totalVotes => yesVotes + noVotes;

  double get yesPercentage {
    if (totalVotes == 0) return 0.0;
    return (yesVotes / totalVotes) * 100.0;
  }

  double get noPercentage {
    if (totalVotes == 0) return 0.0;
    return (noVotes / totalVotes) * 100.0;
  }

  String get categoryDisplay {
    switch (category.toLowerCase()) {
      case 'eco':
      case 'eco-tourism':
        return 'ECO-TOURISM';
      case 'cultural':
      case 'heritage':
        return 'CULTURAL HERITAGE';
      case 'food_trade':
      case 'food & dining':
        return 'FOOD & CULINARY';
      default:
        return category.toUpperCase();
    }
  }
}
