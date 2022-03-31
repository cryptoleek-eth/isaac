%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash_chain import hash_chain
from starkware.cairo.common.math import (assert_lt, assert_nn)
from starkware.cairo.common.math_cmp import (is_le, is_nn_le)
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import (get_block_number, get_caller_address)

from contracts.macro import (forward_world_macro)
from contracts.design.constants import (ns_device_types, face_index_to_radians, test_90_degrees)
from contracts.util.structs import (
    MicroEvent, Vec2
)
from contracts.util.grid import (
    is_valid_grid, are_contiguous_grids_given_valid_grids,
    is_zero
)
from contracts.libs.taylor import (sine_7th)

func coord_transform {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
        momentum_magnitude : felt, face_index : felt, phi : felt
    ) -> (momentum_vector : felt):
    alloc_locals

    # get the starting radian value of the given face
    if face_index == 0:
        let original_face_index_normal_radians = face_index_to_radians.face0
        jmp next
    end
    if face_index == 1:
        let original_face_index_normal_radians = face_index_to_radians.face1
        jmp next
    end
    if face_index == 3:
        let original_face_index_normal_radians = face_index_to_radians.face3
        jmp next
    end
    if face_index == 4:
        let original_face_index_normal_radians = face_index_to_radians.face4
        jmp next
    else: 
        return(0)
    end

    next: 
    # get the direction the given face is pointing currently in radians
    let curr_face_index_normal_radians : felt = phi + original_face_index_normal_radians
    
    let cos_value : felt = test_90_degrees - curr_face_index_normal_radians

    # turn momentum_magnitude into momentum in the x and y direction
    let momentum_x : felt = momentum_magnitude * sine_7th(cos_value)
    let momentum_y : felt = momentum_magnitude * sine_7th(curr_face_index_normal_radians)

    return (Vec2(momentum_x, momentum_y))
end