class Ride {
  final String? id;
  final String vehicleId;
  final String vehicleType; // Car, Bike, CNG
  final String vehicleModel;
  final String origin;
  final String destination;
  final DateTime departureTime;
  final int seatsTotal;
  final int seatsAvailable; // Initially same as seatsTotal
  final String genderPreference; // Male, Female, Both
  final double pricePerSeat;
  final bool instantMatch;

  Ride({
    this.id,
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
}