// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract ScarCoin is ERC20, AccessControl, EIP712, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant MINT_TYPEHASH =
        keccak256("MintRitual(bytes32 ritualId,address to,uint256 amount,bytes32 nonce,uint256 deadline,bytes payloadHash)");

    address public registry; // RitualRegistry address

    event Pulse(address indexed from, address indexed to, uint256 value);
    event RitualTrigger(bytes32 indexed ritualId, address indexed to, uint256 amount, bytes payload);

    constructor(address registry_)
        ERC20("ScarCoin", "SCAR")
        EIP712("ScarCoin", "1")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        registry = registry_;
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {
        emit Pulse(from, to, amount);
    }

    function setRegistry(address r) external onlyRole(DEFAULT_ADMIN_ROLE) { registry = r; }

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

        // Verify against registry
        (bool ok, address agent) = _validateWithRegistry(ritualId, nonce, payload);
        require(ok, "ritual: invalid");

        // EIP-712 signed by the attested agent
        bytes32 structHash = keccak256(abi.encode(
            MINT_TYPEHASH, ritualId, to, amount, nonce, deadline, keccak256(payload)
        ));
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(digest, sig);
        require(signer == agent, "ritual: bad signer");

        _mint(to, amount);
        emit RitualTrigger(ritualId, to, amount, payload);
    }

    function _validateWithRegistry(bytes32 ritualId, bytes32 nonce, bytes calldata payload)
        internal
        returns (bool ok, address agent)
    {
        (bool success, bytes memory data) = registry.call(
            abi.encodeWithSignature("validate(bytes32,bytes32,bytes)", ritualId, nonce, payload)
        );
        if (!success) return (false, address(0));
        (ok, agent) = abi.decode(data, (bool, address));
    }
}
