%lang starknet


from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_nn, assert_le, assert_lt, assert_not_equal
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_add, uint256_lt


from contracts.interfaces.IERC20 import IERC20
from contracts.interfaces.IOracle import IOracle
from contracts.oracles.oracle import ContractData

from openzeppelin.utils.constants import TRUE

# 
# the oracle is non-existant...TODO - oracle contract that can be asked for data and given a callback function to execute
# TODO assertions to check for various conditions and assumptions
# TODO NFT for the position in the bet
struct BetInfo:

    member participant1:felt
    member participant2:felt
    member currency_address: felt
    member position_participant1:felt # 0 means bet that price will be lower than predicted price point and 1 means higher
    member predicted_price_point:Uint256
    member staked_amount:Uint256
    member status: felt
    member winner: felt
end


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

@constructor
func constructor{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(address:felt):

    oracle_address.write(address)
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

@event
func start_bet_called(initiator:felt, bet_id:felt):
end
# the participant initiating the bet gets to decide the position (0 lower / 1 higher), price point, and staked amount
@external
func start_bet{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(position:felt, price_point:Uint256, amount:Uint256, currency_address:felt) -> (bet_id:felt):


    let UINT256_ONE:Uint256=Uint256(low=1,high=0)

    with_attr error_message("Staked amount cannot be less than 1"):
        let (staked_amount_status:felt ) = uint256_lt(amount, UINT256_ONE)
        assert staked_amount_status = 0
    end

    with_attr error_message("Position can only be 0 or 1"):
        assert_nn(position)
        assert_le(position,1)
    end


    let (participant1)=get_caller_address()

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
                         winner=0)

    let (current_bet_id) = bet_id.read()
    bet_id.write(current_bet_id+1)

    bet_info.write(current_bet_id,new_bet_info)
    start_bet_called.emit(initiator=participant1,bet_id=current_bet_id)

    return (current_bet_id)
end


@external
func join_bet{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(existing_bet_id:felt):

    let (participant2)=get_caller_address()

    check_valid_bet_id(existing_bet_id)

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
                                    winner=0)
    bet_info.write(existing_bet_id,updated_bet_info)

    #function selector found using get_selector_from_name in starkware.starknet.public.abi (.py)
    #get_selector_from_name('complete_bet')
    let function_selector:felt = 843701533249128903986784726593517935028271838306755478971744945730444094598

    let contract:ContractData = ContractData(contract_address=recipient_address,
                                  function_selector=function_selector,
                                  function_called=0)

    let (current_oracle_address) = oracle_address.read()
    let (status)=IOracle.set_task(contract_address=current_oracle_address,index=existing_bet_id,contract=contract)

    with_attr error_message("Problem setting task in oracle"):
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
                                    winner=winner)
    bet_info.write(bet_id,updated_bet_info)
    
    let (winning_amount:Uint256, carry:felt ) = uint256_add(existing_bet_info.staked_amount,existing_bet_info.staked_amount)
    # we are just going to assume we are delaing with small enough numbers that carry does not matter

    let (status:felt) = IERC20.transfer(contract_address=existing_bet_info.currency_address,
                                        recipient=winner, 
                                        amount=winning_amount)


    with_attr error_message("Problem transfering winning amount"):
        assert status = TRUE
    end
    #increase_balance(winner, 2*existing_bet_info.staked_amount)
    #decrease_balance(0,2*existing_bet_info.staked_amount)
    
    return()
end

#this will ideally be called by an oracle contract to which we have passed this function's selector
@external
func complete_bet{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(bet_id:felt,current_price_point:Uint256):

    alloc_locals
   
    check_valid_bet_id(bet_id)
    let(caller) = get_caller_address()
    let(current_oracle_address)=oracle_address.read()
    with_attr error_message("Unauthorized caller"):

        assert caller = current_oracle_address
    end

    let existing_bet_info: BetInfo=bet_info.read(bet_id=bet_id)
    
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