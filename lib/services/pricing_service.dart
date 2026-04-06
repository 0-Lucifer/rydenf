import '../models/ride_model.dart';

/// Centralized pricing logic for Ryden rides.
/// Single flat rate applied to the entire distance based on which bracket
/// the total km falls into. The minimum fare acts as a floor.
class PricingService {
  PricingService._();

  static const double minimumFare = 50.0;
  static const double fallbackMaxFare = 250.0;

  /// Calculate the maximum fare for a ride based on distance and vehicle type.
  ///
  /// Cars / CNG (per seat):
  ///   ≤ 7 km  →  ৳10/km × total km
  ///   > 7 km  →  ৳7/km  × total km
  ///
  /// Bikes:
  ///   ≤ 7 km  →  ৳12/km × total km
  ///   7–12 km →  ৳9/km  × total km
  ///   > 12 km →  ৳7/km  × total km
  ///
  /// Result is floored at [minimumFare] (৳50).
  static double calculateMaxFare({
    required double distanceKm,
    required VehicleType vehicleType,
  }) {
    if (distanceKm <= 0) return minimumFare;

    final double rate = _getRate(distanceKm, vehicleType);
    final double calculated = rate * distanceKm;

    // Floor at minimum fare
    return calculated < minimumFare ? minimumFare : _round(calculated);
  }

  /// Get the per-km rate for the given distance bracket and vehicle type.
  static double _getRate(double distanceKm, VehicleType vehicleType) {
    switch (vehicleType) {
      case VehicleType.bike:
        if (distanceKm <= 7) return 12.0;
        if (distanceKm <= 12) return 9.0;
        return 7.0;
      case VehicleType.car:
      case VehicleType.cng:
        if (distanceKm <= 7) return 10.0;
        return 7.0;
    }
  }

  /// Clamp the host's offered price within valid bounds.
  /// If [maxFare] is null (no distance data), use fallback range.
  static double clampPrice(double offeredPrice, double? maxFare) {
    final double ceiling = maxFare ?? fallbackMaxFare;
    if (offeredPrice < minimumFare) return minimumFare;
    if (offeredPrice > ceiling) return ceiling;
    return offeredPrice;
  }

  /// Whether the offered price is within the valid range.
  static bool isValidPrice(double offeredPrice, double? maxFare) {
    final double ceiling = maxFare ?? fallbackMaxFare;
    return offeredPrice >= minimumFare && offeredPrice <= ceiling;
  }

  /// Get a human-readable breakdown of the pricing for display.
  static PricingBreakdown getBreakdown({
    required double distanceKm,
    required VehicleType vehicleType,
  }) {
    if (distanceKm <= 0) {
      return PricingBreakdown(
        rate: 0,
        distanceKm: 0,
        calculatedFare: minimumFare,
        finalFare: minimumFare,
        isMinimumApplied: true,
      );
    }

    final double rate = _getRate(distanceKm, vehicleType);
    final double calculated = rate * distanceKm;
    final double finalFare = calculated < minimumFare ? minimumFare : _round(calculated);

    return PricingBreakdown(
      rate: rate,
      distanceKm: distanceKm,
      calculatedFare: _round(calculated),
      finalFare: finalFare,
      isMinimumApplied: calculated < minimumFare,
    );
  }

  /// Round to nearest integer for clean display.
  static double _round(double value) => value.roundToDouble();
}

/// Breakdown of pricing calculation for display purposes.
class PricingBreakdown {
  final double rate;
  final double distanceKm;
  final double calculatedFare;
  final double finalFare;
  final bool isMinimumApplied;

  const PricingBreakdown({
    required this.rate,
    required this.distanceKm,
    required this.calculatedFare,
    required this.finalFare,
    required this.isMinimumApplied,
  });
}
