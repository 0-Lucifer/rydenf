<div align="center">

# 🚗 RYDEN

### _Your Campus Ride-Sharing Companion_

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Backend-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-22C55E?style=for-the-badge)](LICENSE)

**Ryden** connects riders and drivers in a clean, real-time platform — built for students who share daily commutes.
Offer a ride, find one, or host a group ride in seconds.

---

</div>

## ✨ Feature Highlights

| Feature | Description |
|---|---|
| 🚘 **Offer a Ride** | Drivers can publish rides with origin, destination, stops, vehicle type (Car / Bike / CNG), pricing, and seat count |
| 🔍 **Find a Ride** | Passengers can browse, filter by location/date, and request seats — instantly booked or pending driver approval |
| 👥 **Group Rides** | Host or join campus group rides with built-in seat management, request approval, and auto-expiry |
| ⚡ **Instant Match** | Toggle instant booking so passengers skip the approval step and get confirmed immediately (race-safe via Firestore transactions) |
| 💬 **Real-Time Chat** | 1-on-1 DMs between riders + auto-created group chats for accepted group rides — with sent/delivered/seen status |
| 🔔 **Smart Notifications** | In-app notification centre with ride requests, approvals, chat alerts, and badge counts — plus local push notifications |
| 👤 **Rich Profiles** | Custom display names, university, gender, profile pictures, and public profile pop-ups when tapping any user |
| 🗓️ **Premium Pickers** | Beautifully themed date & time pickers with indigo accents, custom typography, and smooth dial interactions |
| 🧹 **Auto-Cleanup** | Stale notifications (7 days), old rides (7 days), expired group rides (24h), and expired chats are cleaned up automatically on startup |
| 💾 **Offline-Ready** | Firestore persistence with a capped 100 MB offline cache so the app works even with spotty connections |

---

## 🏗️ Architecture

```
lib/
├── main.dart                        # Entry point, Firebase init, cache config, cleanup
├── firebase_options.dart            # Auto-generated Firebase config
│
├── models/                          # Clean data classes with Firestore (de)serialisation
│   ├── ride_model.dart              # Ride with vehicle type, stops, instant match toggle
│   ├── ride_request_model.dart      # Seat request (pending / accepted / rejected)
│   ├── group_ride_model.dart        # Group ride with host, seats, status
│   ├── group_ride_request_model.dart
│   ├── chat_room_model.dart         # 1:1 and group chat rooms with expiry
│   ├── chat_message_model.dart      # Messages with sent/delivered/seen status
│   ├── notification_model.dart      # In-app notification entries
│   └── user_model.dart              # User profile with uni, gender, avatar
│
├── services/                        # Business logic & backend
│   ├── auth_service.dart            # Firebase Auth (email/password, sign up, verification)
│   ├── auth_gate.dart               # Auth state listener → login or main app
│   ├── firestore_service.dart       # All Firestore CRUD, transactions, batch ops, cleanup
│   └── local_notification_service.dart  # Local push notifications via flutter_local_notifications
│
├── screens/                         # 19 fully-designed screens
│   ├── home_screen.dart             # Hero banner, quick actions, recent rides
│   ├── offer_ride_screen.dart       # Multi-step ride creation form
│   ├── available_rides.dart         # Browse + filter rides by location/date
│   ├── ride_detail_screen.dart      # Full ride info, request seat, manage passengers
│   ├── my_rides_screen.dart         # Driver's ride management dashboard
│   ├── ongoing_ride_screen.dart     # Active ride tracking & passenger list
│   ├── group_rides_screen.dart      # Browse group rides with search/filter
│   ├── host_group_ride_screen.dart  # Create a group ride
│   ├── group_ride_card_details.dart # Group ride details, join, enter GC
│   ├── group_ride_requests_screen.dart # Host manages incoming requests
│   ├── trips_screen.dart            # Ride history for both drivers and passengers
│   ├── chat_list_screen.dart        # All conversations with unread badges
│   ├── chat_screen.dart             # Real-time messaging with status indicators
│   ├── notifications_screen.dart    # Notification centre with mark-all-read
│   ├── profile_screen.dart          # User profile with stats
│   ├── edit_profile_screen.dart     # Edit name, university, gender, avatar
│   ├── login_screen.dart            # Email/password login
│   ├── signup_screen.dart           # Registration + email verification
│   └── email_verification_screen.dart
│
└── widgets/                         # Reusable UI components
    ├── main_wrapper.dart            # Bottom nav bar with badge counts
    ├── ride_card.dart               # Ride preview card with driver info
    ├── action_tile.dart             # Home screen quick-action buttons
    ├── profile_popup.dart           # Tap-to-view public profile modal
    └── premium_pickers.dart         # Custom-themed date & time pickers
```

---

## 🛡️ Database Safety

Ryden isn't just a prototype — it handles real-world edge cases:

| Concern | Solution |
|---|---|
| **Double-booking** | Instant bookings use **Firestore transactions** that re-read seat counts before committing |
| **Batch overflow** | All bulk writes use a **chunk helper** that splits operations into groups of 450 (below Firestore's 500 limit) |
| **Stale data bloat** | **Auto-cleanup** on startup deletes old notifications, completed rides, expired group rides, and expired chats |
| **Storage creep** | Offline cache is **capped at 100 MB** so phones don't silently fill up |
| **Seat integrity** | Group ride seats are **only deducted when the host accepts**, not on request — preventing phantom reservations |

---

## 🧰 Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.10+ (Dart 3.0+) |
| **Auth** | Firebase Authentication (email/password) |
| **Database** | Cloud Firestore (real-time sync, offline persistence) |
| **Notifications** | `flutter_local_notifications` for local push |
| **Typography** | Google Fonts — Plus Jakarta Sans, Inter |
| **Design** | Material 3 with custom theme tokens |

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `≥ 3.10`
- A Firebase project with **Auth** and **Firestore** enabled
- Android Studio / Xcode for emulators

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/0-Lucifer/rydenf.git
cd rydenf

# 2. Install dependencies
flutter pub get

# 3. Configure Firebase (if not already set up)
#    Place your google-services.json (Android) and GoogleService-Info.plist (iOS)
#    Or use FlutterFire CLI:
dart pub global activate flutterfire_cli
flutterfire configure

# 4. Run the app
flutter run
```

### Firestore Rules (recommended starter)

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    match /rides/{rideId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    match /ride_requests/{requestId} {
      allow read, write: if request.auth != null;
    }
    match /group_rides/{rideId} {
      allow read, write: if request.auth != null;
    }
    match /group_ride_requests/{requestId} {
      allow read, write: if request.auth != null;
    }
    match /notifications/{notifId} {
      allow read, write: if request.auth != null;
    }
    match /chat_rooms/{roomId} {
      allow read, write: if request.auth != null;
      match /messages/{messageId} {
        allow read, write: if request.auth != null;
      }
    }
  }
}
```

---

## 📁 Firestore Collections

| Collection | Purpose |
|---|---|
| `users` | User profiles (name, email, university, gender, avatar) |
| `rides` | Published rides with route, vehicle, pricing, seat info |
| `ride_requests` | Seat requests (pending → accepted / rejected) |
| `group_rides` | Group rides with host, seats, status, auto-expiry |
| `group_ride_requests` | Join requests for group rides |
| `chat_rooms` | 1:1 and group chat metadata with participant tracking |
| `chat_rooms/{id}/messages` | Individual chat messages with delivery status |
| `notifications` | In-app notifications with type, read status, timestamps |

---

<!-- ## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request -->

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for details.

---

<div align="center">

**Built with ❤️ using Flutter & Firebase**

_Ryden — Because every ride is better when shared._

</div>
