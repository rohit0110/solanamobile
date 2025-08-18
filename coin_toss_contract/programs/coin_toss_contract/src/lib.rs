use anchor_lang::prelude::*;

declare_id!("DgQs1qXHvkbBKJwgVP9DcS4EzN48beF9AEw5UpiCBSS3");

#[program]
pub mod coin_toss_contract {
    use super::*;

    pub fn create_player_profile(ctx: Context<CreatePlayerProfile>, name: String) -> Result<()> {
        let player_profile = &mut ctx.accounts.player_profile;
        player_profile.name = name;
        player_profile.owner = ctx.accounts.player.key();
        Ok(())
    }
}

// CONTEXTS ------------------------------------

#[derive(Accounts)]
pub struct CreatePlayerProfile<'info> {
    #[account(
        init,
        payer = player,
        space = 8 + PlayerProfile::INIT_SPACE,
        seeds = [b"player_profile", player.key().as_ref()],
        bump
    )]
    pub player_profile: Account<'info, PlayerProfile>,
    #[account(mut)]
    pub player: Signer<'info>,
    pub system_program: Program<'info, System>
}

// STATE --------------------------------------
#[account]
#[derive(Default, Debug, PartialEq, InitSpace)]
pub struct PlayerProfile {
    #[max_len(32)]
    pub name: String,
    pub owner: Pubkey,
}
