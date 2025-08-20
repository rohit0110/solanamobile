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
  final recepient = Ed25519HDPublicKey.fromBase58("6hLe4G744egMy5STYQ8Zs8qBvS4oKs1e1V5vhqLFyjYX");
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
    final client = SolanaClient(
      rpcUrl: Uri.parse('https://api.devnet.solana.com'),
      websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
    );
    final playerPublicKey = Ed25519HDPublicKey(widget.publicKey);
    
    final programId = Ed25519HDPublicKey.fromBase58('DgQs1qXHvkbBKJwgVP9DcS4EzN48beF9AEw5UpiCBSS3');

    final playerProfilePda = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        'player_profile'.codeUnits,
        playerPublicKey.bytes,
      ],
      programId: programId,
    ); 
    final info = await client.rpcClient.getAccountInfo(playerProfilePda.toBase58());
    if (info.value != null) {
      Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CoinTossPage()),
    );
    }
    final dto = CreatePlayerProfileDto(name: name);
    
    // Create the instruction
    final instruction = await AnchorInstruction.forMethod(
      programId: programId,
      method: 'create_player_profile',
      accounts: [
        AccountMeta(pubKey: playerProfilePda, isSigner: false, isWriteable: true),
        AccountMeta(pubKey: playerPublicKey, isSigner: true, isWriteable: true),
        AccountMeta(pubKey: SystemProgram.id, isSigner: false, isWriteable: false),
      ],
      // Convert the DTO to Borsh bytes
      arguments: ByteArray(dto.toBorsh()),
      namespace: 'global',
    );

    
    // Get latest blockhash
    final latestBlockhash = await client.rpcClient.getLatestBlockhash();
    final bal = await client.rpcClient.getBalance(playerPublicKey.toBase58());
    print(playerPublicKey);
    print("BALANCE IS ---------");
    print(bal.value);
    // Create and compile the message
    final message = Message(instructions: [instruction]);
    
    final compiledMessage = message.compileV0(
      recentBlockhash: latestBlockhash.value.blockhash,
      feePayer: playerPublicKey,
    );
    final transaction = SignedTx(compiledMessage: compiledMessage, signatures: [Signature(Uint8List(64), publicKey: playerPublicKey)]);
    final encodedTx = transaction.encode();
    final Uint8List unsignedTxBytes = base64Decode(encodedTx);
    // Sign and send if simulation succeeds
    final signed = await mobileClient.signTransactions(
      transactions: [unsignedTxBytes],
    );
    final signedTx = signed.signedPayloads.first;
    // final sim = await client.rpcClient.simulateTransaction(base64Encode(signedTx));
    // print("HEREeeeeeeeeeeee");
    // sim.value.logs?.forEach(print);
    // if (sim.value.err != null) {
    //   throw Exception('Preflight failed: ${sim.value.err}');
    // }
    final sig = await client.rpcClient.sendTransaction(base64Encode(signedTx));
    print('tx sig: $sig');
    print('Transaction sent with signature: $sig');

    // Wait for confirmation
    await client.waitForSignatureStatus(
      sig,
      status: Commitment.confirmed,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CoinTossPage()),
    );

    await session.close();

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
