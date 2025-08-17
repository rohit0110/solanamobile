
import 'package:coin_toss/features/coin_toss/domain/coin_toss_service.dart';
import 'package:coin_toss/features/profile/data/profile_storage_service.dart';
import 'package:coin_toss/features/profile/domain/player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Define the state for this screen
class CoinTossScreenState {
  final Player? player;
  final String message;

  CoinTossScreenState({this.player, this.message = ''});

  CoinTossScreenState copyWith({Player? player, String? message}) {
    return CoinTossScreenState(
      player: player ?? this.player,
      message: message ?? this.message,
    );
  }
}

// 2. Create a StateNotifier for the screen's state
class CoinTossScreenNotifier extends StateNotifier<CoinTossScreenState> {
  final ProfileStorageService _profileStorageService;
  final CoinTossService _coinTossService;

  CoinTossScreenNotifier(this._profileStorageService, this._coinTossService)
      : super(CoinTossScreenState()) {
    _loadPlayer();
  }

  void _loadPlayer() {
    final player = _profileStorageService.getPlayer();
    state = state.copyWith(player: player);
  }

  void tossCoin(int stake) {
    if (state.player != null && stake > 0 && stake <= state.player!.balance) {
      final result = _coinTossService.toss();
      Player updatedPlayer;
      String message;

      if (result == CoinFace.heads) { // Win
        final newBalance = state.player!.balance + (stake * 2);
        updatedPlayer = state.player!.copyWith(balance: newBalance);
        message = 'You won!';
      } else { // Lose
        final newBalance = state.player!.balance - stake;
        updatedPlayer = state.player!.copyWith(balance: newBalance);
        message = 'You lost!';
      }
      
      _profileStorageService.savePlayer(updatedPlayer);
      state = state.copyWith(player: updatedPlayer, message: message);
    }
  }
}

// 3. Create a provider for the StateNotifier
final coinTossScreenProvider =
    StateNotifierProvider<CoinTossScreenNotifier, CoinTossScreenState>((ref) {
  final profileStorageService = ref.watch(profileStorageServiceProvider);
  final coinTossService = ref.watch(coinTossServiceProvider);
  return CoinTossScreenNotifier(profileStorageService, coinTossService);
});


// 4. Refactor the UI to be a simple ConsumerWidget
class CoinTossPage extends ConsumerWidget {
  const CoinTossPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stakeController = TextEditingController();
    final screenState = ref.watch(coinTossScreenProvider);
    final player = screenState.player;

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${player?.name ?? ''}'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text('Balance: ${player?.balance ?? 0}'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: stakeController,
              decoration: const InputDecoration(
                labelText: 'Enter your stake',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final stake = int.tryParse(stakeController.text) ?? 0;
                ref.read(coinTossScreenProvider.notifier).tossCoin(stake);
              },
              child: const Text('Toss Coin'),
            ),
            const SizedBox(height: 20),
            if (screenState.message.isNotEmpty)
              Text(
                screenState.message,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
          ],
        ),
      ),
    );
  }
}
