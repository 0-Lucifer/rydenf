import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/ride_model.dart';
import '../models/rating_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/rating_dialog.dart';

class OngoingRideScreen extends StatelessWidget {
  final String rideId;
  const OngoingRideScreen({super.key, required this.rideId});

  static const Color kPrimary = Color(0xFF2E7CF6);
  static const Color kTextPrimary = Color(0xFF0F172A);
  static const Color kTextSecondary = Color(0xFF64748B);
  static const Color kGreen = Color(0xFF10B981);
  static const Color kRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<Ride?>(
        stream: FirestoreService.getRideStream(rideId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimary));
          }
          final ride = snapshot.data;
          if (ride == null) {
            return const Center(child: Text("Ride not found"));
          }

          final isDriver = ride.driverId == AuthService.currentUser?.uid;
          final isCompleted = ride.status == 'completed';

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildLiveHeader(context, ride, isDriver, isCompleted)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 24),
                    _buildRouteProgress(ride),
                    const SizedBox(height: 20),
                    _buildPassengerList(ride),
                    const SizedBox(height: 20),
                    _buildRideDetails(ride),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: StreamBuilder<Ride?>(
        stream: FirestoreService.getRideStream(rideId),
        builder: (context, snapshot) {
          final ride = snapshot.data;
          if (ride == null) return const SizedBox.shrink();

          final isDriver = ride.driverId == AuthService.currentUser?.uid;
          final isCompleted = ride.status == 'completed';

          return _buildBottomBar(context, ride, isDriver, isCompleted);
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  LIVE HEADER
  // ───────────────────────────────────────────────────────

  Widget _buildLiveHeader(BuildContext context, Ride ride, bool isDriver, bool isCompleted) {
    return Container(
      decoration: BoxDecoration(
        gradient: isCompleted
            ? const LinearGradient(colors: [Color(0xFF64748B), Color(0xFF94A3B8)])
            : const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF34D399)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  if (!isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text("LIVE", style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.5,
                          )),
                        ],
                      ),
                    ),
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text("Completed", style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w800, color: kTextSecondary,
                      )),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                isCompleted ? "Ride Completed" : (isDriver ? "You're Driving" : "Ride in Progress"),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${ride.origin}  →  ${ride.destination}",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _headerChip(Icons.people_rounded, "${ride.passengers.length} Passenger${ride.passengers.length != 1 ? 's' : ''}"),
                  const SizedBox(width: 12),
                  _headerChip(Icons.access_time_rounded, DateFormat('hh:mm a').format(ride.departureTime)),
                  const SizedBox(width: 12),
                  _headerChip(
                    ride.vehicleType == VehicleType.bike ? Icons.two_wheeler_rounded : Icons.directions_car_filled_rounded,
                    ride.vehicleModel,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text, style: GoogleFonts.plusJakartaSans(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
            ), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  ROUTE PROGRESS
  // ───────────────────────────────────────────────────────

  Widget _buildRouteProgress(Ride ride) {
    final allStops = [ride.origin, ...ride.stops, ride.destination];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("ROUTE", style: GoogleFonts.plusJakartaSans(
            fontSize: 11, fontWeight: FontWeight.w800, color: kTextSecondary, letterSpacing: 1.2,
          )),
          const SizedBox(height: 16),
          ...List.generate(allStops.length, (i) {
            final isFirst = i == 0;
            final isLast = i == allStops.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: isFirst ? kGreen : (isLast ? kRed : const Color(0xFFF59E0B)),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isFirst
                            ? const Icon(Icons.my_location_rounded, color: Colors.white, size: 14)
                            : isLast
                                ? const Icon(Icons.flag_rounded, color: Colors.white, size: 14)
                                : Text("${i}", style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                    if (!isLast) Container(
                      width: 2, height: 36,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: const Color(0xFFE2E8F0),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(allStops[i], style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary,
                        )),
                        if (isFirst) Text("Pickup", style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: kGreen, fontWeight: FontWeight.w600,
                        )),
                        if (isLast) Text("Drop-off", style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: kRed, fontWeight: FontWeight.w600,
                        )),
                        if (!isFirst && !isLast) Text("Stopover", style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: const Color(0xFFF59E0B), fontWeight: FontWeight.w600,
                        )),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  PASSENGER LIST
  // ───────────────────────────────────────────────────────

  Widget _buildPassengerList(Ride ride) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, size: 20, color: kPrimary),
              const SizedBox(width: 10),
              Text("Passengers", style: GoogleFonts.plusJakartaSans(
                fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary,
              )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text("${ride.passengers.length}", style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w800, color: kPrimary,
                )),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (ride.passengers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text("Nothing yet", style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w600, color: kTextSecondary,
                )),
              ),
            )
          else
            ...ride.passengers.asMap().entries.map((entry) {
              final idx = entry.key;
              return FutureBuilder<String>(
                future: _getPassengerName(entry.value),
                builder: (context, snap) {
                  final name = snap.data ?? 'Loading...';
                  return Container(
                    margin: EdgeInsets.only(bottom: idx < ride.passengers.length - 1 ? 10 : 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: kPrimary.withOpacity(0.08),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800, color: kPrimary, fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(name, style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700, fontSize: 14, color: kTextPrimary,
                          )),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: kGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text("On Board", style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, fontWeight: FontWeight.w700, color: kGreen,
                          )),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
        ],
      ),
    );
  }

  Future<String> _getPassengerName(String uid) async {
    final profile = await FirestoreService.getUserProfile(uid);
    return profile?.displayName ?? 'Passenger';
  }

  // ───────────────────────────────────────────────────────
  //  RIDE DETAILS
  // ───────────────────────────────────────────────────────

  Widget _buildRideDetails(Ride ride) {
    final isDriver = ride.driverId == AuthService.currentUser?.uid;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("RIDE INFO", style: GoogleFonts.plusJakartaSans(
            fontSize: 11, fontWeight: FontWeight.w800, color: kTextSecondary, letterSpacing: 1.2,
          )),
          const SizedBox(height: 16),
          _detailRow(Icons.calendar_today_rounded, "Date", DateFormat('EEEE, MMM dd yyyy').format(ride.departureTime)),
          _detailRow(Icons.access_time_rounded, "Departure", DateFormat('hh:mm a').format(ride.departureTime)),
          _detailRow(Icons.attach_money_rounded, "Price/Seat", "৳${ride.pricePerSeat.toInt()}"),
          _detailRow(Icons.people_outline_rounded, "Gender Pref", ride.genderPreference),
          if (!isDriver)
            _detailRow(Icons.person_rounded, "Driver", ride.driverName),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kPrimary),
          const SizedBox(width: 14),
          Text(label, style: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary,
          )),
          const Spacer(),
          Text(value, style: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary,
          )),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  BOTTOM BAR
  // ───────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context, Ride ride, bool isDriver, bool isCompleted) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: isCompleted
          ? SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showRatingFlow(context, ride, isDriver),
                icon: const Icon(Icons.star_rounded, color: Colors.white),
                label: Text("Rate & Finish", style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white,
                )),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            )
          : isDriver
              ? SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showCompleteDialog(context, ride),
                    icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                    label: Text("Complete Ride", style: GoogleFonts.plusJakartaSans(
                      fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white,
                    )),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_rounded, color: kGreen, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Enjoy your ride!",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  void _showCompleteDialog(BuildContext context, Ride ride) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Complete Ride?", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text(
          "Mark this ride as completed. All passengers will see the ride as finished.",
          style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Not Yet", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: kTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await FirestoreService.completeRide(ride.id!);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result.message, style: const TextStyle(fontWeight: FontWeight.w600)),
                  backgroundColor: result.success ? kGreen : kRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text("Complete", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  //  HELPERS
  // ───────────────────────────────────────────────────────

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
  );

  // ───────────────────────────────────────────────────────
  //  RATING FLOW
  // ───────────────────────────────────────────────────────

  Future<void> _showRatingFlow(BuildContext context, Ride ride, bool isDriver) async {
    final currentUid = AuthService.currentUser?.uid;
    if (currentUid == null) {
      if (context.mounted) Navigator.pop(context);
      return;
    }

    if (isDriver) {
      // Driver rates each passenger
      for (final passengerId in ride.passengers) {
        final alreadyRated = await FirestoreService.hasRatedForRide(ride.id!, passengerId);
        if (alreadyRated || !context.mounted) continue;

        final passengerName = await _getPassengerName(passengerId);
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => RatingDialog(
            userName: passengerName,
            role: 'passenger',
            onSubmit: (rating, comment) async {
              await FirestoreService.submitRating(RideRating(
                rideId: ride.id!,
                fromUserId: currentUid,
                toUserId: passengerId,
                rating: rating,
                comment: comment,
              ));
            },
          ),
        );
      }
    } else {
      // Passenger rates the driver
      final alreadyRated = await FirestoreService.hasRatedForRide(ride.id!, ride.driverId);
      if (!alreadyRated && context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => RatingDialog(
            userName: ride.driverName,
            role: 'driver',
            onSubmit: (rating, comment) async {
              await FirestoreService.submitRating(RideRating(
                rideId: ride.id!,
                fromUserId: currentUid,
                toUserId: ride.driverId,
                rating: rating,
                comment: comment,
              ));
            },
          ),
        );
      }
    }

    if (context.mounted) Navigator.pop(context);
  }
}
