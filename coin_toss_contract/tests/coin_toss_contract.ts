import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { CoinTossContract } from "../target/types/coin_toss_contract";
import { Keypair, SystemProgram } from "@solana/web3.js";
import assert from "assert";

describe("coin_toss_contract", () => {
  // Configure the client to use the local cluster.
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.CoinTossContract as Program<CoinTossContract>;
  const player = Keypair.generate();

  before(async () => {
    // Airdrop SOL to the player account
    const signature = await provider.connection.requestAirdrop(
      player.publicKey,
      10 * anchor.web3.LAMPORTS_PER_SOL // 10 SOL
    );
    await provider.connection.confirmTransaction(signature);
  });

  it("creates a player profile and verifies its data", async () => {
    const playerName = "Alice";

    // Find the PDA for the player profile
    const [playerProfilePda] =
      anchor.web3.PublicKey.findProgramAddressSync(
        [Buffer.from("player_profile"), player.publicKey.toBuffer()],
        program.programId
      );

    // Create the player profile
    await program.methods
      .createPlayerProfile(playerName)
      .accounts({
        playerProfile: playerProfilePda,
        player: player.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .signers([player])
      .rpc();

    // Fetch the created account
    const playerProfile = await program.account.playerProfile.fetch(
      playerProfilePda
    );

    // Check the data
    assert.strictEqual(playerProfile.name, playerName, "Player name does not match");
    assert.ok(playerProfile.owner.equals(player.publicKey), "Player public key does not match");
  });
});
