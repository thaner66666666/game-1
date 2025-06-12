# loot_manager.gd - FIXED: Proper physics-based loot dropping
extends Node

# Load our loot scene files
@export var coin_scene: PackedScene = preload("res://Scenes/Coin.tscn")
@export var health_potion_scene: PackedScene = preload("res://Scenes/health_potion.tscn")
@export var xp_orb_scene: PackedScene = preload("res://Scenes/xp_orb.tscn")
@export var weapon_scene: PackedScene  # Changed from preload to export var
@export var weapon_pickup_scene: PackedScene = preload("res://Scenes/weapon_pickup.tscn")

# Loot drop configurations
@export var enemy_loot_config = {
	"coin": {
		"drop_chance": 0.7,
		"amount_min": 8,
		"amount_max": 15
	},
	"health_potion": {
		"drop_chance": 0.2,
		"heal_amount": 30
	},
	"xp_orb": {
		"drop_chance": 1.0,
		"xp_amount_min": 8,
		"xp_amount_max": 15
	},
	"weapon": {
		"drop_chance": 0.05,  # 5% chance for weapons from enemies
		"avoid_duplicates": true
	}
}

@export var chest_loot_config = {
	"coin": {
		"drop_chance": 1.0,
		"amount_min": 200,  # Massively increased from 50
		"amount_max": 500   # Massively increased from 100
	},
	"health_potion": {
		"drop_chance": 1.0,
		"heal_amount": 75    # Keeping this the same
	},
	"xp_orb": {
		"drop_chance": 1.0,
		"xp_amount_min": 150,  # Massively increased from 40
		"xp_amount_max": 300   # Massively increased from 60
	},
	"weapon": {
		"drop_chance": 0.8,  # 80% chance for weapons from chests
		"avoid_duplicates": true
	}
}

@export var destructible_loot_config = {
	"crate": {
		"coin_chance": 0.8,
		"coin_min": 1,
		"coin_max": 3,
		"health_potion_chance": 0.15,
		"weapon_chance": 0.005
	},
	"barrel": {
		"coin_chance": 0.9,
		"coin_min": 2,
		"coin_max": 5,
		"health_potion_chance": 0.2,
		"weapon_chance": 0.01
	}
}

# FIXED: Simple physics settings
@export var launch_force_min = 2
@export var launch_force_max = 4
@export var upward_force = 5
@export var pickup_delay = 0.2  # Reduced from 1.0 to 0.2 seconds
@export var spread_radius = 5

func _ready():
	add_to_group("loot_manager")
	print("💎 Loot Manager: Ready with proper physics dropping!")

func drop_enemy_loot(position: Vector3, enemy_node: Node = null):
	"""Drop loot from a dead enemy with proper physics"""
	print("💎 Dropping enemy loot at: ", position)
	
	var config = enemy_loot_config
	var parent_node = _get_drop_parent(enemy_node)
	if not parent_node:
		return
	
	# Check for rare weapon drop
	if randf() <= config["weapon"]["drop_chance"]:
		_drop_weapon_with_physics(position, parent_node)
	
	# Regular loot drops
	for loot_type in config.keys():
		if loot_type == "weapon":
			continue
		var loot_data = config[loot_type]
		var drop_chance = loot_data.get("drop_chance", 0.0)
		if randf() <= drop_chance:
			_create_physics_loot_item(loot_type, loot_data, position, parent_node)

func drop_chest_loot(position: Vector3, chest_node: Node = null):
	"""Drop loot from a treasure chest with proper physics"""
	print("💎 Dropping chest loot at: ", position)
	
	var config = chest_loot_config
	var parent_node = _get_drop_parent(chest_node)
	if not parent_node:
		return
	
	# Handle weapons first
	if randf() <= config["weapon"]["drop_chance"]:
		_drop_weapon_with_physics(position, parent_node)
	
	# Special handling for coins and XP orbs - spawn multiple instances
	if randf() <= config["coin"]["drop_chance"]:
		var total_coins = randi_range(config["coin"]["amount_min"], config["coin"]["amount_max"])
		var coins_per_stack = 25  # Break into smaller stacks for better visual effect
		while total_coins > 0:
			var stack_size = mini(coins_per_stack, total_coins)
			var coin_data = config["coin"].duplicate()
			coin_data["amount_min"] = stack_size
			coin_data["amount_max"] = stack_size
			_create_physics_loot_item("coin", coin_data, position, parent_node)
			total_coins -= stack_size
	
	if randf() <= config["xp_orb"]["drop_chance"]:
		var total_xp = randi_range(config["xp_orb"]["xp_amount_min"], config["xp_orb"]["xp_amount_max"])
		var xp_per_orb = 30  # Break into smaller orbs for better visual effect
		while total_xp > 0:
			var orb_size = mini(xp_per_orb, total_xp)
			var orb_data = config["xp_orb"].duplicate()
			orb_data["xp_amount_min"] = orb_size
			orb_data["xp_amount_max"] = orb_size
			_create_physics_loot_item("xp_orb", orb_data, position, parent_node)
			total_xp -= orb_size
	
	# Health potion remains as single item
	if randf() <= config["health_potion"]["drop_chance"]:
		_create_physics_loot_item("health_potion", config["health_potion"], position, parent_node)

func drop_destructible_loot(position: Vector3, object_type: String):
	"""Handle drops from destructible objects with physics"""
	print("💥 Dropping loot from destroyed ", object_type)
	
	var config = destructible_loot_config[object_type]
	
	# Handle coin drops
	if randf() <= config.coin_chance:
		var coin_count = randi_range(config.coin_min, config.coin_max)
		for i in range(coin_count):
			_create_physics_loot_item("coin", {"amount_min": 1, "amount_max": 1}, position, get_parent())
	
	# Handle health potion
	if randf() <= config.health_potion_chance:
		_create_physics_loot_item("health_potion", {"heal_amount": 30}, position, get_parent())
	
	# Handle weapon drops
	if randf() <= config.weapon_chance and has_method("drop_weapon"):
		drop_weapon(position)

func drop_weapon(position: Vector3, weapon_resource: WeaponResource = null):
	"""Drop a weapon with physics, optionally with a specific weapon_resource"""
	if not weapon_scene:
		print("⚠ Warning: No weapon scene assigned!")
		return

	# Load the scene now in case it was assigned after initialization
	if not weapon_scene.is_loaded():
		if ResourceLoader.exists(weapon_scene.resource_path):
			print("🔄 Loading weapon scene...")
			await weapon_scene.load()
		else:
			print("❌ Weapon scene resource not found!")
			return

	var weapon_pickup = weapon_scene.instantiate()
	var parent = get_tree().current_scene
	parent.add_child(weapon_pickup)

	# Assign the correct weapon resource if provided
	if weapon_resource and weapon_pickup.has_method("set_weapon_resource"):
		weapon_pickup.set_weapon_resource(weapon_resource)

	# Apply random weapon properties here if needed
	if weapon_pickup.has_method("randomize_properties") and not weapon_resource:
		weapon_pickup.randomize_properties()

	# Apply physics launch
	_launch_with_physics(weapon_pickup, position)

func _get_drop_parent(source_node: Node) -> Node:
	if source_node and source_node.get_parent():
		return source_node.get_parent()
	return get_tree().current_scene

func _create_physics_loot_item(loot_type: String, loot_data: Dictionary, position: Vector3, parent: Node):
	"""Create loot item with proper physics launch"""
	
	match loot_type:
		"coin":
			_create_physics_coin(loot_data, position, parent)
		"health_potion":
			_create_physics_health_potion(loot_data, position, parent)
		"xp_orb":
			_create_physics_xp_orb(loot_data, position, parent)

func _create_physics_coin(loot_data: Dictionary, position: Vector3, parent: Node):
	"""Create coin with physics launch"""
	if not coin_scene:
		return
	
	var coin = coin_scene.instantiate()
	parent.add_child(coin)
	
	# Set coin value
	var amount_min = loot_data.get("amount_min", 10)
	var amount_max = loot_data.get("amount_max", 10)
	var coin_amount = randi_range(amount_min, amount_max)
	
	if coin.has_method("set_coin_value"):
		coin.set_coin_value(coin_amount)
	
	# Apply physics launch
	_launch_with_physics(coin, position)

func _create_physics_health_potion(loot_data: Dictionary, position: Vector3, parent: Node):
	"""Create health potion with physics launch"""
	if not health_potion_scene:
		return
	
	var potion = health_potion_scene.instantiate()
	parent.add_child(potion)
	
	# Set heal amount
	var heal_amount = loot_data.get("heal_amount", 30)
	if potion.has_method("set_heal_amount"):
		potion.set_heal_amount(heal_amount)
	
	# Apply physics launch
	_launch_with_physics(potion, position)

func _create_physics_xp_orb(loot_data: Dictionary, position: Vector3, parent: Node):
	"""Create XP orb with physics launch"""
	if not xp_orb_scene:
		return
	
	var orb = xp_orb_scene.instantiate()
	parent.add_child(orb)
	
	# Set XP value
	var xp_min = loot_data.get("xp_amount_min", 10)
	var xp_max = loot_data.get("xp_amount_max", 10)
	var xp_amount = randi_range(xp_min, xp_max)
	
	if orb.has_method("set_xp_value"):
		orb.set_xp_value(xp_amount)
	
	# Apply physics launch
	_launch_with_physics(orb, position)

func _drop_weapon_with_physics(position: Vector3, parent: Node):
	"""Drop a weapon with physics like coins and potions"""
	if not weapon_pickup_scene:
		print("⚠️ No weapon pickup scene available!")
		return
	
	if not WeaponPool:
		print("⚠️ WeaponPool not available!")
		return
	
	# Get random weapon from pool
	var weapon_resource = WeaponPool.get_random_weapon()
	if not weapon_resource:
		print("⚠️ No weapon available from pool!")
		return
	
	# Create weapon pickup
	var weapon_pickup = weapon_pickup_scene.instantiate()
	parent.add_child(weapon_pickup)
	
	# Set the weapon resource
	weapon_pickup.set_weapon_resource(weapon_resource)
	# Mark as coming from physics for pickup delay
	weapon_pickup.set_meta("from_physics", true)
	
	# Apply physics launch (same as coins/potions)
	_launch_with_physics(weapon_pickup, position)
	
	print("🗡️ Dropped weapon with physics: ", weapon_resource.weapon_name)

func _launch_with_physics(loot_item: Node, spawn_position: Vector3):
	"""Convert item to RigidBody3D, launch it, then convert back to Area3D"""
	
	# Store original data
	var original_scene_data = _extract_loot_data(loot_item)
	if loot_item.is_in_group("weapon_pickup"):
		original_scene_data["is_weapon"] = true
		original_scene_data["weapon_resource"] = loot_item.weapon_resource
		loot_item.set_meta("from_physics", true)
	
	# Replace with RigidBody3D for physics
	var physics_body = _create_physics_version(loot_item, original_scene_data)
	var parent = loot_item.get_parent()
	loot_item.queue_free()
	parent.add_child(physics_body)
	physics_body.global_position = spawn_position + Vector3(0, 0.5, 0)  # Start slightly above
	
	# Apply random launch force
	var horizontal_direction = Vector3(
		randf_range(-1.0, 1.0),
		0,
		randf_range(-1.0, 1.0)
	).normalized()
	
	var launch_force = randf_range(launch_force_min, launch_force_max)
	var launch_velocity = horizontal_direction * launch_force + Vector3(0, upward_force, 0)
	
	physics_body.linear_velocity = launch_velocity
	
	# Wait for item to settle, then convert back to Area3D for pickup
	_wait_for_settle_and_convert(physics_body, original_scene_data)

func _extract_loot_data(loot_item: Node) -> Dictionary:
	"""Extract important data from the original loot item"""
	var data = {}
	
	# Get visual components
	var mesh_instance = loot_item.get_node_or_null("CoinMesh")
	if not mesh_instance:
		mesh_instance = loot_item.get_node_or_null("PotionMesh")
	if not mesh_instance:
		mesh_instance = loot_item.get_node_or_null("OrbMesh")
	
	if mesh_instance:
		data["mesh"] = mesh_instance.mesh
		data["material"] = mesh_instance.material_override
		data["scale"] = mesh_instance.scale
	
	# Get metadata
	data["coin_value"] = loot_item.get_meta("coin_value", 0)
	data["heal_amount"] = loot_item.get_meta("heal_amount", 0)
	data["xp_value"] = loot_item.get_meta("xp_value", 0)
	
	# Determine type
	if loot_item.is_in_group("currency"):
		data["type"] = "coin"
	elif loot_item.is_in_group("health_potion"):
		data["type"] = "health_potion"
	elif loot_item.is_in_group("xp_orb"):
		data["type"] = "xp_orb"
	
	return data

func _create_physics_version(_original_item: Node, data: Dictionary) -> RigidBody3D:
	"""Create a RigidBody3D version for physics simulation"""
	var physics_body = RigidBody3D.new()
	physics_body.name = "PhysicsLoot"

	# Set up collision layers: layer 8 for loot, mask 1 for terrain/walls only
	physics_body.collision_layer = 1 << 7  # Layer 8 (bit 7)
	physics_body.collision_mask = 1 << 0   # Mask 1 (bit 0)

	# Set up physics properties
	physics_body.mass = 0.1
	physics_body.gravity_scale = 1.0
	physics_body.linear_damp = 0.5  # Some air resistance
	physics_body.angular_damp = 0.8  # Reduce spinning

	# Create visual mesh
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = data.get("mesh")
	mesh_instance.material_override = data.get("material")
	mesh_instance.scale = data.get("scale", Vector3.ONE)
	physics_body.add_child(mesh_instance)

	# Create collision shape based on mesh type
	var collision = CollisionShape3D.new()
	if data.get("type") == "coin":
		var cylinder_shape = CylinderShape3D.new()
		cylinder_shape.height = 0.1
		cylinder_shape.radius = 0.2
		collision.shape = cylinder_shape
	else:
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = 0.18
		collision.shape = sphere_shape

	physics_body.add_child(collision)

	# Store the original data for later conversion
	physics_body.set_meta("loot_data", data)

	return physics_body

func _wait_for_settle_and_convert(physics_body: RigidBody3D, original_data: Dictionary):
	"""Wait for physics body to settle, then convert back to pickup Area3D"""
	
	# Shorter initial wait
	await get_tree().create_timer(0.3).timeout  # Reduced from 1.5
	
	# Check if item has mostly stopped moving
	var settle_check_timer = 0.0
	var max_settle_time = 1.0  # Reduced from 3.0
	
	while settle_check_timer < max_settle_time:
		if not is_instance_valid(physics_body):
			return
		
		var velocity = physics_body.linear_velocity
		if velocity.length() < 0.5:  # Mostly stopped
			break
		
		await get_tree().create_timer(0.1).timeout
		settle_check_timer += 0.1
	
	# Convert back to pickup item
	_convert_to_pickup_item(physics_body, original_data)

func _convert_to_pickup_item(physics_body: RigidBody3D, data: Dictionary):
	"""Convert physics body back to pickup-able Area3D"""
	
	if not is_instance_valid(physics_body):
		return
	
	var final_position = physics_body.global_position
	var parent = physics_body.get_parent()
	
	# Create the proper pickup item based on type
	var pickup_item: Area3D
	
	match data.get("type"):
		"coin":
			pickup_item = coin_scene.instantiate()
			if pickup_item.has_method("set_coin_value"):
				pickup_item.set_coin_value(data.get("coin_value", 1))  # Changed from 10 to 1
		"health_potion":
			pickup_item = health_potion_scene.instantiate()
			if pickup_item.has_method("set_heal_amount"):
				pickup_item.set_heal_amount(data.get("heal_amount", 30))
		"xp_orb":
			pickup_item = xp_orb_scene.instantiate()
			if pickup_item.has_method("set_xp_value"):
				pickup_item.set_xp_value(data.get("xp_value", 10))
		_:
			pass
	# Weapon pickup handling
	if data.get("is_weapon", false):
		pickup_item = weapon_pickup_scene.instantiate()
		if pickup_item.has_method("set_weapon_resource"):
			pickup_item.set_weapon_resource(data.get("weapon_resource"))
		pickup_item.set_meta("from_physics", true)
	
	if pickup_item:
		# Remove physics body and add pickup item
		physics_body.queue_free()
		parent.add_child(pickup_item)
		pickup_item.global_position = final_position
		
		# Disable pickup for the delay period
		pickup_item.set_meta("pickup_disabled", true)
		
		# Create visual indicator
		if pickup_item.has_method("_create_pickup_delay_effect"):
			pickup_item._create_pickup_delay_effect(pickup_delay)
		
		# Enable pickup after delay
		await get_tree().create_timer(pickup_delay).timeout
		
		if is_instance_valid(pickup_item):
			pickup_item.set_meta("pickup_disabled", false)
			print("✅ Loot item ready for pickup!")
