# 🌉 Ethereum ↔ Starknet Token Bridging

A full-stack implementation of token bridging between **Ethereum (L1)** and **Starknet (L2)** using Solidity and Cairo 1.0.

---

## 🔎 What is Bridging?

> Bridging moves token *representation* between blockchains — not actual tokens.

In this project:

* **L1**: Ethereum Mainnet — handles original tokens
* **L2**: Starknet — scalable ZK-rollup that mirrors tokens

### Why?

* 🚀 **Scalability**: L2 is faster & cheaper
* 🔄 **Interoperability**: Seamlessly move assets across chains
* 🔗 **Access**: DeFi apps live on both L1 and L2

---

## 🧠 How Bridging Works

> Bridging is a **Lock & Mint / Burn & Unlock** process

### L1 → L2 (Deposit)

1. Burn tokens on Ethereum (L1)
2. Send message to Starknet (L2)
3. Mint tokens on L2

### L2 → L1 (Withdraw)

1. Burn tokens on Starknet (L2)
2. Send message to Ethereum (L1)
3. Mint tokens on L1

---

## 📊 Bridging Flowchart

```mermaid
flowchart LR
    %% Ethereum L1 Side
    subgraph EthereumL1["Ethereum L1"]
        A1["User Wallet (L1)"]
        A2["MintableToken.sol"]
        A3["TokenBridge.sol"]
    end
    
    %% StarkNet L2 Side  
    subgraph StarkNetL2["StarkNet L2"]
        B1["User Wallet (L2)"]
        B2["MintableToken.cairo"]
        B3["TokenBridge.cairo"]
    end
    
    %% L1 → L2 Deposit Flow
    A1 -.->|"🔽 Call bridgeToL2"| A3
    A3 -.->|"🔥 Burn tokens"| A2
    A3 ==>|"📨 Send msg to L2"| B3
    B3 -.->|"⚡ Handle deposit"| B2
    B2 -.->|"✨ Mint tokens"| B1
    
    %% L2 → L1 Withdraw Flow
    B1 -.->|"🔼 Call bridge_to_l1"| B3
    B3 -.->|"🔥 Burn tokens"| B2
    B3 ==>|"📨 Send msg to L1"| A3
    A3 -.->|"📥 Consume msg"| A2
    A2 -.->|"✨ Mint tokens"| A1
    
    %% Styling
    classDef l1Color fill:#4fc3f7,stroke:#0277bd,stroke-width:2px,color:#000
    classDef l2Color fill:#ba68c8,stroke:#7b1fa2,stroke-width:2px,color:#fff
    classDef bridgeColor fill:#ff7043,stroke:#d84315,stroke-width:3px,color:#fff
    classDef walletColor fill:#66bb6a,stroke:#2e7d32,stroke-width:2px,color:#fff
    
    class A2,B2 bridgeColor
    class A3,B3 bridgeColor
    class A1,B1 walletColor
```

---

## 🏗️ Architecture Overview

```
┌─────────────────┐    Messaging     ┌────────────────────┐
│   Ethereum L1   │ ◄──────────────►│    Starknet L2     │
│                 │                 │                    │
│ TokenBridge.sol │                 │ TokenBridge.cairo  │
│ MintableToken   │                 │ MintableToken.cairo│
└─────────────────┘                 └────────────────────┘
```

---

## 🔩 Components

### 📦 Tokens

* ERC20 token on L1
* Mintable token on L2

### 🔗 Bridge Contracts

* Solidity-based bridge on L1
* Cairo-based bridge on L2

### 📬 Messaging

* `sendMessageToL2` on L1
* `send_message_to_l1_syscall` on L2

---

## 🧪 Bridging Outputs

| Preview                                                                              | Caption                                      |
| ------------------------------------------------------------------------------------ | -------------------------------------------- |
| ![](https://github.com/user-attachments/assets/41540c06-1559-4caf-bbd9-164258af4783) | **Figure 1**: Bridging Tokens to L2 from L1  |
| ![](https://github.com/user-attachments/assets/315fd16c-7087-44d8-8645-c372d9a0d882) | **Figure 2**: Tokens Received on Starknet L2 |
| ![](https://github.com/user-attachments/assets/f9bab844-9504-4529-9321-a29c3f0de9e0) | **Figure 3**: Tokens Reflected in Wallet     |
| ![](https://github.com/user-attachments/assets/160a8666-cc7a-4b58-9fad-6c9fa77d1b90) | **Figure 4**: Bridging Back to Ethereum      |
| ![](https://github.com/user-attachments/assets/58b3a0b3-31bd-4afb-b04a-feb1b06b4902) | **Figure 5**: Final Confirmation on L1       |

---

## ⚙️ Core Functions

### 📤 L2 → L1 Withdrawal

```cairo
fn bridge_to_l1(ref self: ContractState, l1_recipient: EthAddress, amount: u256) {
    // Burn on L2
    IMintableTokenDispatcher { contract_address: self.l2_token.read() }
        .burn(caller_address, amount);

    // Message L1
    let mut payload: Array<felt252> = array![
        l1_recipient.into(), amount.low.into(), amount.high.into(),
    ];
    syscalls::send_message_to_l1_syscall(self.l1_bridge.read(), payload.span()).unwrap_syscall();
}
```

### 📥 L1 → L2 Deposit Handler

```cairo
#[l1_handler]
pub fn handle_deposit(ref self: ContractState, from_address: felt252, account: ContractAddress, amount: u256) {
    assert(from_address == self.l1_bridge.read(), Errors::EXPECTED_FROM_BRIDGE_ONLY);
    IMintableTokenDispatcher { contract_address: self.l2_token.read() }.mint(account, amount);
}
```

### 🧨 L1 Deposit to L2

```solidity
function bridgeToL2(uint256 recipientAddress, uint256 amount) external payable {
    token.burn(msg.sender, amount);
    (uint128 low, uint128 high) = splitUint256(amount);

    uint256[] memory payload = new uint256[](3);
    payload[0] = recipientAddress;
    payload[1] = low;
    payload[2] = high;

    snMessaging.sendMessageToL2{value: msg.value}(
        l2Bridge,
        l2HandlerSelector,
        payload
    );
}
```

### ✅ L1 Consumes Withdrawal

```solidity
function consumeWithdrawal(uint256 fromAddress, address recipient, uint128 low, uint128 high) external {
    uint256[] memory payload = new uint256[](3);
    payload[0] = uint256(uint160(recipient));
    payload[1] = uint256(low);
    payload[2] = uint256(high);

    snMessaging.consumeMessageFromL2(fromAddress, payload);
    uint256 amount = (uint256(high) << 128) | uint256(low);
    token.mint(recipient, amount);
}
```

---

## 📐 Serialization: `uint256` in Cairo

```solidity
function splitUint256(uint256 value) private pure returns (uint128 low, uint128 high) {
    low = uint128(value & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    high = uint128(value >> 128);
}
```

```cairo
// Recombined using u256 struct in Cairo
let amount = u256_from_words(low, high);
```

---

## 🛠️ Dev Tips & Best Practices

* ✅ Always validate source: `assert(from_address == self.l1_bridge.read())`
* 🔐 Mint/burn permissions must be tightly controlled
* 💡 Emit events for all cross-chain state changes
* ⏳ L2 → L1 may require hours (proof generation)

---

## 🧪 Testing Strategy

* Unit test: mint/burn, serialization, access control
* Integration test: complete bridge cycle
* Failure test: invalid selectors, mismatched amounts

---

## ⚠️ Gotchas

* ❌ L2 → L1 messages aren't auto-processed: user must call `consumeWithdrawal`
* ⚙️ Use `uint128` chunks for all messaging payloads
* 🚨 L1 handler selector mismatch will silently fail

---

## 📚 Conclusion

This repo shows how to bridge ERC20-like tokens securely between Ethereum and Starknet using minimal, composable smart contracts. You can extend it with:

* zk-proof verification for withdrawals
* on-chain receipts and history
* batch bridging

PRs & stars welcome ⭐
