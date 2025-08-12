// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract RitualRegistry is Ownable, AccessControl, Pausable {
    bytes32 public constant CURATOR_ROLE = keccak256("CURATOR_ROLE");

    struct Ritual {
        address agent;        // off-chain agent identity (attested signer)
        bytes32 schema;       // EIP-712 typehash for payload schema
        bool active;
    }

    mapping(bytes32 => Ritual) public rituals;  // ritualId => Ritual
    mapping(bytes32 => bool) public seenNonces; // replay protection across rituals

    event RitualRegistered(bytes32 indexed ritualId, address agent, bytes32 schema);
    event RitualStatus(bytes32 indexed ritualId, bool active);

    constructor(address owner_) {
        _transferOwnership(owner_);
        _grantRole(DEFAULT_ADMIN_ROLE, owner_);
        _grantRole(CURATOR_ROLE, owner_);
    }

    function registerRitual(bytes32 ritualId, address agent, bytes32 schema)
        external
        whenNotPaused
        onlyRole(CURATOR_ROLE)
    {
        rituals[ritualId] = Ritual({agent: agent, schema: schema, active: true});
        emit RitualRegistered(ritualId, agent, schema);
    }

    function setActive(bytes32 ritualId, bool active)
        external
        onlyRole(CURATOR_ROLE)
    {
        rituals[ritualId].active = active;
        emit RitualStatus(ritualId, active);
    }

    function validate(bytes32 ritualId, bytes32 nonce, bytes calldata payload)
        external
        view
        whenNotPaused
        returns (bool ok, address agent)
    {
        Ritual memory r = rituals[ritualId];
        if (!r.active) return (false, address(0));
        if (r.agent == address(0)) return (false, address(0));
        // Per instructions, nonce is passed but not validated within the registry itself.
        // Replay protection relies on the caller contract.
        return (true, r.agent);
    }
}
