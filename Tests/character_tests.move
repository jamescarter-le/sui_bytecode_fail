#[test_only]
module my_game::character_tests {
    //use std::debug;
    use sui::test_scenario::{Self};
    use my_game::character::{Self, Character};

    const ADMIN: address = @0xC0FFEE;
    const USER1: address = @0x01;

    #[test]
    fun can_init()
    {
        let scenario = &mut test_scenario::begin(&ADMIN);
        character::test_init(test_scenario::ctx(scenario));
    }

    #[test]
    fun can_mint_defender() {
        let scenario = &mut test_scenario::begin(&ADMIN);
        character::test_init(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, &ADMIN);
        {
            character::mint_character(false, 10, test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, &ADMIN);
        {
            let character = test_scenario::take_owned<Character>(scenario);

            assert!(!character::is_attacker(&character), 1);
            test_scenario::return_owned<Character>(scenario, character);    
        };
    }

    #[test]
    fun can_mint_attacker() {
        let scenario = &mut test_scenario::begin(&ADMIN);
        character::test_init(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, &ADMIN);
        {
            character::mint_character(true, 10, test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, &ADMIN);
        {
            let character = test_scenario::take_owned<Character>(scenario);

            assert!(character::is_attacker(&character), 1);
            test_scenario::return_owned<Character>(scenario, character);    
        };
    }
}