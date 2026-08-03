class GovernanceConfigModel {
  final int voteFeeMjdq;
  final int burnBps;
  final int escrowBps;
  final int organizerBondMjdq;
  final int quorumBps;

  GovernanceConfigModel({
    required this.voteFeeMjdq,
    required this.burnBps,
    required this.escrowBps,
    required this.organizerBondMjdq,
    required this.quorumBps,
  });

  factory GovernanceConfigModel.fromJson(Map<String, dynamic> json) {
    return GovernanceConfigModel(
      voteFeeMjdq: (json['vote_fee_mjdq'] as num?)?.toInt() ?? 10,
      burnBps: (json['burn_bps'] as num?)?.toInt() ?? 2000,
      escrowBps: (json['escrow_bps'] as num?)?.toInt() ?? 8000,
      organizerBondMjdq: (json['organizer_bond_mjdq'] as num?)?.toInt() ?? 25000,
      quorumBps: (json['quorum_bps'] as num?)?.toInt() ?? 1500,
    );
  }

  double get voteFeeJdq => voteFeeMjdq / 1000.0;
  double get burnPercent => burnBps / 100.0;
  double get escrowPercent => escrowBps / 100.0;
}
