# Declare this file as a StarkNet contract.
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
# THIS CONTRACT IS JUST FOR TESTING VARIOUS LANGUAGE FEATURES/COMPILATION ISSUES - DO NOT DEPLOY

# Define a storage variable.
@storage_var
func balance() -> (res : felt):
end

# Increases the balance by the given amount.
@external
func increase_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount : felt):
    let (res) = balance.read()
    balance.write(res + amount)
    return ()
end

# Returns the current balance.
@view
func get_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        res : felt):
    let (res) = balance.read()
    return (res)
end

struct Point:
    member x : felt
    member y : felt
end

@view
func sum_points{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(points : (Point, Point)) -> (res : Point):
    return (
        res=Point(
        x=points[0].x + points[1].x,
        y=points[0].y + points[1].y))
end

@storage_var
func point_storage(id:felt) -> (res:Point):
end

@external
func create_struct{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(x:felt, y:felt):
    let point = Point(x=x,y=y)
    point_storage.write(0,point)
    return()
end

@view
func get_point_storage{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(id:felt) -> (res:Point):
    let point:Point = point_storage.read(id)
    return(point)
end

