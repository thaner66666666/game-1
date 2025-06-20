extends Camera3D

@export var follow_speed := 8.0
@export var min_zoom := 3.0
@export var max_zoom := 25.0
@export var zoom_speed := 2.0
@export var camera_height := 15.0
@export var camera_angle := -45.0

var target_distance := 15.0
var current_distance := 15.0
var player: Node3D

# --- Add: dynamic camera angle ---
var dynamic_angle := -45.0

# --- Camera rotation variables (right-click) ---
var is_rotating_camera := false
var mouse_sensitivity := 2.0
var camera_rotation_x := 0.0
var camera_rotation_y := 0.0
var max_camera_tilt := 80.0

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
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_distance = max(min_zoom, target_distance - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_distance = min(max_zoom, target_distance + zoom_speed)
	elif event is InputEventMouseMotion and is_rotating_camera:
		camera_rotation_y -= event.relative.x * mouse_sensitivity * 0.01
		camera_rotation_x -= event.relative.y * mouse_sensitivity * 0.01
		camera_rotation_x = clamp(camera_rotation_x, deg_to_rad(-max_camera_tilt), deg_to_rad(max_camera_tilt))
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			# Reset camera rotation
			camera_rotation_x = 0.0
			camera_rotation_y = 0.0
			print('Camera rotation reset!')
		elif event.keycode == KEY_F1:
			debug_movement = !debug_movement
			print('Movement debug: ', debug_movement)

func _process(delta):
	if not player or not is_instance_valid(player):
		return
	
	# Smoothly adjust zoom distance
	current_distance = lerp(current_distance, target_distance, follow_speed * delta)
	
	# --- Calculate dynamic camera angle based on zoom ---
	var angle_start = -45.0
	var angle_end = -30.0  # Less top-down when zoomed in
	var transition_range = 5.0
	if current_distance <= min_zoom + transition_range:
		var t = clamp((current_distance - min_zoom) / transition_range, 0.0, 1.0)
		dynamic_angle = lerp(angle_end, angle_start, t)
	else:
		dynamic_angle = angle_start

	# --- Camera rotation logic ---
	if is_rotating_camera:
		# Camera rotation is handled in _input
		pass

	# Update camera position to follow player
	_update_camera_position(follow_speed * delta)

func _update_camera_position(lerp_amount: float):
	if not player or not is_instance_valid(player):
		return
	# Combine dynamic angle with camera rotation
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
	global_position = global_position.lerp(target_position, lerp_amount)
	look_at(player.global_position, Vector3.UP)
