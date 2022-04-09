%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace ITaskManager:

    func add_task(bet_id:felt, decision_time:felt, asset_type:felt) -> (res:felt):
    end
end

