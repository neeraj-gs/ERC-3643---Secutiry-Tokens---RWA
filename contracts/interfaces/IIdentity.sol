// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IIdentity
 * @dev Interface for OnchainID Identity contracts
 */
interface IIdentity {
    
    // Events
    event KeyAdded(bytes32 indexed key, uint256 indexed purpose, uint256 indexed keyType);
    event KeyRemoved(bytes32 indexed key, uint256 indexed purpose, uint256 indexed keyType);
    event ClaimRequested(uint256 indexed claimRequestId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimAdded(bytes32 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimRemoved(bytes32 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimChanged(bytes32 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    
    // Key structure
    struct Key {
        uint256 purpose;
        uint256 keyType;
        bytes32 key;
    }
    
    // Claim structure  
    struct Claim {
        uint256 topic;
        uint256 scheme;
        address issuer;
        bytes signature;
        bytes data;
        string uri;
    }
    
    // Key management
    function getKey(bytes32 key) external view returns(uint256 purpose, uint256 keyType, bytes32 _key);
    function keyHasPurpose(bytes32 key, uint256 purpose) external view returns(bool exists);
    function getKeysByPurpose(uint256 purpose) external view returns(bytes32[] memory keys);
    function addKey(bytes32 key, uint256 purpose, uint256 keyType) external returns (bool success);
    function removeKey(bytes32 key, uint256 purpose) external returns (bool success);
    
    // Claim management
    function getClaim(bytes32 claimId) external view returns(uint256 topic, uint256 scheme, address issuer, bytes memory signature, bytes memory data, string memory uri);
    function getClaimIdsByTopic(uint256 topic) external view returns(bytes32[] memory claimIds);
    function addClaim(uint256 topic, uint256 scheme, address issuer, bytes calldata signature, bytes calldata data, string calldata uri) external returns (bytes32 claimRequestId);
    function removeClaim(bytes32 claimId) external returns (bool success);
    
    // Execution
    function execute(address to, uint256 value, bytes calldata data) external returns (uint256 executionId);
    function approve(uint256 id, bool approve) external returns (bool success);
} 