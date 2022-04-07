# Private Prediction Market for Starknet

### Basic Idea
<p>A and B can enter into a bet by staking some token(ERC20-compliant) - lets say they bet on the price of ETH after 1 month, so we setup a callback with an oracle asking it to give the results to the protocol after the stipulated time, and whoever wins gets to keep the full staked amount - this can then be extended to arbitrary number of participants - we can also create an NFT to represent the position in the bet for a participant which can then be traded on any permissionless NFT market (thereby securitizing predictions/opinions ?) - we could also deposit the staked amounts into some kind of yield bearing protocol, and the interest earned can be the reward for the winner and the staked amounts could be returned to the participants thereby creating a kind of lossless prediction market.</p>

<p>
The oracle is currently spoofed - we just provide the contract address (the address of the protocool - prediction_market) and the function selector which should be manually triggered to complete the bet. Further, the bet/prediction can be about anything as long as the data can be provided by the oracle.</p>

### Deployment
The protocol(prediction_market), a test ERC-20 token and an oracle are deployed on the goerli testnet. The relevant addresses can be found in the [goerli.deployments.txt](https://github.com/udayj/starknet_prediction_market/blob/master/goerli.deployments.txt) file.

### User Flow
Important functions in the prediction_market contract
<ol>
  
  <li>start_bet function needs the following arguments to initiate a bet</li>
<ul>
  <li>Position (0/1) 0 means you are betting that price will go down and 1 means price will go up</li>
  <li>Predicted Price Point (the price point around which the prediction is being made)</li>
  <li>Staked amount</li>
  <li>ERC-20 token address which you want to stake (the requirement for this argument will be removed later) </li>
</ul>
<li>join_bet function needs the bet_id which is returned from start_bet (and also emitted in an event)</li>
<li>complete_bet function is callable only by the oracle (oracle needs to suppy the bet id and result/current price point)</li>
<li>The callback function (complete_bet) in the prediction_market is triggered by calling the call_indexed_contract function in the oracle.</li>
  <li>The test ERC-20 token deployed can be used to stake tokens in the bet.</li>

