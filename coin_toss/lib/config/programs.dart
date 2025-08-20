import 'package:solana/src/crypto/ed25519_hd_public_key.dart';

class Programs {
  static const programId = 'DgQs1qXHvkbBKJwgVP9DcS4EzN48beF9AEw5UpiCBSS3';
  static final Ed25519HDPublicKey id = Ed25519HDPublicKey.fromBase58(programId);
}