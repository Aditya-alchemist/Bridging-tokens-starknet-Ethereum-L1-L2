//class hash 0x050af6acdd896305513039ae83da70593039a48e5554aa25230bcbfbfacadd56
// deployed at 0x0522348dfb0479e3a196dd50af99751812b592c800222cd493d6afc35d347415



use starknet::{ContractAddress, EthAddress};
 

#[starknet::interface]
pub trait IMintableToken<TContractState> {
    fn mint(ref self: TContractState, account: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, account: ContractAddress, amount: u256);
}
 
#[starknet::interface]
pub trait ITokenBridge<TContractState> {
    fn bridge_to_l1(ref self: TContractState, l1_recipient: EthAddress, amount: u256);
    fn set_l1_bridge(ref self: TContractState, l1_bridge_address: EthAddress);
    fn set_token(ref self: TContractState, l2_token_address: ContractAddress);
    fn governor(self: @TContractState) -> ContractAddress;
    fn l1_bridge(self: @TContractState) -> felt252;
    fn l2_token(self: @TContractState) -> ContractAddress;
}
 
#[starknet::contract]
pub mod TokenBridge {
    use core::num::traits::Zero;
    use starknet::{ContractAddress, EthAddress, get_caller_address, syscalls, SyscallResultTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::{IMintableTokenDispatcher, IMintableTokenDispatcherTrait};
 
    #[storage]
    pub struct Storage {
       
        pub governor: ContractAddress,
        pub l1_bridge: felt252,
        pub l2_token: ContractAddress,
    }
 
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        WithdrawInitiated: WithdrawInitiated,
        DepositHandled: DepositHandled,
        L1BridgeSet: L1BridgeSet,
        L2TokenSet: L2TokenSet,
    }
 
    
    #[derive(Drop, starknet::Event)]
    pub struct WithdrawInitiated {
        pub l1_recipient: EthAddress,
        pub amount: u256,
        pub caller_address: ContractAddress,
    }
 
   
    #[derive(Drop, starknet::Event)]
    pub struct DepositHandled {
        pub account: ContractAddress,
        pub amount: u256,
    }
 
   
    #[derive(Drop, starknet::Event)]
    struct L1BridgeSet {
        l1_bridge_address: EthAddress,
    }
 
    
    #[derive(Drop, starknet::Event)]
    struct L2TokenSet {
        l2_token_address: ContractAddress,
    }
 
    pub mod Errors {
        pub const EXPECTED_FROM_BRIDGE_ONLY: felt252 = 'Expected from bridge only';
        pub const INVALID_ADDRESS: felt252 = 'Invalid address';
        pub const INVALID_AMOUNT: felt252 = 'Invalid amount';
        pub const UNAUTHORIZED: felt252 = 'Unauthorized';
        pub const TOKEN_NOT_SET: felt252 = 'Token not set';
        pub const L1_BRIDGE_NOT_SET: felt252 = 'L1 bridge address not set';
    }
 
    #[constructor]
    fn constructor(ref self: ContractState, governor: ContractAddress) {
        assert(governor.is_non_zero(), Errors::INVALID_ADDRESS);
        self.governor.write(governor);
    }
 
    #[abi(embed_v0)]
    impl TokenBridge of super::ITokenBridge<ContractState> {
        fn bridge_to_l1(ref self: ContractState, l1_recipient: EthAddress, amount: u256) {
            assert(l1_recipient.is_non_zero(), Errors::INVALID_ADDRESS);
            assert(amount.is_non_zero(), Errors::INVALID_AMOUNT);
            self._assert_l1_bridge_set();
            self._assert_token_set();
 
            let caller_address = get_caller_address();
            IMintableTokenDispatcher { contract_address: self.l2_token.read() }
                .burn(caller_address, amount);
 
            // Send the message to L1 to mint tokens there.
            let mut payload: Array<felt252> = array![
                l1_recipient.into(), amount.low.into(), amount.high.into(),
            ];
            syscalls::send_message_to_l1_syscall(self.l1_bridge.read(), payload.span())
                .unwrap_syscall();
 
            self.emit(WithdrawInitiated { l1_recipient, amount, caller_address });
        }
 
        fn set_l1_bridge(ref self: ContractState, l1_bridge_address: EthAddress) {
            self._assert_only_governor();
            assert(l1_bridge_address.is_non_zero(), Errors::INVALID_ADDRESS);
 
            self.l1_bridge.write(l1_bridge_address.into());
            self.emit(L1BridgeSet { l1_bridge_address });
        }
 
        fn set_token(ref self: ContractState, l2_token_address: ContractAddress) {
            self._assert_only_governor();
            assert(l2_token_address.is_non_zero(), Errors::INVALID_ADDRESS);
 
            self.l2_token.write(l2_token_address);
            self.emit(L2TokenSet { l2_token_address });
        }
 
        // Getters
 
        fn governor(self: @ContractState) -> ContractAddress {
            self.governor.read()
        }
 
        fn l1_bridge(self: @ContractState) -> felt252 {
            self.l1_bridge.read()
        }
 
        fn l2_token(self: @ContractState) -> ContractAddress {
            self.l2_token.read()
        }
    }
 
    #[generate_trait]
    impl Internal of InternalTrait {
        fn _assert_only_governor(self: @ContractState) {
            assert(get_caller_address() == self.governor.read(), Errors::UNAUTHORIZED);
        }
 
        fn _assert_token_set(self: @ContractState) {
            assert(self.l2_token.read().is_non_zero(), Errors::TOKEN_NOT_SET);
        }
 
        fn _assert_l1_bridge_set(self: @ContractState) {
            assert(self.l1_bridge.read().is_non_zero(), Errors::L1_BRIDGE_NOT_SET);
        }
    }
 
    #[l1_handler]
    pub fn handle_deposit(
        ref self: ContractState, from_address: felt252, account: ContractAddress, amount: u256,
    ) {
        assert(from_address == self.l1_bridge.read(), Errors::EXPECTED_FROM_BRIDGE_ONLY);
        assert(account.is_non_zero(), Errors::INVALID_ADDRESS);
        assert(amount.is_non_zero(), Errors::INVALID_AMOUNT);
        self._assert_token_set();
 
        // Call mint on l2_token contract.
        IMintableTokenDispatcher { contract_address: self.l2_token.read() }.mint(account, amount);
 
        self.emit(Event::DepositHandled(DepositHandled { account, amount }));
    }
}


