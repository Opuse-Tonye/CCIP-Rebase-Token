// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";

// Note: Contract name changed to BridgeTokensScript (with 's') to match bash script
contract BridgeTokensScript is Script {
    function sendMessage(
        address receiverAddress, 
        uint64 destinationChainSelector, 
        address tokenToSendAddress,
        uint256 amountToSend,
        address linkTokenAddress, 
        address routerAddress
    ) public {
        vm.startBroadcast();
        
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: tokenToSendAddress,
            amount: amountToSend
        });
        
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkTokenAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });
        
        uint256 ccipFee = IRouterClient(routerAddress).getFee(destinationChainSelector, message);
        IERC20(linkTokenAddress).approve(routerAddress, ccipFee);
        IERC20(tokenToSendAddress).approve(routerAddress, amountToSend);

        bytes32 messageId = IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);
        
        vm.stopBroadcast();
        
        console.log("CCIP Message sent with ID:");
        console.logBytes32(messageId);
    }
    
    // Backward compatibility - keeping the old function signature
    function run(
        address receiverAddress, 
        uint64 destinationChainSelector, 
        address tokenToSendAddress,
        address linkTokenAddress, 
        uint256 amountToSend, 
        address routerAddress
    ) public {
        sendMessage(receiverAddress, destinationChainSelector, tokenToSendAddress, amountToSend, linkTokenAddress, routerAddress);
    }
}