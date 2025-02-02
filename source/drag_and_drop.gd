extends Node3D

var DRAG_FORCE := 350.0
var DRAG_RELATIVE_POSITION := Vector3.UP * .1

var ZOOM_SPEED := 0.15
var ZOOM_MIN := 0.5
var ZOOM_MAX := 1.65

var STABILISATION_SPEED := 3.5
var STABILISATION_ANGLE := Vector3(.2, 1, 0)

const CONTROLS := {
	# Values from Input map
	"DRAG":     "drag",
	"ZOOM_IN":  "zoom_in",
	"ZOOM_OUT": "zoom_out",
}

@onready var drag_raycast:RayCast3D = $"."

# Currently only works for RigidBody3D
var drag_object:Node3D
var drag_distance:float
var drag_angle:Vector3

# HELPERS

func get_collision_distance(raycast:RayCast3D = drag_raycast) -> float:
	if not raycast.is_colliding():
		return -1
	
	return raycast.global_transform.origin.distance_to(raycast.get_collision_point())

func is_object_draggable(object) -> bool:
	return object is RigidBody3D

func get_draggable_aimed(raycast:RayCast3D = drag_raycast) -> Node3D:
	if not raycast:
		return null
	
	var object_aimed = raycast.get_collider()
	
	if is_object_draggable(object_aimed):
		return object_aimed
	
	return null

func get_drag_position(
		distance:float = drag_distance,
		offset:Vector3 = Vector3.ZERO,
		raycast:RayCast3D = drag_raycast,
	) -> Vector3:
	if not raycast:
		return Vector3.ZERO
	
	var forward = -raycast.get_global_transform().basis.z
	return raycast.global_position + forward * distance + offset

func get_drag_velocity(
		delta:float,
		force:float = DRAG_FORCE,
		object:Node3D = drag_object,
		raycast:RayCast3D = drag_raycast,
	) -> Vector3:
	if not object or not raycast:
		return Vector3.ZERO
	
	var drag_pos = get_drag_position()
	return (drag_pos - object.global_position) * delta * force

# SETTERS

func set_drag_distance(distance:float) -> float:
	drag_distance = clamp(distance, ZOOM_MIN, ZOOM_MAX)
	return drag_distance

func set_drag_object(object:Node3D) -> Node3D:
	if drag_object:
		stop_dragging()
	
	drag_object = object
	return drag_object

func set_drag_angle(angle:Vector3 = STABILISATION_ANGLE) -> Vector3:
	drag_angle = angle
	return drag_angle

# ACTIONS

func start_dragging(
		object:Node3D = get_draggable_aimed(),
		distance:float = get_collision_distance(),
		angle:Vector3 = STABILISATION_ANGLE,
		raycast:RayCast3D = drag_raycast,
	) -> bool:
	if not object or not raycast:
		return false
	
	if drag_object:
		stop_dragging()
	
	set_drag_object(object)
	set_drag_distance(distance)
	set_drag_angle(angle)
	
	return true

func stop_dragging():
	if not drag_object:
		return
	
	# RigidyBody3D specific
	drag_object.sleeping = false
	
	drag_object = null

func drag(
		delta:float,
		force:float = DRAG_FORCE,
		object:Node3D = drag_object,
	):
	if not object:
		return
	
	object.linear_velocity = get_drag_velocity(delta, force, object)
	object.angular_velocity = Vector3.ZERO

func stabilize(
		delta:float,
		speed:float = STABILISATION_SPEED,
		angle:Vector3 = drag_angle,
		object:Node3D = drag_object,
	):
	if not object:
		return
	
	object.rotation = object.rotation.lerp(angle, delta * speed)

# CONTROLS

func _unhandled_input(event:InputEvent):
	if event.is_action_pressed(CONTROLS.DRAG):
		start_dragging()
	
	elif event.is_action_released(CONTROLS.DRAG):
		stop_dragging()
	
	if event.is_action_pressed(CONTROLS.ZOOM_IN):
		set_drag_distance(drag_distance - ZOOM_SPEED)
	
	elif event.is_action_pressed(CONTROLS.ZOOM_OUT):
		set_drag_distance(drag_distance + ZOOM_SPEED)

func _physics_process(delta:float):
	drag(delta)
	stabilize(delta)
