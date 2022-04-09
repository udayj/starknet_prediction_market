%lang starknet
%builtins pedersen range_check

from starkware.starknet.common.syscalls import call_contract
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

@storage_var
func datastore(asset_type:felt) -> (value:Uint256):
end

@external
func get_data{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(asset_type:felt) -> (value:Uint256):
    
    let current_value:Uint256 = datastore.read(asset_type)

    return (current_value)
end

@external
func set_data{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(asset_type: felt, value: Uint256):
    

    datastore.write(asset_type, value)
    return()
end
