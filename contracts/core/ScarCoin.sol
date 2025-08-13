// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

interface IRitualRegistry {
    function validateAndConsumeNonce(bytes32 ritualId, bytes32 nonce) external returns (address agent);
}

contract ScarCoin is ERC20, AccessControl, EIP712, Pausable {
    bytes32 public constant MINT_TYPEHASH =
        keccak256("MintRitual(bytes32 ritualId,address to,uint256 amount,bytes32 nonce,uint256 deadline,bytes payloadHash)");

    address public registry;

    // Rate limiting
    uint256 public cooldownSeconds;
    uint256 public dailyCapAmount;
    mapping(address => uint256) public lastMintTimestamp;
    uint256 public currentDay;
    uint256 public dailyMintedAmount;

    event Pulse(address indexed from, address indexed to, uint256 value);
    event RitualTrigger(bytes32 indexed ritualId, address indexed to, uint256 amount, bytes payload);

    constructor(address registry_)
        ERC20("ScarCoin", "SCAR")
        EIP712("ScarCoin", "1")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        registry = registry_;
        cooldownSeconds = 60; // Default 1 minute cooldown
        dailyCapAmount = 1000 * (10**decimals()); // Default 1000 token daily cap
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {
        emit Pulse(from, to, amount);
    }

    function setRegistry(address r) external onlyRole(DEFAULT_ADMIN_ROLE) {
        registry = r;
    }

    function setCooldown(uint256 _cooldown) external onlyRole(DEFAULT_ADMIN_ROLE) {
        cooldownSeconds = _cooldown;
    }

    function setDailyCap(uint256 _cap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        dailyCapAmount = _cap;
    }

    function mintRitual(
        bytes32 ritualId,
        address to,
        uint256 amount,
        bytes32 nonce,
        uint256 deadline,
        bytes calldata payload,
        bytes calldata sig
    ) external whenNotPaused {
        require(block.timestamp <= deadline, "ritual: expired");

        // --- Rate Limiting Checks ---
        // Cooldown check
        require(block.timestamp >= lastMintTimestamp[to] + cooldownSeconds, "cooldown");

        // Daily cap check
        if (block.timestamp / 1 days > currentDay) {
            currentDay = block.timestamp / 1 days;
            dailyMintedAmount = 0;
        }
        require(dailyMintedAmount + amount <= dailyCapAmount, "cap");

        // --- Signature and Registry Validation ---
        address agent = IRitualRegistry(registry).validateAndConsumeNonce(ritualId, nonce);

        bytes32 structHash = keccak256(abi.encode(
            MINT_TYPEHASH, ritualId, to, amount, nonce, deadline, keccak256(payload)
        ));
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(digest, sig);
        require(signer == agent, "ritual: bad signer");

        // --- Update State and Mint ---
        lastMintTimestamp[to] = block.timestamp;
        dailyMintedAmount += amount;

        _mint(to, amount);
        emit RitualTrigger(ritualId, to, amount, payload);
    }
}
