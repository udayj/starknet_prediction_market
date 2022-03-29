%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.math_cmp import is_le

# oversimplication of the ERC20 mechanics below - no tokens are actually transfered...we just keep track of balance in a var
# the oracle is non-existant...TODO - oracle contract that can be asked for data and given a callback function to execute
# TODO assertions to check for various conditions and assumptions
# TODO NFT for the position in the bet
struct BetInfo:

    member participant1:felt
    member participant2:felt
    member position_participant1:felt # 0 means bet that price will be lower than predicted price point and 1 means higher
    member predicted_price_point:felt
    member staked_amount:felt
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
func balance(user:felt) -> (res:felt):
end

@external
func increase_balance{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(participant:felt, amount:felt):

    let (current_balance) = balance.read(user=participant)
    balance.write(participant, current_balance + amount)
    return()
end

@external
func decrease_balance{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(participant:felt, amount:felt):

    let (current_balance) = balance.read(user=participant)
    balance.write(participant, current_balance - amount)
    return()
end

# the participant initiating the bet gets to decide the position (0 lower / 1 higher), price point, and staked amount
@external
func start_bet{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(position:felt, price_point:felt, amount:felt) -> (bet_id:felt):

    with_attr error_message("Price point cannot be negative"):
        assert_nn(price_point)
    end

    let (participant1)=get_caller_address()

    let (current_participant_balance)=balance.read(user=participant1)

    # this is the part where we spoof the ERC20 mechanics
    decrease_balance(participant1, amount)
    increase_balance(0,amount)
    #balance.write(user=participant, current_participant_balance-amount)
    #balance.write(user=0, amount)  #user=0 signifies the protocol address
    let new_bet_info:BetInfo=BetInfo(participant1=participant1,
                         participant2=0,
                         position_participant1=position,
                         predicted_price_point=price_point,
                         staked_amount=amount,
                         status=0, #0 means open, 1 means closed but undecided, 2 means decided and completed
                         winner=0)

    let (current_bet_id) = bet_id.read()
    bet_id.write(current_bet_id+1)

    bet_info.write(current_bet_id,new_bet_info)
    return (current_bet_id)
end


@external
func join_bet{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(existing_bet_id:felt):

    let (participant2)=get_caller_address()

    let (current_participant_balance)=balance.read(user=participant2)

    

    #balance.write(user=participant, current_participant_balance-amount)
    #balance.write(user=0, amount)

    let existing_bet_info:BetInfo = bet_info.read(bet_id=existing_bet_id)

    decrease_balance(participant2, existing_bet_info.staked_amount)
    increase_balance(0,existing_bet_info.staked_amount)

    let updated_bet_info: BetInfo = BetInfo(participant1=existing_bet_info.participant1,
                                    participant2=participant2,
                                    position_participant1=existing_bet_info.position_participant1,
                                    predicted_price_point=existing_bet_info.predicted_price_point,
                                    staked_amount=existing_bet_info.staked_amount,
                                    status=1,
                                    winner=0)
    bet_info.write(existing_bet_id,updated_bet_info)
    return()
end

#this will ideally be called by an oracle contract to which we have passed this function's selector
@external
func close_bet{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(bet_id:felt,current_price_point:felt):

    alloc_locals
    local syscall_ptr:felt* = syscall_ptr
    local pedersen_ptr:HashBuiltin* = pedersen_ptr
    let existing_bet_info: BetInfo=bet_info.read(bet_id=bet_id)
    local position = existing_bet_info.position_participant1
    

    let is_le_status:felt = is_le(current_price_point,existing_bet_info.predicted_price_point)
   

        if is_le_status == 1:
        if position == 0:
            set_winner(bet_id, existing_bet_info.participant1)
            return()
        end
        set_winner(bet_id, existing_bet_info.participant2)
        return()
    end


    if is_le_status == 0:

        if position == 1:
            set_winner(bet_id, existing_bet_info.participant1)
            return()
        end
        set_winner(bet_id, existing_bet_info.participant2)
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
                                    position_participant1=existing_bet_info.position_participant1,
                                    staked_amount=existing_bet_info.staked_amount,
                                    predicted_price_point=existing_bet_info.predicted_price_point,
                                    status=2,
                                    winner=winner)
    bet_info.write(bet_id,updated_bet_info)

    increase_balance(winner, 2*existing_bet_info.staked_amount)
    decrease_balance(0,2*existing_bet_info.staked_amount)
    return()
end