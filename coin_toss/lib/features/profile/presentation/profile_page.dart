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
    if (_isLoading) {
      return;
    }

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

      final instruction = [await AnchorInstruction.forMethod(
        programId: programId,
        method: 'createPlayerProfile',
        accounts: [
          AccountMeta(pubKey: playerProfilePda, isSigner: false, isWriteable: true),
          AccountMeta(pubKey: playerPublicKey, isSigner: true, isWriteable: true),
          AccountMeta(pubKey: SystemProgram.id, isSigner: false, isWriteable: false),
        ],
        arguments: ByteArray(CreatePlayerProfileDto(name: name).toBorsh()),
        namespace: 'global',
      )];

      final client = SolanaClient(
        rpcUrl: Uri.parse('https://api.devnet.solana.com'),
        websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
      );
      final latestBlockhash = await client.rpcClient.getLatestBlockhash();
      
      final message = Message(
        instructions: instruction,
      );
      final transactions = message.compile(recentBlockhash: latestBlockhash.value.blockhash, feePayer: playerPublicKey);
      final transaction = transactions.toByteArray().toList();

      final simulationResult = await client.rpcClient.simulateTransaction(
        base64Encode(transaction),
      );
      if (simulationResult.value.err != null) {
        print('Transaction simulation failed: ${simulationResult.value.err}');
        print('Logs: ${simulationResult.value.logs}');
        throw Exception('Transaction simulation failed. See logs for details.');
      }

      final result = await mobileClient.signAndSendTransactions(transactions: [Uint8List.fromList(transaction)]);

      final signature = base58encode(result.signatures.first);

      await client.waitForSignatureStatus(
        signature,
        status: Commitment.confirmed,
      );

      await session.close();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CoinTossPage()),
      );

    } catch (e) {
      print('Error creating profile: $e');
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
