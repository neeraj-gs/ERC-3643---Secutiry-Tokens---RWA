// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title ICompliance
 * @dev Interface for compliance modules
 */
interface ICompliance {
    
    // Events  
    event TokenAgentAdded(address indexed agent);
    event TokenAgentRemoved(address indexed agent);
    event TokenBound(address indexed token);
    event TokenUnbound(address indexed token);
    
    // Core compliance functions
    function canTransfer(address from, address to, uint256 amount) external view returns (bool);
    function transferred(address from, address to, uint256 amount) external;
    function created(address to, uint256 amount) external;
    function destroyed(address from, uint256 amount) external;
    
    // Token binding
    function bindToken(address token) external;
    function unbindToken(address token) external;
    function isTokenBound(address token) external view returns (bool);
    
    // Agent management
    function addTokenAgent(address agent) external;
    function removeTokenAgent(address agent) external;
    function isTokenAgent(address agent) external view returns (bool);
    
    // Module management
    function addModule(address module) external;
    function removeModule(address module) external;
    function getModules() external view returns (address[] memory);
} 