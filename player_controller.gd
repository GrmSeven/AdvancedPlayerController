extends CharacterBody2D

var physics_delta = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

@export_category("Controller settings")
# Small shift for values to slip into static position
@export var DEVIATION = 0.1 ** 2

@export_group("wip")
@export var ROTATE_WITH_GRAVITY	:= false

# 
@export_group("Movement/Horisontal")
@export var MAX_X_VELOCITY = 400
@export_range(0, 100, 0.1) var ACCEL_SPEED: float = physics_delta * MAX_X_VELOCITY:
	set(V):
		ACCEL_SPEED = -log(1-V/101) * physics_delta * MAX_X_VELOCITY
@export_range(0, 100, 0.1) var DEACCEL_SPEED: float = physics_delta * MAX_X_VELOCITY:
	set(V):
		DEACCEL_SPEED = -log(1-V/101) * physics_delta * MAX_X_VELOCITY
#@export var SURFACE_FRICTION = 1.0
#@export var RUN_MULTIPLIER = 1.0
#@export var CROUCH_MULTIPLIER = 1.0
@export var AIR_MANEUVERABILITY = 0.8
@export var FALL_PRECISION = true


@export_group("Movement/Vertical")
@export var MAX_Y_VELOCITY = 500
@export var AIR_FRICTION = 0.1

@export var HOLDABLE_JUMP = false
@export var MAX_JUMP_TIME = 0.3
@export var MIN_JUMP_TIME = 0.0
@export var JUMP_VELOCITY = 400
@export_range(0, 1, 0.01) var JUMP_DEACCEL = 0.8
@export var JUMP_DEACCEL_TIME = 0.1
@export var COYOTE_TIME = 0.1
@export var DELAYED_JUMP_TIME = 0.1
@export var N_JUMPS = 1
@export var DESCEND_MULTIPLIER = 2.0

### TODO:
# Make only relevant show up
# https://github.com/godotengine/godot-proposals/issues/1056
# Wall jump
# Gravity rotation
# N jumps

# Tool functions
func get_numbers_sign(num: float) -> int:
	if num == 0:
		return 0
	elif num > 0:
		return 1
	else:
		return -1
	
func one_devided(num) -> float:
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
	apply_jump(delta)
	apply_movement(delta)
	
	move_and_slide()

# Jumping
var air_timer = 0
var jump_timer = 0
var jump_deaccel_timer = 0
var jump_started = true
var jumping = false
var jump_stop = false

func apply_jump(delta) -> void:
	if jump_input_just_pressed:
		jump_timer = 0
	if is_on_floor():
		air_timer = 0
		if jump_started:
			jump_started = false
		if jumping:
			jumping = false
		# If player pressed jump
		if HOLDABLE_JUMP and jump_input_held:
			jumping = true
		# If player triggered jump in advance
		elif jump_timer <= DELAYED_JUMP_TIME:
			jumping = true
	# Coyote time jump
	if air_timer <= COYOTE_TIME and !jump_started and jump_input_just_pressed:
		air_timer = 0
		jumping = true
	
	if jumping:
		if !jump_stop and (jump_input_held and air_timer < MAX_JUMP_TIME or air_timer < MIN_JUMP_TIME):
			velocity.y = -JUMP_VELOCITY
			jump_deaccel_timer = 0
		else:
			jump_stop = true
		if jump_stop:
			if jump_deaccel_timer <= JUMP_DEACCEL_TIME:
				velocity.y *= JUMP_DEACCEL
			else:
				jumping = false
				jump_stop = false
		
		jump_started = true
	
	air_timer += delta
	jump_timer += delta
	jump_deaccel_timer += delta

# Moving
var velocity_direction
var move_mult

func apply_movement(delta) -> void:
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
		velocity.x += move_input_axis * ACCEL_SPEED * move_mult * delta
		if abs(velocity.x) > MAX_X_VELOCITY:
			velocity.x = MAX_X_VELOCITY * get_numbers_sign(velocity.x)
		if move_input_axis == 0:
			if abs(velocity.x) < delta * DEACCEL_SPEED * move_mult + DEVIATION:
				velocity.x = 0
			else:
				velocity.x -= velocity_direction * DEACCEL_SPEED * move_mult * delta
	else:
		velocity.x -= velocity_direction * DEACCEL_SPEED * move_mult * delta

# Graviting
var NEW_MAX_Y_VELOCITY
var gravity_multiplier
var multiplied_descend

func apply_gravity(delta) -> void:
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
