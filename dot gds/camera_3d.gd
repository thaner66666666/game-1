extends Camera3D

@export var follow_speed := 8.0   # Balanced follow speed - not too fast
@export var min_zoom := 3.0
@export var max_zoom := 25.0
@export var zoom_speed := 2.0
@export var camera_height := 15.0
@export var camera_angle := -45.0

var target_distance := 15.0
var current_distance := 15.0
var player: Node3D

# --- Dynamic camera angle ---
var dynamic_angle := -45.0

# --- Enhanced Camera rotation variables ---
var is_rotating_camera := false
var mouse_sensitivity := 2.2  # Balanced sensitivity - not too fast
var camera_rotation_x := 0.0
var camera_rotation_y := 0.0
var max_camera_tilt := 80.0

# --- NEW: Smooth rotation system ---
var target_rotation_x := 0.0
var target_rotation_y := 0.0
var rotation_smoothing := 6.0   # Gentler smoothing - prevents jitter
var zoom_smoothing := 5.0       # Smooth zoom interpolation

# --- NEW: Camera momentum and smoothing ---
var rotation_velocity_x := 0.0
var rotation_velocity_y := 0.0
var momentum_decay := 0.95      # Gentler momentum decay
var position_velocity := Vector3.ZERO
var max_position_velocity := 50.0

var debug_movement := false

func _ready():
	add_to_group("camera")
	# Set initial distance
	current_distance = camera_height
	target_distance = camera_height
	call_deferred("find_player")

func find_player():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("Camera: Player not found, retrying...")
		get_tree().create_timer(0.5).timeout.connect(find_player)
	else:
		print("Camera: Found player at: ", player.global_position)
		# Set initial camera position
		_update_camera_position(1.0)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_rotating_camera = event.pressed
			if is_rotating_camera:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				# Momentum disabled to prevent jitter
				# _apply_rotation_momentum()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_distance = max(min_zoom, target_distance - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_distance = min(max_zoom, target_distance + zoom_speed)
	elif event is InputEventMouseMotion and is_rotating_camera:
		# Store rotation input for smooth application
		var rotation_input_x = -event.relative.y * mouse_sensitivity * 0.015  # Conservative sensitivity
		var rotation_input_y = -event.relative.x * mouse_sensitivity * 0.015
		
		# Add to target rotation instead of direct assignment
		target_rotation_y += rotation_input_y
		target_rotation_x += rotation_input_x
		target_rotation_x = clamp(target_rotation_x, deg_to_rad(-max_camera_tilt), deg_to_rad(max_camera_tilt))
		
		# Store velocity for momentum
		rotation_velocity_x = rotation_input_x
		rotation_velocity_y = rotation_input_y
		
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			# Smooth reset camera rotation
			_reset_camera_smoothly()
			print('Camera rotation reset!')
		elif event.keycode == KEY_F1:
			debug_movement = !debug_movement
			print('Movement debug: ', debug_movement)

# NEW: Apply momentum when mouse rotation stops
func _apply_rotation_momentum():
	# Continue rotating briefly with momentum
	var momentum_frames = 10
	var momentum_strength = 0.3
	
	for i in momentum_frames:
		await get_tree().process_frame
		var momentum_factor = (1.0 - float(i) / momentum_frames) * momentum_strength
		target_rotation_x += rotation_velocity_x * momentum_factor
		target_rotation_y += rotation_velocity_y * momentum_factor
		target_rotation_x = clamp(target_rotation_x, deg_to_rad(-max_camera_tilt), deg_to_rad(max_camera_tilt))

# NEW: Smooth camera reset
func _reset_camera_smoothly():
	target_rotation_x = 0.0
	target_rotation_y = 0.0

func _process(delta):
	if not player or not is_instance_valid(player):
		return
	
	# --- Smooth zoom with exponential easing ---
	current_distance = lerp(current_distance, target_distance, zoom_smoothing * delta)
	
	# --- Calculate dynamic camera angle based on zoom ---
	var angle_start = -45.0
	var angle_end = -30.0  # Less top-down when zoomed in
	var transition_range = 5.0
	if current_distance <= min_zoom + transition_range:
		var t = clamp((current_distance - min_zoom) / transition_range, 0.0, 1.0)
		dynamic_angle = lerp(angle_end, angle_start, t)
	else:
		dynamic_angle = angle_start

	# --- NEW: Smooth rotation interpolation ---
	camera_rotation_x = lerp(camera_rotation_x, target_rotation_x, rotation_smoothing * delta)
	camera_rotation_y = lerp(camera_rotation_y, target_rotation_y, rotation_smoothing * delta)
	
	# Apply momentum decay
	rotation_velocity_x *= momentum_decay
	rotation_velocity_y *= momentum_decay

	# Update camera position with enhanced smoothing
	_update_camera_position_smooth(delta)

# NEW: Enhanced camera position update with velocity-based smoothing
func _update_camera_position_smooth(delta: float):
	if not player or not is_instance_valid(player):
		return
		
	# Combine dynamic angle with smooth camera rotation
	var total_angle_x = deg_to_rad(dynamic_angle) + camera_rotation_x
	var total_angle_y = camera_rotation_y
	
	# Calculate camera position with rotation
	var horizontal_distance = current_distance * cos(total_angle_x)
	var vertical_height = current_distance * sin(-total_angle_x)
	
	# Apply Y rotation (left/right camera orbit)
	var rotated_offset = Vector3(
		horizontal_distance * sin(total_angle_y),
		vertical_height,
		horizontal_distance * cos(total_angle_y)
	)
	
	var target_position = player.global_position + rotated_offset
	
	# Use consistent follow speed to prevent jerkiness
	var smooth_follow_speed = follow_speed
	
	# Smooth position interpolation
	global_position = global_position.lerp(target_position, smooth_follow_speed * delta)
	
	# Less frequent look_at calls for better performance
	if Engine.get_process_frames() % 2 == 0:  # Every other frame
		look_at(player.global_position, Vector3.UP)

# Legacy function for compatibility
func _update_camera_position(_lerp_amount: float):
	_update_camera_position_smooth(get_process_delta_time())
