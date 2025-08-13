// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IRitualRegistry {
    function validate(bytes32 ritualId) external view returns (bool ok, address agent);
    function consumeNonce(bytes32 ritualId, bytes32 nonce) external;
}

contract ScarCoin is ERC20, AccessControl, EIP712, Pausable, ReentrancyGuard {
    // --- Errors ---
    error Expired();
    error Cooldown();
    error DailyCapExceeded();
    error InvalidRitual();
    error BadSigner();
    error PayloadTooLarge();

    // --- Constants ---
    bytes32 public constant MINT_TYPEHASH =
        keccak256("MintRitual(bytes32 ritualId,address to,uint256 amount,bytes32 nonce,uint256 deadline,bytes payloadHash)");
    uint256 public constant MAX_PAYLOAD_BYTES = 512;

    // --- State ---
    address public registry;
    uint256 public cooldownSeconds;
    uint256 public dailyCapAmount;
    mapping(address => uint256) public lastMintTimestamp;
    uint256 public currentDay;
    uint256 public dailyMintedAmount;

    // --- Events ---
    event Pulse(address indexed from, address indexed to, uint256 value);
    event RitualTrigger(bytes32 indexed ritualId, address indexed to, uint256 amount, bytes payload);
    event LimitsUpdated(uint256 cooldownSeconds, uint256 dailyCap);

    constructor(address registry_)
        ERC20("ScarCoin", "SCAR")
        EIP712("ScarCoin", "1")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        registry = registry_;
        cooldownSeconds = 60;
        dailyCapAmount = 1000 * (10**decimals());
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {
        emit Pulse(from, to, amount);
    }

    function setRegistry(address r) external onlyRole(DEFAULT_ADMIN_ROLE) {
        registry = r;
    }

    function setCooldown(uint256 _cooldown) external onlyRole(DEFAULT_ADMIN_ROLE) {
        cooldownSeconds = _cooldown;
        emit LimitsUpdated(cooldownSeconds, dailyCapAmount);
    }

    function setDailyCap(uint256 _cap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        dailyCapAmount = _cap;
        emit LimitsUpdated(cooldownSeconds, dailyCapAmount);
    }

    function mintRitual(
        bytes32 ritualId,
        address to,
        uint256 amount,
        bytes32 nonce,
        uint256 deadline,
        bytes calldata payload,
        bytes calldata sig
    ) external whenNotPaused nonReentrant {
        if (block.timestamp > deadline) revert Expired();
        if (payload.length > MAX_PAYLOAD_BYTES) revert PayloadTooLarge();

        // --- Rate Limiting ---
        if (block.timestamp < lastMintTimestamp[to] + cooldownSeconds) revert Cooldown();
        if (block.timestamp / 1 days > currentDay) {
            currentDay = block.timestamp / 1 days;
            dailyMintedAmount = 0;
        }
        if (dailyMintedAmount + amount > dailyCapAmount) revert DailyCapExceeded();

        // --- Validation ---
        (bool ok, address agent) = IRitualRegistry(registry).validate(ritualId);
        if (!ok) revert InvalidRitual();

        bytes32 structHash = keccak256(abi.encode(
            MINT_TYPEHASH, ritualId, to, amount, nonce, deadline, keccak256(payload)
        ));
        bytes32 digest = _hashTypedDataV4(structHash);
        if (ECDSA.recover(digest, sig) != agent) revert BadSigner();

        // --- State Change ---
        IRitualRegistry(registry).consumeNonce(ritualId, nonce);
        lastMintTimestamp[to] = block.timestamp;
        dailyMintedAmount += amount;

        _mint(to, amount);
        emit RitualTrigger(ritualId, to, amount, payload);
    }
}
