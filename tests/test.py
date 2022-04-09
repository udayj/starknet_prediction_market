from ctypes import addressof
import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils.Account import Account

# reference - https://perama-v.github.io/cairo/examples/test_accounts/
# Create signers that use a private key to sign transaction objects.
NUM_SIGNING_ACCOUNTS = 2
DUMMY_PRIVATE = 123456789987654321
# All accounts currently have the same L1 fallback address.
L1_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984

@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture(scope='module')
async def account_factory():
    # Initialize network
    starknet = await Starknet.empty()
    accounts = []
    print(f'Deploying {NUM_SIGNING_ACCOUNTS} accounts...')
    for i in range(NUM_SIGNING_ACCOUNTS):
        account = Account(DUMMY_PRIVATE + i, L1_ADDRESS)
        await account.create(starknet)
        accounts.append(account)
        print(f'Account {i} is: {account}')

    # Admin is usually accounts[0], user_1 = accounts[1].
    # To build a transaction to call func_xyz(arg_1, arg_2)
    # on a TargetContract:

    # user_1 = accounts[1]
    # await user_1.tx_with_nonce(
    #     to=TargetContractAddress,
    #     selector_name='func_xyz',
    #     calldata=[arg_1, arg_2])
    return starknet, accounts


@pytest.fixture(scope='module')
async def application_factory(account_factory):
    starknet, accounts = account_factory
    oracle = await starknet.deploy(source="contracts/oracles/oracle.cairo")
    token = await starknet.deploy(source="contracts/tokens/ERC20.cairo",constructor_calldata=[1,1,18])
    market = await starknet.deploy(source="contracts/prediction_market.cairo",constructor_calldata=[oracle.contract_address])

    return starknet, accounts, oracle, token, market

@pytest.mark.asyncio
async def test_flow(application_factory):

    
    _, accounts, oracle, token, market = application_factory
    # Let two different users save a number.
    user_0 = accounts[0]
   
    user_1 = accounts[1]
  
    
    await user_0.tx_with_nonce(
        to=token.contract_address,
        selector_name='mint',
        calldata=[user_0.address,1000,0])

    await user_1.tx_with_nonce(
            to=token.contract_address,
            selector_name='mint',
            calldata=[user_1.address,2000,0])

    # View transactions don't require an authorized transaction.
    user_0_balance = await token.balanceOf(
        user_0.address).invoke()
    user_1_balance = await token.balanceOf(
        user_1.address).invoke()

    #print(user_0_balance.result)
    assert user_0_balance.result[0] == (1000,0)
    assert user_1_balance.result[0] == (2000,0)

    await user_0.tx_with_nonce(

        to=token.contract_address,
        selector_name='approve',
        calldata=[market.contract_address,1000,0]
    )

    await user_0.tx_with_nonce(

        to=market.contract_address,
        selector_name='start_bet',
        calldata=[1,2000,0,1000,0,token.contract_address]
    )

    execution_info = await market.get_bet_info(0).invoke()

    print(execution_info.result)


    await user_1.tx_with_nonce(

        to=token.contract_address,
        selector_name='approve',
        calldata=[market.contract_address,1000,0]
    )

    await user_1.tx_with_nonce(

        to=market.contract_address,
        selector_name='join_bet',
        calldata=[0]
    )

    execution_info = await market.get_bet_info(0).invoke()

    assert execution_info.result[0][0]==user_0.address
    assert execution_info.result[0][1]==user_1.address

    #execution_info = await market.get_bet_info(0).invoke()

    #print(execution_info.result)

    await user_1.tx_with_nonce(
        to=oracle.contract_address,
        selector_name='call_indexed_contract',
        calldata=[0,3,0,2500,0]
    )


    user_0_balance = await token.balanceOf(
        user_0.address).invoke()
    user_1_balance = await token.balanceOf(
        user_1.address).invoke()
    
    assert user_0_balance.result[0] == (2000,0) # check balances
    assert user_1_balance.result[0] == (1000,0) # check balances


    execution_info = await market.get_bet_info(0).invoke()


    assert execution_info.result[0][7]==user_0.address  # check winner
 
    assert execution_info.result[0][6]==2  # check status




    #print(execution_info.result)

    #execution_info = await oracle.get_task(0).invoke()

    #print(execution_info.result)

    execution_info = await market.initiator_to_bet_ids(user_0.address).invoke()

    assert len(execution_info.result[0]) == 1
    assert execution_info.result[0][0] == 0  # check only bet id 0 was created by user_0

    execution_info = await market.initiator_to_bet_ids(user_1.address).invoke()

    assert len(execution_info.result[0]) == 0


    #print(execution_info.result)

