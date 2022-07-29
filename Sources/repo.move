module my_game::repo {

    use sui::object::{Self, Info};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    const ADMIN: address = @0xC0FFEE;
    struct ExampleObject has key {
        info: Info,
        value: u64
    }

    fun create_example_object(value: u64, ctx: &mut TxContext) {
        transfer::transfer(ExampleObject {
            info: object::new(ctx),
            value: value
        }, tx_context::sender(ctx));
    }

   // #[test]
   // fun fails() {
   //     use sui::test_scenario;
   //     use std::debug;
//
   //     let scenario = &mut test_scenario::begin(&ADMIN);
   //     create_example_object(1, test_scenario::ctx(scenario));
   //     test_scenario::next_tx(scenario, &ADMIN);
   //     {
   //         let obj = test_scenario::take_last_created_owned<ExampleObject>(scenario);
   //         debug::print(&obj.value);
   //         assert!(obj.value == 1, 1);
   //         test_scenario::return_owned(scenario, obj);
   //     };
   //     create_example_object(2, test_scenario::ctx(scenario));
   //     test_scenario::next_tx(scenario, &ADMIN);
   //     {
   //         let obj = test_scenario::take_last_created_owned<ExampleObject>(scenario);
   //         debug::print(&obj.value);
   //         assert!(obj.value == 2, 2);
   //         test_scenario::return_owned(scenario, obj);
   //     };
   //     create_example_object(3, test_scenario::ctx(scenario));
   //     test_scenario::next_tx(scenario, &ADMIN);
   //     {
   //         let obj = test_scenario::take_last_created_owned<ExampleObject>(scenario);
   //         debug::print(&obj.value);
   //         assert!(obj.value == 3, 3);
   //         test_scenario::return_owned(scenario, obj);
   //     };
   // }

}
