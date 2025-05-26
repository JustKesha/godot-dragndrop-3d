class_name DragAndDrop3D extends Node
# WARNING Treat all uppercase variables as consts
# Dont try to overwrite them at runtime unles you know what youre doing

@export_group("Draggables")
# Requires draggable objects to have truthy metadata with chosen name
# (For example a boolean set to True/On)
# NOTE Leave an empty string to disable
@export var METADATA := 'draggable'
# Requires draggable objects to be in the selecter collision layer
# NOTE Set 0 to disable
@export_range(0, 32) var COLLISION_LAYER := 0 # int 1-32 (Not bit or value)

@export_group("General")
# Choose between toggling drag action / holding the drag key down
@export var DRAG_TOGGLE := true
# (Timer is started right after picking up a draggable)
@export var DRAG_COOLDOWN := .25
# Will offset the draggable from holding position
@export var DRAG_OFFSET := Vector3.ZERO
# Allows draggable to keep it's initial offset from the raycast hit point
@export var ALLOW_INITIAL_OFFSET := true
# Whether or not to keep track of draggables hovered (needed for some signals)
@export var TRACK_HOVERING := true
# If set to false, will use prevent_clipping() to move the object closer to you when facing a wall
# The downside is, it does not return objects to original distance (zoom) when you back off
@export var ALLOW_CLIPPING := false

@export_group("Controls")
# Will use CONTROLS.DRAG for the DRAG & DROP
# (or instead for the DRAG & THROW if ALLOW_THROW is enabled)
@export var SINGLE_ACTION_CONTROLS := true
@export var CONTROLS := {
	# Values from input map
	"DRAG": "drag",
	"DROP": "drop",
	"THROW": "throw",
	"ZOOM_IN": "zoom_in",
	"ZOOM_OUT": "zoom_out",
}

@export_group("Zoom")
@export var USE_ZOOM := true
@export var ZOOM_MIN := .75
@export var ZOOM_MAX := 2.25
@export var ZOOM_SPEED := .2
# The distance from raycast start at which to position a newly picked up draggable
@export var ZOOM_START := -1.0 # Anything < 0 will use distance to object as initial zoom
# Whether or not to instatly set draggable distance when picked up
@export var TELEPORT_ON_START := false

@export_group("Static Drag (Setpos)")
# This mode uses direct position updates
# Which can result into objects clipping through other objects

@export var DRAG_SPEED := 12.0
# Will ignore DRAG_SPEED and instead update object pos as fast as possible
@export var INSTANT_DRAG := false

# "Physical Drag"
@export_group("Rigid Drag (Velocity)")
# Will use linear velocity (DRAG_FORCE) instead of the Static Drag,
# NOTE But only if the draggable object is a RigidBody3D
# Allows for object tossing and gets rid of the clipping issue with Static Drag
@export var USE_RIGID_DRAG := true
@export var DRAG_FORCE := 350.0
@export var FORCE_STATIC_OBJECTS := false
@export var RELEASE_VELOCITY_MULT := Vector3.ONE * .8
@export var WAKE_UP_VELOCITY := Vector3.UP * .35

@export_group("Throwing")
# Allows you to throw rigid objects
@export var ALLOW_THROW := true
# True: will slowly build up the power of your throws (THROW_CHARGE_TIME for full THROW_SPEED_MAX)
# False: will always use THROW_SPEED_MAX
@export var CHARGE_THROW := true
@export var THROW_SPEED_MIN := 0.0
@export var THROW_SPEED_MAX := 8.0
@export var THROW_CHARGE_TIME := 1.0
# If true, will automatically throw the object once THROW_SPEED_MAX is reached (for CHARGE_THROW only)
@export var THROW_WHEN_CHARGED := true
@export var THROW_OFFSET := Vector3.UP * .1
@export var USE_RANDOM_ANGLE := true
@export var ANGULAR_SPEED_MULT := .6
# If the object is not rigid
@export var DROP_IF_CANT_THROW := true

@export_group("Angle Stabilisation")
# Mainly, for the Rigid Drag Mode
@export var USE_STABILISATION := true
# Custom stabilisation angle (rotation)
@export var STABILISATION_ANGLE := Vector3.ZERO
# Will lock the object to the angle (rotation) it was picked up at
@export var USE_STARTING_ANGLE := false
# How fast the object will return to the set angle (rotation)
@export var STABILISATION_SPEED := 5.0
# Whether or not to apply angle stabilisation to static objects
@export var STABILISE_NON_RIGID := false
# If playing stabilisation to static objects, this will insta rotate them
@export var INSTANT_STATICS_STABILISATION := true

@export_group("Jam Handling")
# NOTE Only for the Rigid Drag Mode
@export var TRACK_JAMMING := true
# If TRACK_JAMMING is on/true,
# Will determine the type of response to the draggable objects getting "stuck"
@export var JAM_RESPONSE := JAM_RESPONSES.LOWER_DISTANCE
# If at any point object's center is JAM_MIN_DISTANCE+ away from the "drag point"
# (point to which youre trying to drag the object), jam check will start:
# 1. Object's position is saved
# 2. A timer of JAM_MIN_TIME seconds starts
# 3. Once over, we check how far the object had traveled during that time
# 4. If it stayed within the JAM_ZONE_RADIUS, then trigger a JAM_RESPONSE
@export var JAM_MIN_DISTANCE := .25
# NOTE ^ Basically the breaking distance (between object and where youre trying
# to drag it) at which JAM_RESPONSE is triggered
# WARNING ^ Important to adjust JAM_MIN_DISTANCE to scale of your objects
@export var JAM_MIN_TIME := .1
@export var JAM_ZONE_RADIUS := .1

# Settings for specific JAM_RESPONSE types
@export var JAM_TELEPORT_CLOSE_DIST := -1
@export var JAM_LOWER_DISTANCE_MULT := .85
@export var JAM_LOWER_DISTANCE_FAIL := JAM_RESPONSES.TELEPORT_CLOSE

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
signal teleported (object:Node3D)

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

func get_start_distance(raycast:RayCast3D = drag_raycast) -> float:
	return get_collision_distance(raycast) if ZOOM_START < 0 else ZOOM_START

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

func should_use_velocity(object) -> bool:
	if not USE_RIGID_DRAG or not is_object_forcable(object):
		return false
	
	if is_object_static(object) and not FORCE_STATIC_OBJECTS:
		return false
	
	return true

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

func set_use_velocity(value:bool = USE_RIGID_DRAG) -> bool:
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
		distance:float = get_start_distance(),
		angle:Vector3 = get_default_angle(object),
		offset:Vector3 = DRAG_OFFSET + get_drag_offset(object),
		use_velocity:bool = should_use_velocity(object),
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
	
	drag_raycast.add_exception(object)
	
	started_dragging.emit(drag_object)
	
	if TELEPORT_ON_START:
		teleport()
	
	return true

func stop_dragging():
	if not drag_object:
		return
	
	if drag_use_velocity:
		drag_object.linear_velocity *= RELEASE_VELOCITY_MULT
	
	if drag_object is RigidBody3D:
		drag_object.freeze = drag_origin_freeze
		wake_up(drag_object)
	
	drag_raycast.remove_exception(drag_object)
	
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
			teleport()
		JAM_RESPONSES.TELEPORT_CLOSE:
			set_drag_distance(JAM_TELEPORT_CLOSE_DIST)
			teleport()
	
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

func teleport(object:Node3D = drag_object, to:Vector3 = get_drag_position()):
	object.global_position = to
	teleported.emit(object)

func prevent_clipping():
	if not drag_object:
		return
	
	var col_distance = get_collision_distance()
	
	if col_distance > 0 and drag_distance > col_distance:
		drag_distance = col_distance

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
	if not drag_object:
		return
	
	drag(delta)
	if USE_STABILISATION:
		stabilize(delta)
	if TRACK_JAMMING:
		jam_check()
	if not ALLOW_CLIPPING:
		prevent_clipping()

func _unhandled_input(event:InputEvent):
	var CONTROLS_THROW = CONTROLS.DRAG if SINGLE_ACTION_CONTROLS else CONTROLS.THROW
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
