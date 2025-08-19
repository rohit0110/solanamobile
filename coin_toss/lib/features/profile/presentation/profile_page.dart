import 'dart:convert';
import 'dart:typed_data';
import 'package:coin_toss/features/coin_toss/presentation/coin_toss_page.dart';
import 'package:coin_toss/features/profile/data/create_player_profile_dto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/base58.dart';
import 'package:solana/solana.dart';
import 'package:solana/src/encoder/encoder.dart';
import 'package:solana/anchor.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

class ProfilePage extends ConsumerStatefulWidget {
  final String authToken;
  final Uint8List publicKey;
  const ProfilePage({
    super.key,
    required this.authToken,
    required this.publicKey,
  });

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  Future<void> _createProfile() async {
  if (_isLoading) return;

  setState(() {
    _isLoading = true;
  });

  try {
    final name = _nameController.text;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    final session = await LocalAssociationScenario.create();
    session.startActivityForResult(null).ignore();
    final mobileClient = await session.start();

    await mobileClient.reauthorize(
      identityUri: Uri.parse('cointoss://app'),
      identityName: 'Coin Toss',
      authToken: widget.authToken,
    );

    final programId = Ed25519HDPublicKey.fromBase58('DgQs1qXHvkbBKJwgVP9DcS4EzN48beF9AEw5UpiCBSS3');
    final playerPublicKey = Ed25519HDPublicKey(widget.publicKey);

    final playerProfilePda = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        'player_profile'.codeUnits,
        playerPublicKey.bytes,
      ],
      programId: programId,
    );

    // Create the DTO and serialize it
    final dto = CreatePlayerProfileDto(name: name);
    
    // Create the instruction
    final instruction = await AnchorInstruction.forMethod(
      programId: programId,
      method: 'createPlayerProfile',
      accounts: [
        AccountMeta(pubKey: playerProfilePda, isSigner: false, isWriteable: true),
        AccountMeta(pubKey: playerPublicKey, isSigner: true, isWriteable: true),
        AccountMeta(pubKey: SystemProgram.id, isSigner: false, isWriteable: false),
      ],
      // Convert the DTO to Borsh bytes
      arguments: ByteArray(Uint8List.fromList(dto.toBorsh())),
      namespace: 'global',
    );

    final client = SolanaClient(
      rpcUrl: Uri.parse('https://api.devnet.solana.com'),
      websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
    );

    // Get latest blockhash
    final latestBlockhash = await client.rpcClient.getLatestBlockhash();
    
    // Create and compile the message
    final message = Message(instructions: [instruction]);
    final compiledMessage = message.compile(
      recentBlockhash: latestBlockhash.value.blockhash,
      feePayer: playerPublicKey,
    );

    // Convert to bytes
    final transaction = compiledMessage.toByteArray().toList();

    // Debug logs
    print('Transaction data:');
    print('PDA: ${playerProfilePda.toBase58()}');
    print('Player: ${playerPublicKey.toBase58()}');
    print('Instruction data length: ${instruction.data.length}');
    print('First few bytes of instruction: ${instruction.data.take(10).toList()}');

    // Simulate first
    final simulationResult = await client.rpcClient.simulateTransaction(
      base64Encode(transaction),
      commitment: Commitment.confirmed,
      signers: [playerPublicKey],
    );

    // Print simulation logs for debugging
    print('Simulation logs:');
    print(simulationResult.value.logs?.join('\n'));

    if (simulationResult.value.err != null) {
      throw Exception('Simulation failed: ${simulationResult.value.err}\nLogs: ${simulationResult.value.logs?.join('\n')}');
    }

    // Sign and send if simulation succeeds
    final result = await mobileClient.signAndSendTransactions(
      transactions: [Uint8List.fromList(transaction)],
    );

    final signature = base58encode(result.signatures.first);
    print('Transaction sent with signature: $signature');

    // Wait for confirmation
    await client.waitForSignatureStatus(
      signature,
      status: Commitment.confirmed,
    );

    await session.close();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CoinTossPage()),
    );

  } catch (e) {
    print('Detailed error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error creating profile: $e')),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                    child: const Text('Save and Play'),
                  ),
          ],
        ),
      ),
    );
  }
}
