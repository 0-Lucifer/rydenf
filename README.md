<p align="center">
  <img src="assets/images/logo.png" alt="Ryden Logo" width="120"/>
</p>

<h1 align="center">Ryden</h1>
<p align="center">
  <b>Community ride sharing — find a ride, offer a ride, ride together.</b>
</p>

<p align="center">
  <a href="https://ryden-2.web.app">
    <img src="https://img.shields.io/badge/Live%20Web%20App-ryden--2.web.app-4F46E5?style=for-the-badge&logo=firebase" alt="Live Web App"/>
  </a>
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Firebase-Powered-FFCA28?style=for-the-badge&logo=firebase" alt="Firebase"/>
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-success?style=for-the-badge" alt="Platform"/>
</p>

---

## 📖 Overview

**Ryden** is a community-driven ride-sharing application built with Flutter. It connects people who are heading in the same direction — whether for daily commutes, university trips, or group outings. Instead of hailing a cab, Ryden lets real people offer and find rides with others in their community, reducing cost and carbon footprint while building connections.

The app runs natively on **Android** and **iOS**, and is also available as a **Progressive Web App (PWA)** deployed on Firebase Hosting.

🌐 **Live:** [https://rydenbd.com](https://rydenbd.com)

---

## ✨ Features

### 🚗 Ride Sharing
- **Offer a Ride** — Set your route, seats, vehicle type (car/bike), and fare. Dynamic distance-based pricing calculated via the Google Routes API.
- **Find a Ride** — Browse available rides filtered by destination and departure.
- **Ride Requests** — Send and receive join requests with real-time Firestore updates.
- **Ongoing Ride Tracking** — Live GPS tracking of active rides for both hosts and passengers.

### 👥 Group Rides
- **Create Groups** — Organize recurring rides with a fixed group of people.
- **Group Chat** — Built-in real-time messaging for each group.
- **Seat Management** — Dynamic seat availability with request/approval flow.
- **Group Admin Controls** — Hosts can manage members, approve requests, and remove riders.

### 💬 Messaging
- **Chat System** — One-on-one and group real-time chat powered by Firestore.
- **Chat List** — Unified inbox showing all active conversations.

### 🗺️ Maps & Location
- **Uber-Style Map Picker** — Full-screen map with a fixed center pin for intuitive location selection.
- **Places Autocomplete** — Search for any location in Bangladesh with instant suggestions.
- **Route Visualization** — Polyline-rendered routes between pickup and destination.
- **Reverse Geocoding** — Converts GPS coordinates to readable addresses on all platforms.

### 🔔 Notifications
- **Push Notifications** — Firebase Cloud Messaging (FCM) for ride requests, approvals, and messages.
- **Background Service** — Persistent notification listener keeps users updated even when the app is closed.
- **In-App Alerts** — Dedicated notifications screen with real-time updates.

### ⭐ Rating System
- **Passenger Ratings** — Rate your driver after a completed ride.
- **Skip Option** — Permanently skip rating for a specific ride without being prompted again.

### 👤 User Management
- **Authentication** — Email/password sign-up and login with Firebase Auth.
- **Email Verification** — Enforced email verification before accessing the app.
- **Profile Management** — Edit display name, photo, and personal info.
- **Trip History** — View all past rides as a host and as a passenger.

### ⚙️ App Management
- **Force Update** — Prompts users to update when a minimum version requirement is not met.
- **Settings** — Notification preferences and account management.
- **Privacy Policy** — In-app privacy policy screen.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter (Dart) |
| **Backend / Database** | Firebase Firestore |
| **Authentication** | Firebase Auth |
| **Push Notifications** | Firebase Cloud Messaging (FCM) |
| **Web Hosting** | Firebase Hosting |
| **Maps** | Google Maps Flutter / Maps JavaScript API |
| **Places Autocomplete** | Google Maps JS Places API (web) / Places REST API (mobile) |
| **Routing & Distance** | Google Routes API |
| **Geocoding** | Google Maps JS Geocoder (web) / `geocoding` package (mobile) |
| **Fonts** | Google Fonts — Plus Jakarta Sans |
| **State Management** | Flutter built-in (`setState`, `StreamBuilder`) |
| **Environment Config** | `flutter_dotenv` |

---

## 📂 Project Structure

```
lib/
├── config/          # App configuration & API endpoints
├── models/          # Data models (Ride, User, Group, etc.)
├── screens/         # All app screens
│   ├── home_screen.dart
│   ├── offer_ride_screen.dart
│   ├── available_rides.dart
│   ├── group_rides_screen.dart
│   ├── chat_screen.dart
│   ├── ongoing_ride_screen.dart
│   ├── track_ride_screen.dart
│   └── ...
├── services/        # Business logic & API services
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── places_service.dart
│   ├── routes_service.dart
│   ├── location_service.dart
│   └── ...
└── widgets/         # Reusable UI components
    ├── map_location_picker.dart
    └── ...

web/
├── index.html       # Web entry point with Maps JS SDK
├── favicon.png      # Browser tab icon
└── icons/           # PWA icons

assets/
└── images/          # App logo and images
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- A Google Cloud project with the following APIs enabled:
  - Maps JavaScript API
  - Maps SDK for Android / iOS
  - Places API
  - Routes API
  - Geocoding API

### Setup

**1. Clone the repository**

```bash
git clone https://github.com/0-Lucifer/rydenf.git
cd rydenf
```

**2. Create a `.env` file** in the project root:

```env
GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here
```

**3. Configure Firebase**

- Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
- Run `flutterfire configure` to generate `lib/firebase_options.dart`

**4. Install dependencies**

```bash
flutter pub get
```

**5. Run the app**

```bash
# Mobile
flutter run

# Web
flutter run -d chrome
```

### Build & Deploy Web

```bash
flutter build web --release
firebase deploy --only hosting
```

---

## 📱 Supported Platforms

| Platform | Status |
|---|---|
| Android | ✅ Supported |
| iOS | ✅ Supported |
| Web (PWA) | ✅ Supported |

---

## 🔮 Future Plans

- [ ] **In-App Payments** — Integrate a payment gateway (e.g., bKash / Stripe) for cashless fare collection.
- [ ] **Ride Scheduling** — Allow users to schedule rides in advance with calendar integration.
- [ ] **Driver Verification** — KYC-style ID and license verification for ride hosts.
- [ ] **Women-Only Rides** — A filter for female passengers to find female-hosted rides.
- [ ] **SOS / Emergency Button** — One-tap emergency alert with live location sharing to trusted contacts.
- [ ] **AI Route Suggestions** — Suggest optimal pickup points and routes based on traffic and demand.
- [ ] **Carbon Footprint Tracker** — Show users how much CO₂ they've saved by sharing rides.
- [ ] **Multi-Stop Rides** — Support for rides with multiple pickup/dropoff points along a route.
- [ ] **Recurring Ride Schedule** — Set repeating daily/weekly rides for regular commuters.
- [ ] **Play Store & App Store Release** — Official public app store listings.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome. Feel free to open an issue or submit a pull request.

---

## 📄 License

This project is private and not licensed for redistribution.

---

<p align="center">Built with ❤️ using Flutter & Firebase</p>
