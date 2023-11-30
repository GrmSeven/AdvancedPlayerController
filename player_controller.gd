extends CharacterBody2D

var physics_delta = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

@export_category("Controller settings")
# Platformer has jump; top-down can move in all 4 directions
@export_enum("Platformer", "Top-Down") var GAMEPLAY_MODE := 0
# Small shift for values to slip into static position
@export var DEVIATION = 0.1 ** 2

# 
@export_group("Movement/Horisontal")
@export var MAX_X_VELOCITY = 500
@export_range(0, 100, 0.1) var ACCEL_SPEED: float = physics_delta * MAX_X_VELOCITY:
	set(V):
		ACCEL_SPEED = -log(1-V/101) * physics_delta * MAX_X_VELOCITY
@export_range(0, 100, 0.1) var DEACCEL_SPEED: float = physics_delta * MAX_X_VELOCITY:
	set(V):
		DEACCEL_SPEED = -log(1-V/101) * physics_delta * MAX_X_VELOCITY
@export var SURFACE_FRICTION = 1.0
@export var RUN_MULTIPLIER = 1.0
@export var CROUCH_MULTIPLIER = 1.0
@export var AIR_MANEUVERABILITY = 1.0
@export var FALL_PRECISION = false


@export_group("Movement/Vertical")
@export var MAX_Y_VELOCITY = 1000
@export var AIR_FRICTION = 0.05

@export var HOLDABLE_JUMP = false
@export var MAX_JUMP_TIME = 0.2
@export var MIN_JUMP_TIME = 0.2
@export var JUMP_VELOCITY = 500
@export_range(0, 1, 0.01) var JUMP_DEACCEL = 0.9
@export var COYOTE_TIME = 1
@export var DELAYED_INPUT_DETECTION_TIME = 0.1

@export var DESCEND_MULTIPLIER = 1.0


@export_group("Work in progress")
@export var ROTATE_WITH_GRAVITY	:= false

### TODO:
# Make only relevant show up
# https://github.com/godotengine/godot-proposals/issues/1056
# Wall jump
# Gravity rotation
# N jumps
# Gameplay Mode

# Tool functions
func get_numbers_sign(num: float):
	if num == 0:
		return 0
	elif num > 0:
		return 1
	else:
		return -1
	
func one_devided(num):
	if num == 0:
		return 0
	else:
		return 1 / num

# Main
var jump_input_held
var jump_input_just_pressed
var move_input_axis
var descend_input_held


func _physics_process(delta: float) -> void:
	move_input_axis = Input.get_axis("ui_left", "ui_right")
	jump_input_held = Input.is_action_pressed("game_jump")
	jump_input_just_pressed = Input.is_action_just_pressed("game_jump")
	descend_input_held = Input.is_action_pressed("ui_down")

	
	apply_gravity(delta)
	apply_jump(delta) # switched with movement
	apply_movement(delta)
	
	move_and_slide()

# Jumping
var air_time = 0
var jump_time = 0
var jump_deaccel_time = 0
var jump_started = true
var jumping = false
var jump_stop = false

func apply_jump(delta):
	if jump_input_just_pressed:
		jump_time = 0
	if is_on_floor():
		air_time = 0
		if jump_started:
			jump_started = false
		if jumping:
			jumping = false
		# If player pressed jump
		if HOLDABLE_JUMP and jump_input_held:
			jumping = true
		# If player triggered jump in advance
		elif jump_time <= DELAYED_INPUT_DETECTION_TIME:
			jumping = true
	# Coyote time jump
	if air_time <= COYOTE_TIME and !jump_started and jump_input_just_pressed:
		air_time = 0
		jumping = true
	
	if jumping:
		if !jump_stop and (jump_input_held and air_time < MAX_JUMP_TIME or air_time < MIN_JUMP_TIME):
			velocity.y = -JUMP_VELOCITY
			jump_deaccel_time = 0
		else:
			jump_stop = true
		if jump_stop:
			if jump_deaccel_time <= 0.1:
				velocity.y *= JUMP_DEACCEL
			else:
				jumping = false
				jump_stop = false
		
		jump_started = true
	
	air_time += delta
	jump_time += delta
	jump_deaccel_time += delta

# Moving
var velocity_direction
var move_mult

func apply_movement(delta):
	print(velocity.x)
	velocity_direction = get_numbers_sign(velocity.x)
	if velocity_direction == 0:
		velocity_direction = move_input_axis
	if is_on_floor():
		move_mult = 1
	elif multiplied_descend and FALL_PRECISION:
		move_mult = AIR_MANEUVERABILITY * DESCEND_MULTIPLIER
	else:
		move_mult = AIR_MANEUVERABILITY
		
	if abs(velocity.x) < MAX_X_VELOCITY + DEVIATION:
		velocity.x += move_input_axis * ACCEL_SPEED * move_mult * delta / SURFACE_FRICTION
		if abs(velocity.x) > MAX_X_VELOCITY:
			velocity.x = MAX_X_VELOCITY * get_numbers_sign(velocity.x)
		if move_input_axis == 0:
			if abs(velocity.x) < delta * DEACCEL_SPEED * move_mult * SURFACE_FRICTION + DEVIATION:
				velocity.x = 0
			else:
				velocity.x -= velocity_direction * DEACCEL_SPEED * move_mult * SURFACE_FRICTION * delta
	else:
		velocity.x -= velocity_direction * DEACCEL_SPEED * move_mult * SURFACE_FRICTION * delta

# Graviting
var NEW_MAX_Y_VELOCITY
var gravity_multiplier
var multiplied_descend

func apply_gravity(delta):
	multiplied_descend = velocity.y >= MAX_Y_VELOCITY and descend_input_held
	if multiplied_descend:
		NEW_MAX_Y_VELOCITY = DESCEND_MULTIPLIER * MAX_Y_VELOCITY
		gravity_multiplier = DESCEND_MULTIPLIER
	else:
		NEW_MAX_Y_VELOCITY = MAX_Y_VELOCITY
		gravity_multiplier = 1
	
	if velocity.y < NEW_MAX_Y_VELOCITY + DEVIATION:
		velocity.y += gravity * gravity_multiplier * delta
		if velocity.y > NEW_MAX_Y_VELOCITY:
			velocity.y = NEW_MAX_Y_VELOCITY
	else:
		velocity.y -= (velocity.y - NEW_MAX_Y_VELOCITY) * AIR_FRICTION
