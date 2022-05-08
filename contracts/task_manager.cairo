%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.math_cmp import is_le
from contracts.interfaces.IOracle_v2 import IOracle_v2
from starkware.cairo.common.uint256 import Uint256
from contracts.interfaces.IPredictionMarket import IPredictionMarket

struct Task:

    member bet_id:felt
    member decision_time: felt
    member status: felt
    member asset_type: felt
end

@storage_var
func data_task_store(task_id:felt) -> (task: Task):
end

@storage_var
func task_id()->(res:felt):
end

@storage_var
func market_address()->(res:felt):
end

@storage_var
func oracle_address()->(res:felt):
end

# function to add task to task store for execution at decision time
@external
func add_task{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(bet_id:felt, decision_time: felt, asset_type:felt) -> (res:felt):

    alloc_locals

    let (current_task_id)=task_id.read()

    let new_task:Task = Task(bet_id=bet_id,
                             decision_time=decision_time,
                             status=0,
                             asset_type=asset_type)
    data_task_store.write(current_task_id,new_task)
    
    task_id.write(current_task_id+1)
    return(1)
end

@external
func set_market_address{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(address: felt):

    market_address.write(address)
    return()
end

@external
func set_oracle_address{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(address: felt):

    oracle_address.write(address)
    return()
end

# this function recursively checks whether a task is ready for execution by comparing decision time to current blocktimestamp
# it returns true on finding the first task ready for exectuion without checking exhaustively

func check_for_readiness{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(num_tasks:felt) -> (result:felt):
    
    alloc_locals
    if num_tasks == 0:
        return (0)
    end

    let index = num_tasks - 1

    let task : Task = data_task_store.read(index)
    let (current_block_timestamp) = get_block_timestamp()

    local syscall_ptr:felt* = syscall_ptr
    let (is_le_status) = is_le(task.decision_time, current_block_timestamp)
    let (is_executed_status) = is_le(task.status,0)
    if is_le_status*is_executed_status == 1:
        return (1)
    else:

        let (result) = check_for_readiness(num_tasks-1)
        return (result)
    end
end

# defined as per reference https://docs.yagi.fi/developers/automation/how-to-create-a-task

@view
func probeTask{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}() -> (taskReady: felt):

    alloc_locals

    let (num_tasks) = task_id.read()

    let (local taskReady) = check_for_readiness(num_tasks)

    return (taskReady)
end

# this function executes tasks recursively by rechecking every task for 2 conditions
# decision time < current blocktimestamp
# task has not already been executed i.e. status==0

func execute_tasks{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr} (num_tasks: felt):

    alloc_locals
    if num_tasks == 0:
        return()
    end
    local index = num_tasks - 1

    let (local task : Task) = data_task_store.read(index)
    let (current_block_timestamp) = get_block_timestamp()
    let (is_timestamp_status) = is_le(task.decision_time, current_block_timestamp)
    let (is_executed_status) = is_le(task.status,0)

    # ready for execution && not already executed
    if is_timestamp_status*is_executed_status == 1:

        let (local oracle ) = oracle_address.read()
        let (local market ) = market_address.read()


        let current_asset_value:Uint256 = IOracle_v2.get_data(contract_address=oracle, asset_type=task.asset_type)

        IPredictionMarket.complete_bet(contract_address=market, 
                                       bet_id=task.bet_id, 
                                       current_price_point = current_asset_value)

        let updated_task: Task = Task (bet_id = task.bet_id,
                                       decision_time = task.decision_time,
                                       status = 1,
                                       asset_type = task.asset_type)
        data_task_store.write(index,updated_task)

        execute_tasks(num_tasks - 1)
        return()
    
    else:
        execute_tasks(num_tasks - 1)
        return()
    end
end

# defined as per reference https://docs.yagi.fi/developers/automation/how-to-create-a-task

@external
func executeTask{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}():

    alloc_locals

    let (num_tasks) = task_id.read()

    execute_tasks(num_tasks)

    return()
end

# the following are simple helper functions to get to know the state of the system

@view
func get_current_task_id{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}() -> (current_task_id:felt):

    let (current_task_id)=task_id.read()
    return (current_task_id)
end

@view
func get_data_task{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(task_id:felt) -> (task:Task):

    let task:Task = data_task_store.read(task_id)

    return (task)
end

@view
func get_market_address{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}() -> (address:felt):

    let (current_market_address)=market_address.read()
    return(current_market_address)
end

@view
func get_oracle_address{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}() -> (address: felt):

    let (current_oracle_address)=oracle_address.read()
    return(current_oracle_address)
end

@view
func get_current_blocktimestamp{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}() -> (res:felt):
    
    let (current_timestamp) = get_block_timestamp()
    return(current_timestamp)
end