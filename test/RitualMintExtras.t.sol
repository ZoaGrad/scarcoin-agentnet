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
  function mintRitual(
    bytes32 ritualId,
    address to,
    uint256 amount,
    bytes32 nonce,
    uint256 deadline,
    bytes calldata payload,
    bytes calldata sig
  ) external;
  function balanceOf(address) external view returns (uint256);
  function setRegistry(address) external;
}

contract RitualMintExtras is Test {
  IRitualRegistry reg;
  IScarCoin      scar;

  function setUp() public {
    // Deploy Registry
    bytes memory regCode = vm.getCode("contracts/RitualRegistry.sol:RitualRegistry");
    address regAddr;
    assembly { regAddr := create(0, add(regCode, 0x20), mload(regCode)) }
    reg = IRitualRegistry(regAddr);

    // Deploy ScarCoin(reg)
    bytes memory scarCode = vm.getCode("contracts/ScarCoin.sol:ScarCoin");
    bytes memory scarInit = abi.encodeWithSignature("constructor(address)", regAddr);
    bytes memory scarFull = bytes.concat(scarCode, scarInit);
    address scarAddr;
    assembly { scarAddr := create(0, add(scarFull, 0x20), mload(scarFull)) }
    scar = IScarCoin(scarAddr);
    scar.setRegistry(regAddr);
  }

  function _sign(
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
      MINT_TYPEHASH,
      ritualId, to, amount, nonce, deadline, keccak256(payload)
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

  function _amt(uint8 dec, uint256 units) internal pure returns (uint256) {
    return dec == 0 ? units : units * (10 ** dec);
  }

  function test_RegistryPaused_HaltsMint() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));

    uint8 dec = scar.decimals();
    address to = address(0xF00D);
    uint256 amount = _amt(dec, 1);
    bytes32 nonce = keccak256("pause");
    uint256 deadline = block.timestamp + 600;
    bytes memory payload = hex"";

    bytes memory sig = _sign(agentPk, ritualId, to, amount, nonce, deadline, payload, address(scar));
    // Pause the registry -> validate() should revert underneath mintRitual
    reg.pause();
    vm.expectRevert();
    scar.mintRitual(ritualId, to, amount, nonce, deadline, payload, sig);
  }

  function test_InactiveRitual_Reverts() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));
    reg.setActive(ritualId, false);

    uint8 dec = scar.decimals();
    address to = address(0xBADA55);
    uint256 amount = _amt(dec, 1);
    bytes32 nonce = keccak256("inactive");
    uint256 deadline = block.timestamp + 600;
    bytes memory payload = hex"";
    bytes memory sig = _sign(agentPk, ritualId, to, amount, nonce, deadline, payload, address(scar));

    vm.expectRevert(); // "ritual: invalid"
    scar.mintRitual(ritualId, to, amount, nonce, deadline, payload, sig);
  }

  function test_TamperedPayload_Reverts() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));

    uint8 dec = scar.decimals();
    address to = address(0xAABB);
    uint256 amount = _amt(dec, 2);
    bytes32 nonce = keccak256("tamper");
    uint256 deadline = block.timestamp + 600;

    bytes memory signedPayload = bytes('{"reason":"ok"}');
    bytes memory sig = _sign(agentPk, ritualId, to, amount, nonce, deadline, signedPayload, address(scar));

    // Call with a different payload -> digest mismatch -> bad signer
    bytes memory tampered = bytes('{"reason":"oops"}');

    vm.expectRevert(); // "bad signer"
    scar.mintRitual(ritualId, to, amount, nonce, deadline, tampered, sig);
  }

  function test_SameNonceAcrossDifferentRituals_Reverts() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 r1 = keccak256("FAUCET_V1");
    bytes32 r2 = keccak256("ANOTHER");
    reg.registerRitual(r1, agent, bytes32(0));
    reg.registerRitual(r2, agent, bytes32(0));

    uint8 dec = scar.decimals();
    address to = address(0xD1CE);
    uint256 amount = _amt(dec, 1);
    bytes32 nonce = keccak256("global-nonce");
    uint256 deadline = block.timestamp + 600;
    bytes memory payload = hex"";

    bytes memory s1 = _sign(agentPk, r1, to, amount, nonce, deadline, payload, address(scar));
    scar.mintRitual(r1, to, amount, nonce, deadline, payload, s1);

    // Reuse nonce with another ritual should fail because nonces are global
    bytes memory s2 = _sign(agentPk, r2, to, amount, nonce, deadline, payload, address(scar));
    vm.expectRevert(); // "ritual: replay"
    scar.mintRitual(r2, to, amount, nonce, deadline, payload, s2);
  }

  function test_DomainMismatch_VerifyingContract_Reverts() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));

    uint8 dec = scar.decimals();
    address to = address(0x5555);
    uint256 amount = _amt(dec, 1);
    bytes32 nonce = keccak256("wrong-domain");
    uint256 deadline = block.timestamp + 600;
    bytes memory payload = hex"";

    // Sign against a different verifying contract address
    address wrongVerifying = address(0xDEAD);
    bytes memory sig = _sign(agentPk, ritualId, to, amount, nonce, deadline, payload, wrongVerifying);

    vm.expectRevert(); // "bad signer"
    scar.mintRitual(ritualId, to, amount, nonce, deadline, payload, sig);
  }
}
