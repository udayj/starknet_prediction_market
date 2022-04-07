%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.interfaces.IPredictionMarket import IPredictionMarket
from contracts.interfaces.IOracle import IOracle
from contracts.interfaces.IERC20 import IERC20
from pytest_cairo.contract_index import contracts
from pytest_cairo.helpers import deploy_contract


@view 
func test_deploy{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}() -> ():

    let (calldata : felt*) = alloc()
    assert calldata[0] = 1  # Value is not relevant
    let (oracle_address) = deploy_contract(contracts.oracles.oracle, 1, calldata)


    let (calldata_token : felt*) = alloc()
    assert calldata_token[0] = 1
    assert calldata_token[1] = 1
    assert calldata_token[2] = 18
    let (token_address) = deploy_contract(contracts.tokens.ERC20,3,calldata_token)

    let (calldata_market : felt*) = alloc()
    assert calldata_market[0] = oracle_address

    let (market_address) = deploy_contract(contracts.prediction_market,1,calldata_market)

end

    
