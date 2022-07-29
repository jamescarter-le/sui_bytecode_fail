module my_game::castle {
    #[test_only] friend my_game::castle_tests;

    use std::vector;
    use std::debug;
    use std::fixed_point32::{create_from_rational, multiply_u64, FixedPoint32};

    use sui::object::{Self, Info, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin;
    use sui::balance::{Self, Balance};
    use sui::coin::TreasuryCap;

    use my_game::character::{Self, Character};

    struct GameMasterCap has key {
        info: Info
    }

    // Witness for token creation
    struct CASTLE_TOKEN has drop {}

    struct Castle has key {
        info: Info,
        base_token_reward: u64,

        // Aggregate functions of associated Characters
        defender_total_count: u64,
        defender_total_damage: u64,
        defender_reward_created: u64,

        attacker_total_count: u64,
        attacker_total_damage: u64,

        battle_count: u64,
        battles: vector<Battle>,
        pendingRewards: Balance<CASTLE_TOKEN>,
    }

    struct CastleCharacter has store, drop {
        castleId: ID,
        characterId: ID,

        battle_entered: u64,
        battle_claimed: u64,
    }

    struct Battle has store {
        index: u64,
        epoch: u64,

        defender_total_count: u64,
        defender_total_damage: u64,
        defender_reward_created: u64,

        attacker_total_count: u64,
        attacker_total_damage: u64,
    }

    public(friend) fun defender_total_count(castle: &Castle):u64    { castle.defender_total_count }
    public(friend) fun defender_total_damage(castle: &Castle):u64   { castle.defender_total_damage }
    public(friend) fun defender_reward_created(castle: &Castle):u64 { castle.defender_reward_created }
    public(friend) fun attacker_total_count(castle: &Castle):u64    { castle.attacker_total_count }
    public(friend) fun attacker_total_damage(castle: &Castle):u64   { castle.attacker_total_damage }

    #[test_only]
    public fun test_init(ctx: &mut TxContext)
    {
        init(ctx);
    }

    fun init(ctx: &mut TxContext) {
        // We just generate the Cap here, Castles are created on command and passed their Coin to mint.
        transfer::transfer(GameMasterCap {
            info: object::new(ctx)
        }, tx_context::sender(ctx));
    }

    public entry fun create_castle(cap: &mut GameMasterCap, ctx: &mut TxContext) {
         
         let castleId = object::new(ctx);
         let castle = Castle {
            info: castleId,
            
            base_token_reward: 100,
            defender_total_count: 0,
            defender_total_damage: 0,
            defender_reward_created: 0,

            attacker_total_count: 0,
            attacker_total_damage: 0,

            battle_count: 0,
            battles: vector::empty<Battle>(),
            pendingRewards: balance::zero<CASTLE_TOKEN>()
        };

        let treasuryCap = coin::create_currency(CASTLE_TOKEN {}, ctx);
        transfer::transfer_to_object(treasuryCap, cap);

        // Castle needs to be shared, because when we enter/exit the castle we update the aggregate statistics.
        transfer::share_object(castle);
    }

    public entry fun battle(_cap: &mut GameMasterCap, treasuryCap: &mut TreasuryCap<CASTLE_TOKEN>, castle: &mut Castle, ctx: &mut TxContext)
    {
        // TODO: Ensure can only be called when it is time for Battle.

        let participents = castle.defender_total_count + castle.attacker_total_count;
        if(participents > 0)
        {
            let battle = Battle {
                index: castle.battle_count,
                epoch: tx_context::epoch(ctx),

                defender_total_count: castle.defender_total_count,
                defender_total_damage: castle.defender_total_damage,
                defender_reward_created: castle.defender_reward_created,
                attacker_total_count: castle.attacker_total_count,
                attacker_total_damage: castle.attacker_total_damage,
            };

            // Add the rewards to the Castle for people to collect.
            let createdBalance = coin::mint_balance<CASTLE_TOKEN>(treasuryCap, battle.defender_reward_created);
            balance::join(&mut castle.pendingRewards, createdBalance);

            vector::push_back(&mut castle.battles, battle);

            castle.battle_count = castle.battle_count + 1;
        }

        // TODO: Set the parameter gating Battle for the next time it can happen.
    }

    public entry fun enter_castle(castle: &mut Castle, character: &mut Character, _ctx: &mut TxContext)
    {
        // TODO: Check character is in a state that it can enter the Castle.
        //debug::print(character);
        character::is_modifyable(character);
        character::set_battle_entered(character, castle.battle_count);

        if(character::is_attacker(character)) {
            castle.attacker_total_count = castle.attacker_total_count + 1;
            castle.attacker_total_damage = castle.attacker_total_damage + character::damage(character);
        } else {
            castle.defender_total_count = castle.defender_total_count + 1;
            castle.defender_total_damage = castle.defender_total_damage + character::damage(character);
            castle.defender_reward_created = castle.defender_reward_created + castle.base_token_reward;
        };

        // TODO: Set a property on the Character that reflects this location.
        character::set_frozen(character, true);
    }

    public entry fun exit_castle(castle: &mut Castle, character: &mut Character, ctx: &mut TxContext)
    {
        // TODO: Check character is this Castle.
        // Claim rewards.
        claim_rewards(castle, character, ctx);

        if(character::is_attacker(character)) {
            castle.attacker_total_count = castle.attacker_total_count - 1;
            castle.attacker_total_damage = castle.attacker_total_damage - character::damage(character);
        } else {
            castle.defender_total_count = castle.defender_total_count - 1;
            castle.defender_total_damage = castle.defender_total_damage - character::damage(character);
            castle.defender_reward_created = castle.defender_reward_created - castle.base_token_reward;
        };

        // TODO: Remove this location from the Character
        character::set_frozen(character, false);
        character::set_battle_entered(character, 0);
    }

    fun get_battle_math(battle: &Battle) : (u64, FixedPoint32) {
        let attacker_rewards;
        let defender_ratio: FixedPoint32;

        if(battle.attacker_total_damage == battle.defender_total_damage) {
            attacker_rewards = ratio(battle.defender_reward_created, 1, 2);
            defender_ratio = create_from_rational(1, 2);
        } else if(battle.attacker_total_damage > battle.defender_total_damage) {
            attacker_rewards = battle.defender_reward_created - ratio(battle.defender_reward_created, battle.defender_total_damage, battle.attacker_total_damage);
            defender_ratio = create_from_rational(battle.defender_total_damage, battle.attacker_total_damage);
        } else {
            attacker_rewards = ratio(battle.defender_reward_created, battle.attacker_total_damage, battle.defender_total_damage);
            let temp = if(attacker_rewards <= battle.defender_reward_created) battle.defender_reward_created - attacker_rewards else 0;
            defender_ratio = create_from_rational(temp, battle.defender_reward_created);
        };

        (attacker_rewards, defender_ratio)
    }

    fun ratio(amount : u64, numerator: u64, denominator: u64) : u64 {
        let point = create_from_rational(numerator, denominator);
        let result = multiply_u64(amount, point);
        result
    }

    fun get_pending_rewards(castle: &mut Castle, character: &mut Character) : u64 {
        let n = vector::length(&castle.battles);
        let tokensToClaim = 0;
        let i = character::battle_entered(character);
        while (i < n) {
            let battle = vector::borrow(&mut castle.battles, i);
            let (attacker_rewards, defender_ratio) = get_battle_math(battle);
            if (character::is_attacker(character))
            {
                if(attacker_rewards > 0)
                {
                    let attackerReward = ratio(attacker_rewards, character::damage(character),battle.attacker_total_damage);
                   // debug::print(&2);
                   // debug::print(&attacker_rewards);
                   // debug::print(&character::damage(character));
                   // debug::print(&battle.attacker_total_damage);
                  //  debug::print(&attackerReward);
                    tokensToClaim = tokensToClaim + attackerReward;
                }
            }
            else
            {
                let defenderGenerated = 100;
                let defenderReward = if(battle.attacker_total_damage > 0) multiply_u64(defenderGenerated, defender_ratio) else defenderGenerated;
                defenderReward = if(defenderReward > defenderGenerated) defenderGenerated else defenderReward;

               // debug::print(&1);
               // debug::print(&defenderReward);
                tokensToClaim = tokensToClaim + defenderReward;
            };
            i = i + 1;
        };

        tokensToClaim
    }

    public entry fun claim_rewards(castle: &mut Castle, character: &mut Character, ctx: &mut TxContext)
    {
        // TODO: Check character is this Castle.

        let tokensToClaim = get_pending_rewards(castle, character);
        debug::print(&tokensToClaim);
        let share = balance::split(&mut castle.pendingRewards, tokensToClaim);
        coin::keep(coin::from_balance(share, ctx), ctx);

        // Reset the battle counter so they are not paid for previous battles again.
        character::set_battle_entered(character, castle.battle_count);
    }
}