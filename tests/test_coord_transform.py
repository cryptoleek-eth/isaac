import pytest
import os
from starkware.starknet.testing.starknet import Starknet
import asyncio
from Signer import Signer
import random
from enum import Enum
import logging

from starkware.starknet.compiler.compile import (
    compile_starknet_files)
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.testing.contract import StarknetContract

LOGGER = logging.getLogger(__name__)
TEST_NUM_PER_CASE = 100
PRIME = 3618502788666131213697322783095070105623107215331596699973092056135872020481
PRIME_HALF = PRIME//2
PLANET_DIM = 100

# The path to the contract source code.
CONTRACT_FILE = os.path.join(
    os.path.dirname(__file__), "../contracts/mocks/mock_coord_transform.cairo")

print("test: "+os.path.dirname(__file__))

@pytest.mark.asyncio
async def test_micro ():
    print("test: "+os.path.dirname(__file__))
    # Compile the contract.
    contract_definition = compile_starknet_files(
        [CONTRACT_FILE], debug_info=True)

    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    print(f'> Deploying mock_micro.cairo ..')
    contract = await starknet.deploy (
        source = 'contracts/mocks/mock_coord_transform.cairo',
        constructor_calldata = []
    )

    #############################
    # Test `mock_device_deploy()`
    #############################
    print('> Testing mock_device_deploy()')




    # LOGGER.info (f'> {i_format}/{TEST_NUM_PER_CASE} | input: grid {grid} on face {face} and edge {edge}, output: {ret.result}')
