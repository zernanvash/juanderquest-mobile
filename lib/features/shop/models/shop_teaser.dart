class ShopTeaser {
  const ShopTeaser({required this.id,required this.title,required this.description,required this.iconKey,this.etaText});
  final String id,title,description,iconKey; final String? etaText;
  factory ShopTeaser.fromJson(Map<String,dynamic> j)=>ShopTeaser(id:j['id']??'',title:j['title']??'',description:j['description']??'',iconKey:j['iconKey']??j['icon_key']??'sparkles',etaText:j['etaText']??j['eta_text']);
}
