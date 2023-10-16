// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console2 } from "forge-std/console2.sol";
import { Strings } from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import { SafeCastUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/utils/math/SafeCastUpgradeable.sol";
import { AddressManager } from "../../contracts/common/AddressManager.sol";
import { SignalService } from "../../contracts/signal/SignalService.sol";
import { TaikoL2 } from "../../contracts/L2/TaikoL2.sol";
import { TestBase } from "../TestBase.sol";

contract TestTaikoL2 is TestBase {
    using SafeCastUpgradeable for uint256;

    // same as `block_gas_limit` in foundry.toml
    uint32 public constant BLOCK_GAS_LIMIT = 30_000_000;

    AddressManager public addressManager;
    SignalService public ss;
    TaikoL2 public L2;
    uint256 private logIndex;

    function setUp() public {
        addressManager = new AddressManager();
        addressManager.init();

        ss = new SignalService();
        ss.init(address(addressManager));
        registerAddress("signal_service", address(ss));

        L2 = new TaikoL2();
        uint128 gasExcess = 0;
        L2.init(address(addressManager), gasExcess);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 30);
    }

    function test_L2_AnchorTx_with_constant_block_time() external {
        for (uint256 i; i < 100; ++i) {
            vm.fee(1);

            vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
            _anchor(BLOCK_GAS_LIMIT);

            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 30);
        }
    }

    function test_L2_AnchorTx_with_decreasing_block_time() external {
        for (uint256 i; i < 32; ++i) {
            vm.fee(1);

            vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
            _anchor(BLOCK_GAS_LIMIT);

            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 30 - i);
        }
    }

    function test_L2_AnchorTx_with_increasing_block_time() external {
        for (uint256 i; i < 30; ++i) {
            vm.fee(1);

            vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
            _anchor(BLOCK_GAS_LIMIT);

            vm.roll(block.number + 1);

            vm.warp(block.timestamp + 30 + i);
        }
    }

    // calling anchor in the same block more than once should fail
    function test_L2_AnchorTx_revert_in_same_block() external {
        vm.fee(1);

        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        _anchor(BLOCK_GAS_LIMIT);

        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        vm.expectRevert(); // L2_PUBLIC_INPUT_HASH_MISMATCH
        _anchor(BLOCK_GAS_LIMIT);
    }

    // calling anchor in the same block more than once should fail
    function test_L2_AnchorTx_revert_from_wrong_signer() external {
        vm.fee(1);
        vm.expectRevert();
        _anchor(BLOCK_GAS_LIMIT);
    }

    function test_L2_AnchorTx_signing(bytes32 digest) external {
        (uint8 v, uint256 r, uint256 s) = L2.signAnchor(digest, uint8(1));
        address signer = ecrecover(digest, v + 27, bytes32(r), bytes32(s));
        assertEq(signer, L2.GOLDEN_TOUCH_ADDRESS());

        (v, r, s) = L2.signAnchor(digest, uint8(2));
        signer = ecrecover(digest, v + 27, bytes32(r), bytes32(s));
        assertEq(signer, L2.GOLDEN_TOUCH_ADDRESS());

        vm.expectRevert();
        L2.signAnchor(digest, uint8(0));

        vm.expectRevert();
        L2.signAnchor(digest, uint8(3));
    }

    function _anchor(uint32 parentGasLimit) private {
        bytes32 l1Hash = getRandomBytes32();
        bytes32 l1SignalRoot = getRandomBytes32();
        L2.anchor(l1Hash, l1SignalRoot, 12_345, parentGasLimit);
    }

    function registerAddress(bytes32 nameHash, address addr) internal {
        addressManager.setAddress(block.chainid, nameHash, addr);
        console2.log(block.chainid, uint256(nameHash), unicode"→", addr);
    }
}
