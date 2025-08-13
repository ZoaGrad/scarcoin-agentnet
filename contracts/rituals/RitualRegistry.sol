// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract RitualRegistry is Ownable, AccessControl, Pausable {
    bytes32 public constant CURATOR_ROLE = keccak256("CURATOR_ROLE");
    address public scarCoinContract;

    struct Ritual {
        address agent;
        bytes32 schema;
        bool active;
    }

    mapping(bytes32 => Ritual) public rituals;
    mapping(bytes32 => bool) public seenNonces;

    event RitualRegistered(bytes32 indexed ritualId, address agent, bytes32 schema);
    event RitualStatus(bytes32 indexed ritualId, bool active);
    event ScarCoinContractUpdated(address indexed newScarCoinContract);

    modifier onlyScarCoin() {
        require(msg.sender == scarCoinContract, "Only ScarCoin contract can call this");
        _;
    }

    constructor(address owner_) {
        _transferOwnership(owner_);
        _grantRole(DEFAULT_ADMIN_ROLE, owner_);
        _grantRole(CURATOR_ROLE, owner_);
    }

    function setScarCoinContract(address _scarCoinContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_scarCoinContract != address(0), "Invalid address");
        scarCoinContract = _scarCoinContract;
        emit ScarCoinContractUpdated(_scarCoinContract);
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

    function validateAndConsumeNonce(bytes32 ritualId, bytes32 nonce)
        external
        whenNotPaused
        onlyScarCoin
        returns (address agent)
    {
        require(!seenNonces[nonce], "ritual: replay");
        seenNonces[nonce] = true;

        Ritual memory r = rituals[ritualId];
        require(r.active, "ritual: inactive");
        require(r.agent != address(0), "ritual: unknown");

        return r.agent;
    }
}
