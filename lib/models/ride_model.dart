enum VehicleType { car, bike, cng }

class Ride {
  final String? id;
  final String? driverName;
  final String? rating;
  final String vehicleId;
  final VehicleType vehicleType;
  final String vehicleModel;
  final String origin;
  final String destination;
  final DateTime departureTime;
  final int seatsTotal;
  final int seatsAvailable;
  final String genderPreference; // Male, Female, Both
  final double pricePerSeat;
  final bool instantMatch;

  Ride({
    this.id,
    this.driverName,
    this.rating,
    required this.vehicleId,
    required this.vehicleType,
    required this.vehicleModel,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.seatsTotal,
    required this.seatsAvailable,
    this.genderPreference = 'Both',
    required this.pricePerSeat,
    this.instantMatch = false,
  });

  // Helper to convert from JSON or Map safely
  static VehicleType stringToVehicleType(String type) {
    switch (type.toLowerCase()) {
      case 'bike': return VehicleType.bike;
      case 'cng': return VehicleType.cng;
      default: return VehicleType.car;
    }
  }
}
