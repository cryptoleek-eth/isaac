%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash_chain import hash_chain
from starkware.cairo.common.math import (assert_lt, assert_nn)
from starkware.cairo.common.math_cmp import (is_le, is_nn_le)
from starkware.cairo.common.alloc import (alloc)

from contracts.design.constants import (face_index_to_radians, test_90_degrees)
from contracts.util.structs import (Vec2)
from contracts.libs.taylor import (sine_7th)

func coord_transform {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
        momentum_magnitude : felt, face_index : felt, phi : felt
    ) -> (momentum_vector : Vec2):
    alloc_locals

    # get the starting radian value of the given face
    local original_face_index_normal_radians
    if face_index == 0:
        assert original_face_index_normal_radians = face_index_to_radians.face0
        jmp next
    end
    if face_index == 1:
        assert original_face_index_normal_radians = face_index_to_radians.face1
        jmp next
    end
    if face_index == 3:
        assert original_face_index_normal_radians = face_index_to_radians.face3
        jmp next
    end
    if face_index == 4:
        assert original_face_index_normal_radians = face_index_to_radians.face4
        jmp next
    else: 
        return(Vec2(0,0))
    end

    next: 

    # get the direction the given face is pointing currently in radians
    let curr_face_index_normal_radians : felt = phi + original_face_index_normal_radians
    
    # using cos(theta) = sin(90 - theta)
    let cos_value : felt = test_90_degrees - curr_face_index_normal_radians

    # turn momentum_magnitude into momentum in the x and y direction
    let sine_result_1 : felt = sine_7th(cos_value)
    let momentum_x : felt = momentum_magnitude * sine_result_1
    let sine_result_2 : felt = sine_7th(curr_face_index_normal_radians)
    let momentum_y : felt = momentum_magnitude * sine_result_2

    return (Vec2(momentum_x, momentum_y))
end