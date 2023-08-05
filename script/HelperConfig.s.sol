// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {VRFCoordinatorV2Mock} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address linkContract;
    }

    NetworkConfig public activeNetworkConfig;
    uint96 private constant BASE_FEE = 0.25 ether;
    uint96 private constant GAS_PRICE_LINK = 1e9;
    uint32 private constant CHAINID_GOERLI = 5;
    uint8 private constant CHAINID_ETHEREUM = 1;

    constructor() {
        if (block.chainid == CHAINID_GOERLI) activeNetworkConfig = _getGoerliEthConfig();
        else activeNetworkConfig = _getOrCreateTestChainEthConfig();
    }

    function _getGoerliEthConfig() internal pure returns (NetworkConfig memory) {
        NetworkConfig memory goerliConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D,
            gasLane: 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15,
            subscriptionId: 13505,
            callbackGasLimit: 500000,
            linkContract: 0x326C977E6efc84E512bB9C30f76E30c160eD06FB
        });
        return goerliConfig;
    }

    function _getOrCreateTestChainEthConfig() internal returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) return activeNetworkConfig;

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(BASE_FEE , GAS_PRICE_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        NetworkConfig memory config = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorV2Mock),
            gasLane: 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            linkContract: address(linkToken)
        });
        return config;
    }
}
