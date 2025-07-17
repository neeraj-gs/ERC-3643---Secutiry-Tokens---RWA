// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ICompliance.sol";

/**
 * @title Compliance
 * @dev Basic compliance implementation for ERC-3643
 */
contract Compliance is ICompliance, Ownable {
    
    // Token binding
    mapping(address => bool) private _tokensBound;
    
    // Agent management
    mapping(address => bool) private _agents;
    
    // Compliance modules
    address[] private _modules;
    mapping(address => bool) private _modulesList;
    
    // Compliance rules storage
    struct ComplianceRule {
        uint256 maxTokens;
        uint256 maxHolders;
        mapping(uint16 => bool) allowedCountries;
        mapping(address => uint256) holderTokens;
        address[] holders;
        uint256 currentHolders;
    }
    
    mapping(address => ComplianceRule) private _rules;
    
    modifier onlyAgent() {
        require(_agents[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }
    
    modifier onlyBoundToken() {
        require(_tokensBound[msg.sender], "Token not bound");
        _;
    }
    
    constructor() Ownable(msg.sender) {
        _agents[msg.sender] = true;
    }
    
    // Core compliance functions
    function canTransfer(address from, address to, uint256 amount) external view override returns (bool) {
        // Basic compliance checks
        ComplianceRule storage rule = _rules[msg.sender];
        
        // Check if this would exceed max tokens
        if (rule.maxTokens > 0 && amount > rule.maxTokens) {
            return false;
        }
        
        // Check if adding new holder would exceed max holders
        if (from != to && rule.holderTokens[to] == 0) {
            if (rule.maxHolders > 0 && rule.currentHolders >= rule.maxHolders) {
                return false;
            }
        }
        
        // Additional module checks can be added here
        for (uint256 i = 0; i < _modules.length; i++) {
            try ICompliance(_modules[i]).canTransfer(from, to, amount) returns (bool result) {
                if (!result) return false;
            } catch {
                // If module fails, consider it as rejection
                return false;
            }
        }
        
        return true;
    }
    
    function transferred(address from, address to, uint256 amount) external override onlyBoundToken {
        ComplianceRule storage rule = _rules[msg.sender];
        
        // Update holder tracking
        if (from != address(0)) {
            rule.holderTokens[from] -= amount;
            if (rule.holderTokens[from] == 0) {
                _removeHolder(msg.sender, from);
            }
        }
        
        if (to != address(0)) {
            bool wasZero = rule.holderTokens[to] == 0;
            rule.holderTokens[to] += amount;
            if (wasZero && rule.holderTokens[to] > 0) {
                _addHolder(msg.sender, to);
            }
        }
        
        // Notify modules
        for (uint256 i = 0; i < _modules.length; i++) {
            try ICompliance(_modules[i]).transferred(from, to, amount) {
                // Module notified successfully
            } catch {
                // Continue with other modules
            }
        }
    }
    
    function created(address to, uint256 amount) external override onlyBoundToken {
        ComplianceRule storage rule = _rules[msg.sender];
        
        bool wasZero = rule.holderTokens[to] == 0;
        rule.holderTokens[to] += amount;
        if (wasZero && rule.holderTokens[to] > 0) {
            _addHolder(msg.sender, to);
        }
        
        // Notify modules
        for (uint256 i = 0; i < _modules.length; i++) {
            try ICompliance(_modules[i]).created(to, amount) {
                // Module notified successfully
            } catch {
                // Continue with other modules
            }
        }
    }
    
    function destroyed(address from, uint256 amount) external override onlyBoundToken {
        ComplianceRule storage rule = _rules[msg.sender];
        
        rule.holderTokens[from] -= amount;
        if (rule.holderTokens[from] == 0) {
            _removeHolder(msg.sender, from);
        }
        
        // Notify modules
        for (uint256 i = 0; i < _modules.length; i++) {
            try ICompliance(_modules[i]).destroyed(from, amount) {
                // Module notified successfully
            } catch {
                // Continue with other modules
            }
        }
    }
    
    // Token binding
    function bindToken(address token) external override onlyAgent {
        require(!_tokensBound[token], "Token already bound");
        _tokensBound[token] = true;
        emit TokenBound(token);
    }
    
    function unbindToken(address token) external override onlyAgent {
        require(_tokensBound[token], "Token not bound");
        _tokensBound[token] = false;
        
        // Clean up rules
        ComplianceRule storage rule = _rules[token];
        delete _rules[token];
        
        emit TokenUnbound(token);
    }
    
    function isTokenBound(address token) external view override returns (bool) {
        return _tokensBound[token];
    }
    
    // Agent management
    function addTokenAgent(address agent) external override onlyOwner {
        _agents[agent] = true;
        emit TokenAgentAdded(agent);
    }
    
    function removeTokenAgent(address agent) external override onlyOwner {
        _agents[agent] = false;
        emit TokenAgentRemoved(agent);
    }
    
    function isTokenAgent(address agent) external view override returns (bool) {
        return _agents[agent];
    }
    
    // Module management
    function addModule(address module) external override onlyOwner {
        require(module != address(0), "Invalid module address");
        require(!_modulesList[module], "Module already added");
        
        _modules.push(module);
        _modulesList[module] = true;
    }
    
    function removeModule(address module) external override onlyOwner {
        require(_modulesList[module], "Module not found");
        
        _modulesList[module] = false;
        
        // Remove from array
        for (uint256 i = 0; i < _modules.length; i++) {
            if (_modules[i] == module) {
                _modules[i] = _modules[_modules.length - 1];
                _modules.pop();
                break;
            }
        }
    }
    
    function getModules() external view override returns (address[] memory) {
        return _modules;
    }
    
    // Compliance rules management
    function setMaxTokens(address token, uint256 maxTokens) external onlyAgent {
        require(_tokensBound[token], "Token not bound");
        _rules[token].maxTokens = maxTokens;
    }
    
    function setMaxHolders(address token, uint256 maxHolders) external onlyAgent {
        require(_tokensBound[token], "Token not bound");
        _rules[token].maxHolders = maxHolders;
    }
    
    function addAllowedCountry(address token, uint16 country) external onlyAgent {
        require(_tokensBound[token], "Token not bound");
        _rules[token].allowedCountries[country] = true;
    }
    
    function removeAllowedCountry(address token, uint16 country) external onlyAgent {
        require(_tokensBound[token], "Token not bound");
        _rules[token].allowedCountries[country] = false;
    }
    
    function isCountryAllowed(address token, uint16 country) external view returns (bool) {
        return _rules[token].allowedCountries[country];
    }
    
    function getHolderCount(address token) external view returns (uint256) {
        return _rules[token].currentHolders;
    }
    
    function getHolders(address token) external view returns (address[] memory) {
        return _rules[token].holders;
    }
    
    function getHolderTokens(address token, address holder) external view returns (uint256) {
        return _rules[token].holderTokens[holder];
    }
    
    // Internal functions
    function _addHolder(address token, address holder) internal {
        ComplianceRule storage rule = _rules[token];
        rule.holders.push(holder);
        rule.currentHolders++;
    }
    
    function _removeHolder(address token, address holder) internal {
        ComplianceRule storage rule = _rules[token];
        
        // Find and remove holder
        for (uint256 i = 0; i < rule.holders.length; i++) {
            if (rule.holders[i] == holder) {
                rule.holders[i] = rule.holders[rule.holders.length - 1];
                rule.holders.pop();
                rule.currentHolders--;
                break;
            }
        }
    }
} 