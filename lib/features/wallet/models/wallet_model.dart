class WalletModel {
  final String settlement;
  final String unit;
  final int balanceMjdq;
  final double balanceJdq;

  WalletModel({
    required this.settlement,
    required this.unit,
    required this.balanceMjdq,
    required this.balanceJdq,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      settlement: json['settlement'] as String? ?? 'off-chain prototype',
      unit: json['unit'] as String? ?? 'mJDQ',
      balanceMjdq: (json['balance_mjdq'] as num?)?.toInt() ?? 0,
      balanceJdq: (json['balance_jdq'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get formattedJdq => '${balanceJdq.toStringAsFixed(2)} JDQ';
  String get formattedMjdq => '$balanceMjdq mJDQ';
}
