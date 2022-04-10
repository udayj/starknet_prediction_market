%lang starknet


from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address, 
    get_contract_address, 
    get_block_timestamp
)
from starkware.cairo.common.math import (
    assert_nn, 
    assert_le, 
    assert_lt, 
    assert_not_equal
)
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import (
    Uint256, 
    uint256_le, 
    uint256_add, 
    uint256_lt
)
from openzeppelin.utils.constants import TRUE
from starkware.cairo.common.alloc import alloc
from contracts.interfaces.IERC20 import IERC20
from contracts.interfaces.IOracle import IOracle
from contracts.oracles.oracle import ContractData
from contracts.data_types import BetInfo
from contracts.interfaces.ITaskManager import ITaskManager




# we are spoofing the oracle contract that can is just given the function selector to execute
# TODO NFT for the position in the bet
# separate explicit position for participant 2 not being stored as it is assumed that it will be opposite to that of participant1


@storage_var
func bet_info(bet_id:felt) -> (bet: BetInfo):
end

@storage_var
func bet_id() -> (res:felt):
end

@storage_var
func oracle_address() -> (address:felt):
end

# address -> number of bets initiated mapping
@storage_var
func num_bets_initiated(address:felt) -> (num:felt):
end

@storage_var
func task_manager_address() -> (address: felt):
end

@external
func set_task_manager_address{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(address:felt):

    task_manager_address.write(address)
    return()
end

@constructor
func constructor{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(address:felt):

    oracle_address.write(address) #store oracle address that will call complete_bet function to decide winner
    return()
end


func check_valid_account(participant:felt):

     with_attr error_message("This function is only callable from an account"):
        assert_not_equal(participant,0)
    end
    return()
end

@external
func check_valid_bet_id{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(existing_bet_id:felt):
    let (current_bet_id)= bet_id.read()

    with_attr error_message("Incorrect Bet ID"):
        assert_lt(existing_bet_id,current_bet_id)
        assert_nn(existing_bet_id)
    end
    return()

end

# any front-end for this contract should listen for this event (to get the bet id - which will be used by 2nd participant
# for joining the bet

@event
func start_bet_called(initiator:felt, bet_id:felt):
end
# the participant initiating the bet gets to decide the position (0 lower / 1 higher), price point (in USD), and staked amount
# and staking token address alongwith asset_type (currently ignored and assumed to be ETH)
@external
func start_bet{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(position:felt, 
                         price_point:Uint256, 
                         amount:Uint256, 
                         currency_address:felt,
                         asset_type: felt,
                         time_duration: felt) -> (bet_id:felt):

    alloc_locals
    let UINT256_ONE:Uint256=Uint256(low=1,high=0)

    with_attr error_message("Staked amount cannot be less than 1"):
        let (staked_amount_status:felt ) = uint256_lt(amount, UINT256_ONE)
        assert staked_amount_status = 0
    end

    with_attr error_message("Position can only be 0 or 1"):
        assert_nn(position)
        assert_le(position,1)
    end

    with_attr error_message("Time duration cannot be negative"):
        assert_nn(time_duration)
    end

    let (local current_timestamp) = get_block_timestamp()
    local decision_time = time_duration + current_timestamp
    let (participant1)=get_caller_address()

    #this function needs to be called through an account contract
    check_valid_account(participant1)


    let (recipient_address:felt) = get_contract_address()
    let (status) = IERC20.transferFrom(contract_address=currency_address,
                                       sender=participant1, 
                                       recipient=recipient_address, 
                                       amount=amount)
    
    with_attr error_message("Problem staking tokens with contract"):
        assert status = TRUE
    end
   
    let new_bet_info:BetInfo=BetInfo(participant1=participant1,
                         participant2=0,
                         currency_address=currency_address,
                         position_participant1=position,
                         predicted_price_point=price_point,
                         staked_amount=amount,
                         status=0, #0 means open, 1 means closed but undecided, 2 means decided and completed
                         winner=0,
                         asset_type=asset_type,
                         decision_time=decision_time)

    let (current_bet_id) = bet_id.read()
    bet_id.write(current_bet_id+1)

    bet_info.write(current_bet_id,new_bet_info)
    let (num_bets)= num_bets_initiated.read(participant1)
    num_bets_initiated.write(participant1,num_bets+1)
    #emitting the event for front end to get to know the bet id
    start_bet_called.emit(initiator=participant1,bet_id=current_bet_id)

    return (current_bet_id)
end


# this function will be called by the 2nd participant to join an existing bet which is still open (status==0)
@external
func join_bet{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(existing_bet_id:felt):

    let (participant2)=get_caller_address()

    check_valid_bet_id(existing_bet_id)

    #this function can should be called from an account contract
    check_valid_account(participant2)

    let existing_bet_info:BetInfo = bet_info.read(bet_id=existing_bet_id)

    with_attr error_message("This bet is not open for joining"):
        assert existing_bet_info.status = 0
    end

    let (recipient_address:felt) = get_contract_address()
    let (status:felt) = IERC20.transferFrom(contract_address=existing_bet_info.currency_address,
                                            sender = participant2,
                                            recipient = recipient_address,
                                            amount=existing_bet_info.staked_amount)
    

    with_attr error_message("Problem staking tokens with contract"):
        assert status = TRUE
    end

    

    let updated_bet_info: BetInfo = BetInfo(participant1=existing_bet_info.participant1,
                                    participant2=participant2,
                                    currency_address = existing_bet_info.currency_address,
                                    position_participant1=existing_bet_info.position_participant1,
                                    predicted_price_point=existing_bet_info.predicted_price_point,
                                    staked_amount=existing_bet_info.staked_amount,
                                    status=1,
                                    winner=0,
                                    asset_type=existing_bet_info.asset_type,
                                    decision_time=existing_bet_info.decision_time)
    bet_info.write(existing_bet_id,updated_bet_info)

   

    let (task_manager) = task_manager_address.read()

    # add new task to task manager - this will be executed at decision time to get the latest asset price
    # for deciding winner of the bet
    let (status) = ITaskManager.add_task(contract_address = task_manager,
                                         bet_id = existing_bet_id,
                                         decision_time = existing_bet_info.decision_time,
                                         asset_type = existing_bet_info.asset_type)

    with_attr error_message("Problem setting task in task manager"):
        assert status = 1
    end

    return()
end

func set_winner{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(bet_id:felt, winner:felt):

    alloc_locals

    local syscall_ptr:felt* = syscall_ptr
     let existing_bet_info:BetInfo=bet_info.read(bet_id=bet_id)

     let updated_bet_info: BetInfo = BetInfo(participant1=existing_bet_info.participant1,
                                    participant2=existing_bet_info.participant2,
                                    currency_address=existing_bet_info.currency_address,
                                    position_participant1=existing_bet_info.position_participant1,
                                    predicted_price_point=existing_bet_info.predicted_price_point,
                                    staked_amount=existing_bet_info.staked_amount,
                                    status=2,
                                    winner=winner,
                                    asset_type=existing_bet_info.asset_type,
                                    decision_time=existing_bet_info.decision_time)
    bet_info.write(bet_id,updated_bet_info)
    
    let (winning_amount:Uint256, carry:felt ) = uint256_add(existing_bet_info.staked_amount,existing_bet_info.staked_amount)
    # we are just going to assume we are delaing with small enough numbers that carry does not matter

    let (status:felt) = IERC20.transfer(contract_address=existing_bet_info.currency_address,
                                        recipient=winner, 
                                        amount=winning_amount)


    with_attr error_message("Problem transfering winning amount"):
        assert status = TRUE
    end
     
    return()
end

#this can only be called by an oracle contract to which we have passed this function's selector
@external
func complete_bet{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(bet_id:felt,current_price_point:Uint256):

    alloc_locals
   
    check_valid_bet_id(bet_id)
    let(caller) = get_caller_address()
    let(current_task_manager_address)=task_manager_address.read()
    with_attr error_message("Unauthorized caller"):

        assert caller = current_task_manager_address
    end

    let existing_bet_info: BetInfo=bet_info.read(bet_id=bet_id)
    
    #only bets with status==1 can be completed and winner decided
    with_attr error_message("Only closed and undecided bets can be completed"):
        assert existing_bet_info.status = 1
    end

    local position = existing_bet_info.position_participant1
    
    let is_le_status:felt = uint256_le(current_price_point,existing_bet_info.predicted_price_point)
    tempvar syscall_ptr:felt*=syscall_ptr

    if is_le_status == 1:
        if position == 0:
            set_winner(bet_id, existing_bet_info.participant1)
            tempvar syscall_ptr:felt* = syscall_ptr
            
        else:
            set_winner(bet_id, existing_bet_info.participant2)
            tempvar syscall_ptr:felt* = syscall_ptr
        end
    
    else:

        if position == 1:
            set_winner(bet_id, existing_bet_info.participant1)
            tempvar syscall_ptr:felt* = syscall_ptr
        else:
            set_winner(bet_id, existing_bet_info.participant2)
            tempvar syscall_ptr:felt* = syscall_ptr
        end
    end



    return()
end

# this function recursively gets the bet_ids associated with address as the participant1

func get_bet_ids{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(address:felt, num_bets:felt, bet_ids:felt*, bets_found:felt, index:felt):

    if num_bets==bets_found:
        return()
    end

    let bet:BetInfo = get_bet_info(index)

    if bet.participant1 == address:
        assert [bet_ids]=index
        get_bet_ids(address,num_bets,bet_ids+1,bets_found+1,index+1)
        return()
    else:
        get_bet_ids(address,num_bets,bet_ids,bets_found,index+1)
        return()
    end
    
end

# this function takes an address and returns the list of bet ids that were created by this address as the initiator
# here initiator means participant1 in terms of BetInfo members

@view
func initiator_to_bet_ids{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(address:felt) -> (bet_ids_len:felt, bet_ids:felt*):

    alloc_locals
    let (local num_bets) = num_bets_initiated.read(address)

    let (bet_ids) = alloc()

    # recursively fill the bet_ids array with the relevant bet ids
    get_bet_ids(address=address,
                num_bets=num_bets,
                bet_ids=bet_ids,
                bets_found=0,
                index=0)

    return(num_bets,bet_ids)
end


@external
func set_oracle_address{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(address:felt):

    with_attr error_message("cannot be 0 address"):
        assert_not_equal(address,0)
    end

    oracle_address.write(address)
    return()
end



@view
func get_bet_info{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(bet_id:felt) -> (res:BetInfo):
    return bet_info.read(bet_id)
end


@view
func get_oracle_address{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}() -> (address:felt):

    let (current_oracle_address) = oracle_address.read()
    return(current_oracle_address)
end

@view
func get_current_bet_id{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (current_bet_id:felt):
    let (current_bet_id) = bet_id.read()
    return (current_bet_id)
end

@view
func get_task_manager_address{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}() -> (address:felt):

    let (current_task_manager_address) = task_manager_address.read()
    return(current_task_manager_address)
end


