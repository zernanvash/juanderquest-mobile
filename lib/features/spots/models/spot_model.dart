class SpotModel {
  final String id, slug, name, description, category, subcategory, municipality, address, sourceName, trustLevel;
  final double gpsLat, gpsLng;
  final double? distanceKm;
  final String? questId;
  final List<String> tags, reasons;
  const SpotModel({required this.id,required this.slug,required this.name,required this.description,required this.category,required this.subcategory,required this.municipality,required this.address,required this.sourceName,required this.trustLevel,required this.gpsLat,required this.gpsLng,required this.tags,required this.reasons,this.distanceKm,this.questId});
  factory SpotModel.fromJson(Map<String,dynamic> j)=>SpotModel(id:j['id']??'',slug:j['slug']??'',name:j['name']??'',description:j['description']??'',category:j['category']??'',subcategory:j['subcategory']??'',municipality:j['municipality']??'',address:j['address']??'',sourceName:j['source_name']??'',trustLevel:j['trust_level']??'',gpsLat:(j['gps_lat']as num?)?.toDouble()??0,gpsLng:(j['gps_lng']as num?)?.toDouble()??0,distanceKm:(j['distance_km']as num?)?.toDouble(),questId:j['quest_id'],tags:List<String>.from(j['tags']??[]),reasons:List<String>.from(j['recommendation_reasons']??[]));
}
