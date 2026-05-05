## STAGING
Spice Dispenser Mobile App

Android-optimized Flutter application designed to control an ESP32-powered spice dispensing machine via Bluetooth Low Energy (BLE).

1. Getting Started

Prerequisites

Flutter SDK 3.x or higher

Android SDK (API Level 21+)

Physical Android device (required for BLE testing)

VS Code or Android Studio

Installation

Clone the repository

Run dependency fetch:

flutter pub get


Generate JSON serializers and type adapters:

flutter pub run build_runner build --delete-conflicting-outputs


2. Project Structure

The app follows a Feature-First Clean Architecture to ensure the BLE communication logic is decoupled from the UI.

lib/
├── core/                  # App-wide singletons and utilities
│   ├── ble/               # flutter_blue_plus wrappers and scanning logic
│   ├── database/          # Hive initialization and type adapters
│   ├── theme/             # Material 3 design tokens
│   └── utils/             # Flavor configuration and JSON helpers
├── features/              # Modular business logic units
│   ├── connection/        # Scanning, Handshake, and UUID pairing
│   ├── recipes/           # Recipe CRUD and syncing logic
│   ├── dashboard/         # Real-time monitoring and levels
│   └── dispensing/        # Active dispense state and Emergency Stop
├── app.dart               # Root MaterialApp and Theme initialization
└── main.dart              # Entry point with Flavor setup


Layered Folders within Features

Each feature directory (e.g., features/recipes) contains:

presentation: Widgets and State Management (Riverpod providers)

domain: Business entities and Use Cases

data: Repositories, Models, and Data Sources (BLE/Local DB)

3. Running the App (Flavors)

The project supports different flavors to distinguish between hardware environments.

Dev Flavor (Connects to real ESP32 with logging):

flutter run --flavor dev -t lib/main.dart


Prod Flavor (Optimized for release):

flutter run --flavor prod -t lib/main.dart


4. Communication Protocol (BLE)

The app communicates with the ESP32 using serialized JSON strings. Key command types defined in the Technical Specification include:

Handshake:

{"type": "handshake", "uuid": "...", "version": 1}


Dispense:

{"type": "dispense", "recipe_id": 1, "items": []}


Abort:

{"type": "abort"}


Update Slot:

{"type": "update_slot", "slot": 1, "name": "Cumin"}


5. Branching Strategy

main: Stable, production-ready code.

develop: Main integration branch for development.

feature/feature-name: Individual feature development branched from develop.

6. Definition of Done (DoD)

A task is considered done when:

Code is linted and passes all static analysis rules.

JSON structures match Section 7 of the Technical Spec exactly.

ESP32 successfully acknowledges and executes the command via the "Acknowledge-Commit" pattern.

Local database state matches machine state after transactions.

No unhandled exceptions occur during BLE disconnect/reconnect cycles.

7. Key Dependencies

flutter_blue_plus: BLE communication.

flutter_riverpod: Reactive state management.

hive_flutter: High-performance local storage for recipes and slots.

json_serializable: Automated JSON conversion logic.