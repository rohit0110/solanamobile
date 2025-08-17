
class Player {
  final String name;
  final int balance;

  Player({required this.name, required this.balance});

  Player copyWith({
    String? name,
    int? balance,
  }) {
    return Player(
      name: name ?? this.name,
      balance: balance ?? this.balance,
    );
  }
}
