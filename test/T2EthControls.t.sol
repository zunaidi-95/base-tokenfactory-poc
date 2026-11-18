// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";

interface ITokenE {
    function isMinter(address) external view returns (bool);
    function minterAllowance(address) external view returns (uint256);
    function mint(address to, uint256 amount) external returns (bool);
    function updateExchangeRate(uint256 r) external;
    function exchangeRate() external view returns (uint256);
}

interface IMFE {
    function mint(address to, uint256 amount) external;
}

contract T2EthControlsTest is Test {
    address constant CBETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address constant MF = 0x6D44bfB8432d17882bB6e84652f5C3B36fcC8280;
    address constant ERU = 0x9b37180d847B27ADC13C2277299045C1237Ae281;

    function setUp() public {
        vm.createSelectFork("mainnet", 26441372);
    }

    function test_neg_mintAsNonMinterCbEthReverts() public {
        vm.prank(address(0xA77ACC));
        vm.expectRevert();
        ITokenE(CBETH).mint(address(0xA77ACC), 1);
    }

    function test_neg_mfMintAsNonCallerReverts() public {
        vm.prank(address(0xA77ACC));
        vm.expectRevert();
        IMFE(MF).mint(address(0xA77ACC), 1);
    }

    function test_neg_cbEthUpdateRateAsNonOracleReverts() public {
        vm.prank(address(0xA77ACC));
        vm.expectRevert();
        ITokenE(CBETH).updateExchangeRate(2e18);
    }

    function test_neg_eruUpdateRateAsNonCallerReverts() public {
        vm.prank(address(0xA77ACC));
        vm.expectRevert();
        ITokenE(ERU).updateExchangeRate(2e18);
    }

    function test_pos_liveRolesNotAttackerEth() public {
        address attacker = address(0xA77ACC);
        assertFalse(ITokenE(CBETH).isMinter(attacker));
        assertEq(ITokenE(CBETH).minterAllowance(attacker), 0);
        assertGt(ITokenE(CBETH).exchangeRate(), 1e18);
    }

    // ERU caller CANNOT move the rate beyond its allowance: delta > allowance reverts.
    // (Privileged-caller path is by design; this test pins the bound.)
    function test_eruCallerBoundEnforced() public {
        address caller = 0xA74D6B26e308B140423928F7e71b50E02819Cb5c;
        uint256 rate = ITokenE(CBETH).exchangeRate();
        vm.prank(caller);
        vm.expectRevert();
        ITokenE(ERU).updateExchangeRate(rate + 11e18); // allowance is 10e18
    }
}
