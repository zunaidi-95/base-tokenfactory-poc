// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";

interface IToken {
    function owner() external view returns (address);
    function masterMinter() external view returns (address);
    function pauser() external view returns (address);
    function blacklister() external view returns (address);
    function isBlacklisted(address) external view returns (bool);
    function isMinter(address) external view returns (bool);
    function minterAllowance(address) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function mint(address to, uint256 amount) external returns (bool);
    function pause() external;
    function blacklist(address a) external;
    function configureMinter(address m, uint256 amt) external returns (bool);
    function initialize(string calldata n, string calldata s, string calldata c, uint8 d, address mm, address p, address b, address o) external;
    function exchangeRate() external view returns (uint256);
    function updateExchangeRate(uint256 r) external;
    function oracle() external view returns (address);
}

interface IMF {
    function mint(address to, uint256 amount) external;
    function owner() external view returns (address);
}

contract T2ControlsTest is Test {
    function setUp() public {
        vm.createSelectFork("base", 59038136);
    }

    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant CBETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address constant CBADA = 0xcbADA732173e39521CDBE8bf59a6Dc85A9fc7b8c;
    address constant MF = 0x6D44bfB8432d17882bB6e84652f5C3B36fcC8280;
    address constant ERU = 0x9b37180d847B27ADC13C2277299045C1237Ae281;

    // V2_2 (cbADA) blacklists the token contract itself at initializeV2_2.
    // If deployed V2_2 dropped the notBlacklisted check on approve (as in Circle repo HEAD),
    // approve() FROM the blacklisted token address succeeds while transfer() reverts.
    function test_V22_approveFromBlacklistedSelf() public {
        assertTrue(IToken(CBADA).isBlacklisted(CBADA), "token should blacklist itself in V2_2");
        address spender = address(0xBEEF);
        vm.prank(CBADA);
        bool okApprove = IToken(CBADA).approve(spender, 100);
        emit log_named_string("approve from blacklisted token contract succeeded?", okApprove ? "YES" : "NO");
        // Control: transfer from the same blacklisted address must revert
        vm.prank(CBADA);
        vm.expectRevert();
        IToken(CBADA).transfer(spender, 1);
    }

    // Control for the V2_2 approve finding: on V2_1 (cbBTC) the token contract is
    // ALSO blacklisted (isBlacklisted(self)==true), but approve() DOES enforce the
    // blacklist there, so approve from the token address must revert.
    function test_V21_approveFromBlacklistedSelfReverts() public {
        assertTrue(IToken(CBBTC).isBlacklisted(CBBTC), "cbBTC should blacklist itself");
        vm.prank(CBBTC);
        vm.expectRevert();
        IToken(CBBTC).approve(address(0xBEEF), 100);
    }

    function test_neg_initializeReinitReverts() public {
        vm.prank(address(0xA77ACC));
        vm.expectRevert();
        IToken(CBBTC).initialize("X", "X", "", 8, address(1), address(2), address(3), address(4));
    }

    function test_neg_mintAsNonMinterReverts() public {
        vm.prank(address(0xA77ACC));
        vm.expectRevert();
        IToken(CBBTC).mint(address(0xA77ACC), 1);
    }

    function test_neg_pauseAsNonPauserReverts() public {
        vm.prank(address(0xA77ACC));
        vm.expectRevert();
        IToken(CBBTC).pause();
    }

    function test_neg_blacklistAsNonBlacklisterReverts() public {
        vm.prank(address(0xA77ACC));
        vm.expectRevert();
        IToken(CBBTC).blacklist(address(0xBEEF));
    }

    function test_neg_configureMinterAsNonMasterMinterReverts() public {
        vm.prank(address(0xA77ACC));
        vm.expectRevert();
        IToken(CBBTC).configureMinter(address(0xA77ACC), 100);
    }

    function test_pos_liveRolesNotAttacker() public {
        // Sanity: attacker holds no role on any live Base token
        address attacker = address(0xA77ACC);
        assertFalse(IToken(CBBTC).isMinter(attacker));
        assertEq(IToken(CBBTC).minterAllowance(attacker), 0);
        assertFalse(IToken(CBADA).isMinter(attacker));
        assertEq(IToken(CBADA).minterAllowance(attacker), 0);
        assertFalse(IToken(CBBTC).isBlacklisted(attacker));
    }
}
