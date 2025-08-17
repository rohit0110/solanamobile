
import 'package:coin_toss/core/storage/local_storage.dart';
import 'package:coin_toss/features/profile/domain/player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _playerNameKey = 'player_name';
const String _playerBalanceKey = 'player_balance';

class ProfileStorageService {
  final LocalStorage _localStorage;

  ProfileStorageService(this._localStorage);

  Future<void> savePlayer(Player player) async {
    await _localStorage.setValue(_playerNameKey, player.name);
    await _localStorage.setValue(_playerBalanceKey, player.balance);
  }

  Player? getPlayer() {
    final name = _localStorage.getValue(_playerNameKey) as String?;
    final balance = _localStorage.getValue(_playerBalanceKey) as int?;

    if (name != null && balance != null) {
      return Player(name: name, balance: balance);
    }
    return null;
  }
}

final profileStorageServiceProvider = Provider<ProfileStorageService>((ref) {
  final localStorage = ref.watch(localStorageProvider);
  return ProfileStorageService(localStorage);
});
