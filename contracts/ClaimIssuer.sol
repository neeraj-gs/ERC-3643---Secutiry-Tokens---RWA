// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IClaimIssuer.sol";
import "./interfaces/IIdentity.sol";

/**
 * @title ClaimIssuer
 * @dev Implementation of claim issuer for ERC-3643 compliance
 */
contract ClaimIssuer is IClaimIssuer, Ownable {
    
    // Claim topics this issuer can issue
    mapping(uint256 => bool) private _claimTopics;
    uint256[] private _claimTopicsArray;
    
    // Revoked claims
    mapping(bytes32 => bool) private _revokedClaims;
    
    // Claim issuance tracking
    mapping(address => mapping(uint256 => bytes32)) private _issuedClaims;
    
    event ClaimTopicAdded(uint256 indexed topic);
    event ClaimTopicRemoved(uint256 indexed topic);
    event ClaimIssued(address indexed identity, uint256 indexed topic, bytes32 indexed claimId);
    event ClaimRevoked(bytes32 indexed claimId);
    
    modifier onlyValidTopic(uint256 topic) {
        require(_claimTopics[topic], "Invalid claim topic");
        _;
    }
    
    constructor() Ownable(msg.sender) {
        // Default claim topics for KYC/AML
        _addClaimTopic(1); // KYC verification
        _addClaimTopic(2); // AML verification
        _addClaimTopic(3); // Accredited investor
    }
    
    // Claim topic management
    function addClaimTopic(uint256 topic) external onlyOwner {
        _addClaimTopic(topic);
    }
    
    function removeClaimTopic(uint256 topic) external onlyOwner {
        require(_claimTopics[topic], "Topic does not exist");
        _claimTopics[topic] = false;
        
        // Remove from array
        for (uint256 i = 0; i < _claimTopicsArray.length; i++) {
            if (_claimTopicsArray[i] == topic) {
                _claimTopicsArray[i] = _claimTopicsArray[_claimTopicsArray.length - 1];
                _claimTopicsArray.pop();
                break;
            }
        }
        
        emit ClaimTopicRemoved(topic);
    }
    
    function getClaimTopics() external view override returns (uint256[] memory) {
        return _claimTopicsArray;
    }
    
    function isClaimTopic(uint256 topic) external view override returns (bool) {
        return _claimTopics[topic];
    }
    
    // Claim issuance
    function issueClaim(
        address identity,
        uint256 topic,
        uint256 scheme,
        bytes calldata data,
        string calldata uri
    ) external override onlyOwner onlyValidTopic(topic) {
        require(identity != address(0), "Invalid identity address");
        
        // Create claim hash
        bytes32 claimId = keccak256(abi.encodePacked(identity, topic, data));
        
        // Check if claim already exists
        require(_issuedClaims[identity][topic] == bytes32(0), "Claim already exists");
        
        // Store claim reference
        _issuedClaims[identity][topic] = claimId;
        
        // Create signature
        bytes memory signature = _signClaim(identity, topic, scheme, data, uri);
        
        // Add claim to identity contract
        try IIdentity(identity).addClaim(topic, scheme, address(this), signature, data, uri) returns (bytes32 returnedClaimId) {
            require(returnedClaimId == claimId, "Claim ID mismatch");
            emit ClaimIssued(identity, topic, claimId);
        } catch {
            // Clean up if identity contract call fails
            delete _issuedClaims[identity][topic];
            revert("Failed to add claim to identity");
        }
    }
    
    function revokeClaim(bytes32 claimId, address identity) external override onlyOwner {
        require(claimId != bytes32(0), "Invalid claim ID");
        require(!_revokedClaims[claimId], "Claim already revoked");
        
        _revokedClaims[claimId] = true;
        
        // Remove from identity contract
        try IIdentity(identity).removeClaim(claimId) {
            emit ClaimRevoked(claimId);
        } catch {
            // Continue even if identity contract call fails
            emit ClaimRevoked(claimId);
        }
    }
    
    function revokeClaimByTopic(address identity, uint256 topic) external onlyOwner {
        require(identity != address(0), "Invalid identity address");
        require(_claimTopics[topic], "Invalid claim topic");
        
        bytes32 claimId = _issuedClaims[identity][topic];
        require(claimId != bytes32(0), "Claim not found");
        
        revokeClaim(claimId, identity);
        delete _issuedClaims[identity][topic];
    }
    
    function isClaimRevoked(bytes32 claimId) external view override returns (bool) {
        return _revokedClaims[claimId];
    }
    
    function isClaimValid(address identity, uint256 topic, bytes calldata signature, bytes calldata data) external view override returns (bool) {
        if (!_claimTopics[topic]) return false;
        
        bytes32 claimId = _issuedClaims[identity][topic];
        if (claimId == bytes32(0)) return false;
        if (_revokedClaims[claimId]) return false;
        
        // Verify signature
        bytes32 hash = keccak256(abi.encodePacked(identity, topic, data));
        return _verifySignature(hash, signature);
    }
    
    // Batch operations
    function batchIssueClaims(
        address[] calldata identities,
        uint256[] calldata topics,
        uint256[] calldata schemes,
        bytes[] calldata dataArray,
        string[] calldata uris
    ) external onlyOwner {
        require(
            identities.length == topics.length &&
            topics.length == schemes.length &&
            schemes.length == dataArray.length &&
            dataArray.length == uris.length,
            "Arrays length mismatch"
        );
        
        for (uint256 i = 0; i < identities.length; i++) {
            issueClaim(identities[i], topics[i], schemes[i], dataArray[i], uris[i]);
        }
    }
    
    function batchRevokeClaims(bytes32[] calldata claimIds, address[] calldata identities) external onlyOwner {
        require(claimIds.length == identities.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < claimIds.length; i++) {
            revokeClaim(claimIds[i], identities[i]);
        }
    }
    
    // Helper functions
    function _addClaimTopic(uint256 topic) private {
        require(!_claimTopics[topic], "Topic already exists");
        _claimTopics[topic] = true;
        _claimTopicsArray.push(topic);
        emit ClaimTopicAdded(topic);
    }
    
    function _signClaim(
        address identity,
        uint256 topic,
        uint256 scheme,
        bytes calldata data,
        string calldata uri
    ) private view returns (bytes memory) {
        bytes32 hash = keccak256(abi.encodePacked(identity, topic, scheme, data, uri));
        return abi.encodePacked(hash);
    }
    
    function _verifySignature(bytes32 hash, bytes calldata signature) private pure returns (bool) {
        // Basic signature verification
        // In a real implementation, this would verify the signature using ECDSA
        return signature.length > 0 && hash != bytes32(0);
    }
    
    // View functions
    function getClaimId(address identity, uint256 topic) external view returns (bytes32) {
        return _issuedClaims[identity][topic];
    }
    
    function hasClaimTopic(address identity, uint256 topic) external view returns (bool) {
        return _issuedClaims[identity][topic] != bytes32(0) && !_revokedClaims[_issuedClaims[identity][topic]];
    }
} 