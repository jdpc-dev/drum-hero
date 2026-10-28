class_name HitDetection
extends Node

var highway_ref


func try_hit_lane(lane_index: int, touch_position: Vector2) -> bool:
    if not highway_ref:
        return false
    var time: float = TimingEngine.get_time()
    for lane in highway_ref.lane_nodes:
        if lane.lane_index == lane_index:
            return lane.try_hit(time, touch_position)
    return false


func try_kick() -> bool:
    if not highway_ref:
        return false
    var time: float = TimingEngine.get_time()
    if highway_ref.get_kick_lane():
        return highway_ref.get_kick_lane().try_hit(time, Vector2.ZERO)
    var kick_lane_index: int = 3
    for lane in highway_ref.lane_nodes:
        if lane.lane_index == kick_lane_index:
            return lane.try_hit(time, Vector2.ZERO)
    return false
