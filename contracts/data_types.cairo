%lang starknet

from starkware.cairo.common.uint256 import Uint256

#this struct holds all the relevant data pertaining to a bet/private market

struct BetInfo:

    member participant1:felt
    member participant2:felt
    member currency_address: felt
    member position_participant1:felt # 0 means bet that price will be lower than predicted price point and 1 means higher
    member predicted_price_point:Uint256 # this can be price of anything (like ETH) which can be provided by a trustable oracle
    member staked_amount:Uint256
    member status: felt
    member winner: felt
    member asset_type: felt # presently ignored but eventually can be used to support different assets (ETH,wBTC etc.)
    member decision_time: felt # decision time will be time_duration (supplied by initiator) + current block timestamp
end