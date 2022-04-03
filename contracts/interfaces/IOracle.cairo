# SPDX-License-Identifier: MIT

%lang starknet

from contracts.oracles.oracle import ContractData

@contract_interface
namespace IOracle:

    func get_task(index:felt) -> (contract:ContractData):
    end

    func set_task(index:felt,contract:ContractData) -> (status:felt):
    end

    func call_indexed_contract(index:felt, calldata_len:felt, calldata:felt*):
    end
end



