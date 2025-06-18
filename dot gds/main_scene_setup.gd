# main_scene_setup.gd - FIXED: Prevents double spawning issue
extends Node3D

# Time of day system - 64 different times
@export_group("Time of Day")
@export var time_of_day_segments := 64
var current_time_segment: int = 0
var main_light: DirectionalLight3D
var world_environment: WorldEnvironment

func _ready():
	print("🎮 Main Scene: Starting...")
	
	# Create lighting
	_setup_lighting()
	
	# Instantiate enemy spawner from scene early
	var spawner_scene = load("res://Scenes/spawner.tscn")
	if spawner_scene:
		var spawner = spawner_scene.instantiate()
		spawner.name = "EnemySpawner"
		add_child(spawner)
		spawner.add_to_group("spawner")
		print("✅ Enemy spawner instantiated from Scenes/spawner.tscn and added to group")
	else:
		print("❌ Could not load Scenes/spawner.tscn!")
	
	# Create systems step by step
	call_deferred("_create_simple_systems")

func _setup_lighting():
	"""Create dynamic lighting that changes based on time of day"""
	main_light = DirectionalLight3D.new()
	main_light.name = "MainLight"
	main_light.shadow_enabled = true
	main_light.light_energy = 0.8 # Lowered for dramatic torch effect
	main_light.shadow_bias = 0.05
	main_light.shadow_normal_bias = 0.8
	main_light.shadow_max_distance = 60.0
	main_light.shadow_blur = 2.0
	add_child(main_light)

	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_energy = 0.15 # Lowered ambient for more contrast
	env.ambient_light_color = Color(0.2, 0.2, 0.25)

	world_environment = WorldEnvironment.new()
	world_environment.environment = env
	add_child(world_environment)
	
	# Set random time of day when game starts
	_set_random_time_of_day()

func _set_random_time_of_day():
	"""Randomly select one of 64 time segments and apply lighting"""
	current_time_segment = randi() % time_of_day_segments
	_apply_time_of_day_lighting(current_time_segment)
	print("🌅 Time of day set to segment: ", current_time_segment, "/", time_of_day_segments)

func _apply_time_of_day_lighting(segment: int):
	"""Apply lighting settings based on time segment (0-63)"""
	if not main_light or not world_environment:
		return
	
	# Convert segment to time (0 = midnight, 32 = noon)
	var time_progress = float(segment) / float(time_of_day_segments)
	var sun_angle = time_progress * 360.0 - 90.0  # -90° to 270°
	
	# Calculate sun position
	var sun_elevation = sin(deg_to_rad(sun_angle + 90.0)) * 90.0
	var sun_rotation = Vector3(sun_elevation, sun_angle * 0.5, 0)
	main_light.rotation_degrees = sun_rotation
	
	# Determine lighting phase
	var is_night = sun_elevation < -10.0
	var is_dawn = sun_elevation >= -10.0 and sun_elevation < 10.0
	var is_day = sun_elevation >= 10.0 and sun_elevation < 80.0
	var is_dusk = sun_elevation >= 80.0 and sun_elevation < 100.0
	
	# Apply lighting based on phase
	if is_night:
		_apply_night_lighting()
	elif is_dawn:
		_apply_dawn_lighting(sun_elevation)
	elif is_day:
		_apply_day_lighting(sun_elevation)
	elif is_dusk:
		_apply_dusk_lighting(sun_elevation)

func _apply_night_lighting():
	"""Dark night lighting"""
	main_light.light_energy = 0.2
	main_light.light_color = Color(0.4, 0.5, 0.8)
	world_environment.environment.ambient_light_energy = 0.1
	world_environment.environment.ambient_light_color = Color(0.2, 0.3, 0.6)

func _apply_dawn_lighting(elevation: float):
	"""Sunrise/golden hour lighting"""
	var intensity = remap(elevation, -10.0, 10.0, 0.3, 0.8)
	main_light.light_energy = intensity
	main_light.light_color = Color(1.0, 0.8, 0.6)
	world_environment.environment.ambient_light_energy = intensity * 0.4
	world_environment.environment.ambient_light_color = Color(0.9, 0.7, 0.5)

func _apply_day_lighting(elevation: float):
	"""Bright daytime lighting"""
	var intensity = remap(elevation, 10.0, 80.0, 0.8, 1.2)
	main_light.light_energy = intensity
	main_light.light_color = Color.WHITE
	world_environment.environment.ambient_light_energy = intensity * 0.4
	world_environment.environment.ambient_light_color = Color.WHITE

func _apply_dusk_lighting(elevation: float):
	"""Sunset lighting"""
	var intensity = remap(elevation, 80.0, 100.0, 0.8, 0.3)
	main_light.light_energy = intensity
	main_light.light_color = Color(1.0, 0.6, 0.4)
	world_environment.environment.ambient_light_energy = intensity * 0.3
	world_environment.environment.ambient_light_color = Color(0.8, 0.5, 0.3)

func _create_simple_systems():
	"""Create simple reliable systems"""
	# Step 1: Wait for existing main.tscn systems to be ready
	await get_tree().create_timer(1.0).timeout
	
	# Step 2: Create simple room generator
	var room_generator = _create_simple_room_generator()
	if not room_generator:
		print("❌ Failed to create room generator!")
		return
	
	# Step 3: Wait for spawner to initialize (no longer created here)
	await get_tree().create_timer(2.0).timeout
	
	# Step 4: Setup spawner for rooms
	var spawner = get_node_or_null("EnemySpawner")
	if spawner:
		_setup_spawner_for_rooms(spawner, room_generator)
		print("✅ Enemy spawner ready!")
	else:
		print("❌ Enemy spawner not found in scene!")
	
	await get_tree().create_timer(5.0).timeout
	_check_system_status()

func _create_simple_room_generator() -> Node3D:
	"""Create the simple room generator using separate script file"""
	var room_gen = Node3D.new()
	room_gen.name = "SimpleRoomGenerator"
	
	# Load the separate script file
	var room_script = load("res://dot gds/simple_room_generator.gd")
	if room_script:
		room_gen.script = room_script
		add_child(room_gen)
		print("✅ Simple room generator created from separate file")
		return room_gen
	else:
		print("❌ Could not load dot gds/simple_room_generator.gd!")
		return null

func _setup_spawner_for_rooms(spawner: Node3D, room_generator: Node3D):
	"""Connect spawner to room system"""
	await get_tree().create_timer(1.0).timeout
	
	print("🔗 Connecting wave system to room generator...")
	
	# ✅ FIXED: Check if signal is already connected before connecting
	if spawner.has_signal("wave_completed") and room_generator.has_method("_on_wave_completed"):
		if not spawner.wave_completed.is_connected(room_generator._on_wave_completed):
			spawner.wave_completed.connect(room_generator._on_wave_completed)
			print("✅ Connected wave_completed signal!")
		else:
			print("ℹ️ wave_completed signal already connected, skipping...")
	
	# Give spawner the starting room
	if room_generator.has_method("get_rooms"):
		var rooms = room_generator.get_rooms()
		if rooms.size() > 0:
			spawner.set_newest_spawning_room(rooms[0])
			print("🏠 Set starting room for spawner")
	
	print("✅ Wave system integration complete!")
	
	# Start the wave system
	if spawner.has_method("start_wave_system"):
		spawner.start_wave_system()
		print("🚀 Started wave progression system!")

func _check_system_status():
	var room_gen = get_node_or_null("SimpleRoomGenerator")
	var spawner = get_node_or_null("EnemySpawner")
	var player = get_tree().get_first_node_in_group("player")
	var enemies = get_tree().get_nodes_in_group("enemies")
	if not room_gen:
		print("❌ No room generator found!")
	if not spawner:
		print("❌ No spawner found!")
	if not player:
		print("❌ No player found!")
	if spawner and spawner.has_method("get_wave_info"):
		var wave_info = spawner.get_wave_info()
		var is_spawning = wave_info.get("is_spawning", false)
		var wave_active = wave_info.get("wave_active", false)
		if not is_spawning and not wave_active and enemies.size() == 0:
			print("🚨 Spawner exists but isn't working!")
	else:
		print("🚨 Spawner missing methods!")
