extends Node

var METADATA := 'draggable'
var COLLISION_LAYER := 0 # 1-32 NOTE Not bit, value or name

var DRAG_TOGGLE := true
var DRAG_SPEED := 12.0
var INSTANT_DRAG := false
var DRAG_OFFSET := Vector3.ZERO
var DRAG_COOLDOWN := .25
var ALLOW_INITIAL_OFFSET := true

var USE_ZOOM := true
var ZOOM_MIN := .75
var ZOOM_MAX := 2.25
var ZOOM_SPEED := .2
var ZOOM_START := -1.0
# -1 will use distance to object as initial zoom

var USE_STABILISATION := true
var USE_STARTING_ANGLE := false
var STABILISATION_SPEED := 5.0
var STABILISATION_ANGLE := Vector3.ZERO
var STABILISE_NON_RIGID := false
var INSTANT_STATICS_STABILISATION := true

var TRACK_HOVERING := true

# Values from input map
const CONTROLS := {
	"DRAG": "drag",
	"THROW": "throw",
	"ZOOM_IN": "zoom_in",
	"ZOOM_OUT": "zoom_out",
}

# Will use CONTROLS.DRAG action for both drag and throw interactions
var SINGLE_ACTION_DRAG_AND_THROW := true

# Will use linear velocity (FORCE) instead of position changing (SPEED),
# for RigidBody objects, to avoid clipping and allow for tossing
var USE_VELOCITY := true
var DRAG_FORCE := 350.0
var RELEASE_VELOCITY_MULT := Vector3.ONE * .8
var WAKE_UP_VELOCITY := Vector3.UP * .35

var ALLOW_THROW := true
var CHARGE_THROW := true
var THROW_SPEED_MIN := 0.0
var THROW_SPEED_MAX := 8.0
var THROW_CHARGE_TIME := 1.0
var THROW_WHEN_CHARGED := true
var THROW_OFFSET := Vector3.UP * .1
var USE_RANDOM_ANGLE := true
var ANGULAR_SPEED_MULT := .6
var DROP_IF_CANT_THROW := true

# Only works when using force
var TRACK_JAMMING := true
var JAM_RESPONSE := JAM_RESPONSES.LOWER_DISTANCE
var JAM_MIN_DISTANCE := .25
var JAM_MIN_TIME := .1
var JAM_ZONE_RADIUS := .1

# Settings for specific JAM_RESPONSE types
var JAM_TELEPORT_CLOSE_DIST := -1
var JAM_LOWER_DISTANCE_MULT := .85
var JAM_LOWER_DISTANCE_FAIL := JAM_RESPONSES.TELEPORT_CLOSE

@onready var drag_raycast:RayCast3D = $"."
@onready var drag_cooldown_timer:Timer = Timer.new()
@onready var drag_jam_timer:Timer = Timer.new()
@onready var throw_charge_timer:Timer = Timer.new()

enum JAM_RESPONSES {
	NONE = -1,
	STOP_DRAGGING = 0,
	TELEPORT = 1,
	TELEPORT_CLOSE = 2,
	LOWER_DISTANCE = 3,
}

signal dragging (object:Node3D)
signal started_dragging (object:Node3D)
signal stopped_dragging (object:Node3D)
signal draggable_hovered (object:Node3D)
signal draggable_unhovered (object:Node3D)
signal cooldown_timeset
signal cooldown_timeout
signal jammed
signal thrown
signal throw_charge_started
signal throw_charge_stopped
signal throw_charge_full

var drag_object:Node3D
var drag_object_staic:bool
var drag_hovered:Node3D
var drag_distance:float
var drag_angle:Vector3
var drag_use_velocity:bool
var drag_origin_freeze:bool
var drag_offset:Vector3
var drag_on_cooldown:bool
var drag_jam_point:Vector3
var drag_suspecting_jam:bool
var throw_charging:bool

# HELPERS

func get_collision_distance(raycast:RayCast3D = drag_raycast) -> float:
	if not raycast.is_colliding():
		return -1
	
	return raycast.global_transform.origin.distance_to(raycast.get_collision_point())

func get_drag_distance(raycast:RayCast3D = drag_raycast) -> float:
	if ZOOM_START <= -1:
		return get_collision_distance(raycast)
	return ZOOM_START

func wake_up(object:RigidBody3D):
	# Changing .sleeping doesnt seem to be enough
	object.linear_velocity += WAKE_UP_VELOCITY

func is_object_draggable(object:CollisionObject3D) -> bool:
	if not object is Node3D:
		return false
	
	if METADATA and not object.get_meta(METADATA, false):
		return false
	
	if COLLISION_LAYER and not object.get_collision_layer_value(COLLISION_LAYER):
		return false
	
	return true

func is_object_forcable(object) -> bool:
	return object is RigidBody3D

func is_object_static(object) -> bool:
	return not object is RigidBody3D or object.freeze

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

func get_raycast_forward(raycast:RayCast3D = drag_raycast) -> Vector3:
	return -raycast.get_global_transform().basis.z

func get_drag_position(
		distance:float = drag_distance,
		offset:Vector3 = drag_offset,
		raycast:RayCast3D = drag_raycast,
	) -> Vector3:
	if not raycast:
		return Vector3.ZERO
	
	return raycast.global_position + offset + get_raycast_forward() * distance

func get_drag_velocity(
		delta:float,
		force:float = DRAG_FORCE,
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
	if not object:
		return STABILISATION_ANGLE
	
	if USE_STARTING_ANGLE or is_object_static(object):
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

func get_random_angle(from:float = -1, to:float = 1) -> Vector3:
	return Vector3(randf_range(from, to), randf_range(from, to), randf_range(from, to))

func get_throw_charge_time() -> float:
	if not throw_charging or not throw_charge_timer:
		return 0
	
	return THROW_CHARGE_TIME - throw_charge_timer.time_left

func get_throw_speed(
		min:float = THROW_SPEED_MIN,
		max:float = THROW_SPEED_MAX,
		charge:bool = CHARGE_THROW,
		charge_time:float = get_throw_charge_time(),
		full_charge_time:float = THROW_CHARGE_TIME,
		is_being_charged:bool = throw_charging,
	) -> float:
	if not charge:
		return max
	
	if not is_being_charged:
		return 0
	
	return min + charge_time * (max-min) / full_charge_time

# SETTERS

func set_drag_distance(distance:float) -> float:
	drag_distance = clamp(distance, ZOOM_MIN, ZOOM_MAX)
	return drag_distance

func set_drag_object(object:Node3D):
	if drag_object:
		stop_dragging()
	
	drag_object = object

func set_drag_angle(angle:Vector3 = get_default_angle()) -> Vector3:
	drag_angle = angle
	return drag_angle

func set_drag_offset(offset:Vector3):
	drag_offset = offset

func set_use_velocity(value:bool = USE_VELOCITY) -> bool:
	drag_use_velocity = value
	return value

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

func set_draggable_hovered(value:Node3D):
	var old_value = drag_hovered
	
	if old_value == value:
		return
	
	drag_hovered = value
	
	if not value:
		draggable_unhovered.emit(old_value)
		return
	
	draggable_hovered.emit(value)

func set_drag_object_static(value:bool = is_object_static(drag_object)) -> bool:
	drag_object_staic = value
	return value

# ACTIONS

func start_dragging(
		object:Node3D = get_draggable_aimed(),
		ignore_cooldown:bool = false,
		distance:float = get_drag_distance(),
		angle:Vector3 = get_default_angle(object),
		offset:Vector3 = DRAG_OFFSET + get_drag_offset(object),
		use_velocity:bool = USE_VELOCITY and is_object_forcable(object),
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
	set_drag_object_static()
	
	if TRACK_HOVERING:
		set_draggable_hovered(null)
	
	if object is RigidBody3D:
		drag_origin_freeze = object.freeze
		object.freeze = !use_velocity
	
	started_dragging.emit(drag_object)
	
	return true

func stop_dragging():
	if not drag_object:
		return
	
	if drag_use_velocity:
		drag_object.linear_velocity *= RELEASE_VELOCITY_MULT
	
	if drag_object is RigidBody3D:
		drag_object.freeze = drag_origin_freeze
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
	
	var target_pos = get_drag_position()
	
	if speed < 0 or INSTANT_DRAG:
		object.global_position = target_pos
	else:
		object.global_position = object.global_position.lerp(
			target_pos, delta * speed
		)
	
	dragging.emit(object)

func drag_by_velocity(
		delta:float,
		force:float = DRAG_FORCE,
		object:RigidBody3D = drag_object
	):
	if not drag_object:
		return stop_dragging()
	
	object.linear_velocity = get_drag_velocity(delta, force, object)
	object.angular_velocity = Vector3.ZERO
	
	dragging.emit(object)

func drag(
		delta:float,
		speed:float = DRAG_SPEED,
		force:float = DRAG_FORCE,
		use_velocity:bool = drag_use_velocity,
		object:Node3D = drag_object,
	):
	if use_velocity:
		drag_by_velocity(delta, force, object)
	else:
		drag_by_setpos(delta, speed, object)

func stabilize(
		delta:float,
		speed:float = STABILISATION_SPEED,
		angle:Vector3 = drag_angle,
		object:Node3D = drag_object,
	):
	if( not object
		or (not object is RigidBody3D and not STABILISE_NON_RIGID)):
		return
	
	if drag_object_staic and INSTANT_STATICS_STABILISATION:
		speed = -1
	
	if speed < 0:
		object.rotation = angle
		return
	
	object.rotation = object.rotation.lerp(angle, delta * speed)

func throw(
		object:Node3D = drag_object,
		speed:float = get_throw_speed(),
		direction:Vector3 = get_raycast_forward() + THROW_OFFSET,
		angular_speed:float = ANGULAR_SPEED_MULT * speed,
		angle:Vector3 = get_random_angle() if USE_RANDOM_ANGLE else Vector3.ZERO,
		was_charging:bool = throw_charging,
	):
	if not object:
		return
	
	if was_charging:
		stop_throw_charing()
	
	if not is_object_forcable(object):
		if DROP_IF_CANT_THROW:
			stop_dragging()
		return
	
	if object == drag_object:
		stop_dragging()
	
	object.linear_velocity += direction * speed
	object.angular_velocity += angle * angular_speed
	
	thrown.emit()

func start_throw_charging(full_charge_time:float = THROW_CHARGE_TIME):
	throw_charge_timer.wait_time = full_charge_time
	throw_charge_timer.start()
	
	throw_charging = true
	
	throw_charge_started.emit()

func stop_throw_charing():
	throw_charge_timer.stop()
	
	throw_charging = false
	
	throw_charge_stopped.emit()

# CONTROLS

func _ready():
	drag_cooldown_timer.one_shot = true
	drag_cooldown_timer.timeout.connect(Callable(self, "_on_cooldown_timeout"))
	add_child(drag_cooldown_timer)
	
	drag_jam_timer.one_shot = true
	drag_jam_timer.timeout.connect(Callable(self, "_on_jam_timeout"))
	add_child(drag_jam_timer)
	
	throw_charge_timer.one_shot = true
	throw_charge_timer.timeout.connect(Callable(self, "_on_throw_fully_charged"))
	add_child(throw_charge_timer)

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
	var CONTROLS_THROW = CONTROLS.DRAG if SINGLE_ACTION_DRAG_AND_THROW else CONTROLS.THROW
	var DRAGGING = drag_object
	var DRAG_DOWN = event.is_action_pressed(CONTROLS.DRAG)
	var DRAG_UP = event.is_action_released(CONTROLS.DRAG)
	var THROW_DOWN = event.is_action_pressed(CONTROLS_THROW)
	var THROW_UP = event.is_action_released(CONTROLS_THROW)
	var ZOOM_IN = event.is_action_pressed(CONTROLS.ZOOM_IN)
	var ZOOM_OUT = event.is_action_pressed(CONTROLS.ZOOM_OUT)
	var CHARGING = get_throw_charge_time()
	
	if not ALLOW_THROW:
		THROW_DOWN = false
		THROW_UP = false
	
	if DRAG_TOGGLE:
		if DRAGGING:
			if THROW_DOWN:
				if CHARGE_THROW:
					if not CHARGING:
						return start_throw_charging()
				else:
					return throw()
			elif THROW_UP and CHARGE_THROW and (THROW_UP != DRAG_UP or CHARGING):
				return throw()
		
		if DRAG_DOWN:
			if DRAGGING:
				return stop_dragging()
			else:
				start_dragging()
		elif DRAG_UP:
			return
	else:
		if THROW_UP and DRAGGING:
			return throw()
		
		if DRAG_DOWN:
			start_dragging()
		elif DRAG_UP and DRAGGING:
			return stop_dragging()
		
		if THROW_DOWN:
			if CHARGE_THROW:
				return start_throw_charging()
			elif DRAGGING:
				return throw()
	
	if USE_ZOOM:
		if ZOOM_IN:
			return set_drag_distance(drag_distance - ZOOM_SPEED)
		elif ZOOM_OUT:
			return set_drag_distance(drag_distance + ZOOM_SPEED)

func _on_cooldown_timeout():
	cooldown_clear()

func _on_jam_timeout():
	if is_in_jam_zone():
		handle_jam()
	else:
		drag_suspecting_jam = false

func _on_throw_fully_charged():
	throw_charge_full.emit()
	if THROW_WHEN_CHARGED and not drag_object_staic:
		throw()
