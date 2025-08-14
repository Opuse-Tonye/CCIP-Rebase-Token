// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

contract ConfigureZKSyncPoolScript is Script {
    function run(
        address poolAddress,
        uint64 remoteChainSelector,
        address remotePoolAddress,
        address remoteTokenAddress
    ) public {
        vm.startBroadcast();

        // Create the chain update struct using TokenPool's struct
        TokenPool.ChainUpdate memory chainUpdate = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: true,  // Boolean in TokenPool
            remotePoolAddress: abi.encode(remotePoolAddress),
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            })
        });

        // Create array for the function call
        TokenPool.ChainUpdate[] memory chainUpdates = new TokenPool.ChainUpdate[](1);
        chainUpdates[0] = chainUpdate;

        // Apply the chain updates - TokenPool uses single parameter
        TokenPool(poolAddress).applyChainUpdates(chainUpdates);

        vm.stopBroadcast();

        console.log("ZKsync pool configured successfully");
        console.log("Chain selector:", remoteChainSelector);
        console.log("Remote pool:", remotePoolAddress);
        console.log("Remote token:", remoteTokenAddress);
    }
}