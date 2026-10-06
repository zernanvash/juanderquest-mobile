class UserModel {
  final String id;
  final String seedId;
  final String displayName;
  final String email;
  final String avatarUrl;
  final String role;
  final int demoPoints;
  final String? walletAddress;
  final int mjdqBalance;
  final int jdqGovernanceBalance;
  final int scoutReputation;

  UserModel({
    required this.id,
    required this.seedId,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.role,
    required this.demoPoints,
    this.walletAddress,
    this.mjdqBalance = 0,
    this.jdqGovernanceBalance = 0,
    this.scoutReputation = 0,
  });

  int get points => demoPoints;
  String get handle => seedId.isNotEmpty ? '@$seedId' : '@${id.substring(0, id.length > 8 ? 8 : id.length)}';
  bool get hasBoundWallet => walletAddress != null && walletAddress!.trim().isNotEmpty;
  String? get formattedWalletAddress {
    if (walletAddress == null || walletAddress!.trim().isEmpty) return null;
    final clean = walletAddress!.trim();
    if (clean.length < 10) return clean;
    return '${clean.substring(0, 6)}...${clean.substring(clean.length - 4)}';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final demoPointsVal = (json['demo_points'] as num?)?.toInt() ?? 0;
    return UserModel(
      id: json['id'] ?? '',
      seedId: json['seed_id'] ?? '',
      displayName: json['display_name'] ?? 'Traveler',
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      role: json['role'] ?? 'user',
      demoPoints: demoPointsVal,
      walletAddress: json['wallet_address'] as String?,
      mjdqBalance: (json['mjdq_balance'] as num?)?.toInt() ?? (demoPointsVal * 1000),
      jdqGovernanceBalance: (json['jdq_governance_balance'] as num?)?.toInt() ?? 0,
      scoutReputation: (json['scout_reputation'] as num?)?.toInt() ?? 0,
    );
  }

  UserModel copyWith({
    int? demoPoints,
    String? walletAddress,
    int? mjdqBalance,
    int? jdqGovernanceBalance,
    int? scoutReputation,
  }) {
    return UserModel(
      id: id,
      seedId: seedId,
      displayName: displayName,
      email: email,
      avatarUrl: avatarUrl,
      role: role,
      demoPoints: demoPoints ?? this.demoPoints,
      walletAddress: walletAddress ?? this.walletAddress,
      mjdqBalance: mjdqBalance ?? this.mjdqBalance,
      jdqGovernanceBalance: jdqGovernanceBalance ?? this.jdqGovernanceBalance,
      scoutReputation: scoutReputation ?? this.scoutReputation,
    );
  }
}
