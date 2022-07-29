module my_game::character {
    friend my_game::castle;

    //use std::debug;
    use sui::object::{Self, Info, info_id, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    const ECharacterNotInModifiableState: u64 = 1;

    struct Character has key {
        info: Info,
        is_attacker: bool,

        // Statistics
        //genome: u128,
        //generation: u8,
        damage: u64,

        current_location: vector<u8>,
        frozen_state: bool,

        battle_entered: u64, // The battle count when we joined a Castle, exclusive.
    }

    struct CharacterStatistics {
        parentX: ID,
        parentY: ID,
        genome : u128,
        generation: u8,
    }

    public fun is_attacker(character: &Character) : bool { character.is_attacker }

    public fun id(character: &Character) : ID { *info_id(&character.info) }

    public(friend) fun damage(character: &Character) : u64 { character.damage }
    public(friend) fun battle_entered(character: &Character) : u64 { character.battle_entered }
    public(friend) fun set_battle_entered(character: &mut Character, value: u64)  {
        character.battle_entered = value;
    }

    public(friend) fun set_frozen(character: &mut Character, value: bool) {
        character.frozen_state = value;
    }

    public(friend) fun is_modifyable(character: &Character) {
        assert!(character.frozen_state != true, ECharacterNotInModifiableState);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    fun init(_ctx: &mut TxContext) {}

    public fun mint_character(is_attacker: bool, damage: u64, ctx: &mut TxContext) : ID {
        let characterId = object::new(ctx);
        let character = Character {
            info: characterId,
            is_attacker: is_attacker,
            damage: damage,

            current_location: x"0000000000000000000000000000000000000000",
            frozen_state: false,
            battle_entered: 0,
        };

        let id =id(&character);
        transfer::transfer(character, tx_context::sender(ctx));

        id
    }
}