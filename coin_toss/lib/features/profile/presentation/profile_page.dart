
import 'package:coin_toss/features/coin_toss/presentation/coin_toss_page.dart';
import 'package:coin_toss/features/profile/data/profile_storage_service.dart';
import 'package:coin_toss/features/profile/domain/player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfilePage extends ConsumerWidget {
  final _nameController = TextEditingController();

  ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            ElevatedButton(
              onPressed: () {
                final name = _nameController.text;
                if (name.isNotEmpty) {
                  final player = Player(name: name, balance: 100);
                  ref.read(profileStorageServiceProvider).savePlayer(player);
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const CoinTossPage()),
                  );
                }
              },
              child: const Text('Save and Play'),
            ),
          ],
        ),
      ),
    );
  }
}
