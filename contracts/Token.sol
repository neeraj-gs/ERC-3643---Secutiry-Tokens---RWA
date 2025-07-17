// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IERC3643.sol";
import "./interfaces/IIdentityRegistry.sol";
import "./interfaces/ICompliance.sol";

/**
 * @title Token
 * @dev ERC-3643 compliant security token implementation
 */
contract Token is ERC20, Ownable, Pausable, IERC3643 {
    
    // Token information
    string private _version;
    address private _onchainID;
    uint8 private _decimals;
    
    // Core contracts
    IIdentityRegistry private _identityRegistry;
    ICompliance private _compliance;
    
    // Frozen addresses and tokens
    mapping(address => bool) private _frozenAddresses;
    mapping(address => uint256) private _frozenTokens;
    
    // Agent roles
    mapping(address => bool) private _agents;
    
    // Modifiers
    modifier onlyAgent() {
        require(_agents[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }
    
    modifier canTransfer(address from, address to, uint256 amount) {
        require(!paused(), "Token is paused");
        require(!_frozenAddresses[from], "Sender address is frozen");
        require(!_frozenAddresses[to], "Receiver address is frozen");
        require(balanceOf(from) - _frozenTokens[from] >= amount, "Insufficient unfrozen balance");
        
        if (from != address(0) && to != address(0)) {
            require(_identityRegistry.isVerified(to), "Receiver not verified");
            require(_compliance.canTransfer(from, to, amount), "Transfer not compliant");
        }
        _;
    }
    
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        address onchainID,
        address identityRegistry,
        address compliance
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _decimals = decimals_;
        _onchainID = onchainID;
        _version = "4.0.0";
        _identityRegistry = IIdentityRegistry(identityRegistry);
        _compliance = ICompliance(compliance);
        _agents[msg.sender] = true;
        
        emit IdentityRegistryAdded(identityRegistry);
        emit ComplianceAdded(compliance);
    }
    
    // Override required functions
    function decimals() public view override(ERC20, IERC3643) returns (uint8) {
        return _decimals;
    }
    
    function name() public view override(ERC20, IERC3643) returns (string memory) {
        return super.name();
    }
    
    function symbol() public view override(ERC20, IERC3643) returns (string memory) {
        return super.symbol();
    }
    
    // ERC-3643 specific functions
    function version() external view override returns (string memory) {
        return _version;
    }
    
    function onchainID() external view override returns (address) {
        return _onchainID;
    }
    
    function identityRegistry() external view override returns (address) {
        return address(_identityRegistry);
    }
    
    function compliance() external view override returns (address) {
        return address(_compliance);
    }
    
    // Transfer functions with compliance checks
    function transfer(address to, uint256 amount) 
        public 
        override(ERC20, IERC3643) 
        canTransfer(msg.sender, to, amount) 
        returns (bool) 
    {
        bool success = super.transfer(to, amount);
        if (success) {
            _compliance.transferred(msg.sender, to, amount);
        }
        return success;
    }
    
    function transferFrom(address from, address to, uint256 amount) 
        public 
        override(ERC20, IERC3643) 
        canTransfer(from, to, amount) 
        returns (bool) 
    {
        bool success = super.transferFrom(from, to, amount);
        if (success) {
            _compliance.transferred(from, to, amount);
        }
        return success;
    }
    
    // Batch transfer
    function batchTransfer(address[] calldata to, uint256[] calldata amounts) external override {
        require(to.length == amounts.length, "Arrays length mismatch");
        for (uint256 i = 0; i < to.length; i++) {
            transfer(to[i], amounts[i]);
        }
    }
    
    // Freeze functions
    function setAddressFrozen(address addr, bool freeze) external override onlyAgent {
        _frozenAddresses[addr] = freeze;
        emit AddressFrozen(addr, freeze, msg.sender);
    }
    
    function freezeTokens(address addr, uint256 amount) external override onlyAgent {
        require(amount <= balanceOf(addr), "Amount exceeds balance");
        _frozenTokens[addr] += amount;
        emit TokensFrozen(addr, amount);
    }
    
    function unfreezeTokens(address addr, uint256 amount) external override onlyAgent {
        require(amount <= _frozenTokens[addr], "Amount exceeds frozen tokens");
        _frozenTokens[addr] -= amount;
        emit TokensUnfrozen(addr, amount);
    }
    
    function batchFreezeTokens(address[] calldata addresses, uint256[] calldata amounts) external override onlyAgent {
        require(addresses.length == amounts.length, "Arrays length mismatch");
        for (uint256 i = 0; i < addresses.length; i++) {
            freezeTokens(addresses[i], amounts[i]);
        }
    }
    
    function batchUnfreezeTokens(address[] calldata addresses, uint256[] calldata amounts) external override onlyAgent {
        require(addresses.length == amounts.length, "Arrays length mismatch");
        for (uint256 i = 0; i < addresses.length; i++) {
            unfreezeTokens(addresses[i], amounts[i]);
        }
    }
    
    function batchSetAddressFrozen(address[] calldata addresses, bool[] calldata freeze) external override onlyAgent {
        require(addresses.length == freeze.length, "Arrays length mismatch");
        for (uint256 i = 0; i < addresses.length; i++) {
            setAddressFrozen(addresses[i], freeze[i]);
        }
    }
    
    function isAddressFrozen(address addr) external view override returns (bool) {
        return _frozenAddresses[addr];
    }
    
    function getFrozenTokens(address addr) external view override returns (uint256) {
        return _frozenTokens[addr];
    }
    
    // Mint and burn functions
    function mint(address to, uint256 amount) external override onlyAgent {
        require(_identityRegistry.isVerified(to), "Receiver not verified");
        _mint(to, amount);
        _compliance.created(to, amount);
    }
    
    function burn(address from, uint256 amount) external override onlyAgent {
        require(balanceOf(from) - _frozenTokens[from] >= amount, "Insufficient unfrozen balance");
        _burn(from, amount);
        _compliance.destroyed(from, amount);
    }
    
    // Pause functions
    function pause() external override onlyAgent {
        _pause();
    }
    
    function unpause() external override onlyAgent {
        _unpause();
    }
    
    function paused() public view override(Pausable, IERC3643) returns (bool) {
        return super.paused();
    }
    
    // Recovery function
    function recoveryAddress(address lostWallet, address newWallet, address investorOnchainID) 
        external 
        override 
        onlyAgent 
        returns (bool) 
    {
        require(_identityRegistry.identity(lostWallet) == investorOnchainID, "Invalid identity");
        require(_identityRegistry.isVerified(newWallet), "New wallet not verified");
        
        uint256 balance = balanceOf(lostWallet);
        uint256 frozenTokens = _frozenTokens[lostWallet];
        
        // Transfer balance
        _transfer(lostWallet, newWallet, balance);
        
        // Transfer frozen tokens
        _frozenTokens[lostWallet] = 0;
        _frozenTokens[newWallet] += frozenTokens;
        
        emit RecoverySuccess(lostWallet, newWallet, investorOnchainID);
        return true;
    }
    
    // Agent management
    function addAgent(address agent) external onlyOwner {
        _agents[agent] = true;
    }
    
    function removeAgent(address agent) external onlyOwner {
        _agents[agent] = false;
    }
    
    function isAgent(address agent) external view returns (bool) {
        return _agents[agent];
    }
    
    // Update functions
    function setIdentityRegistry(address identityRegistry) external onlyOwner {
        _identityRegistry = IIdentityRegistry(identityRegistry);
        emit IdentityRegistryAdded(identityRegistry);
    }
    
    function setCompliance(address compliance) external onlyOwner {
        _compliance = ICompliance(compliance);
        emit ComplianceAdded(compliance);
    }
    
    function setOnchainID(address onchainID) external onlyOwner {
        _onchainID = onchainID;
    }
    
    function updateTokenInformation(
        string calldata newName, 
        string calldata newSymbol, 
        uint8 newDecimals, 
        string calldata newVersion, 
        address newOnchainID
    ) external onlyOwner {
        // Note: Changing name and symbol requires storage updates
        _decimals = newDecimals;
        _version = newVersion;
        _onchainID = newOnchainID;
        emit UpdatedTokenInformation(newName, newSymbol, newDecimals, newVersion, newOnchainID);
    }
} 