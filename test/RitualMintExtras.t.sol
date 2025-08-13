// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

interface IRitualRegistry {
  function registerRitual(bytes32 ritualId, address agent, bytes32 schema) external;
  function setActive(bytes32 ritualId, bool active) external;
  function pause() external;
  function grantRole(bytes32 role, address account) external;
}

interface IScarCoin {
  // Custom Errors
  error InvalidRitual();
  error BadSigner();

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
  function setCooldown(uint256 s) external;
  function setDailyCap(uint256 cap) external;
}

contract RitualMintExtras is Test {
  error Replay();

  IRitualRegistry reg;
  IScarCoin      scar;
  bytes32 constant SCARCOIN_ROLE = keccak256("SCARCOIN_ROLE");

  // Mirror on-chain event signature for expectEmit
  event RitualTrigger(bytes32 indexed ritualId, address indexed to, uint256 amount, bytes payload);

  function setUp() public {
    bytes memory regCode = vm.getCode("contracts/RitualRegistry.sol:RitualRegistry");
    address regAddr;
    assembly { regAddr := create(0, add(regCode, 0x20), mload(regCode)) }
    reg = IRitualRegistry(regAddr);

    bytes memory scarCode = vm.getCode("contracts/ScarCoin.sol:ScarCoin");
    bytes memory ctor = abi.encodeWithSignature("constructor(address)", regAddr);
    bytes memory full = bytes.concat(scarCode, ctor);
    address scarAddr;
    assembly { scarAddr := create(0, add(full, 0x20), mload(full)) }
    scar = IScarCoin(scarAddr);

    reg.grantRole(SCARCOIN_ROLE, scarAddr);
  }

  // ----- helpers -----

  function _amt(uint8 dec, uint256 units) internal pure returns (uint256) {
    return dec == 0 ? units : units * (10 ** dec);
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

    reg.pause();
    vm.expectRevert("Pausable: paused");
    scar.mintRitual(ritualId, to, amount, nonce, deadline, payload, sig);
  }

  function test_InactiveRitual_Reverts() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));
    reg.setActive(ritualId, false);

    address to = address(0xBADA55);
    uint256 amount = _amt(scar.decimals(), 1);
    bytes32 nonce = keccak256("inactive");
    uint256 deadline = block.timestamp + 600;
    bytes memory payload = hex"";
    bytes memory sig = _sign(agentPk, ritualId, to, amount, nonce, deadline, payload, address(scar));

    vm.expectRevert(IScarCoin.InvalidRitual.selector);
    scar.mintRitual(ritualId, to, amount, nonce, deadline, payload, sig);
  }

  function test_TamperedPayload_Reverts() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));

    address to = address(0xAABB);
    uint256 amount = _amt(scar.decimals(), 2);
    bytes32 nonce = keccak256("tamper");
    uint256 deadline = block.timestamp + 600;
    bytes memory signedPayload = bytes('{"reason":"ok"}');
    bytes memory sig = _sign(agentPk, ritualId, to, amount, nonce, deadline, signedPayload, address(scar));

    bytes memory tampered = bytes('{"reason":"oops"}');
    vm.expectRevert(IScarCoin.BadSigner.selector);
    scar.mintRitual(ritualId, to, amount, nonce, deadline, tampered, sig);
  }

  function test_SameNonceAcrossDifferentRituals_Reverts() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 r1 = keccak256("FAUCET_V1");
    bytes32 r2 = keccak256("ANOTHER");
    reg.registerRitual(r1, agent, bytes32(0));
    reg.registerRitual(r2, agent, bytes32(0));
    scar.setCooldown(0);

    address to = address(0xD1CE);
    uint256 amount = _amt(scar.decimals(), 1);
    bytes32 nonce = keccak256("global-nonce");
    uint256 deadline = block.timestamp + 600;
    bytes memory payload = hex"";

    bytes memory s1 = _sign(agentPk, r1, to, amount, nonce, deadline, payload, address(scar));
    scar.mintRitual(r1, to, amount, nonce, deadline, payload, s1);

    bytes memory s2 = _sign(agentPk, r2, to, amount, nonce, deadline, payload, address(scar));
    vm.expectRevert(Replay.selector);
    scar.mintRitual(r2, to, amount, nonce, deadline, payload, s2);
  }

  function test_DomainMismatch_VerifyingContract_Reverts() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));

    address to = address(0x5555);
    uint256 amount = _amt(scar.decimals(), 1);
    bytes32 nonce = keccak256("wrong-domain");
    uint256 deadline = block.timestamp + 600;
    bytes memory payload = hex"";
    address wrongVerifying = address(0xDEAD);
    bytes memory sig = _sign(agentPk, ritualId, to, amount, nonce, deadline, payload, wrongVerifying);

    vm.expectRevert(IScarCoin.BadSigner.selector);
    scar.mintRitual(ritualId, to, amount, nonce, deadline, payload, sig);
  }

    function test_DailyCap_RevertsWhenExceeded() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));

    scar.setCooldown(0);
    uint8 dec = scar.decimals();
    uint256 cap = _amt(dec, 5);
    scar.setDailyCap(cap);

    address to = address(0xC0FFEE);
    uint256 a1 = _amt(dec, 3);
    uint256 a2 = _amt(dec, 3);

    {
      bytes32 n1 = keccak256("cap-nonce-1");
      uint256 dl = block.timestamp + 600;
      bytes memory p = bytes('{"reason":"quota-1"}');
      bytes memory s1 = _sign(agentPk, ritualId, to, a1, n1, dl, p, address(scar));
      scar.mintRitual(ritualId, to, a1, n1, dl, p, s1);
    }

    {
      bytes32 n2 = keccak256("cap-nonce-2");
      uint256 dl = block.timestamp + 600;
      bytes memory p = bytes('{"reason":"quota-2"}');
      bytes memory s2 = _sign(agentPk, ritualId, to, a2, n2, dl, p, address(scar));
      vm.expectRevert(bytes("DailyCapExceeded()"));
      scar.mintRitual(ritualId, to, a2, n2, dl, p, s2);
    }
  }

  function test_EventLayout_RitualTrigger_TopicsAndData() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));

    scar.setCooldown(0);

    address to = address(0xF00D);
    uint256 amount = _amt(scar.decimals(), 7);
    bytes32 nonce = keccak256("emit-nonce");
    uint256 deadline = block.timestamp + 600;
    bytes memory payload = bytes('{"viz":"ok"}');
    bytes memory sig = _sign(agentPk, ritualId, to, amount, nonce, deadline, payload, address(scar));

    vm.expectEmit(true, true, false, true);
    emit RitualTrigger(ritualId, to, amount, payload);

    scar.mintRitual(ritualId, to, amount, nonce, deadline, payload, sig);
  }
}
