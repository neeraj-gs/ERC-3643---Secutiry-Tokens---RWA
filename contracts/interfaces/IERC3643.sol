// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IERC3643
 * @dev Interface for ERC3643 compliant security tokens
 */
interface IERC3643 is IERC20 {
    
    // Events
    event UpdatedTokenInformation(string newName, string newSymbol, uint8 newDecimals, string newVersion, address newOnchainID);
    event IdentityRegistryAdded(address indexed identityRegistry);
    event ComplianceAdded(address indexed compliance);
    event RecoverySuccess(address indexed lostWallet, address indexed newWallet, address indexed investorOnchainID);
    event AddressFrozen(address indexed addr, bool indexed isFrozen, address indexed owner);
    event TokensFrozen(address indexed addr, uint256 amount);
    event TokensUnfrozen(address indexed addr, uint256 amount);
    event Paused(address account);
    event Unpaused(address account);

    // Core functions
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function onchainID() external view returns (address);
    function version() external view returns (string memory);
    
    // Identity and Compliance
    function identityRegistry() external view returns (address);
    function compliance() external view returns (address);
    
    // Transfer restrictions
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    
    // Freeze functions
    function setAddressFrozen(address addr, bool freeze) external;
    function freezeTokens(address addr, uint256 amount) external;
    function unfreezeTokens(address addr, uint256 amount) external;
    function getFrozenTokens(address addr) external view returns (uint256);
    function isAddressFrozen(address addr) external view returns (bool);
    
    // Recovery
    function recoveryAddress(address lostWallet, address newWallet, address investorOnchainID) external returns (bool);
    
    // Mint and Burn (for authorized entities)
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    
    // Pause functionality
    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);
    
    // Batch operations
    function batchTransfer(address[] calldata to, uint256[] calldata amounts) external;
    function batchFreezeTokens(address[] calldata addresses, uint256[] calldata amounts) external;
    function batchUnfreezeTokens(address[] calldata addresses, uint256[] calldata amounts) external;
    function batchSetAddressFrozen(address[] calldata addresses, bool[] calldata freeze) external;
} 