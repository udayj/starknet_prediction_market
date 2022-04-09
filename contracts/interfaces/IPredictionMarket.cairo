%lang starknet

from contracts.oracles.oracle import ContractData
from contracts.data_types import BetInfo
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IPredictionMarket:

    func check_valid_bet_id(existing_bet_id:felt):
    end

    func start_bet(position:felt, price_point:Uint256, amount:Uint256, currency_address:felt) -> (bet_id:felt):
    end

    func join_bet(existing_bet_id:felt):
    end

    func complete_bet(bet_id:felt,current_price_point:Uint256):
    end

    func get_bet_info(bet_id:felt) -> (res:BetInfo):
    end

    func get_oracle_address() -> (address:felt):
    end

end