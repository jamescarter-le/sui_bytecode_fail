module simple_package::hello_world {
	use sui::tx_context::{TxContext};

	use std::debug;

	public entry fun Hello(_ctx: &mut TxContext) {
		let x = 1;

		// Comment out the debug::print statement to fix.
		debug::print(&x);
	}
}