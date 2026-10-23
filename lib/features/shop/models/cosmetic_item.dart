class CosmeticItem {
  const CosmeticItem(
      {required this.id,
      required this.kind,
      required this.name,
      required this.rarity,
      required this.asset,
      required this.owned,
      required this.equipped,
      required this.buyable,
      this.description = '',
      this.pricePoints,
      this.priceTjdq,
      this.unlock,
      this.lockedReason});
  final String id, kind, name, rarity, description;
  final Map<String, dynamic> asset;
  final int? pricePoints, priceTjdq;
  final bool owned, equipped, buyable;
  final Map<String, dynamic>? unlock;
  final String? lockedReason;
  factory CosmeticItem.fromJson(Map<String, dynamic> j) => CosmeticItem(
      id: j['id'] ?? '',
      kind: j['kind'] ?? 'banner',
      name: j['name'] ?? 'Cosmetic',
      rarity: j['rarity'] ?? 'common',
      description: j['description'] ?? '',
      asset: Map<String, dynamic>.from(j['asset'] ?? {}),
      pricePoints: (j['pricePoints'] as num?)?.toInt(),
      priceTjdq: (j['priceTjdq'] as num?)?.toInt(),
      owned: j['owned'] == true,
      equipped: j['equipped'] == true,
      buyable: j['buyable'] == true,
      unlock:
          j['unlock'] == null ? null : Map<String, dynamic>.from(j['unlock']),
      lockedReason: j['lockedReason']);
}

class OwnedCosmetic {
  const OwnedCosmetic({required this.item, required this.source});
  final CosmeticItem item;
  final String source;
  factory OwnedCosmetic.fromJson(Map<String, dynamic> j) => OwnedCosmetic(
      item: CosmeticItem.fromJson({...j, 'owned': true}),
      source: j['source'] ?? 'purchase');
}
