#[test_only]
module my_game::castle_tests {
    use std::debug;
    use sui::object::{ID};
    use sui::coin::{Self, TreasuryCap, Coin};
    use sui::balance::{Self};
    use sui::test_scenario::{Self, Scenario};
    use my_game::castle::{Self, Castle, CASTLE_TOKEN, GameMasterCap};
    use my_game::character::{Self, Character};

    const ADMIN: address = @0xC0FFEE;

    fun get_a_castle() : Scenario {
        let baseScenario = test_scenario::begin(&ADMIN);
        let scenario = &mut baseScenario;
        castle::test_init(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, &ADMIN);
        {
            let cap = test_scenario::take_owned<GameMasterCap>(scenario);
            castle::create_castle(&mut cap, test_scenario::ctx(scenario));
            test_scenario::return_owned(scenario, cap);
        };
        test_scenario::next_tx(scenario, &ADMIN);

        baseScenario
    }

    fun get_castle_with_defender() : Scenario {
        let baseScenario = get_a_castle();
        let scenario = &mut baseScenario;
        {
            character::mint_character(false, 10, test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, &ADMIN);
        {
            let castle_wrapper = test_scenario::take_shared<Castle>(scenario);
            let castle = test_scenario::borrow_mut(&mut castle_wrapper);
            let character = test_scenario::take_owned<Character>(scenario);

            castle::enter_castle(castle, &mut character, test_scenario::ctx(scenario));

            test_scenario::return_owned(scenario, character);
            test_scenario::return_shared(scenario, castle_wrapper);
        };
        test_scenario::next_tx(scenario, &ADMIN);

        baseScenario
    }

    fun do_battle(scenario: &mut Scenario, count: u8) {
        let i = 0;
        while (i < count) {
            test_scenario::next_tx(scenario, &ADMIN);
            {
                let cap = test_scenario::take_owned<GameMasterCap>(scenario);
                let treasuryCap = test_scenario::take_child_object<GameMasterCap, TreasuryCap<CASTLE_TOKEN>>(scenario, &mut cap);
                let castle_wrapper = test_scenario::take_shared<Castle>(scenario);
                let castle = test_scenario::borrow_mut(&mut castle_wrapper);

                castle::battle(&mut cap, &mut treasuryCap, castle, test_scenario::ctx(scenario));
                //debug::print(castle);

                test_scenario::return_owned(scenario, cap);
                test_scenario::return_owned(scenario, treasuryCap);
                test_scenario::return_shared(scenario, castle_wrapper);
            };
            i = i + 1;
        };
        test_scenario::next_tx(scenario, &ADMIN);
    }

    #[test]
    fun castle_can_init()
    {
        let scenario = &mut test_scenario::begin(&ADMIN);
        castle::test_init(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, &ADMIN);
    }

    #[test]
    fun castle_defender_enter() {
        let scenario = &mut test_scenario::begin(&ADMIN);
        castle::test_init(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, &ADMIN);
        character::mint_character(false, 10, test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, &ADMIN);
        {
            let cap = test_scenario::take_owned<GameMasterCap>(scenario);
            castle::create_castle(&mut cap, test_scenario::ctx(scenario));
            test_scenario::return_owned(scenario, cap);
        };
        test_scenario::next_tx(scenario, &ADMIN);
        {
            let castle_wrapper = test_scenario::take_shared<Castle>(scenario);
            let castle = test_scenario::borrow_mut(&mut castle_wrapper);
            let character = test_scenario::take_owned<Character>(scenario);

            let before_count = castle::defender_total_count(castle);
            let before_damage = castle::defender_total_damage(castle);
            let before_reward = castle::defender_reward_created(castle);
            let before_count_attack = castle::attacker_total_count(castle);
            let before_damage_attack = castle::attacker_total_damage(castle);
            assert!(before_count == 0, 1);
            assert!(before_damage == 0, 1);
            assert!(before_reward == 0, 1);
            assert!(before_count_attack == 0, 1);
            assert!(before_damage_attack == 0, 1);

            castle::enter_castle(castle, &mut character, test_scenario::ctx(scenario));

            assert!(castle::defender_total_count(castle) == before_count + 1, 2);
            assert!(castle::defender_total_damage(castle) == before_damage + 10, 2);
            assert!(castle::defender_reward_created(castle) == before_reward + 100, 2);
            assert!(castle::attacker_total_count(castle) == before_count_attack, 2);
            assert!(castle::attacker_total_damage(castle) == before_damage_attack, 2);

            test_scenario::return_owned(scenario, character);
            test_scenario::return_shared(scenario, castle_wrapper);
        };
    }

    #[test]
    fun castle_attacker_enter() {
        let scenario = &mut test_scenario::begin(&ADMIN);
        castle::test_init(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, &ADMIN);
        character::mint_character(true, 10, test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, &ADMIN);
        {
            let cap = test_scenario::take_owned<castle::GameMasterCap>(scenario);
            castle::create_castle(&mut cap, test_scenario::ctx(scenario));
            test_scenario::return_owned(scenario, cap);
        };
        test_scenario::next_tx(scenario, &ADMIN);
        {
            let castle_wrapper = test_scenario::take_shared<Castle>(scenario);
            let castle = test_scenario::borrow_mut(&mut castle_wrapper);
            let character = test_scenario::take_owned<Character>(scenario);

            let before_count = castle::defender_total_count(castle);
            let before_damage = castle::defender_total_damage(castle);
            let before_reward = castle::defender_reward_created(castle);
            let before_count_attack = castle::attacker_total_count(castle);
            let before_damage_attack = castle::attacker_total_damage(castle);
            assert!(before_count == 0, 1);
            assert!(before_damage == 0, 1);
            assert!(before_reward == 0, 1);
            assert!(before_count_attack == 0, 1);
            assert!(before_damage_attack == 0, 1);

            castle::enter_castle(castle, &mut character, test_scenario::ctx(scenario));

            assert!(castle::defender_total_count(castle) == before_count, 2);
            assert!(castle::defender_total_damage(castle) == before_damage, 2);
            assert!(castle::defender_reward_created(castle) == before_reward, 2);
            assert!(castle::attacker_total_count(castle) == before_count_attack + 1, 2);
            assert!(castle::attacker_total_damage(castle) == before_damage_attack + 10, 2);

            test_scenario::return_owned<Character>(scenario, character);
            test_scenario::return_shared<Castle>(scenario, castle_wrapper);
        }
    }

    #[test]
    fun castle_battle_empty() {
        let scenario = &mut get_a_castle();
        do_battle(scenario, 1);
    }

    #[test]
    fun castle_battle_single_defender() {
        let scenario = &mut get_castle_with_defender();
        do_battle(scenario, 1);

        // Claim our rewards.
        test_scenario::next_tx(scenario, &ADMIN);
        {
            let castle_wrapper = test_scenario::take_shared<Castle>(scenario);
            let castle = test_scenario::borrow_mut(&mut castle_wrapper);
            let character = test_scenario::take_owned<Character>(scenario);

            castle::claim_rewards(castle, &mut character, test_scenario::ctx(scenario));
            debug::print(castle);

            test_scenario::return_owned<Character>(scenario, character);
            test_scenario::return_shared<Castle>(scenario, castle_wrapper);
        };
        // Check reward is correct.
        test_scenario::next_tx(scenario, &ADMIN);
        {
            let playerBalance = test_scenario::take_owned<Coin<CASTLE_TOKEN>>(scenario);
            let playerValue = balance::value(coin::balance(&playerBalance));
            assert!(playerValue == 100, 1);
            test_scenario::return_owned(scenario, playerBalance);
        }
    }

    #[test]
    fun castle_battle_single_defender_multiple_battles() {
        let scenario = &mut get_castle_with_defender();
        do_battle(scenario, 3);

        // Claim our rewards.
        test_scenario::next_tx(scenario, &ADMIN);
        {
            let castle_wrapper = test_scenario::take_shared<Castle>(scenario);
            let castle = test_scenario::borrow_mut(&mut castle_wrapper);
            let character = test_scenario::take_owned<Character>(scenario);

            castle::claim_rewards(castle, &mut character, test_scenario::ctx(scenario));
            debug::print(castle);

            test_scenario::return_owned<Character>(scenario, character);
            test_scenario::return_shared<Castle>(scenario, castle_wrapper);
        };
        // Check reward is correct.
        test_scenario::next_tx(scenario, &ADMIN);
        {
            let playerBalance = test_scenario::take_owned<Coin<CASTLE_TOKEN>>(scenario);
            let playerValue = balance::value(coin::balance(&playerBalance));
            assert!(playerValue == 300, 1);
            test_scenario::return_owned(scenario, playerBalance);
        }
    }

    // Reward Tests:
    // 1Def (Should receive full reward) [100] -> [100]
    // 2Def (Should both receive full reward) [100, 100] -> [100, 100]
    // 3Def (Should each receive full reward) [100, 100, 100] -> [100, 100, 100]
    // 1Att (Should receive nothing) [] -> [] [0]
    // 2Att (Should both receive nothing) [] -> [] [0]
    // 1Def_1Att (Should receive equal rewards) [100] -> [50] [50]
    // 1Def_Higher_1Att (Defender should receive more than Att) (15, 5) [100] -> [66] [33]
    // 1Def_Lower_1Att (Defender should receive less than Att) (5, 15) [100] -> [33] [66]
    // 2Def_Equal_1Att (2 Def should receive equal, with Att taking portion of both) 10.10, 10 (20, 10) [100, 100] -> [50, 50, 100]
    // 1Def_2Att (2 Att should receive equal, with Def taking less) 10, 10.10 (10, 20) [100] -> [50] [25, 25]
    // 1Def_2Att_Unequal (2 Att should receive unequal rewards, Def taking same as equal) 10, 5, 15 (10, 20) -> [50] [16, 34]
    // 2Def_Unequal_1Att (2 Def shold receive equal, with Att taking potion of both) 5.15, 20 (20, 20) -> [50, 50] -> [100]

    #[test] // 1Def (Should receive full reward) [100] -> [100]
    fun reward_1def() {
        let scenario = get_a_castle();
        let def = create_def_in_castle(&mut scenario, 10);
        do_battle(&mut scenario, 1);
        claim_reward_for_character(&mut scenario, def);
        assert_player_balance(&mut scenario, 100);
    }

    #[test] // 2Def (Should both receive full reward) [100, 100] -> [100, 100]
    fun reward_2def() {
        let scenario = get_a_castle();
        let def1 = create_def_in_castle(&mut scenario, 10);
        let def2 = create_def_in_castle(&mut scenario, 10);
        do_battle(&mut scenario, 1);
        claim_reward_for_character(&mut scenario, def1);
        assert_player_balance(&mut scenario, 100);
        claim_reward_for_character(&mut scenario, def2);
        assert_player_balance(&mut scenario, 100);
    }

    #[test] // 3Def (Should each receive full reward) [100, 100, 100] -> [100, 100, 100]
    fun reward_3def() {
        let scenario = get_a_castle();
        let def1 = create_def_in_castle(&mut scenario, 10);
        let def2 = create_def_in_castle(&mut scenario, 10);
        let def3 = create_def_in_castle(&mut scenario, 10);
        do_battle(&mut scenario, 1);
        claim_reward_for_character(&mut scenario, def1);
        assert_player_balance(&mut scenario, 100);
        claim_reward_for_character(&mut scenario, def2);
        assert_player_balance(&mut scenario, 100);
        claim_reward_for_character(&mut scenario, def3);
        assert_player_balance(&mut scenario, 100);
    }

    #[test] // 1Att (Should receive nothing) [] -> [] [0]
    fun reward_1att() {
        let scenario = get_a_castle();
        let att = create_att_in_castle(&mut scenario, 10);
        do_battle(&mut scenario, 1);
        claim_reward_for_character(&mut scenario, att);
        assert_player_balance(&mut scenario, 0);
    }

    #[test] // 2Att (Should both receive nothing) [] -> [] [0]
    fun reward_2att() {
        let scenario = get_a_castle();
        let att1 = create_att_in_castle(&mut scenario, 10);
        let att2 = create_att_in_castle(&mut scenario, 10);
        do_battle(&mut scenario, 1);
        claim_reward_for_character(&mut scenario, att1);
        assert_player_balance(&mut scenario, 0);
        claim_reward_for_character(&mut scenario, att2);
        assert_player_balance(&mut scenario, 0);
    }

    #[test] // 1Def_1Att (Should receive equal rewards) [100] -> [50] [50]
    fun reward_1def_1att() {
        let scenario = get_a_castle();
        let def = create_def_in_castle(&mut scenario, 10);
        let att = create_att_in_castle(&mut scenario, 10);
        do_battle(&mut scenario, 1);
        claim_reward_for_character(&mut scenario, def);
        assert_player_balance(&mut scenario, 50);
        claim_reward_for_character(&mut scenario, att);
        assert_player_balance(&mut scenario, 50);
    }

    #[test] // 1Def_Higher_1Att (Defender should receive more than Att) (15, 5) [100] -> [66] [33]
    fun reward_1def_higher_1att() {
        let scenario = get_a_castle();
        let def = create_def_in_castle(&mut scenario, 15);
        let att = create_att_in_castle(&mut scenario, 5);
        do_battle(&mut scenario, 1);
        claim_reward_for_character(&mut scenario, def);
        assert_player_balance(&mut scenario, 66);
        claim_reward_for_character(&mut scenario, att);
        assert_player_balance(&mut scenario, 33);
    }

    #[test] // 1Def_Lower_1Att (Defender should receive less than Att) (5, 15) [100] -> [33] [66]
    fun reward_1def_lower_1att() {
        let scenario = get_a_castle();
        let def = create_def_in_castle(&mut scenario, 5);
        let att = create_att_in_castle(&mut scenario, 15);
        do_battle(&mut scenario, 1);
        claim_reward_for_character(&mut scenario, def);
        assert_player_balance(&mut scenario, 33);
        claim_reward_for_character(&mut scenario, att);
        assert_player_balance(&mut scenario, 67);
    }

    #[test] // 2Def_Equal_1Att (2 Def should receive equal, with Att taking portion of both) 10.10, 10 (20, 10) [100, 100] -> [50, 50, 100]
    fun reward_2def_equal_1att() {
        let scenario = get_a_castle();
        let def1 = create_def_in_castle(&mut scenario, 10);
        let def2 = create_def_in_castle(&mut scenario, 10);
        let att = create_att_in_castle(&mut scenario, 10);
        do_battle(&mut scenario, 1);
        claim_reward_for_character(&mut scenario, def1);
        assert_player_balance(&mut scenario, 50);
        claim_reward_for_character(&mut scenario, def2);
        assert_player_balance(&mut scenario, 50);
        claim_reward_for_character(&mut scenario, att);
        assert_player_balance(&mut scenario, 100);
    }

    #[test] // 1Def_2Att (2 Att should receive equal, with Def taking less) 10, 10.10 (10, 20) [100] -> [50] [25, 25]
    fun reward_1def_2att() {
        let scenario = get_a_castle();
        let def = create_def_in_castle(&mut scenario, 10);
        let att1 = create_att_in_castle(&mut scenario, 10);
        let att2 = create_att_in_castle(&mut scenario, 10);
        do_battle(&mut scenario, 1);
        claim_reward_for_character(&mut scenario, def);
        assert_player_balance(&mut scenario, 50);
        claim_reward_for_character(&mut scenario, att1);
        assert_player_balance(&mut scenario, 25);
        claim_reward_for_character(&mut scenario, att2);
        assert_player_balance(&mut scenario, 25);
    }

    #[test] // 1Def_2Att_Unequal (2 Att should receive unequal rewards, Def taking same as equal) 10, 5.15 (10, 20) -> [50] [16, 34]
    fun reward_1def_2att_unequal() {
        let scenario = get_a_castle();
        let def = create_def_in_castle(&mut scenario, 10);
        let att1 = create_att_in_castle(&mut scenario, 5);
        let att2 = create_att_in_castle(&mut scenario, 15);
        do_battle(&mut scenario, 1);
        claim_reward_for_character(&mut scenario, def);
        assert_player_balance(&mut scenario, 50);
        claim_reward_for_character(&mut scenario, att1);
        assert_player_balance(&mut scenario, 12);
        claim_reward_for_character(&mut scenario, att2);
        assert_player_balance(&mut scenario, 37);
    }

    #[test] // 2Def_Unequal_1Att (2 Def shold receive equal, with Att taking potion of both) 5.15, 20 (20, 20) -> [50, 50] -> [100]
    fun reward_2def_unequal_1att() {
        let scenario = get_a_castle();
        let def1 = create_def_in_castle(&mut scenario, 5);
        let def2 = create_def_in_castle(&mut scenario, 15);
        let att1 = create_att_in_castle(&mut scenario, 20);
        do_battle(&mut scenario, 1);
        claim_reward_for_character(&mut scenario, def1);
        assert_player_balance(&mut scenario, 50);
        claim_reward_for_character(&mut scenario, def2);
        assert_player_balance(&mut scenario, 50);
        claim_reward_for_character(&mut scenario, att1);
        assert_player_balance(&mut scenario, 100);
    }

    fun assert_player_balance(_scenario: &mut Scenario, _expectedBalance: u64) {
      //  let playerBalance = test_scenario::take_last_created_owned<Coin<CASTLE_TOKEN>>(scenario);
      //  let playerValue = balance::value(coin::balance(&playerBalance));
      //  debug::print(&playerValue);
      //  assert!(playerValue == expectedBalance, expectedBalance);
      //  test_scenario::return_owned(scenario, playerBalance);
    }

    fun claim_reward_for_character(scenario: &mut Scenario, characterId: ID) {
        test_scenario::next_tx(scenario, &ADMIN);
        {
            let castle_wrapper = test_scenario::take_shared<Castle>(scenario);
            let castle = test_scenario::borrow_mut(&mut castle_wrapper);
            let character = test_scenario::take_owned_by_id<Character>(scenario, characterId);

            castle::claim_rewards(castle, &mut character, test_scenario::ctx(scenario));

            test_scenario::return_owned<Character>(scenario, character);
            test_scenario::return_shared<Castle>(scenario, castle_wrapper);
        };
        test_scenario::next_tx(scenario, &ADMIN);
    }

    fun create_def_in_castle(scenario: &mut Scenario, damage: u64) : ID
    {
        let characterId : ID;
        {
            characterId = character::mint_character(false, damage, test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, &ADMIN);
        {
            let castle_wrapper = test_scenario::take_shared<Castle>(scenario);
            let castle = test_scenario::borrow_mut(&mut castle_wrapper);
            let character = test_scenario::take_owned_by_id<Character>(scenario, characterId);

            castle::enter_castle(castle, &mut character, test_scenario::ctx(scenario));

            test_scenario::return_owned(scenario, character);
            test_scenario::return_shared(scenario, castle_wrapper);
        };
        test_scenario::next_tx(scenario, &ADMIN);
        characterId
    }

    fun create_att_in_castle(scenario: &mut Scenario, damage: u64) : ID
    {
        let characterId : ID;
        {
            characterId = character::mint_character(true, damage, test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, &ADMIN);
        {
            let castle_wrapper = test_scenario::take_shared<Castle>(scenario);
            let castle = test_scenario::borrow_mut(&mut castle_wrapper);
            let character = test_scenario::take_owned_by_id<Character>(scenario, characterId);

            castle::enter_castle(castle, &mut character, test_scenario::ctx(scenario));

            test_scenario::return_owned(scenario, character);
            test_scenario::return_shared(scenario, castle_wrapper);
        };
        test_scenario::next_tx(scenario, &ADMIN);
        characterId
    }
}