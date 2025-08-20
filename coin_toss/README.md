# Coin Toss Flutter App

This is a simple coin toss game built with Flutter that demonstrates a clean architecture approach and integration with the Solana blockchain.

The application is built to be cross-platform, with support for **Android, iOS, Linux, macOS, Web, and Windows**.

## Core Technologies

- **Flutter**: For building the cross-platform user interface.
- **Riverpod**: For state management.
- **Solana**: For blockchain interaction. The user's profile is created as an on-chain account.
- **SharedPreferences**: For local data persistence (caching player data).

## App Flow

1.  **Authentication**: The app uses `solana_mobile_client` to connect to a mobile wallet for authentication.
2.  **Profile Creation**: On the first launch, the user is prompted to create a profile by entering their name. This action creates a new account on the Solana blockchain tied to their wallet address.
3.  **Coin Toss Game**: The main screen of the app where the user can play the coin toss game.
    - The player's current balance is displayed at the top.
    - The user can enter a stake amount.
    - On tossing the coin:
        - **Win**: The user wins double the stake amount.
        - **Lose**: The user loses the stake amount.
    - The result of the toss is displayed on the screen.
    - The player's balance is updated and saved locally to the device.

## Folder Structure

The project follows a feature-based folder structure:

```
assets/
 ├── idl/                 # Stores the Solana program's IDL (Interface Definition Language) JSON.
 │
lib/
 ├── config/              # Stores constant values, like the Solana Program ID.
 │
 ├── core/                # Core functionalities shared across the app.
 │    ├── solana/         # Solana-specific services and helpers.
 │    ├── storage/        # Local storage helper for SharedPreferences.
 │    └── theme/          # App theming (colors, text styles).
 │
 ├── features/            # Feature-based modules.
 │    ├── auth/           # Handles wallet authentication.
 │    ├── profile/        # On-chain profile creation and management.
 │    │    ├── data/      # Data layer (e.g., storage service).
 │    │    ├── domain/    # Business logic (e.g., Player model).
 │    │    └── presentation/ # UI layer (e.g., profile page).
 │    │
 │    └── coin_toss/      # Coin toss game feature.
 │         ├── domain/    # Game logic (e.g., coin toss service).
 │         └── presentation/ # UI layer (e.g., coin toss page).
 │
 ├── app.dart             # MaterialApp, routing, and initial setup.
 └── main.dart            # Entry point of the application.
```

## How to Run the App

1.  Ensure you have Flutter installed.
2.  Clone the repository.
3.  Run `flutter pub get` to install the dependencies.
4.  Run `flutter run` to launch the app on your device or emulator.

## Key Concepts

### Solana Integration

This project uses the following packages for Solana integration:
- **[solana](https://pub.dev/packages/solana)**: A Dart client for the Solana JSON RPC API.
- **[solana_mobile_client](https://pub.dev/packages/solana_mobile_client)**: For interacting with the Solana Mobile Stack and mobile wallets.
- **[borsh](https://pub.dev/packages/borsh)**: For serializing and deserializing data sent to and from the Solana program.

The user's profile is stored on-chain in an account defined by the IDL in `assets/idl/coin_toss.json`.

### State Management with Riverpod

This project uses [Riverpod](https://riverpod.dev/) for state management. Riverpod helps in managing the state of the app in a clean and testable way.

- **Providers**: Providers are the core of Riverpod. They are used to provide a value (e.g., a service, a state) to the widgets.
- **ConsumerWidget**: A widget that can listen to providers and rebuild when the value of a provider changes.
- **StateNotifierProvider**: A provider that is used to manage a state that can change over time.

### Data Persistence with SharedPreferences

[SharedPreferences](https://pub.dev/packages/shared_preferences) is used to store simple data on the device (e.g., player name, balance).

- **`local_storage.dart`**: This file provides a wrapper around `SharedPreferences` to make it easy to use across the app.

### Theming

- **`app_theme.dart`**: This file defines the theme of the app. It contains the color scheme, text styles, and other UI properties.

### Navigation

- **`app.dart`**: This file handles the initial routing of the app. It checks if a player profile exists and navigates to the appropriate screen.
