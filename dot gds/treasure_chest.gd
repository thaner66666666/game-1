# treasure_chest.gd - Fantasy treasure chest with opening lid and floating text
extends StaticBody3D

@export var coins_min = 25
@export var coins_max = 50
@export var health_potion_chance = 0.8
@export var xp_orb_min = 25
@export var xp_orb_max = 40

var is_opened = false
var player_in_range = false
var player: Node3D

# Visual components
var chest_base: MeshInstance3D
var chest_lid: MeshInstance3D
var interaction_area: Area3D
var floating_text: Label3D
var lid_hinge_point: Node3D

# Materials
var wood_material: StandardMaterial3D
var metal_material: StandardMaterial3D
var gem_material: StandardMaterial3D

func _ready():
	print("💎 Fantasy Treasure Chest: Setting up...")
	_create_materials()
	_create_fantasy_chest()
	_setup_interaction_area()
	_create_floating_text()
	_find_player()

func _create_materials():
	"""Create fantasy-themed materials"""
	# Rich wooden material
	wood_material = StandardMaterial3D.new()
	wood_material.albedo_color = Color(0.4, 0.25, 0.1)  # Rich dark wood
	wood_material.roughness = 0.8
	wood_material.metallic = 0.0
	
	# Ornate metal material
	metal_material = StandardMaterial3D.new()
	metal_material.albedo_color = Color(0.8, 0.6, 0.2)  # Golden metal
	metal_material.roughness = 0.2
	metal_material.metallic = 0.9
	metal_material.emission_enabled = true
	metal_material.emission = Color(0.4, 0.3, 0.1) * 0.2  # Subtle golden glow
	
func _create_fantasy_chest():
	"""Create a proper fantasy treasure chest with hollow interior"""
	# Move the entire chest up off the ground
	global_position.y += 2.0
	# === HOLLOW CHEST BASE ===
	chest_base = MeshInstance3D.new()
	chest_base.name = "ChestBase"
	add_child(chest_base)
	chest_base.position = Vector3(0, 0, 0)

	# Create hollow base with separate walls
	_create_base_walls()

	# === CHEST LID (with hinge point) ===
	lid_hinge_point = Node3D.new()
	lid_hinge_point.name = "LidHinge"
	add_child(lid_hinge_point)
	lid_hinge_point.position = Vector3(0, 0.6, -0.4)  # Back edge for hinge

	# Create hollow lid with separate walls
	_create_lid_walls()

	# === METAL CORNER REINFORCEMENTS ===
	var corner_positions = [
		Vector3(-0.55, 0.1, -0.35), Vector3(0.55, 0.1, -0.35),  # Front bottom
		Vector3(-0.55, 0.5, -0.35), Vector3(0.55, 0.5, -0.35),  # Front top
		Vector3(-0.55, 0.1, 0.35), Vector3(0.55, 0.1, 0.35),    # Back bottom
		Vector3(-0.55, 0.5, 0.35), Vector3(0.55, 0.5, 0.35)     # Back top
	]
	
	for pos in corner_positions:
		var corner = MeshInstance3D.new()
		var corner_mesh = BoxMesh.new()
		corner_mesh.size = Vector3(0.08, 0.08, 0.08)
		corner.mesh = corner_mesh
		corner.material_override = metal_material
		corner.position = pos
		add_child(corner)
	
	# === METAL BANDS (horizontal stripes) ===
	for band_y in [0.15, 0.45]:
		var band = MeshInstance3D.new()
		var band_mesh = BoxMesh.new()
		band_mesh.size = Vector3(1.25, 0.06, 0.85)
		band.mesh = band_mesh
		band.material_override = metal_material
		band.position = Vector3(0, band_y, 0)
		add_child(band)
	
	# === ORNATE LOCK (front center) ===
	var lock_base = MeshInstance3D.new()
	var lock_mesh = BoxMesh.new()
	lock_mesh.size = Vector3(0.15, 0.2, 0.08)
	lock_base.mesh = lock_mesh
	lock_base.material_override = metal_material
	lock_base.position = Vector3(0, 0.3, -0.45)
	add_child(lock_base)
	
	# === CHEST FEET ===
	var feet_positions = [
		Vector3(-0.5, -0.02, -0.3), Vector3(0.5, -0.02, -0.3),
		Vector3(-0.5, -0.02, 0.3), Vector3(0.5, -0.02, 0.3)
	]
	
	for pos in feet_positions:
		var foot = MeshInstance3D.new()
		var foot_mesh = CylinderMesh.new()
		foot_mesh.top_radius = 0.08
		foot_mesh.bottom_radius = 0.1
		foot_mesh.height = 0.1
		foot.mesh = foot_mesh
		foot.material_override = metal_material
		foot.position = pos
		add_child(foot)
	
	# === COLLISION ===
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.2, 0.6, 0.8)
	collision.shape = shape
	collision.position = Vector3(0, 0.3, 0)
	add_child(collision)

func _create_base_walls():
	"""Create hollow base with separate wall pieces"""
	var wall_thickness = 0.08
	
	# Bottom
	var bottom = MeshInstance3D.new()
	var bottom_mesh = BoxMesh.new()
	bottom_mesh.size = Vector3(1.2, wall_thickness, 0.8)
	bottom.mesh = bottom_mesh
	bottom.material_override = wood_material
	bottom.position = Vector3(0, wall_thickness/2, 0)
	chest_base.add_child(bottom)
	
	# Front wall
	var front = MeshInstance3D.new()
	var front_mesh = BoxMesh.new()
	front_mesh.size = Vector3(1.2, 0.6, wall_thickness)
	front.mesh = front_mesh
	front.material_override = wood_material
	front.position = Vector3(0, 0.3, -0.4 + wall_thickness/2)
	chest_base.add_child(front)
	
	# Back wall
	var back = MeshInstance3D.new()
	var back_mesh = BoxMesh.new()
	back_mesh.size = Vector3(1.2, 0.6, wall_thickness)
	back.mesh = back_mesh
	back.material_override = wood_material
	back.position = Vector3(0, 0.3, 0.4 - wall_thickness/2)
	chest_base.add_child(back)
	
	# Left wall
	var left = MeshInstance3D.new()
	var left_mesh = BoxMesh.new()
	left_mesh.size = Vector3(wall_thickness, 0.6, 0.8 - 2*wall_thickness)
	left.mesh = left_mesh
	left.material_override = wood_material
	left.position = Vector3(-0.6 + wall_thickness/2, 0.3, 0)
	chest_base.add_child(left)
	
	# Right wall
	var right = MeshInstance3D.new()
	var right_mesh = BoxMesh.new()
	right_mesh.size = Vector3(wall_thickness, 0.6, 0.8 - 2*wall_thickness)
	right.mesh = right_mesh
	right.material_override = wood_material
	right.position = Vector3(0.6 - wall_thickness/2, 0.3, 0)
	chest_base.add_child(right)

func _create_lid_walls():
	"""Create hollow lid with separate wall pieces"""
	chest_lid = MeshInstance3D.new()
	chest_lid.name = "ChestLid"
	lid_hinge_point.add_child(chest_lid)
	chest_lid.position = Vector3(0, 0.15, 0.4)
	
	var wall_thickness = 0.08
	
	# Top
	var top = MeshInstance3D.new()
	var top_mesh = BoxMesh.new()
	top_mesh.size = Vector3(1.2, wall_thickness, 0.8)
	top.mesh = top_mesh
	top.material_override = wood_material
	top.position = Vector3(0, 0.15 - wall_thickness/2, 0)
	chest_lid.add_child(top)
	
	# Front wall
	var front = MeshInstance3D.new()
	var front_mesh = BoxMesh.new()
	front_mesh.size = Vector3(1.2, 0.3, wall_thickness)
	front.mesh = front_mesh
	front.material_override = wood_material
	front.position = Vector3(0, 0, -0.4 + wall_thickness/2)
	chest_lid.add_child(front)
	
	# Back wall
	var back = MeshInstance3D.new()
	var back_mesh = BoxMesh.new()
	back_mesh.size = Vector3(1.2, 0.3, wall_thickness)
	back.mesh = back_mesh
	back.material_override = wood_material
	back.position = Vector3(0, 0, 0.4 - wall_thickness/2)
	chest_lid.add_child(back)
	
	# Left wall
	var left = MeshInstance3D.new()
	var left_mesh = BoxMesh.new()
	left_mesh.size = Vector3(wall_thickness, 0.3, 0.8 - 2*wall_thickness)
	left.mesh = left_mesh
	left.material_override = wood_material
	left.position = Vector3(-0.6 + wall_thickness/2, 0, 0)
	chest_lid.add_child(left)
	
	# Right wall
	var right = MeshInstance3D.new()
	var right_mesh = BoxMesh.new()
	right_mesh.size = Vector3(wall_thickness, 0.3, 0.8 - 2*wall_thickness)
	right.mesh = right_mesh
	right.material_override = wood_material
	right.position = Vector3(0.6 - wall_thickness/2, 0, 0)
	chest_lid.add_child(right)

func _setup_interaction_area():
	"""Setup area for player interaction"""
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	add_child(interaction_area)
	
	var area_collision = CollisionShape3D.new()
	var area_shape = SphereShape3D.new()
	area_shape.radius = 2.5
	area_collision.shape = area_shape
	interaction_area.add_child(area_collision)
	
	interaction_area.collision_layer = 0
	interaction_area.collision_mask = 1
	
	interaction_area.body_entered.connect(_on_player_entered)
	interaction_area.body_exited.connect(_on_player_exited)

func _create_floating_text():
	"""Create beautiful floating interaction text"""
	floating_text = Label3D.new()
	floating_text.name = "FloatingText"
	floating_text.text = "Press E to Open"
	floating_text.position = Vector3(0, 1.2, 0)  # Float above chest
	floating_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	floating_text.no_depth_test = true
	floating_text.modulate = Color(1.0, 0.9, 0.4, 0.9)  # Golden color
	floating_text.outline_modulate = Color(0.2, 0.1, 0.0, 1.0)  # Dark outline
	floating_text.font_size = 48
	floating_text.outline_size = 8
	floating_text.visible = false  # Hidden by default
	add_child(floating_text)
	
	# Add gentle floating animation
	_animate_floating_text()

func _animate_floating_text():
	"""Create gentle floating animation for text"""
	var tween = create_tween()
	tween.set_loops()
	tween.set_parallel(true)
	
	# Gentle up and down movement
	var start_y = floating_text.position.y
	tween.tween_property(floating_text, "position:y", start_y + 0.1, 1.5)
	tween.tween_property(floating_text, "position:y", start_y - 0.1, 1.5).set_delay(1.5)
	
	# Gentle glow pulsing
	tween.tween_property(floating_text, "modulate:a", 1.0, 1.0)
	tween.tween_property(floating_text, "modulate:a", 0.7, 1.0).set_delay(1.0)

func _find_player():
	"""Find the player"""
	player = get_tree().get_first_node_in_group("player")

func _on_player_entered(body):
	"""Player entered interaction range"""
	if body.is_in_group("player") and not is_opened:
		player_in_range = true
		floating_text.visible = true
		print("💎 Press E to open treasure chest!")

func _on_player_exited(body):
	"""Player left interaction range"""
	if body.is_in_group("player"):
		player_in_range = false
		floating_text.visible = false

func _input(event):
	"""Handle interaction input"""
	if event.is_action_pressed("interaction") and player_in_range and not is_opened:
		_open_chest()

func _open_chest():
	"""Open the chest with dramatic lid animation"""
	if is_opened:
		return
	
	is_opened = true
	print("💎 FANTASY TREASURE CHEST OPENED!")
	
	# Hide interaction text
	floating_text.visible = false
	
	# Create dramatic opening animation
	_create_opening_animation()
	
	# Spawn loot after a short delay
	get_tree().create_timer(0.8).timeout.connect(_spawn_chest_loot)

func _create_opening_animation():
	"""Dramatic chest opening with lid rotation and effects"""
	if not lid_hinge_point or not chest_lid:
		return
	
	# Create opening tween
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Rotate lid open (around the hinge point)
	tween.tween_property(lid_hinge_point, "rotation_degrees:x", -85.0, 1.2)
	
	# Make the whole chest bounce slightly
	var original_pos = position
	tween.tween_property(self, "position:y", original_pos.y + 0.1, 0.3)
	tween.tween_property(self, "position:y", original_pos.y, 0.3).set_delay(0.3)
	
	# Change materials to "opened" state
	await get_tree().create_timer(0.5).timeout
	_apply_opened_materials()

func _apply_opened_materials():
	"""Change materials to show chest is opened"""
	# Make wood slightly lighter
	var opened_wood = wood_material.duplicate()
	opened_wood.albedo_color = Color(0.5, 0.35, 0.2)
	opened_wood.emission_enabled = true
	opened_wood.emission = Color(0.3, 0.2, 0.1) * 0.1
	
	# Apply to all base wall pieces
	if chest_base:
		for child in chest_base.get_children():
			if child is MeshInstance3D:
				child.material_override = opened_wood
	
	# Apply to all lid wall pieces
	if chest_lid:
		for child in chest_lid.get_children():
			if child is MeshInstance3D:
				child.material_override = opened_wood

func _spawn_chest_loot():
	"""Spawn loot using the autoload loot manager with BOUNCY physics!"""
	print("💎 Treasure chest opening - spawning BOUNCY loot!")
	
	if LootManager:
		LootManager.drop_chest_loot(global_position, self)
		print("✅ Called LootManager.drop_chest_loot()")
	else:
		print("❌ LootManager autoload not found!")

# Example function to determine if an item should spawn
func shouldSpawnItem(chance = 0.1) -> bool:
	return randf() < chance

# When spawning an enemy or chest
func spawnEnemy():
	var enemy = {} # ...enemy properties...
	if shouldSpawnItem():
		enemy.item = getRandomItem() # Assign a random item/weapon
	return enemy

func spawnChest():
	var chest = {} # ...chest properties...
	if shouldSpawnItem():
		chest.item = getRandomItem()
	return chest

# Example random item function
func getRandomItem():
	var items = ['Sword', 'Shield', 'Potion']
	return items[randi() % items.size()]
