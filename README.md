# sui_bytecode_fail

The reason for this is that when debug::print is used by the Move code, the bytecode fails to verify.

In the Sources/HelloWorld.move file, if you comment out debug::print and run `sui move publish --gas-budget 5000' it will publish the module.
This needs to either be fixed so it can be verified, or raised as an error by the compiler.

![image](https://user-images.githubusercontent.com/1643692/181771504-b823808a-eda6-4c26-9aba-cef91941011a.png)
