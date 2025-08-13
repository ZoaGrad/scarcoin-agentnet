// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

interface IRitualRegistry {
  function registerRitual(bytes32 ritualId, address agent, bytes32 schema) external;
  function setActive(bytes32 ritualId, bool active) external;
  function pause() external;
}

interface IScarCoin {
  function decimals() external view returns (uint8);
  function balanceOf(address) external view returns (uint256);
  function setRegistry(address) external;
  function mintRitual(
    bytes32 ritualId,
    address to,
    uint256 amount,
    bytes32 nonce,
    uint256 deadline,
    bytes calldata payload,
    bytes calldata sig
  ) external;

  // Admin knobs (expected in your hardened contract)
  function setCooldown(uint256 s) external;
  function setDailyCap(uint256 cap) external;
}

contract RitualMintLimitsAndEvents is Test {
  IRitualRegistry reg;
  IScarCoin      scar;

  // Mirror on-chain event signature for expectEmit
  event RitualTrigger(bytes32 indexed ritualId, address indexed to, uint256 amount, bytes payload);

  function setUp() public {
    // Deploy Registry
    bytes memory regCode = vm.getCode("contracts/RitualRegistry.sol:RitualRegistry");
    address regAddr;
    assembly { regAddr := create(0, add(regCode, 0x20), mload(regCode)) }
    reg = IRitualRegistry(regAddr);

    // Deploy ScarCoin(registry)
    bytes memory scarCode = vm.getCode("contracts/ScarCoin.sol:ScarCoin");
    bytes memory ctor = abi.encodeWithSignature("constructor(address)", regAddr);
    bytes memory full = bytes.concat(scarCode, ctor);
    address scarAddr;
    assembly { scarAddr := create(0, add(full, 0x20), mload(full)) }
    scar = IScarCoin(scarAddr);
    scar.setRegistry(regAddr);
  }

  // ----- helpers -----

  function _amt(uint8 dec, uint256 units) internal pure returns (uint256) {
    return dec == 0 ? units : units * (10 ** dec);
  }

  function _signMint(
    uint256 agentPk,
    bytes32 ritualId,
    address to,
    uint256 amount,
    bytes32 nonce,
    uint256 deadline,
    bytes memory payload,
    address verifying
  ) internal view returns (bytes memory sig) {
    bytes32 MINT_TYPEHASH = keccak256(
      "MintRitual(bytes32 ritualId,address to,uint256 amount,bytes32 nonce,uint256 deadline,bytes payloadHash)"
    );
    bytes32 structHash = keccak256(abi.encode(
      MINT_TYPEHASH, ritualId, to, amount, nonce, deadline, keccak256(payload)
    ));

    bytes32 DOMAIN_TYPEHASH = keccak256(
      "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 domain = keccak256(abi.encode(
      DOMAIN_TYPEHASH,
      keccak256(bytes("ScarCoin")),
      keccak256(bytes("1")),
      block.chainid,
      verifying
    ));

    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domain, structHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(agentPk, digest);
    return abi.encodePacked(r, s, v);
  }

  // ----- tests -----

  function test_DailyCap_RevertsWhenExceeded() public {
    // arrange
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));

    // ease testing: no cooldown & a tiny daily cap
    scar.setCooldown(0);
    uint8 dec = scar.decimals();
    uint256 cap = _amt(dec, 5);
    scar.setDailyCap(cap);

    address to = address(0xC0FFEE);
    uint256 a1 = _amt(dec, 3);
    uint256 a2 = _amt(dec, 3); // total 6 > 5 ⇒ second mint should revert

    // first mint (ok)
    {
      bytes32 n1 = keccak256("cap-nonce-1");
      uint256 dl = block.timestamp + 600;
      bytes memory p = bytes('{"reason":"quota-1"}');
      bytes memory s1 = _signMint(agentPk, ritualId, to, a1, n1, dl, p, address(scar));
      scar.mintRitual(ritualId, to, a1, n1, dl, p, s1);
    }

    // second mint (exceeds daily cap)
    {
      bytes32 n2 = keccak256("cap-nonce-2");
      uint256 dl = block.timestamp + 600;
      bytes memory p = bytes('{"reason":"quota-2"}');
      bytes memory s2 = _signMint(agentPk, ritualId, to, a2, n2, dl, p, address(scar));

      vm.expectRevert(); // "cap" in your implementation; generic revert is fine here
      scar.mintRitual(ritualId, to, a2, n2, dl, p, s2);
    }
  }

  function test_EventLayout_RitualTrigger_TopicsAndData() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));

    // cooldown=0 so we can emit without delay
    scar.setCooldown(0);

    uint8 dec = scar.decimals();
    address to = address(0xF00D);
    uint256 amount = _amt(dec, 7);
    bytes32 nonce = keccak256("emit-nonce");
    uint256 deadline = block.timestamp + 600;
    bytes memory payload = bytes('{"viz":"ok"}');
    bytes memory sig = _signMint(agentPk, ritualId, to, amount, nonce, deadline, payload, address(scar));

    // expect event: ritualId & to are indexed; amount and payload in data
    vm.expectEmit(true, true, true, true); // check all topics/data
    emit RitualTrigger(ritualId, to, amount, payload);

    scar.mintRitual(ritualId, to, amount, nonce, deadline, payload, sig);
  }
}
