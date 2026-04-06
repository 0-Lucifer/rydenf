import 'package:cloud_firestore/cloud_firestore.dart';

enum VehicleType { car, bike, cng }

class Ride {
  final String? id;
  final String driverId;
  final String driverName;
  final String? rating;
  final String vehicleId;
  final VehicleType vehicleType;
  final String vehicleModel;
  final String origin;
  final String destination;
  final List<String> stops;
  final DateTime departureTime;
  final int seatsTotal;
  final int seatsAvailable;
  final String genderPreference;
  final double pricePerSeat;
  final bool instantMatch;
  final String status; // active, full, completed, cancelled
  final List<String> passengers; // accepted passenger UIDs
  final DateTime createdAt;

  // GPS coordinates (nullable for backward compat with existing rides)
  final double? originLat;
  final double? originLng;
  final double? destinationLat;
  final double? destinationLng;
  final double? distanceKm;
  final int? durationMinutes;
  final double? maxFare;

  // Live driver location (updated during in_progress rides)
  final double? driverLat;
  final double? driverLng;

  Ride({
    this.id,
    required this.driverId,
    this.driverName = '',
    this.rating,
    required this.vehicleId,
    required this.vehicleType,
    required this.vehicleModel,
    required this.origin,
    required this.destination,
    this.stops = const [],
    required this.departureTime,
    required this.seatsTotal,
    required this.seatsAvailable,
    this.genderPreference = 'Both',
    required this.pricePerSeat,
    this.instantMatch = false,
    this.status = 'active',
    this.passengers = const [],
    this.originLat,
    this.originLng,
    this.destinationLat,
    this.destinationLng,
    this.distanceKm,
    this.durationMinutes,
    this.maxFare,
    this.driverLat,
    this.driverLng,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Serialize to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'driverName': driverName,
      'rating': rating,
      'vehicleId': vehicleId,
      'vehicleType': vehicleType.name,
      'vehicleModel': vehicleModel,
      'origin': origin,
      'destination': destination,
      'stops': stops,
      'departureTime': Timestamp.fromDate(departureTime),
      'seatsTotal': seatsTotal,
      'seatsAvailable': seatsAvailable,
      'genderPreference': genderPreference,
      'pricePerSeat': pricePerSeat,
      'instantMatch': instantMatch,
      'status': status,
      'passengers': passengers,
      'createdAt': Timestamp.fromDate(createdAt),
      if (originLat != null) 'originLat': originLat,
      if (originLng != null) 'originLng': originLng,
      if (destinationLat != null) 'destinationLat': destinationLat,
      if (destinationLng != null) 'destinationLng': destinationLng,
      if (distanceKm != null) 'distanceKm': distanceKm,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (maxFare != null) 'maxFare': maxFare,
      if (driverLat != null) 'driverLat': driverLat,
      if (driverLng != null) 'driverLng': driverLng,
    };
  }

  // Deserialize from Firestore document
  factory Ride.fromMap(Map<String, dynamic> map, String docId) {
    return Ride(
      id: docId,
      driverId: map['driverId'] ?? '',
      driverName: map['driverName'] ?? '',
      rating: map['rating'],
      vehicleId: map['vehicleId'] ?? '',
      vehicleType: _stringToVehicleType(map['vehicleType'] ?? 'car'),
      vehicleModel: map['vehicleModel'] ?? '',
      origin: map['origin'] ?? '',
      destination: map['destination'] ?? '',
      stops: List<String>.from(map['stops'] ?? []),
      departureTime: (map['departureTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      seatsTotal: map['seatsTotal'] ?? 1,
      seatsAvailable: map['seatsAvailable'] ?? 1,
      genderPreference: map['genderPreference'] ?? 'Both',
      pricePerSeat: (map['pricePerSeat'] ?? 0).toDouble(),
      instantMatch: map['instantMatch'] ?? false,
      status: map['status'] ?? 'active',
      passengers: List<String>.from(map['passengers'] ?? []),
      originLat: (map['originLat'] as num?)?.toDouble(),
      originLng: (map['originLng'] as num?)?.toDouble(),
      destinationLat: (map['destinationLat'] as num?)?.toDouble(),
      destinationLng: (map['destinationLng'] as num?)?.toDouble(),
      distanceKm: (map['distanceKm'] as num?)?.toDouble(),
      durationMinutes: map['durationMinutes'] as int?,
      maxFare: (map['maxFare'] as num?)?.toDouble(),
      driverLat: (map['driverLat'] as num?)?.toDouble(),
      driverLng: (map['driverLng'] as num?)?.toDouble(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static VehicleType _stringToVehicleType(String type) {
    switch (type.toLowerCase()) {
      case 'bike':
        return VehicleType.bike;
      case 'cng':
        return VehicleType.cng;
      default:
        return VehicleType.car;
    }
  }

  /// Whether this ride has GPS coordinates.
  bool get hasCoordinates =>
      originLat != null && originLng != null && destinationLat != null && destinationLng != null;
}
