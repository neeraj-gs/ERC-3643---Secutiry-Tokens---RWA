// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IIdentityRegistry
 * @dev Interface for the Identity Registry contract
 */
interface IIdentityRegistry {
    
    // Events
    event IdentityStored(address indexed investorAddress, address indexed identity);
    event IdentityRemoved(address indexed investorAddress, address indexed identity);
    event IdentityModified(address indexed oldIdentity, address indexed newIdentity);
    event CountryModified(address indexed investorAddress, uint16 indexed country);
    event IdentityRegistryBound(address indexed identityRegistry);
    
    // Functions
    function registerIdentity(address userAddress, address identity, uint16 country) external;
    function removeIdentity(address userAddress) external;
    function updateIdentity(address userAddress, address identity) external;
    function updateCountry(address userAddress, uint16 country) external;
    
    function identity(address userAddress) external view returns (address);
    function investorCountry(address userAddress) external view returns (uint16);
    function isVerified(address userAddress) external view returns (bool);
    
    function contains(address userAddress) external view returns (bool);
    function batchRegisterIdentity(address[] calldata userAddresses, address[] calldata identities, uint16[] calldata countries) external;
} 