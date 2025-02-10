extends Node

var DRAG_TOGGLE := true
var DRAG_SPEED := 12.0
var DRAG_OFFSET := Vector3.ZERO
var DRAG_COOLDOWN := .25
var DRAGGABLE_METADATA := 'draggable'
var ALLOW_INITIAL_OFFSET := true

var USE_ZOOM := true
var ZOOM_MIN := .75
var ZOOM_MAX := 2.25
var ZOOM_SPEED := .2

var USE_STABILISATION := true
var USE_STARTING_ANGLE := false
var STABILISATION_SPEED := 5.0
var STABILISATION_ANGLE := Vector3.ZERO

var TRACK_HOVERING := true

# Values from input map
const CONTROLS := {
	"DRAG": "drag",
	"ZOOM_IN": "zoom_in",
	"ZOOM_OUT": "zoom_out",
}

# Will use linear velocity (VELOCITY) instead of position changing (SPEED),
# for RigidBody objects, to avoid clipping and allow for tossing
var USE_VELOCITY := true
var DRAG_VELOCITY := Vector3.ONE * 350.0
var RELEASE_VELOCITY_MULT := Vector3.ONE * .8
var WAKE_UP_VELOCITY := Vector3.UP * .35

# Only works when using force
var TRACK_JAMMING := true
var JAM_RESPONSE := JAM_RESPONSES.NONE
var JAM_MIN_DISTANCE := .2
var JAM_MIN_TIME := .1
var JAM_ZONE_RADIUS := .1

# Settings for specific JAM_RESPONSE types
var JAM_TELEPORT_CLOSE_DIST := -1
var JAM_LOWER_DISTANCE_MULT := .85
var JAM_LOWER_DISTANCE_FAIL := JAM_RESPONSES.TELEPORT_CLOSE

@onready var drag_raycast:RayCast3D = $"."
@onready var drag_cooldown_timer:Timer = Timer.new()
@onready var drag_jam_timer:Timer = Timer.new()

enum JAM_RESPONSES {
	NONE = -1,
	STOP_DRAGGING = 0,
	TELEPORT = 1,
	TELEPORT_CLOSE = 2,
	LOWER_DISTANCE = 3,
}

signal started_dragging (object:Node3D)
signal stopped_dragging (object:Node3D)
signal draggable_hovered (object:Node3D)
signal draggable_unhovered (object:Node3D)
signal cooldown_timeset
signal cooldown_timeout
signal jammed

var drag_object:Node3D
var drag_hovered:Node3D
var drag_distance:float
var drag_angle:Vector3
var drag_use_velocity:bool
var drag_unfreeze_after:bool
var drag_offset:Vector3
var drag_on_cooldown:bool
var drag_jam_point:Vector3
var drag_suspecting_jam:bool

# HELPERS

func get_collision_distance(raycast:RayCast3D = drag_raycast) -> float:
	if not raycast.is_colliding():
		return -1
	
	return raycast.global_transform.origin.distance_to(raycast.get_collision_point())

func wake_up(object:RigidBody3D):
	# Changing .sleeping doesnt seem to work
	object.linear_velocity += WAKE_UP_VELOCITY

func is_object_draggable(object) -> bool:
	return object is Node3D and object.get_meta(DRAGGABLE_METADATA, false)

func is_object_forcable(object) -> bool:
	return object is RigidBody3D

func is_object_static(object) -> bool:
	if not object is RigidBody3D:
		return true
	
	return object.freeze

func get_draggable_aimed(
		raycast:RayCast3D = drag_raycast,
		ignore_cooldown:bool = false,
	) -> Node3D:
	if not raycast or (not ignore_cooldown and drag_on_cooldown):
		return null
	
	var object_aimed = raycast.get_collider()
	
	if is_object_draggable(object_aimed):
		return object_aimed
	
	return null

func get_drag_position(
		distance:float = drag_distance,
		offset:Vector3 = drag_offset,
		raycast:RayCast3D = drag_raycast,
	) -> Vector3:
	if not raycast:
		return Vector3.ZERO
	
	var forward = -raycast.get_global_transform().basis.z
	return raycast.global_position + forward * distance + offset

func get_drag_velocity(
		delta:float,
		force:Vector3 = DRAG_VELOCITY,
		object:Node3D = drag_object,
		distance:float = drag_distance,
		offset:Vector3 = drag_offset,
		raycast:RayCast3D = drag_raycast,
	) -> Vector3:
	if not object or not raycast:
		return Vector3.ZERO
	
	var drag_pos = get_drag_position(distance, offset, raycast)
	return (drag_pos - object.global_position) * delta * force

func get_default_angle(object:Node3D = drag_object) -> Vector3:
	if USE_STARTING_ANGLE and object:
		return object.rotation
	
	return STABILISATION_ANGLE

func get_object_offset(
		object:Node3D = drag_object,
		raycast:RayCast3D = drag_raycast,
	) -> Vector3:
	if not object or not raycast:
		return Vector3.ZERO
	
	return object.global_position - raycast.get_collision_point()

func get_drag_offset(object:Node3D) -> Vector3:
	return DRAG_OFFSET + get_object_offset(object) if ALLOW_INITIAL_OFFSET else Vector3.ZERO

func cooldown_clear():
	set_on_cooldown(-1)

func update_draggable_hovered(
		condition:bool = TRACK_HOVERING and not drag_object
	):
	if condition:
		set_draggable_hovered(get_draggable_aimed())

func is_jam_distance_reached(
		object:Node3D = drag_object,
		target:Vector3 = get_drag_position()
	):
	if not object:
		return false
	
	return object.global_position.distance_to(target) >= JAM_MIN_DISTANCE

func is_in_jam_zone(
		object:Node3D = drag_object,
		zone_center:Vector3 = drag_jam_point,
		zone_radius:float = JAM_ZONE_RADIUS,
	):
	if not object:
		return false
	
	return object.global_position.distance_to(zone_center) <= zone_radius

func handle_jam(mode:int = JAM_RESPONSE):
	if not drag_object:
		return
	
	if( mode == JAM_RESPONSES.LOWER_DISTANCE
		and drag_distance == ZOOM_MIN ):
		mode = JAM_LOWER_DISTANCE_FAIL
	
	match mode:
		JAM_RESPONSES.LOWER_DISTANCE:
			set_drag_distance(drag_distance * JAM_LOWER_DISTANCE_MULT)
		JAM_RESPONSES.STOP_DRAGGING:
			stop_dragging()
		JAM_RESPONSES.TELEPORT:
			drag_object.position = get_drag_position()
		JAM_RESPONSES.TELEPORT_CLOSE:
			set_drag_distance(JAM_TELEPORT_CLOSE_DIST)
			drag_object.position = get_drag_position()
	
	drag_suspecting_jam = false
	
	jammed.emit()

func suspect_jam():
	if drag_suspecting_jam:
		return
	
	drag_suspecting_jam = true
	drag_jam_point = drag_object.global_position
	drag_jam_timer.wait_time = JAM_MIN_TIME
	drag_jam_timer.start()

func jam_check():
	if( not drag_object
		or drag_suspecting_jam
		or not drag_use_velocity ):
		return
	
	if not JAM_MIN_DISTANCE:
		suspect_jam()
		return
	
	if is_jam_distance_reached():
		suspect_jam()

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

func set_drag_offset(offset:Vector3) -> Vector3:
	drag_offset = offset
	return drag_offset

func set_use_velocity(
		use_velocity:bool = USE_VELOCITY,
		object:Node3D = drag_object
	) -> bool:
	var can_use_velocity = is_object_forcable(object)
	
	drag_use_velocity = can_use_velocity and use_velocity
	
	if object is RigidBody3D:
		object.freeze = !drag_use_velocity
		drag_unfreeze_after = !object.freeze
	
	return drag_use_velocity

func set_on_cooldown(seconds:float = DRAG_COOLDOWN) -> float:
	if not drag_cooldown_timer:
		return -1
	
	if seconds <= 0:
		drag_cooldown_timer.stop()
		drag_on_cooldown = false
		cooldown_timeout.emit()
		return 0
	
	drag_cooldown_timer.wait_time = seconds
	drag_cooldown_timer.start()
	drag_on_cooldown = true
	cooldown_timeset.emit()
	return seconds

func set_draggable_hovered(new_value:Node3D):
	var old_value = drag_hovered
	
	if old_value == new_value:
		return
	
	drag_hovered = new_value
	
	if not new_value:
		draggable_unhovered.emit(old_value)
		return
	
	draggable_hovered.emit(new_value)

# ACTIONS

func start_dragging(
		object:Node3D = get_draggable_aimed(),
		ignore_cooldown:bool = false,
		distance:float = get_collision_distance(),
		angle:Vector3 = get_default_angle(object),
		offset:Vector3 = DRAG_OFFSET + get_drag_offset(object),
		use_velocity:bool = USE_VELOCITY,
		cooldown:float = DRAG_COOLDOWN,
	) -> bool:
	if not object or (drag_on_cooldown and not ignore_cooldown):
		return false
	
	if drag_object:
		stop_dragging()
	
	set_drag_object(object)
	set_drag_distance(distance)
	set_drag_angle(angle)
	set_drag_offset(offset)
	set_use_velocity(use_velocity)
	set_on_cooldown(cooldown)
	
	if TRACK_HOVERING:
		set_draggable_hovered(null)
	
	started_dragging.emit(drag_object)
	
	return true

func stop_dragging():
	if not drag_object:
		return
	
	if drag_use_velocity:
		drag_object.linear_velocity *= RELEASE_VELOCITY_MULT
	
	if drag_object is RigidBody3D:
		drag_object.freeze = !drag_unfreeze_after
		wake_up(drag_object)
	
	stopped_dragging.emit(drag_object)
	
	drag_object = null
	
	if TRACK_HOVERING:
		update_draggable_hovered()

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
		force:Vector3 = DRAG_VELOCITY,
		object:RigidBody3D = drag_object
	):
	if not drag_object:
		return stop_dragging()
	
	object.linear_velocity = get_drag_velocity(delta, force, object)
	object.angular_velocity = Vector3.ZERO

func drag(
		delta:float,
		speed:float = DRAG_SPEED,
		force:Vector3 = DRAG_VELOCITY,
		use_velocity:bool = drag_use_velocity,
		object:Node3D = drag_object,
	):
	if use_velocity:
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

func _ready():
	drag_cooldown_timer.one_shot = true
	drag_cooldown_timer.timeout.connect(Callable(self, "_on_cooldown_timeout"))
	add_child(drag_cooldown_timer)
	drag_jam_timer.one_shot = true
	drag_jam_timer.timeout.connect(Callable(self, "_on_jam_timeout"))
	add_child(drag_jam_timer)

func _process(_delta:float):
	if TRACK_HOVERING:
		update_draggable_hovered()

func _physics_process(delta:float):
	drag(delta)
	if USE_STABILISATION:
		stabilize(delta)
	if TRACK_JAMMING:
		jam_check()

func _unhandled_input(event:InputEvent):
	if DRAG_TOGGLE:
		if event.is_action_pressed(CONTROLS.DRAG):
			if drag_object:
				stop_dragging()
			else:
				start_dragging()
	else:
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

func _on_cooldown_timeout():
	cooldown_clear()

func _on_jam_timeout():
	if is_in_jam_zone():
		handle_jam()
	else:
		drag_suspecting_jam = false
