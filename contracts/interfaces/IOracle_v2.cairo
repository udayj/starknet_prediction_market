# SPDX-License-Identifier: MIT

%lang starknet

from contracts.oracles.oracle import ContractData
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IOracle_v2:

    func get_data(asset_type:felt) -> (value: Uint256):
    end
end