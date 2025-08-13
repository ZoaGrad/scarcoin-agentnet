// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract RitualRegistry is AccessControl, Pausable {
    bytes32 public constant CURATOR_ROLE = keccak256("CURATOR_ROLE");
    bytes32 public constant SCARCOIN_ROLE = keccak256("SCARCOIN_ROLE");

    struct Ritual {
        address agent;
        bytes32 schema;
        bool active;
    }

    mapping(bytes32 => Ritual) public rituals;
    mapping(bytes32 => bool) public usedNonces;

    event RitualRegistered(bytes32 indexed ritualId, address agent, bytes32 schema);
    event RitualStatus(bytes32 indexed ritualId, bool active);
    event NonceConsumed(bytes32 indexed ritualId, bytes32 indexed nonce);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CURATOR_ROLE, admin);
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
        whenNotPaused
        onlyRole(CURATOR_ROLE)
    {
        rituals[ritualId].active = active;
        emit RitualStatus(ritualId, active);
    }

    function validate(bytes32 ritualId)
        external
        view
        whenNotPaused
        returns (bool ok, address agent)
    {
        Ritual memory r = rituals[ritualId];
        ok = r.active && r.agent != address(0);
        agent = r.agent;
    }

    function consumeNonce(bytes32 ritualId, bytes32 nonce) external whenNotPaused onlyRole(SCARCOIN_ROLE) {
        bytes32 key = keccak256(abi.encode(ritualId, nonce));
        require(!usedNonces[key], "nonce: used");
        usedNonces[key] = true;
        emit NonceConsumed(ritualId, nonce);
    }
}
