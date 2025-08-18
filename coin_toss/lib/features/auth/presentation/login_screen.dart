import 'dart:typed_data';

import 'package:coin_toss/features/profile/presentation/profile_page.dart';
import 'package:flutter/material.dart';
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
      print('Creating local association scenario...');
      final session = await LocalAssociationScenario.create();
      print('Starting activity for result...');
      session.startActivityForResult(null).ignore();
      print('Starting client...');
      final client = await session.start();
      print('Authorizing...');
      final result = await client.authorize(
        identityUri: Uri.parse('cointoss://app'), // TODO: Replace with your app URI
        identityName: 'Coin Toss', // TODO: Replace with your app name
        cluster: 'localnet',
      );
      print('Closing session...');
      await session.close();
      print('Authorization result: $result');

      setState(() {
        authToken = result?.authToken;
        publicKey = result?.publicKey;
      });

      if (authToken != null && publicKey != null) {
        _navigateToProfile();
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

  void _navigateToProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage()),
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