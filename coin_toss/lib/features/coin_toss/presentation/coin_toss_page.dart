import 'dart:convert';
import 'dart:typed_data';

import 'package:coin_toss/features/coin_toss/data/execute_toss_dto.dart';
import 'package:coin_toss/features/coin_toss/domain/coin_toss_service.dart';
import 'package:coin_toss/features/profile/data/profile_storage_service.dart';
import 'package:coin_toss/features/profile/domain/player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/anchor.dart';
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

class PlayerProfile {
  final String name;
  final Ed25519HDPublicKey player;
  final BigInt totalPlayed;
  final BigInt totalWon;

  PlayerProfile({
    required this.name,
    required this.player,
    required this.totalPlayed,
    required this.totalWon,
  });

  factory PlayerProfile.fromAccountData(Uint8List data) {
    // Skip 8-byte discriminator for Anchor accounts
    final borshData = data.sublist(8);
    final byteData = ByteData.sublistView(borshData);
    var offset = 0;

    final nameLen = byteData.getUint32(offset, Endian.little);
    offset += 4;
    final name = utf8.decode(borshData.sublist(offset, offset + nameLen));
    offset += nameLen;

    final playerPkBytes = borshData.sublist(offset, offset + 32);
    final player = Ed25519HDPublicKey(playerPkBytes);
    offset += 32;

    // Using getUint64 and converting to BigInt
    final totalPlayed = BigInt.from(byteData.getUint64(offset, Endian.little));
    offset += 8;
    final totalWon = BigInt.from(byteData.getUint64(offset, Endian.little));

    return PlayerProfile(
      name: name,
      player: player,
      totalPlayed: totalPlayed,
      totalWon: totalWon,
    );
  }
}

class CoinTossScreenState {
  final Player? player;
  final String message;
  final BigInt? totalPlayed;
  final BigInt? totalWon;
  final bool isSaving;
  final bool isFlipping;
  final bool? tossResult; // true for heads
  final bool? selectedSideIsHeads; // true for heads

  CoinTossScreenState({
    this.player,
    this.message = '',
    this.totalPlayed,
    this.totalWon,
    this.isSaving = false,
    this.isFlipping = false,
    this.tossResult,
    this.selectedSideIsHeads,
  });

  CoinTossScreenState copyWith({
    Player? player,
    String? message,
    BigInt? totalPlayed,
    BigInt? totalWon,
    bool? isSaving,
    bool? isFlipping,
    bool? tossResult,
    // use `ValueGetter` to allow passing null
    ValueGetter<bool?>? selectedSideIsHeads,
  }) {
    return CoinTossScreenState(
      player: player ?? this.player,
      message: message ?? this.message,
      totalPlayed: totalPlayed ?? this.totalPlayed,
      totalWon: totalWon ?? this.totalWon,
      isSaving: isSaving ?? this.isSaving,
      isFlipping: isFlipping ?? this.isFlipping,
      tossResult: tossResult ?? this.tossResult,
      selectedSideIsHeads: selectedSideIsHeads != null
          ? selectedSideIsHeads()
          : this.selectedSideIsHeads,
    );
  }
}

class CoinTossScreenNotifier extends StateNotifier<CoinTossScreenState> {
  final ProfileStorageService _profileStorageService;
  final CoinTossService _coinTossService;

  CoinTossScreenNotifier(this._profileStorageService, this._coinTossService)
      : super(CoinTossScreenState()) {
    _init();
  }

  void _init() async {
    final player = _profileStorageService.getPlayer();
    state = state.copyWith(player: player);
    if (player != null) {
      try {
        await _loadOnChainProfile();
      } catch (e) {
        state =
            state.copyWith(message: 'Error loading profile: ${e.toString()}');
      }
    }
  }

  void selectSide(bool isHeads) {
    state = state.copyWith(selectedSideIsHeads: () => isHeads, message: '');
  }

  Future<void> _loadOnChainProfile() async {
    final client = SolanaClient(
      rpcUrl: Uri.parse('https://api.devnet.solana.com'),
      websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
    );
    final playerPublicKey = state.player!.publicKey;
    final programId = Ed25519HDPublicKey.fromBase58(
        'DgQs1qXHvkbBKJwgVP9DcS4EzN48beF9AEw5UpiCBSS3');

    final playerProfilePda = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        'profile'.codeUnits,
        playerPublicKey.bytes,
      ],
      programId: programId,
    );

    final info = await client.rpcClient
        .getAccountInfo(playerProfilePda.toBase58(), encoding: Encoding.base64);

    if (info.value != null) {
      final accountData = base64Decode(info.value!.data!.toJson()[0]);
      final playerProfile = PlayerProfile.fromAccountData(accountData);
      state = state.copyWith(
        totalPlayed: playerProfile.totalPlayed,
        totalWon: playerProfile.totalWon,
      );
    }
  }

  Future<void> makeToss() async {
    if (state.player == null ||
        state.isSaving ||
        state.isFlipping ||
        state.selectedSideIsHeads == null) {
      return;
    }

    state = state.copyWith(isSaving: true, message: 'Submitting...');

    try {
      final tossResult = _coinTossService.toss();
      final tossResultIsHeads = tossResult == CoinFace.heads;
      final won = tossResultIsHeads == state.selectedSideIsHeads;

      final session = await LocalAssociationScenario.create();
      session.startActivityForResult(null).ignore();
      final mobileClient = await session.start();

      await mobileClient.reauthorize(
        identityUri: Uri.parse('cointoss://app'),
        identityName: 'Coin Toss',
        authToken: state.player!.authToken,
      );

      final client = SolanaClient(
        rpcUrl: Uri.parse('https://api.devnet.solana.com'),
        websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
      );
      final playerPublicKey = state.player!.publicKey;
      final programId = Ed25519HDPublicKey.fromBase58(
          'DgQs1qXHvkbBKJwgVP9DcS4EzN48beF9AEw5UpiCBSS3');

      final playerProfilePda = await Ed25519HDPublicKey.findProgramAddress(
        seeds: ['profile'.codeUnits, playerPublicKey.bytes],
        programId: programId,
      );

      final dto = ExecuteTossDto(won: won);

      final instruction = await AnchorInstruction.forMethod(
        programId: programId,
        method: 'execute_toss',
        accounts: [
          AccountMeta(
              pubKey: playerProfilePda, isSigner: false, isWriteable: true),
          AccountMeta(
              pubKey: playerPublicKey, isSigner: true, isWriteable: false),
        ],
        arguments: ByteArray(dto.toBorsh()),
        namespace: 'global',
      );

      final latestBlockhash = await client.rpcClient.getLatestBlockhash();
      final message = Message(instructions: [instruction]);
      final compiledMessage = message.compileV0(
        recentBlockhash: latestBlockhash.value.blockhash,
        feePayer: playerPublicKey,
      );

      final transaction = SignedTx(
        compiledMessage: compiledMessage,
        signatures: [Signature(Uint8List(64), publicKey: playerPublicKey)],
      );
      final unsignedTxBytes = base64Decode(transaction.encode());

      final signed = await mobileClient.signTransactions(
        transactions: [unsignedTxBytes],
      );
      final signedTx = signed.signedPayloads.first;

      final sig = await client.rpcClient.sendTransaction(base64Encode(signedTx));

      await client.waitForSignatureStatus(sig, status: Commitment.confirmed);

      await _loadOnChainProfile();

      state = state.copyWith(
        isSaving: false,
        isFlipping: true,
        tossResult: tossResultIsHeads,
        message: '', // Clear submitting message
      );

      await session.close();

      await Future.delayed(const Duration(seconds: 2));
      
      state = state.copyWith(
        isFlipping: false,
        message: won ? 'You Won!' : 'You Lost!',
        selectedSideIsHeads: () => null, // Reset selection
      );

    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        isFlipping: false,
        message: 'Error: ${e.toString()}',
      );
    }
  }
}

final coinTossScreenProvider =
    StateNotifierProvider<CoinTossScreenNotifier, CoinTossScreenState>((ref) {
  final profileStorageService = ref.watch(profileStorageServiceProvider);
  final coinTossService = ref.watch(coinTossServiceProvider);
  return CoinTossScreenNotifier(profileStorageService, coinTossService);
});

class CoinTossPage extends ConsumerWidget {
  const CoinTossPage({super.key});

  Widget _buildFace(bool isHeads) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: isHeads ? Colors.amber.shade700 : Colors.grey.shade600,
        shape: BoxShape.circle,
        border: Border.all(
            color: isHeads ? Colors.amber.shade900 : Colors.grey.shade800,
            width: 8),
      ),
      child: Center(
        child: Text(
          isHeads ? 'H' : 'T',
          style: const TextStyle(
              fontSize: 80, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenState = ref.watch(coinTossScreenProvider);
    final notifier = ref.read(coinTossScreenProvider.notifier);
    final player = screenState.player;
    final totalPlayed = screenState.totalPlayed;
    final totalWon = screenState.totalWon;

    final isHeadsSelected = screenState.selectedSideIsHeads == true;
    final isTailsSelected = screenState.selectedSideIsHeads == false;
    final isButtonDisabled = screenState.isFlipping || screenState.isSaving;

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${player?.name ?? ''}'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Balance: ${player?.balance ?? 0}'),
                  if (totalPlayed != null && totalWon != null)
                    Text('Played: $totalPlayed | Won: $totalWon',
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (screenState.isFlipping)
              const FlippingCoinAnimation()
            else
              _buildFace(screenState.tossResult ?? screenState.selectedSideIsHeads ?? true),
            const SizedBox(height: 20),
            Text(
              screenState.message,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isHeadsSelected ? Colors.blue.shade200 : null,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                      ),
                      onPressed: isButtonDisabled ? null : () => notifier.selectSide(true),
                      child: const Text('Heads'),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isTailsSelected ? Colors.blue.shade200 : null,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                      ),
                      onPressed: isButtonDisabled ? null : () => notifier.selectSide(false),
                      child: const Text('Tails'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 20),
                  ),
                  onPressed: screenState.selectedSideIsHeads == null || isButtonDisabled
                      ? null
                      : () => notifier.makeToss(),
                  child: screenState.isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                        )
                      : const Text('Toss!'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class FlippingCoinAnimation extends StatefulWidget {
  const FlippingCoinAnimation({Key? key}) : super(key: key);

  @override
  State<FlippingCoinAnimation> createState() => _FlippingCoinAnimationState();
}

class _FlippingCoinAnimationState extends State<FlippingCoinAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.amber.shade700,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text(
            '?',
            style: TextStyle(
                fontSize: 80, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}