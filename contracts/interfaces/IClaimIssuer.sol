// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IClaimIssuer
 * @dev Interface for claim issuers in the ERC-3643 ecosystem
 */
interface IClaimIssuer {
    
    // Events
    event ClaimRequested(uint256 indexed claimRequestId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimAdded(bytes32 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimRemoved(bytes32 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimChanged(bytes32 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    
    // Claim structure
    struct Claim {
        uint256 topic;
        uint256 scheme;
        address issuer;
        bytes signature;
        bytes data;
        string uri;
    }
    
    // Functions
    function getClaim(bytes32 claimId) external view returns(uint256 topic, uint256 scheme, address issuer, bytes memory signature, bytes memory data, string memory uri);
    function getClaimIdsByTopic(uint256 topic) external view returns(bytes32[] memory claimIds);
    function addClaim(uint256 topic, uint256 scheme, address issuer, bytes calldata signature, bytes calldata data, string calldata uri) external returns (bytes32 claimRequestId);
    function removeClaim(bytes32 claimId) external returns (bool success);
    
    function revokeClaim(bytes32 claimId, address identity) external returns(bool);
    function getRecoveredAddress(bytes calldata signature, bytes32 dataHash) external pure returns (address);
    function isClaimValid(address identity, uint256 claimTopic, bytes calldata sig, bytes calldata data) external view returns (bool);
} 