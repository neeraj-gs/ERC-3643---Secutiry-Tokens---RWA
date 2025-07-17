// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IIdentityRegistry.sol";
import "./interfaces/IIdentity.sol";
import "./interfaces/IClaimIssuer.sol";

/**
 * @title IdentityRegistry
 * @dev Implementation of identity registry for ERC-3643
 */
contract IdentityRegistry is IIdentityRegistry, Ownable {
    
    // Storage mappings
    mapping(address => address) private _identities;
    mapping(address => uint16) private _countries;
    mapping(address => bool) private _agents;
    
    // Trusted claim topics and issuers
    address[] private _claimTopicsRegistry;
    address[] private _claimIssuersRegistry;
    
    mapping(uint256 => bool) private _claimTopics;
    mapping(address => bool) private _claimIssuers;
    
    modifier onlyAgent() {
        require(_agents[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }
    
    constructor() Ownable(msg.sender) {
        _agents[msg.sender] = true;
    }
    
    // Identity management
    function registerIdentity(
        address userAddress, 
        address identity, 
        uint16 country
    ) external override onlyAgent {
        require(userAddress != address(0), "Invalid user address");
        require(identity != address(0), "Invalid identity address");
        
        _identities[userAddress] = identity;
        _countries[userAddress] = country;
        
        emit IdentityStored(userAddress, identity);
    }
    
    function removeIdentity(address userAddress) external override onlyAgent {
        address identity = _identities[userAddress];
        require(identity != address(0), "Identity not found");
        
        delete _identities[userAddress];
        delete _countries[userAddress];
        
        emit IdentityRemoved(userAddress, identity);
    }
    
    function updateIdentity(address userAddress, address newIdentity) external override onlyAgent {
        require(_identities[userAddress] != address(0), "Identity not found");
        require(newIdentity != address(0), "Invalid new identity");
        
        address oldIdentity = _identities[userAddress];
        _identities[userAddress] = newIdentity;
        
        emit IdentityModified(oldIdentity, newIdentity);
    }
    
    function updateCountry(address userAddress, uint16 country) external override onlyAgent {
        require(_identities[userAddress] != address(0), "Identity not found");
        
        _countries[userAddress] = country;
        emit CountryModified(userAddress, country);
    }
    
    // Batch operations
    function batchRegisterIdentity(
        address[] calldata userAddresses,
        address[] calldata identities,
        uint16[] calldata countries
    ) external override onlyAgent {
        require(
            userAddresses.length == identities.length && 
            identities.length == countries.length,
            "Arrays length mismatch"
        );
        
        for (uint256 i = 0; i < userAddresses.length; i++) {
            registerIdentity(userAddresses[i], identities[i], countries[i]);
        }
    }
    
    // View functions
    function identity(address userAddress) external view override returns (address) {
        return _identities[userAddress];
    }
    
    function investorCountry(address userAddress) external view override returns (uint16) {
        return _countries[userAddress];
    }
    
    function contains(address userAddress) external view override returns (bool) {
        return _identities[userAddress] != address(0);
    }
    
    function isVerified(address userAddress) external view override returns (bool) {
        address identityContract = _identities[userAddress];
        if (identityContract == address(0)) {
            return false;
        }
        
        // Check if identity has all required claims
        for (uint256 i = 0; i < _claimTopicsRegistry.length; i++) {
            if (!_hasValidClaim(identityContract, uint256(uint160(_claimTopicsRegistry[i])))) {
                return false;
            }
        }
        
        return true;
    }
    
    // Claim topics management
    function addClaimTopic(uint256 claimTopic) external onlyOwner {
        require(!_claimTopics[claimTopic], "Claim topic already exists");
        _claimTopics[claimTopic] = true;
        _claimTopicsRegistry.push(address(uint160(claimTopic)));
    }
    
    function removeClaimTopic(uint256 claimTopic) external onlyOwner {
        require(_claimTopics[claimTopic], "Claim topic does not exist");
        _claimTopics[claimTopic] = false;
        
        // Remove from array
        for (uint256 i = 0; i < _claimTopicsRegistry.length; i++) {
            if (uint256(uint160(_claimTopicsRegistry[i])) == claimTopic) {
                _claimTopicsRegistry[i] = _claimTopicsRegistry[_claimTopicsRegistry.length - 1];
                _claimTopicsRegistry.pop();
                break;
            }
        }
    }
    
    // Claim issuers management
    function addClaimIssuer(address claimIssuer) external onlyOwner {
        require(claimIssuer != address(0), "Invalid claim issuer");
        require(!_claimIssuers[claimIssuer], "Claim issuer already exists");
        
        _claimIssuers[claimIssuer] = true;
        _claimIssuersRegistry.push(claimIssuer);
    }
    
    function removeClaimIssuer(address claimIssuer) external onlyOwner {
        require(_claimIssuers[claimIssuer], "Claim issuer does not exist");
        _claimIssuers[claimIssuer] = false;
        
        // Remove from array
        for (uint256 i = 0; i < _claimIssuersRegistry.length; i++) {
            if (_claimIssuersRegistry[i] == claimIssuer) {
                _claimIssuersRegistry[i] = _claimIssuersRegistry[_claimIssuersRegistry.length - 1];
                _claimIssuersRegistry.pop();
                break;
            }
        }
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
    
    // Helper functions
    function _hasValidClaim(address identityContract, uint256 claimTopic) private view returns (bool) {
        if (identityContract == address(0)) return false;
        
        try IIdentity(identityContract).getClaimIdsByTopic(claimTopic) returns (bytes32[] memory claimIds) {
            if (claimIds.length == 0) return false;
            
            // Check if at least one claim is valid and from a trusted issuer
            for (uint256 i = 0; i < claimIds.length; i++) {
                try IIdentity(identityContract).getClaim(claimIds[i]) returns (
                    uint256 topic,
                    uint256 scheme,
                    address issuer,
                    bytes memory signature,
                    bytes memory data,
                    string memory uri
                ) {
                    if (_claimIssuers[issuer]) {
                        // Additional validation could be performed here
                        return true;
                    }
                } catch {
                    // Continue to next claim
                    continue;
                }
            }
        } catch {
            return false;
        }
        
        return false;
    }
    
    // View functions for claim topics and issuers
    function getClaimTopics() external view returns (address[] memory) {
        return _claimTopicsRegistry;
    }
    
    function getClaimIssuers() external view returns (address[] memory) {
        return _claimIssuersRegistry;
    }
    
    function isClaimTopicSupported(uint256 claimTopic) external view returns (bool) {
        return _claimTopics[claimTopic];
    }
    
    function isClaimIssuerTrusted(address claimIssuer) external view returns (bool) {
        return _claimIssuers[claimIssuer];
    }
} 