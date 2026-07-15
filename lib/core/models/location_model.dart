class LocationModel {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const LocationModel({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory LocationModel.fromPosition(double lat, double lng, DateTime ts) {
    return LocationModel(latitude: lat, longitude: lng, timestamp: ts);
  }
}
