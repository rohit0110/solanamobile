# Solana Mobile Stack Examples

This repository contains example applications demonstrating the usage of Solana Mobile Stack with Flutter.

## Profile Creator Example

A simple Flutter application that demonstrates how to:
1. Load and use a Rust program's IDL
2. Create and send transactions using Mobile Wallet Adapter
3. Implement Borsh serialization for instruction data

### Prerequisites

1. Flutter installed
2. Android device/emulator with a Mobile Wallet Adapter compatible wallet (e.g., Phantom)
3. The Rust program deployed on Solana (devnet/testnet/mainnet)

### Project Structure

```
lib/
├── main.dart           # App entry point
├── models/
│   └── profile.dart    # Profile data model
├── services/
│   └── program.dart    # Program interaction service
└── screens/
    └── profile.dart    # Profile creation screen
```

### Implementation

1. First, create the profile model with Borsh serialization:

```dart
// lib/models/profile.dart
import 'package:borsh_annotation/borsh_annotation.dart';

part 'profile.g.dart';

@BorshSerializable()
class CreateProfileDto with _$CreateProfileDto {
  factory CreateProfileDto({
    @BString() required String name,
  }) = _CreateProfileDto;

  CreateProfileDto._();

  factory CreateProfileDto.fromBorsh(Uint8List data) =>
      _$CreateProfileDtoFromBorsh(data);
}
```

2. Create the program service:

```dart
// lib/services/program.dart
import 'package:solana/anchor.dart';
import 'package:solana/solana.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

class ProgramService {
  static const String idl = '''
    {
      "version": "0.1.0",
      "name": "profile_program",
      "instructions": [
        {
          "name": "createProfile",
          "accounts": [
            {
              "name": "profile",
              "isMut": true,
              "isSigner": false
            },
            {
              "name": "authority",
              "isMut": true,
              "isSigner": true
            },
            {
              "name": "systemProgram",
              "isMut": false,
              "isSigner": false
            }
          ],
          "args": [
            {
              "name": "name",
              "type": "string"
            }
          ]
        }
      ]
    }
  ''';

  final Ed25519HDPublicKey programId;
  final SolanaClient client;

  ProgramService({
    required this.programId,
    required this.client,
  });

  Future<String> createProfile({
    required String name,
    required Ed25519HDPublicKey userPublicKey,
    required LocalAssociationScenario session,
  }) async {
    // Find PDA for profile account
    final profilePda = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        'profile'.codeUnits,
        userPublicKey.bytes,
      ],
      programId: programId,
    );

    // Create the instruction data
    final dto = CreateProfileDto(name: name);
    
    // Create the instruction
    final instruction = await AnchorInstruction.forMethod(
      programId: programId,
      method: 'createProfile',
      accounts: [
        AccountMeta(
          pubKey: profilePda,
          isSigner: false,
          isWriteable: true,
        ),
        AccountMeta(
          pubKey: userPublicKey,
          isSigner: true,
          isWriteable: true,
        ),
        AccountMeta(
          pubKey: SystemProgram.id,
          isSigner: false,
          isWriteable: false,
        ),
      ],
      arguments: ByteArray(dto.toBorsh()),
    );

    // Get latest blockhash
    final blockhash = await client.rpcClient
        .getLatestBlockhash()
        .then((res) => res.value.blockhash);

    // Create and compile the transaction
    final message = Message(instructions: [instruction]);
    final compiledMessage = message.compile(
      recentBlockhash: blockhash,
      feePayer: userPublicKey,
    );

    // Convert to bytes
    final transaction = compiledMessage.toByteArray().toList();

    // Get the mobile wallet client
    final mobileClient = await session.start();

    // Sign and send transaction
    final result = await mobileClient.signAndSendTransactions(
      transactions: [Uint8List.fromList(transaction)],
    );

    // Get the signature
    final signature = base58encode(result.signatures.first);

    // Wait for confirmation
    await client.waitForSignatureStatus(
      signature,
      status: Commitment.confirmed,
    );

    return signature;
  }
}
```

3. Create the profile screen:

```dart
// lib/screens/profile.dart
import 'package:flutter/material.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _authToken;
  Uint8List? _publicKey;

  Future<void> _connectWallet() async {
    final session = await LocalAssociationScenario.create();
    await session.startActivityForResult(null);

    final client = await session.start();
    final result = await client.authorize(
      identityUri: Uri.parse('https://example.com'),
      iconUri: Uri.parse('favicon.ico'),
      identityName: 'Profile Creator',
      cluster: 'devnet',
    );

    if (result != null) {
      setState(() {
        _authToken = result.authToken;
        _publicKey = result.publicKey;
      });
    }

    await session.close();
  }

  Future<void> _createProfile() async {
    if (_isLoading || _publicKey == null) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text;
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your name')),
        );
        return;
      }

      final session = await LocalAssociationScenario.create();
      await session.startActivityForResult(null);

      final programService = ProgramService(
        programId: Ed25519HDPublicKey.fromBase58(
          'YOUR_PROGRAM_ID_HERE',
        ),
        client: SolanaClient(
          rpcUrl: Uri.parse('https://api.devnet.solana.com'),
          websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
        ),
      );

      final signature = await programService.createProfile(
        name: name,
        userPublicKey: Ed25519HDPublicKey(_publicKey!),
        session: session,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile created! Signature: $signature')),
      );

      await session.close();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_publicKey == null)
              ElevatedButton(
                onPressed: _connectWallet,
                child: const Text('Connect Wallet'),
              )
            else
              Column(
                children: [
                  Text('Connected: ${base58encode(_publicKey!)}'),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Enter your name',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _createProfile,
                          child: const Text('Create Profile'),
                        ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
```

4. Set up the main app:

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/profile.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Profile Creator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ProfileScreen(),
    );
  }
}
```

### Setup Instructions

1. Create a new Flutter project:
```bash
flutter create profile_creator
cd profile_creator
```

2. Add dependencies to `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  solana: ^latest_version
  solana_mobile_client: ^latest_version
  borsh_annotation: ^latest_version

dev_dependencies:
  build_runner: ^latest_version
  borsh: ^latest_version
```

3. Generate Borsh serialization code:
```bash
dart run build_runner build
```

4. Replace the program ID in `program.dart` with your deployed program's address.

5. Run the app:
```bash
flutter run
```

### Usage

1. Launch the app on an Android device with a Mobile Wallet Adapter compatible wallet installed
2. Tap "Connect Wallet" to authorize with your wallet
3. Enter your name in the text field
4. Tap "Create Profile" to send the transaction
5. Approve the transaction in your wallet
6. Wait for confirmation

### Notes

- Make sure your wallet has enough SOL for the transaction
- The example uses devnet by default
- Error handling and UI can be enhanced for production use
- Always validate and sanitize user input
- Consider adding loading indicators and better error messages
- Add proper configuration management for program IDs and network endpoints

## License

This project is licensed under the MIT License - see the LICENSE file for details.
