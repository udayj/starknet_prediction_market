# Private Prediction Market for Starknet

### Basic Idea
<p>A and B can enter into a bet by staking some token(ERC20-compliant) - lets say they bet on the price of ETH after 1 month, so we setup a callback with an oracle (through a task_manager) asking it to give the results to the protocol after the stipulated time, and whoever wins gets to keep the full staked amount - this can then be extended to arbitrary number of participants - we can also create an NFT to represent the position in the bet for a participant which can then be traded on any permissionless NFT market (thereby securitizing predictions/opinions ?) - we could also deposit the staked amounts into some kind of yield bearing protocol, and the interest earned can be the reward for the winner and the staked amounts could be returned to the participants thereby creating a kind of lossless prediction market.</p>

<p>
The oracle is currently spoofed - we set the data manually for any asset type which would be retrieved by the task manager (automation system).</p>

### Deployment
The protocol(prediction_market), a test ERC-20 token, task manager (which will call the oracle at decision time to get asset price) and an oracle are deployed on the goerli testnet. The relevant addresses can be found in the [goerli.deployments.txt](https://github.com/udayj/starknet_prediction_market/blob/master/goerli.deployments.txt) file.

### User Flow
Important functions in the prediction_market contract
<ol>
  
  <li>start_bet function needs the following arguments to initiate a bet</li>
<ul>
  <li>Position (0/1) 0 means you are betting that price will go down and 1 means price will go up</li>
  <li>Predicted Price Point (the price point around which the prediction is being made)</li>
  <li>Staked amount</li>
  <li>ERC-20 token address which you want to stake (the requirement for this argument will be removed later) </li>
  <li>Asset Type (currently ignored but helps support prediction for different types of assets ETH, wBTC etc.</li>
  <li>Time Duration - used to calculated decision time (decision time = time_duration + current_blocktimestamp)</li>
  <li> It also issues an NFT to the caller of this function. This NFT represents the position in the bet and is freely tradeable on any marketplace </li>
</ul>
<li>join_bet function needs the bet_id which is returned from start_bet (and also emitted in an event) and issues another NFT to represent the opposite position in this bet</li>
<li>complete_bet function is callable only by the task_manager (needs to suppy the bet id and result/current price point)</li>
<li>The callback function (complete_bet) in the prediction_market is triggered through execution of the executeTask function in task_manager</li>
<li>The close_bet function can be called by the owner of participant1 NFT to close a bet which has not yet been joined by another participant.</li>
<li>The test ERC-20 token deployed can be used to stake tokens in the bet.</li>

