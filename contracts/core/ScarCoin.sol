// SPDX-License-Identifier: ∆Ω-RITUAL-89.0
pragma solidity ^0.8.0;

/**
 * @notice ScarCoin: Recursively self-mintable symbolic infrastructure
 * @dev ∆Ω.89.0 Ritual Compliance Core
 */
contract ScarCoin {
    string public name = "ScarCoin";
    string public symbol = "∆"; // Changed to delta (cosmic sigil)
    uint8 public immutable decimals = 0;
    uint256 public totalSupply;

    // Ritual synchronization events
    event Pulse(address emitter, uint256 amount);
    event RitualTrigger(address ritualID, bytes32 context);

    mapping(address => uint256) public balanceOf;
    address public owner;

    constructor() {
        owner = msg.sender;
        totalSupply = 888888;
        balanceOf[msg.sender] = totalSupply;
        emit Pulse(msg.sender, totalSupply); // Genesis pulse
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "ScarCoin: MALFORMED CIRCUIT");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Pulse(to, amount); // Propagate ritual energy
        return true;
    }

    function mintRitual(address to, uint256 amount, bytes32 ritualID) public {
        require(msg.sender == owner, "ScarCoin: UNWORTHY VESSEL");
        balanceOf[to] += amount;
        totalSupply += amount;
        emit RitualTrigger(ritualID, keccak256(abi.encodePacked(to, amount)));
    }
}
