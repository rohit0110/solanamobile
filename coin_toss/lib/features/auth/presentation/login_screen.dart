import 'dart:typed_data';
import 'package:coin_toss/features/profile/presentation/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:solana/base58.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? authToken;
  Uint8List? publicKey;
  bool _isLoading = false;

  Future<void> _connectWallet() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final session = await LocalAssociationScenario.create();
      session.startActivityForResult(null).ignore();
      final client = await session.start();
      final result = await client.authorize(
        identityUri: Uri.parse('cointoss://app'),
        identityName: 'Coin Toss',
        cluster: 'devnet',
      );

      setState(() {
        authToken = result?.authToken;
        publicKey = result?.publicKey;
      });

      if (authToken != null && publicKey != null) {
        print(base58encode(publicKey!));
        print(authToken);
        _navigateToProfile(authToken!, publicKey!);
        await session.close();
      }
      
    } catch (e) {
      print('Error connecting to wallet: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting to wallet: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToProfile(String authToken, Uint8List publicKey) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(
          authToken: authToken,
          publicKey: publicKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _connectWallet,
                child: const Text('Connect Wallet'),
              ),
      ),
    );
  }
}