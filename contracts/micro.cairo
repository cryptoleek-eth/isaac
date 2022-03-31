%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash_chain import hash_chain
from starkware.cairo.common.math import (assert_lt, assert_nn)
from starkware.cairo.common.math_cmp import (is_le, is_nn_le)
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import (get_block_number, get_caller_address)

from contracts.macro import (forward_world_macro, macro_state, phi_curr)
from contracts.design.constants import (ns_device_types, face_index_to_radians)
from contracts.util.structs import (
    MicroEvent, Vec2
)
from contracts.util.grid import (
    is_valid_grid, are_contiguous_grids_given_valid_grids,
    is_zero
)

##############################

## Note: for utb-set or utl-set, GridStat.deployed_device_index is the set label
struct GridStat:
    member populated : felt
    member deployed_device_type : felt
    member deployed_device_id : felt
    member deployed_device_owner : felt
end

@storage_var
func grid_stats (grid : Vec2) -> (grid_stat : GridStat):
end

func is_unpopulated_grid {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (grid : Vec2) -> ():
    let (grid_stat : GridStat) = grid_stats.read (grid)
    assert grid_stat.populated = 0
    return ()
end

#
# Make this function static i.e. not shifting over time due to geological events, not depleting due to harvest activities;
# instead of initializing this value at civilization start and store it persistently, we choose to recompute the number everytime,
# to (1) reduce compute requirement at civ start (2) trade storage with compute (3) allows for dynamic concentration later on.
# note: if desirable, this function can be replicated as-is in frontend (instead of polling contract from starknet) to compute only-once
# the distribution of concentration value per resource type per grid
#
func get_resource_concentration_at_grid (grid : Vec2, resource_type : felt) -> (resource_concentration_fp10 : felt):
    alloc_locals

    # Requirement 1 / have a different distribution per resource type
    # Requirement 2 / design shape & amplitudes of distribution for specific resources e.g. plutonium-241 for game design purposes
    # Requirement 3 / expose parameters controlling these distributions as constants in `contracts.design.constants` for easier tuning
    # Requirement 4 / deal with fixed-point representation for concentration values

    with_attr error_message ("function not implemented."):
        assert 1 = 0
    end

    return (1)
end

func get_resource_harvest_amount_from_concentration (resource_concentration_fp10 : felt, )

##############################
## Devices (including opsf)
##############################

@storage_var
func device_undeployed_ledger (owner : felt, type : felt) -> (amount : felt):
end

struct DeviceDeployedEmapEntry:
    member grid : Vec2
    member type : felt
    member id : felt
    member tethered_to_utl : felt
    member tethered_to_utb : felt
    member utl_label : felt
    member utb_label : felt
end

struct TransformerResourceBalances:
    member balance_resource_raw : felt
    member balance_resource_transformed : felt
end

@storage_var
func device_deployed_emap_size () -> (size : felt):
end

@storage_var
func device_deployed_emap (emap_index : felt) -> (emap_entry : DeviceDeployedEmapEntry):
end

# for quick reverse lookup (device-id to emap-index), assuming device-id is valid
@storage_var
func device_deployed_id_to_emap_index (id : felt) -> (emap_index : felt):
end

# harvester-type device-id to resource-balance lookup; for simplicity, device-id uniquely identifies resource type harvested
@storage_var
func harvesters_deployed_id_to_resource_balance (id : felt) -> (balance : felt):
end

@storage_var
func transformers_deployed_id_to_resource_balances (id : felt) -> (balances : TransformerResourceBalances):
end

@storage_var
func opsf_deployed_id_to_resource_balances (id : felt, resource_type : felt) -> (balance : felt):
end

@storage_var
func opsf_deployed_id_to_device_balances (id : felt, device_type : felt) -> (balance : felt):
end

func device_deploy {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
        caller : felt,
        type : felt,
        grid : Vec2
    ) -> ():
    alloc_locals

    #
    # Check if caller owns at least 1 undeployed device of type `type`
    #
    let (amount_curr) = device_undeployed_ledger.read (caller, type)
    assert_nn (amount_curr - 1)

    #
    # Check if `grid` is unpopulated
    #
    let (grid_stat) = grid_stats.read (grid)
    assert grid_stat.populated = 0

    #
    # Update `device_undeployed_ledger`
    #
    device_undeployed_ledger.write (caller, type, amount_curr - 1)

    #
    # Create new device id
    #
    tempvar data_ptr : felt* = new (4, caller, type, grid.x, grid.y)
    let (new_id) = hash_chain {hash_ptr = pedersen_ptr} (data_ptr)

    #
    # Update `grid_stats` at `grid`
    #
    grid_stats.write (grid, GridStat(
        populated = 1,
        deployed_device_type = type,
        deployed_device_id =  new_id,
        deployed_device_owner = caller
    ))

    #
    # Update `device_deployed_emap`
    #
    let (emap_size_curr) = device_deployed_emap_size.read ()
    device_deployed_emap_size.write (emap_size_curr + 1)
    device_deployed_emap.write (emap_size_curr, DeviceDeployedEmapEntry(
        grid = grid,
        type = type,
        id = new_id,
        tethered_to_utl = 0,
        tethered_to_utb = 0,
        utl_label = 0,
        utb_label = 0
    ))

    return ()
end

func device_pickup_by_grid {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
        caller : felt,
        grid : Vec2
    ) -> ():
    alloc_locals

    #
    # Check if caller owns the device on `grid`
    #
    let (grid_stat) = grid_stats.read (grid)
    assert grid_stat.populated = 1
    assert grid_stat.deployed_device_owner = caller

    #
    # Update `device_deployed_emap`
    #
    let (emap_index) = device_deployed_id_to_emap_index.read (grid_stat.deployed_device_id)
    let (emap_size_curr) = device_deployed_emap_size.read ()
    let (emap_entry) = device_deployed_emap.read (emap_index)
    let (emap_entry_last) = device_deployed_emap.read (emap_size_curr - 1)
    device_deployed_emap_size.write (emap_size_curr - 1)
    device_deployed_emap.write (emap_size_curr - 1, DeviceDeployedEmapEntry(
        Vec2(0,0), 0, 0, 0, 0, 0, 0
    ))
    device_deployed_emap.write (emap_index, emap_entry_last)

    #
    # Untether utb/utl if tethered;
    # use `emap_entry.utb_label/utl_label` to find emap-entry of the utb-set/utl-set,
    # and unregister src/dst device from it (set device id to 0, assuming 0 does not correspond to some meaning device id)
    #
    if emap_entry.tethered_to_utb == 1:
        let (utb_set_emap_index) = utb_set_deployed_label_to_emap_index.read (emap_entry.utb_label)
        let (utb_set_emap_entry) = utb_set_deployed_emap.read (utb_set_emap_index)
        let (is_src_device) = is_zero (utb_set_emap_entry.src_device_id - grid_stat.deployed_device_id)
        let (is_dst_device) = is_zero (utb_set_emap_entry.dst_device_id - grid_stat.deployed_device_id)
        let new_src_device_id = (1-is_src_device) * utb_set_emap_entry.src_device_id
        let new_dst_device_id = (1-is_dst_device) * utb_set_emap_entry.dst_device_id

        utb_set_deployed_emap.write (utb_set_emap_index, UtbSetDeployedEmapEntry(
            utb_set_deployed_label = utb_set_emap_entry.utb_set_deployed_label,
            utb_deployed_index_start = utb_set_emap_entry.utb_deployed_index_start,
            utb_deployed_index_end = utb_set_emap_entry.utb_deployed_index_end,
            src_device_id = new_src_device_id,
            dst_device_id = new_dst_device_id
        ))

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    # TODO: come back to implement for utl below
    # if emap_entry.tethered_to_utl:
    # end

    #
    # Clear entry in device-id to resource-balance lookup
    #
    let (bool_is_harvester) = is_device_harvester (grid_stat.type)
    let (bool_is_transformer) = is_device_transformer (grid_stat.type)
    if bool_is_harvester == 1:
        harvesters_deployed_id_to_resource_balance.write (
            grid_stat.deployed_device_id,
            0
        )
        jmp recycle
    end
    if bool_is_harvester == 1:
        transformers_deployed_id_to_resource_balances.write (
            grid_stat.deployed_device_id,
            TransformerResourceBalances (0,0)
        )
        jmp recycle
    end

    recycle:
    #
    # Recycle device back to caller
    #
    let (amount_curr) = device_undeployed_ledger.read (caller, grid_stat.deployed_device_type)
    device_undeployed_ledger.write (caller, grid_stat.deployed_device_type, amount_curr + 1)
    grid_stats.write (grid, GridStat(
        populated = 0,
        deployed_device_type = 0,
        deployed_device_id = 0,
        deployed_device_owner = 0
    ))

    return ()
end

##############################
## utb
##############################

#
# utb is fungible before deployment, but non-fungible after deployment,
# because they are deployed as a spatially-contiguous set with the same label,
# where contiguity is defined by the coordinate system on the cube surface;
# they are also deployed exclusively to connect their src & dst devices that meet
# the resource producer-consumer relationship.
#
@storage_var
func utb_undeployed_ledger (owner : felt) -> (amount : felt):
end
## TODO: extend this to `utx_undeployed_ledger (owner, is_utb) -> (amount)` for both utb and utx

#
# Use enumerable map (Emap) to maintain the an array of (set label, utb index start, utb index end)
# credit to Peteris at yagi.fi
#
struct UtbSetDeployedEmapEntry:
    member utb_set_deployed_label : felt
    member utb_deployed_index_start : felt
    member utb_deployed_index_end : felt
    member src_device_id : felt
    member dst_device_id : felt
end

@storage_var
func utb_set_deployed_emap_size () -> (size : felt):
end

@storage_var
func utb_set_deployed_emap (emap_index : felt) -> (emap_entry : UtbSetDeployedEmapEntry):
end

# for quick reverse lookup (utb-set label to emap-index)
@storage_var
func utb_set_deployed_label_to_emap_index (label : felt) -> (emap_index : felt):
end

#
# Append-only
#
@storage_var
func utb_deployed_index_to_grid_size () -> (size : felt):
end

@storage_var
func utb_deployed_index_to_grid (index : felt) -> (grid : Vec2):
end

#
# Player deploys UTB
# by providing a contiguous set of grids
#
func utb_deploy {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
        caller : felt,
        locs_len : felt,
        locs : Vec2*,
        src_device_grid : Vec2,
        dst_device_grid : Vec2
    ) -> ():
    alloc_locals

    #
    # Check if caller owns at least `locs_len` amount of undeployed utb
    #
    let (owned_utb_amount) = utb_undeployed_ledger.read (caller)
    assert_lt (owned_utb_amount, locs_len)

    #
    # Check if caller owns src and dst device
    #
    let (src_grid_stat) = grid_stats.read (src_device_grid)
    let (dst_grid_stat) = grid_stats.read (src_device_grid)
    assert src_grid_stat.populated = 1
    assert dst_grid_stat.populated = 1
    assert src_grid_stat.deployed_device_owner = caller
    assert dst_grid_stat.deployed_device_owner = caller

    #
    # Check src and dst device are untethered to utb
    #
    let src_device_id = src_grid_stat.deployed_device_id
    let dst_device_id = dst_grid_stat.deployed_device_id
    let (src_emap_index) = device_deployed_id_to_emap_index.read (src_device_id)
    let (dst_emap_index) = device_deployed_id_to_emap_index.read (dst_device_id)
    let (src_emap_entry) = device_deployed_emap.read (src_emap_index)
    let (dst_emap_entry) = device_deployed_emap.read (dst_emap_index)
    assert src_emap_entry.tethered_to_utb = 0
    assert dst_emap_entry.tethered_to_utb = 0

    #
    # Check locs[0] is contiguous to src_device_id's grid using `are_contiguous_grids_given_valid_grids()`
    #
    are_contiguous_grids_given_valid_grids (locs[0], src_device_grid)

    #
    # Check locs[locs_len-1] is contiguous to dst_device_id's grid using `are_contiguous_grids_given_valid_grids()`
    #
    are_contiguous_grids_given_valid_grids (locs[locs_len-1], dst_device_grid)

    #
    # Check the type of (src,dst) meets (producer,consumer) relationship
    #
    are_resource_producer_consumer_relationship (
        src_grid_stat.deployed_device_type,
        dst_grid_stat.deployed_device_type
    )

    #
    # Recursively check for each locs's grid: (1) grid validity (2) grid unpopulated (3) grid is contiguous to previous grid
    #
    let (utb_idx_start) = utb_deployed_index_to_grid_size.read ()
    let utb_idx_end = utb_idx_start + locs_len
    tempvar data_ptr : felt* = new (3, caller, utb_idx_start, utb_idx_end)
    let (new_label) = hash_chain {hash_ptr = pedersen_ptr} (data_ptr)
    recurse_utb_deploy (
        caller = caller,
        len = locs_len,
        arr = locs,
        idx = 0,
        utb_idx = utb_idx_start,
        set_label = new_label
    )

    #
    # Decrease caller's undeployed utb amount
    #
    utb_undeployed_ledger.write (caller, owned_utb_amount - locs_len)

    #
    # Update `utb_deployed_index_to_grid_size`
    #
    utb_deployed_index_to_grid_size.write (utb_idx_end)

    #
    # Insert to utb_set_deployed_emap; increase emap size
    #
    let (emap_size) = utb_set_deployed_emap_size.read ()
    utb_set_deployed_emap.write (emap_size, UtbSetDeployedEmapEntry(
        utb_set_deployed_label = new_label,
        utb_deployed_index_start = utb_idx_start,
        utb_deployed_index_end = utb_idx_end,
        src_device_id = src_device_id,
        dst_device_id = dst_device_id
    ))
    utb_set_deployed_emap_size.write (emap_size + 1)

    #
    # Update label-to-index for O(1) reverse lookup
    #
    utb_set_deployed_label_to_emap_index.write (new_label, emap_size)


    #
    # Update device emap entries for src and dst device
    #
    let (src_emap_index) = device_deployed_id_to_emap_index.read (src_device_id)
    device_deployed_emap.write (src_emap_index, DeviceDeployedEmapEntry(
        grid = src_emap_entry.grid,
        type = src_emap_entry.type,
        id = src_emap_entry.id,
        tethered_to_utl = src_emap_entry.tethered_to_utl,
        tethered_to_utb = 1,
        utl_label = src_emap_entry.utl_label,
        utb_label = new_label
    ))

    let (dst_emap_index) = device_deployed_id_to_emap_index.read (dst_device_id)
    device_deployed_emap.write (dst_emap_index, DeviceDeployedEmapEntry(
        grid = dst_emap_entry.grid,
        type = dst_emap_entry.type,
        id = dst_emap_entry.id,
        tethered_to_utl = dst_emap_entry.tethered_to_utl,
        tethered_to_utb = 1,
        utl_label = dst_emap_entry.utl_label,
        utb_label = new_label
    ))

    return ()
end


func recurse_utb_deploy {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
        caller : felt,
        len : felt,
        arr : Vec2*,
        idx : felt,
        utb_idx : felt,
        set_label : felt
    ) -> ():
    alloc_locals

    if idx == len:
        return ()
    end

    #
    # In the following checks, any failure would revert this tx
    #
    # 1. check loc is a valid grid coordinate
    is_valid_grid (arr[idx])

    # 2. check loc is not already populated
    is_unpopulated_grid (arr[idx])

    # 3. check loc is contiguous with previous loc, unless idx==0
    if idx == 0:
        jmp deploy
    end
    are_contiguous_grids_given_valid_grids (arr[idx-1], arr[idx])

    deploy:
    #
    # Update utb_deployed_index_to_grid
    #
    utb_deployed_index_to_grid.write (utb_idx, arr[idx])

    #
    # Update global grid_stats ledger
    #
    grid_stats.write (arr[idx], GridStat (
        populated = 1,
        deployed_device_type = ns_device_types.DEVICE_UTB,
        deployed_device_id = set_label,
        deployed_device_owner = caller
    ))

    recurse_utb_deploy (caller, len, arr, idx+1, utb_idx+1, set_label)
    return ()
end

#
# Player picks up UTB;
# given a grid, check its contains caller's own utb, and pick up the entire utb-set
#
func utb_pickup_by_grid {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
        caller : felt,
        grid : Vec2
    ) -> ():
    alloc_locals

    #
    # Check the grid contains an utb owned by caller
    #
    let (grid_stat) = grid_stats.read (grid)
    assert grid_stat.populated = 1
    assert grid_stat.deployed_device_type = ns_device_types.DEVICE_UTB
    assert grid_stat.deployed_device_owner = caller
    let utb_set_deployed_label = grid_stat.deployed_device_id

    #
    # O(1) find the emap_entry for this utb-set
    #
    let (emap_size_curr) = utb_set_deployed_emap_size.read ()
    let (emap_index) = utb_set_deployed_label_to_emap_index.read (utb_set_deployed_label)
    let (emap_entry) = utb_set_deployed_emap.read (emap_index)
    let utb_start_index = emap_entry.utb_deployed_index_start
    let utb_end_index = emap_entry.utb_deployed_index_end

    #
    # Recurse from start utb-idx to end utb-idx for this set
    # and clear the associated grid
    #
    recurse_pickup_utb_given_start_end_utb_index (
        start_idx = utb_start_index,
        end_idx = utb_end_index,
        idx = 0
    )

    #
    # Return the entire set of utbs back to the caller
    #
    let (amount_curr) = utb_undeployed_ledger.read (caller)
    utb_undeployed_ledger.write (caller, amount_curr + utb_end_index - utb_start_index)

    #
    # Update enumerable map of utb-sets:
    # removal operation - put last entry to index at removed entry, clear index at last entry,
    # and decrease emap size by one
    #
    let (emap_entry_last) = utb_set_deployed_emap.read (emap_size_curr - 1)
    utb_set_deployed_emap.write (emap_index, emap_entry_last)
    utb_set_deployed_emap.write (emap_size_curr - 1, UtbSetDeployedEmapEntry (0,0,0,0,0))
    utb_set_deployed_emap_size.write (emap_size_curr - 1)

    #
    # Update the tethered src and dst device info as well
    #
    let src_device_id = emap_entry.src_device_id
    let dst_device_id = emap_entry.dst_device_id
    let (src_emap_index) = device_deployed_id_to_emap_index.read (src_device_id)
    let (dst_emap_index) = device_deployed_id_to_emap_index.read (dst_device_id)
    let (src_emap_entry) = device_deployed_emap.read (src_emap_index)
    let (dst_emap_entry) = device_deployed_emap.read (dst_emap_index)

    device_deployed_emap.write (src_emap_index, DeviceDeployedEmapEntry(
        grid = src_emap_entry.grid,
        type = src_emap_entry.type,
        id = src_emap_entry.id,
        tethered_to_utl = src_emap_entry.tethered_to_utl,
        tethered_to_utb = 0,
        utl_label = src_emap_entry.utl_label,
        utb_label = 0
    ))

    device_deployed_emap.write (dst_emap_index, DeviceDeployedEmapEntry(
        grid = dst_emap_entry.grid,
        type = dst_emap_entry.type,
        id = dst_emap_entry.id,
        tethered_to_utl = dst_emap_entry.tethered_to_utl,
        tethered_to_utb = 0,
        utl_label = dst_emap_entry.utl_label,
        utb_label = 0
    ))

    return ()
end

func recurse_pickup_utb_given_start_end_utb_index {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
        start_idx,
        end_idx,
        idx
    ) -> ():
    alloc_locals

    if start_idx + idx == end_idx:
        return ()
    end

    let (grid_to_clear) = utb_deployed_index_to_grid.read (start_idx + idx)
    grid_stats.write (grid_to_clear, GridStat(0,0,0,0))

    recurse_pickup_utb_given_start_end_utb_index (start_idx, end_idx, idx + 1)
    return()
end

#
# Tether utb-set to src and device manually;
# useful when player retethers a deployed utb-set to new devices
# and wishes to avoid picking up and deploying utb-set again
#
func utb_tether_by_grid {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
        caller : felt,
        utb_grid : Vec2,
        src_device_grid : Vec2,
        dst_device_grid : Vec2
    ) -> ():
    # TODO
    return ()
end

##############################

func are_resource_producer_consumer_relationship {range_check_ptr} (
    device_type0, device_type1) -> ():

    # TODO: refactir this code to improve extensibility

    #
    # From harvester to corresponding refinery / enrichment facility
    #
    # iron harvester => iron refinery
    if (device_type0 - ns_device_types.DEVICE_FE_HARV - 1) * (device_type1 - ns_device_types.DEVICE_FE_REFN - 1) == 1:
        return ()
    end

    # aluminum harvester => aluminum refinery
    if (device_type0 - ns_device_types.DEVICE_AL_HARV - 1) * (device_type1 - ns_device_types.DEVICE_AL_REFN - 1) == 1:
        return ()
    end

    # copper harvester => copper refinery
    if (device_type0 - ns_device_types.DEVICE_CU_HARV - 1) * (device_type1 - ns_device_types.DEVICE_CU_REFN - 1) == 1:
        return ()
    end

    # silicon harvester => silicon refinery
    if (device_type0 - ns_device_types.DEVICE_SI_HARV - 1) * (device_type1 - ns_device_types.DEVICE_SI_REFN - 1) == 1:
        return ()
    end

    # plutonium harvester => plutonium enrichment facility
    if (device_type0 - ns_device_types.DEVICE_PU_HARV - 1) * (device_type1 - ns_device_types.DEVICE_PEF - 1) == 1:
        return ()
    end

    #
    # From harvester straight to OPSF
    #
    # iron harvester => OPSF
    if (device_type0 - ns_device_types.DEVICE_FE_HARV - 1) * (device_type1 - ns_device_types.DEVICE_OPSF - 1) == 1:
        return ()
    end

    # aluminum harvester => OPSF
    if (device_type0 - ns_device_types.DEVICE_AL_HARV - 1) * (device_type1 - ns_device_types.DEVICE_OPSF - 1) == 1:
        return ()
    end

    # copper harvester => OPSF
    if (device_type0 - ns_device_types.DEVICE_CU_HARV - 1) * (device_type1 - ns_device_types.DEVICE_OPSF - 1) == 1:
        return ()
    end

    # silicon harvester => OPSF
    if (device_type0 - ns_device_types.DEVICE_SI_HARV - 1) * (device_type1 - ns_device_types.DEVICE_OPSF - 1) == 1:
        return ()
    end

    # plutonium harvester => OPSF
    if (device_type0 - ns_device_types.DEVICE_PU_HARV - 1) * (device_type1 - ns_device_types.DEVICE_OPSF - 1) == 1:
        return ()
    end

    #
    # From refinery/enrichment facility to OPSF
    #
    # iron refinery => OPSF
    if (device_type0 - ns_device_types.DEVICE_FE_REFN - 1) * (device_type1 - ns_device_types.DEVICE_OPSF - 1) == 1:
        return ()
    end

    # aluminum refinery => OPSF
    if (device_type0 - ns_device_types.DEVICE_AL_REFN - 1) * (device_type1 - ns_device_types.DEVICE_OPSF - 1) == 1:
        return ()
    end

    # copper refinery => OPSF
    if (device_type0 - ns_device_types.DEVICE_CU_REFN - 1) * (device_type1 - ns_device_types.DEVICE_OPSF - 1) == 1:
        return ()
    end

    # silicon refinery => OPSF
    if (device_type0 - ns_device_types.DEVICE_SI_REFN - 1) * (device_type1 - ns_device_types.DEVICE_OPSF - 1) == 1:
        return ()
    end

    # plutonium enrichment facility => OPSF
    if (device_type0 - ns_device_types.DEVICE_PEF - 1) * (device_type1 - ns_device_types.DEVICE_OPSF - 1) == 1:
        return ()
    end

    with_attr error_message("resource producer-consumer relationship check failed."):
        assert 1 = 0
    end
    return ()
end

func is_device_harvester {range_check_ptr} (type : felt) -> (bool : felt):
    let (bool) = is_nn_le (
        type - ns_device_types.DEVICE_HARVESTER_MIN,
        ns_device_types.DEVICE_HARVESTER_MAX
    )
    return (bool)
end

func is_device_transformer {range_check_ptr} (type : felt) -> (bool : felt):
    let (bool) = is_nn_le (
        type - ns_device_types.DEVICE_TRANSFORMER_MIN,
        ns_device_types.DEVICE_TRANSFORMER_MAX
    )
    return (bool)
end

##############################

func resource_update_at_devices {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
    ) -> ():

    let (emap_size) = device_deployed_emap_size.read ()
    recurse_resource_update_at_devices (
        len = emap_size,
        idx = 0
    )

    return ()
end

func recurse_resource_update_at_devices {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
        len : felt, idx : felt
    ) -> ():
    alloc_locals

    if idx == len:
        return ()
    end

    let (emap_entry) = device_deployed_emap.read (idx)
    let (bool_is_harvester) = is_device_harvester (emap_entry.type)
    let (bool_is_transformer) = is_device_transformer (emap_entry.type)

    #
    # For harvester => increase resource based on resource concentration at land # TODO: use energy to boost harvest rate
    #
    if bool_is_harvester == 1:
        harvesters_deployed_id_to_resource_balance.write (
            emap_entry.id,
            ______TODO_______
        )
        jmp recurse
    end

    #
    # For transformer (refinery/PEF) => decrease raw resource and increase transformed resource
    #
    if bool_is_transformer == 1:
        transformers_deployed_id_to_resource_balances.write (
            emap_entry.id,
            ______TODO_______ # TransformerResourceBalances (0,0)
        )
        jmp recurse
    end

    recurse:
    recurse_resource_update_at_devices (len, idx + 1)

    return ()
end

func resource_transfer_across_utb_sets {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
    ) -> ():

    # TODO:
    # recursively traverse `utb_set_deployed_linked_list`
    #   for each set, check if source device and destination device are still deployed;
    #   if yes, transfer resource from source to destination according to transport rate
    # NOTE: source device can be connected to multiple utb, resulting in higher transport rate
    # NOTE: opsf as destination device can be connected to multiple utb transporting same/different kinds of resources

    return ()
end

func coord_transform {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
        momentum_magnitude: felt, face_index: felt
    ) -> (momentum_vector: felt):
    
    # get current phi of planet
    let (curr_phi: felt) = phi_curr.read() # should this be passed in as params?

    # get the starting radian value of the given face
    if face_index == 0:
        let original_face_index_normal_radians = face_index_to_radians.face0
    else if face_index == 1:
        let original_face_index_normal_radians = face_index_to_radians.face1
    else if face_index == 3:
        let original_face_index_normal_radians = face_index_to_radians.face3
    else if face_index == 4:
        let original_face_index_normal_radians = face_index_to_radians.face4
    else 
        return()

    # get the direction the given face is pointing currently in radians
    let curr_face_index_normal_radians: felt = curr_phi + original_face_index_normal_radians
    
    # turn momentum_magnitude into momentum in the x and y direction

    # get curr_magnitude from server

    # add both magnitudes and return


func forward_world_micro {syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr} (
    ) -> ():

    #
    # Effect resource update at device;
    # akin to propagating D->Q for FFs
    #
    resource_update_at_devices ()

    #
    # Effect resource transfer across deployed utb-sets;
    # akin to propagating values through wires
    #
    resource_transfer_across_utb_sets ()
end

#######################################
## Admin functions for testing purposes
#######################################

# give device to player

