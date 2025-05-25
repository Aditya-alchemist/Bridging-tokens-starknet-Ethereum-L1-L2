// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";


 //0xeb4d8fac24de34e36d3e0f2a9fe11bc3ed6ba5d0
contract MintableTokenMock is ERC20 {
    address public bridge;
 
    
    error InvalidAddress();
 
  
    error Unauthorized();
 
   
    constructor(address _bridge) ERC20("Bridge Token", "BTK") {
        if (_bridge == address(0)) {
            revert InvalidAddress();
        }
        bridge = _bridge;
        _mint(msg.sender, 10e18);
    }
 
   
    modifier onlyBridge() {
        if (bridge != msg.sender) {
            revert Unauthorized();
        }
        _;
    }
 

    function mint(address account, uint256 amount) external onlyBridge {
        _mint(account, amount);
    }
 

    function burn(address account, uint256 amount) external onlyBridge {
        _burn(account, amount);
    }

   
    function setBridge(address newBridge) external onlyBridge {
        if (newBridge == address(0)) {
            revert InvalidAddress();
        }
        bridge = newBridge;
    }
}

interface IMintableToken {
    function burn(address from, uint256 amount) external;
    function mint(address to, uint256 amount) external;
}

interface IStarknetMessaging {
    function sendMessageToL2(
        uint256 to_address,
        uint256 selector,
        uint256[] calldata payload
    ) external payable;

    function consumeMessageFromL2(
        uint256 fromAddress,
        uint256[] calldata payload
    ) external;
}



 //0x7b5539a556d5bbbaeedf047e0c89ef85133ca7f1
contract TokenBridge {
    address public governor;
    IMintableToken public token;
    IStarknetMessaging public snMessaging;
    uint256 public l2Bridge;
    uint256 public l2HandlerSelector;

    error InvalidAmount();
    error InvalidAddress(string param);
    error InvalidRecipient();
    error InvalidSelector();
    error OnlyGovernor();
    error UninitializedL2Bridge();
    error UninitializedToken();

    event L2BridgeSet(uint256 indexed l2Bridge);
    event TokenSet(address indexed token);
    event SelectorSet(uint256 indexed selector);
    event BridgedToL2(address indexed sender, uint256 indexed recipient, uint256 amount);
    event WithdrawnFromL2(uint256 indexed fromAddress, address indexed recipient, uint256 amount);
    event GovernorUpdated(address indexed oldGovernor, address indexed newGovernor);

    constructor(
        address _governor,
        address _snMessaging,
        uint256 _l2HandlerSelector
    ) {
        if (_governor == address(0)) revert InvalidAddress("_governor");
        if (_snMessaging == address(0)) revert InvalidAddress("_snMessaging");
        if (_l2HandlerSelector == 0) revert InvalidSelector();

        governor = _governor;
        snMessaging = IStarknetMessaging(_snMessaging);
        l2HandlerSelector = _l2HandlerSelector;
    }

    modifier onlyGovernor() {
        if (msg.sender != governor) revert OnlyGovernor();
        _;
    }

    modifier onlyWhenL2BridgeInitialized() {
        if (l2Bridge == 0) revert UninitializedL2Bridge();
        _;
    }

    modifier onlyWhenTokenInitialized() {
        if (address(token) == address(0)) revert UninitializedToken();
        _;
    }

   
    function setL2Bridge(uint256 newL2Bridge) external onlyGovernor {
        if (newL2Bridge == 0) revert InvalidAddress("newL2Bridge");
        l2Bridge = newL2Bridge;
        emit L2BridgeSet(newL2Bridge);
    }

  
    function setToken(address newToken) external onlyGovernor {
        if (newToken == address(0)) revert InvalidAddress("newToken");
        token = IMintableToken(newToken);
        emit TokenSet(newToken);
    }

   
    function setL2HandlerSelector(uint256 newSelector) external onlyGovernor {
        if (newSelector == 0) revert InvalidSelector();
        l2HandlerSelector = newSelector;
        emit SelectorSet(newSelector);
    }


    function bridgeToL2(
        uint256 recipientAddress,
        uint256 amount
    ) external payable onlyWhenL2BridgeInitialized onlyWhenTokenInitialized {
        if (recipientAddress == 0) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();

        (uint128 low, uint128 high) = splitUint256(amount);

        uint256[] memory payload = new uint256[](3);
        payload[0] = recipientAddress;
        payload[1] = uint256(low);
        payload[2] = uint256(high);

        token.burn(msg.sender, amount);

        snMessaging.sendMessageToL2{value: msg.value}(
            l2Bridge,
            l2HandlerSelector,
            payload
        );

        emit BridgedToL2(msg.sender, recipientAddress, amount);
    }

   
    function consumeWithdrawal(
        uint256 fromAddress,
        address recipient,
        uint128 low,
        uint128 high
    ) external onlyWhenTokenInitialized {
        if (recipient == address(0)) revert InvalidAddress("recipient");
        
        uint256[] memory payload = new uint256[](3);
        payload[0] = uint256(uint160(recipient));
        payload[1] = uint256(low);
        payload[2] = uint256(high);

        snMessaging.consumeMessageFromL2(fromAddress, payload);

        uint256 amount = (uint256(high) << 128) | uint256(low);
        if (amount == 0) revert InvalidAmount();
        
        token.mint(recipient, amount);

        emit WithdrawnFromL2(fromAddress, recipient, amount);
    }


    function splitUint256(
        uint256 value
    ) private pure returns (uint128 low, uint128 high) {
        low = uint128(value & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
        high = uint128(value >> 128);
    }

   
    function setGovernor(address newGovernor) external onlyGovernor {
        if (newGovernor == address(0)) revert InvalidAddress("newGovernor");
        address oldGovernor = governor;
        governor = newGovernor;
        emit GovernorUpdated(oldGovernor, newGovernor);
    }

 
    function recoverETH() external onlyGovernor {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(governor).call{value: balance}("");
            require(success, "ETH transfer failed");
        }
    }

    function getConfiguration() 
        external 
        view 
        returns (
            address _governor,
            address _token,
            address _snMessaging,
            uint256 _l2Bridge,
            uint256 _l2HandlerSelector
        ) 
    {
        return (
            governor,
            address(token),
            address(snMessaging),
            l2Bridge,
            l2HandlerSelector
        );
    }
}