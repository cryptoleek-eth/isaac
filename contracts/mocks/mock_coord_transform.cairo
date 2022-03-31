%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash_chain import hash_chain
from starkware.cairo.common.math import (assert_lt, assert_nn)
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import (get_block_number, get_caller_address)
from contracts.util.structs import (
    MicroEvent, Vec2
)
from contracts.coord_transform import (coord_transform)

@external
func mock_coord_transform {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
        momentum_magnitude: felt, face_index: felt
    ) -> (momentum_vector: felt):

    let (result) = coord_transform(
        momentum_magnitude,
        face_index
    )
    return (result)
end

