// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

interface IRitualRegistry {
  function registerRitual(bytes32 ritualId, address agent, bytes32 schema) external;
  function setActive(bytes32 ritualId, bool active) external;
  function grantRole(bytes32 role, address account) external;
}

interface IScarCoin {
  // Custom Errors
  error Expired();
  error Cooldown();
  error DailyCapExceeded();
  error InvalidRitual();
  error BadSigner();
  error PayloadTooLarge();

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
  function pause() external;
  function setRegistry(address) external;
  function setCooldown(uint256) external;
}

contract RitualMintTest is Test {
  IRitualRegistry reg;
  IScarCoin      scar;
  bytes32 constant SCARCOIN_ROLE = keccak256("SCARCOIN_ROLE");

  function setUp() public {
    bytes memory regCode = vm.getCode("contracts/RitualRegistry.sol:RitualRegistry");
    bytes memory scarCode = vm.getCode("contracts/ScarCoin.sol:ScarCoin");

    address admin = address(this);
    address regAddr;
    address scarAddr;

    assembly { regAddr := create(0, add(regCode, 0x20), mload(regCode)) }

    bytes memory scarInit = abi.encodeWithSignature("constructor(address)", regAddr);
    bytes memory scarFull = bytes.concat(scarCode, scarInit);
    assembly { scarAddr := create(0, add(scarFull, 0x20), mload(scarFull)) }

    reg = IRitualRegistry(regAddr);
    scar = IScarCoin(scarAddr);

    reg.grantRole(SCARCOIN_ROLE, scarAddr);
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
    bytes32 EIP712DOMAIN_TYPEHASH = keccak256(
      "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 domainSeparator = keccak256(abi.encode(
      EIP712DOMAIN_TYPEHASH, keccak256(bytes("ScarCoin")), keccak256(bytes("1")), block.chainid, verifying
    ));
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(agentPk, digest);
    return abi.encodePacked(r, s, v);
  }

  function test_HappyPath_MintsAndEmits() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));
    scar.setCooldown(0);

    address to = address(0xBEEF);
    uint8 dec = scar.decimals();
    uint256 amount = dec == 0 ? 10 : 10 * (10 ** dec);
    bytes32 nonce = keccak256("nonce-1");
    uint256 deadline = block.timestamp + 600;
    bytes memory payload = bytes("{\"reason\":\"test\",\"tier\":1}");
    bytes memory sig = _signMint(agentPk, ritualId, to, amount, nonce, deadline, payload, address(scar));

    scar.mintRitual(ritualId, to, amount, nonce, deadline, payload, sig);

    assertEq(scar.balanceOf(to), amount, "mint amount mismatch");
  }

  function test_Replay_Reverts() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));
    scar.setCooldown(0);

    address to = address(0xCAFE);
    uint8 dec = scar.decimals();
    uint256 amount = dec == 0 ? 1 : 1 * (10 ** dec);
    bytes32 nonce = keccak256("same-nonce");
    uint256 deadline = block.timestamp + 600;
    bytes memory payload = bytes("{\"reason\":\"replay\"}");
    bytes memory sig = _signMint(agentPk, ritualId, to, amount, nonce, deadline, payload, address(scar));

    scar.mintRitual(ritualId, to, amount, nonce, deadline, payload, sig);

    vm.expectRevert("nonce: used");
    scar.mintRitual(ritualId, to, amount, nonce, deadline, payload, sig);
  }

  function test_BadSigner_Reverts() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));

    address to = address(0xD00D);
    uint256 amount = 3;
    bytes32 nonce = keccak256("nonce-bad");
    uint256 deadline = block.timestamp + 600;
    bytes memory payload = bytes("{}");
    uint256 wrongPk = 0xBADC0DE;
    bytes memory sig = _signMint(wrongPk, ritualId, to, amount, nonce, deadline, payload, address(scar));

    vm.expectRevert(IScarCoin.BadSigner.selector);
    scar.mintRitual(ritualId, to, amount, nonce, deadline, payload, sig);
  }

  function test_Expired_Reverts() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));

    address to = address(0xFEED);
    uint256 amount = 2;
    bytes32 nonce = keccak256("nonce-expired");
    uint256 deadline = block.timestamp + 1;
    bytes memory payload = hex"";
    bytes memory sig = _signMint(agentPk, ritualId, to, amount, nonce, deadline, payload, address(scar));

    skip(2);

    vm.expectRevert(IScarCoin.Expired.selector);
    scar.mintRitual(ritualId, to, amount, nonce, deadline, payload, sig);
  }

  function test_Cooldown_RevertsOnSecondMint() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));

    address to = address(0xABCD);
    uint256 amt = 1;
    bytes32 n1 = keccak256("n1");
    uint256 deadline = block.timestamp + 600;
    bytes memory p = hex"";
    bytes memory s1 = _signMint(agentPk, ritualId, to, amt, n1, deadline, p, address(scar));
    scar.mintRitual(ritualId, to, amt, n1, deadline, p, s1);

    bytes32 n2 = keccak256("n2");
    bytes memory s2 = _signMint(agentPk, ritualId, to, amt, n2, deadline, p, address(scar));

    vm.expectRevert(IScarCoin.Cooldown.selector);
    scar.mintRitual(ritualId, to, amt, n2, deadline, p, s2);
  }

  function test_Pause_HaltsMinting() public {
    uint256 agentPk = 0xA11CE;
    address agent = vm.addr(agentPk);
    bytes32 ritualId = keccak256("FAUCET_V1");
    reg.registerRitual(ritualId, agent, bytes32(0));

    address to = address(0x9999);
    uint256 amount = 5;
    bytes32 nonce = keccak256("n3");
    uint256 deadline = block.timestamp + 600;
    bytes memory payload = hex"";
    bytes memory sig = _signMint(agentPk, ritualId, to, amount, nonce, deadline, payload, address(scar));

    scar.pause();
    vm.expectRevert("Pausable: paused");
    scar.mintRitual(ritualId, to, amount, nonce, deadline, payload, sig);
  }
}
