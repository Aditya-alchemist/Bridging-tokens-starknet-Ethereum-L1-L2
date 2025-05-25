//class hash 0x05e939a94c06d6993246ecf1b99b4c16e024644ce31371c37d9db2c52084a59c
// deployed at 0x033811f27b417f6cbf6f8aebfd341f8aa0439d3264d6ad3d6a327d29bc9fb774



#[starknet::interface]
 trait IMintableToken<TContractState> {
    fn mint(ref self: TContractState, account: starknet::ContractAddress, amount: u256);
    fn burn(ref self: TContractState, account: starknet::ContractAddress, amount: u256);
}

#[starknet::contract]
pub mod MintableTokenMock {
    use ERC20Component::InternalTrait;
use core::num::traits::Zero;
    use starknet::event::EventEmitter;
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
        use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};

            component!(path: ERC20Component, storage: erc20, event: ERC20Event);

             #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20Impl<ContractState>;
        

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

 
 
    #[storage]
    struct Storage {
        // The address of the L2 bridge contract. Only the bridge can invoke burn and mint methods
        bridge: ContractAddress,
         #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }
 
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Minted: Minted,
        Burned: Burned,
         #[flat]
        ERC20Event: ERC20Component::Event,
    }
 
    #[derive(Drop, starknet::Event)]
    pub struct Minted {
        pub account: ContractAddress,
        pub amount: u256,
    }
 
    #[derive(Drop, starknet::Event)]
    pub struct Burned {
        pub account: ContractAddress,
        pub amount: u256,
    }
 
    pub mod Errors {
        pub const INVALID_ADDRESS: felt252 = 'Invalid address';
        pub const UNAUTHORIZED: felt252 = 'Unauthorized';
    }
 
    #[constructor]
    fn constructor(ref self: ContractState, bridge: ContractAddress) {
        self.erc20.initializer( name: "Bridge Token", symbol: "BTK" );
        assert(bridge.is_non_zero(), Errors::INVALID_ADDRESS);
        self.bridge.write(bridge);
    }
 
    #[abi(embed_v0)]
    impl MintableTokenMock of super::IMintableToken<ContractState> {
        fn mint(ref self: ContractState, account: ContractAddress, amount: u256) {
            self._assert_only_bridge();
            self.erc20.mint(account, amount);
            self.emit(Minted { account, amount });
        }
 
        fn burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            self._assert_only_bridge();
            self.erc20.burn(account, amount);
            self.emit(Burned { account, amount });
        }
    }
 
    #[generate_trait]
    impl Internal of ITrait {
        fn _assert_only_bridge(self: @ContractState) {
            assert(get_caller_address() == self.bridge.read(), Errors::UNAUTHORIZED);
        }
    }
}