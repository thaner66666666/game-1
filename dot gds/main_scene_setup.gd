# main_scene_setup.gd - FIXED: Prevents double spawning issue
extends Node3D

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
	"""Create simple lighting"""
	var light = DirectionalLight3D.new()
	light.name = "MainLight"
	light.light_energy = 1.2
	light.position = Vector3(0, 15, 10)
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.shadow_enabled = true
	add_child(light)
	
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_energy = 0.4
	env.ambient_light_color = Color.WHITE
	
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

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
	"""Setup spawner to work with the newest room system"""
	await get_tree().create_timer(1.0).timeout
	
	if room_generator.has_method("get_rooms"):
		var rooms = room_generator.get_rooms()
		if rooms.size() > 0:
			var newest_room = rooms[rooms.size() - 1]  # Get the last (newest) room
			
			print("🎯 Setting spawner to newest room: ", newest_room)
			
			# Give spawner the newest room as the spawning area
			if spawner.has_method("set_newest_spawning_room"):
				spawner.set_newest_spawning_room(newest_room)
			elif spawner.has_method("set_room_boundaries"):
				var room_bounds = {
					"rect": newest_room,
					"map_size": Vector2(60, 60)
				}
				spawner.set_room_boundaries(room_bounds)
			
			# Start the wave system
			if spawner.has_method("start_wave_system"):
				spawner.start_wave_system()
			
			print("✅ Spawner setup complete with newest room focus!")

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
