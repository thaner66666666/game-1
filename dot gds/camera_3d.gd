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
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_distance = max(min_zoom, target_distance - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_distance = min(max_zoom, target_distance + zoom_speed)

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

	# Update camera position to follow player
	_update_camera_position(follow_speed * delta)

func _update_camera_position(lerp_amount: float):
	# --- Use dynamic_angle instead of static camera_angle ---
	var angle_rad = deg_to_rad(dynamic_angle)
	var horizontal_distance = current_distance * cos(angle_rad)
	var vertical_height = current_distance * sin(-angle_rad)  # Negative because we want height above

	var offset = Vector3(0, vertical_height, horizontal_distance)
	var target_position = player.global_position + offset
	global_position = global_position.lerp(target_position, lerp_amount)
	look_at(player.global_position, Vector3.UP)
