%lang starknet
%builtins pedersen range_check

from starkware.starknet.common.syscalls import call_contract
from starkware.cairo.common.cairo_builtins import HashBuiltin

struct ContractData:
    member contract_address:felt
    member function_selector:felt
    member function_called:felt
end

#the indexing is leaky here meaning there is a tight coupling between indexes here and bet ids in the prediction market
@storage_var
func contract_indexer(index:felt) -> (contract:ContractData):
end

@external
func get_task{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(index:felt) -> (contract:ContractData):
    let (contract)=contract_indexer.read(index)
    return(contract)
end

@external 
func set_task{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(index:felt, contract:ContractData) -> (status:felt):
    
        contract_indexer.write(index,contract)
        return(status=1)
end

@external
func call_indexed_contract{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(index:felt, calldata_len:felt, calldata:felt*):

        let(contract)=contract_indexer.read(index)

        with_attr error_message("Call to contract already completed"):
            assert contract.function_called = 0
        end

        let (retdatasize, retdata)=call_contract(contract.contract_address,
                                                 contract.function_selector,
                                                 calldata_len,
                                                 calldata)
        
        let updated_contract_data:ContractData=ContractData(contract.contract_address,
                                                 contract.function_selector,
                                                 1)
        contract_indexer.write(index,updated_contract_data)
        return()
end
        

