extends Node3D

var DRAG_SPEED := 12.0

# Will use linear velocity (FORCE) instead of position changing (SPEED),
# when possible, to avoid objects clipping and allow for tossing
var USE_FORCE  := true
var DRAG_FORCE := 350.0
var RELEASE_VELOCITY_MULTIPLIER := 0.8

var USE_ZOOM   := true
var ZOOM_MIN   := 0.75
var ZOOM_MAX   := 3.0
var ZOOM_SPEED := 0.2

var USE_STABILISATION   := true
var USE_STARTING_ANGLE  := false
var STABILISATION_SPEED := 5.0
var STABILISATION_ANGLE := Vector3.ZERO

var DRAG_OFFSET := Vector3.ZERO

const CONTROLS := {
	# Values from Input map
	"DRAG":     "drag",
	"ZOOM_IN":  "zoom_in",
	"ZOOM_OUT": "zoom_out",
}

@onready var drag_raycast:RayCast3D = $"."

var drag_object:Node3D
var drag_distance:float
var drag_angle:Vector3
var drag_using_force:bool
var drag_unfreeze_after:bool

# HELPERS

func get_collision_distance(raycast:RayCast3D = drag_raycast) -> float:
	if not raycast.is_colliding():
		return -1
	
	return raycast.global_transform.origin.distance_to(raycast.get_collision_point())

func is_object_draggable(object) -> bool:
	return object is Node3D

func is_object_forcable(object) -> bool:
	return object is RigidBody3D

func is_object_static(object) -> bool:
	if not object is RigidBody3D:
		return true
	
	return object.freeze

func get_draggable_aimed(raycast:RayCast3D = drag_raycast) -> Node3D:
	if not raycast:
		return null
	
	var object_aimed = raycast.get_collider()
	
	if is_object_draggable(object_aimed):
		return object_aimed
	
	return null

func get_drag_position(
		distance:float = drag_distance,
		offset:Vector3 = DRAG_OFFSET,
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
		distance:float = drag_distance,
		offset:Vector3 = DRAG_OFFSET,
		raycast:RayCast3D = drag_raycast,
	) -> Vector3:
	if not object or not raycast:
		return Vector3.ZERO
	
	var drag_pos = get_drag_position(distance, offset, raycast)
	return (drag_pos - object.global_position) * delta * force

func get_default_angle(object = drag_object) -> Vector3:
	if USE_STARTING_ANGLE and object:
		return object.rotation
	
	return STABILISATION_ANGLE

# SETTERS

func set_drag_distance(distance:float) -> float:
	drag_distance = clamp(distance, ZOOM_MIN, ZOOM_MAX)
	return drag_distance

func set_drag_object(object:Node3D) -> Node3D:
	if drag_object:
		stop_dragging()
	
	drag_object = object
	return drag_object

func set_drag_angle(angle:Vector3 = get_default_angle()) -> Vector3:
	drag_angle = angle
	return drag_angle

func set_using_force(
		use_force:bool = USE_FORCE,
		object:Node3D = drag_object
	) -> bool:
	var can_use_force = is_object_forcable(object)
	
	drag_using_force = can_use_force and use_force
	
	if object is RigidBody3D:
		object.freeze = !drag_using_force
		drag_unfreeze_after = !object.freeze
	
	return drag_using_force

# ACTIONS

func start_dragging(
		object:Node3D = get_draggable_aimed(),
		distance:float = get_collision_distance(),
		angle:Vector3 = get_default_angle(object),
		use_force:bool = USE_FORCE,
	) -> bool:
	if not object:
		return false
	
	if drag_object:
		stop_dragging()
	
	set_drag_object(object)
	set_drag_distance(distance)
	set_drag_angle(angle)
	set_using_force(use_force)
	
	return true

func stop_dragging():
	if not drag_object:
		return
	
	if drag_object is RigidBody3D:
		drag_object.sleeping = false
		drag_object.freeze = !drag_unfreeze_after
	
	if drag_using_force:
		drag_object.linear_velocity *= RELEASE_VELOCITY_MULTIPLIER
	
	drag_object = null

func drag_by_setpos(
		delta:float,
		speed:float = DRAG_SPEED,
		object:Node3D = drag_object,
	):
	if not object:
		return stop_dragging()
	
	object.global_position = object.global_position.lerp(
		get_drag_position(), delta * speed
	)

func drag_by_force(
		delta:float,
		force:float = DRAG_FORCE,
		object:RigidBody3D = drag_object
	):
	if not drag_object:
		return stop_dragging()
	
	object.linear_velocity = get_drag_velocity(delta, force, object)
	object.angular_velocity = Vector3.ZERO

func drag(
		delta:float,
		speed:float = DRAG_SPEED,
		force:float = DRAG_FORCE,
		use_force:bool = drag_using_force,
		object:Node3D = drag_object,
	):
	if drag_using_force:
		drag_by_force(delta, force, object)
	else:
		drag_by_setpos(delta, speed, object)

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
	
	if not USE_ZOOM:
		return
	if event.is_action_pressed(CONTROLS.ZOOM_IN):
		set_drag_distance(drag_distance - ZOOM_SPEED)
	elif event.is_action_pressed(CONTROLS.ZOOM_OUT):
		set_drag_distance(drag_distance + ZOOM_SPEED)

func _physics_process(delta:float):
	drag(delta)
	if USE_STABILISATION:
		stabilize(delta)
