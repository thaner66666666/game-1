extends CharacterBody3D

func bake_character_in_editor():
	"""Call this function to bake character in editor"""
	if not Engine.is_editor_hint():
		return
	print("🔥 Baking character in editor...")
	# Generate random character
	var config = CharacterGenerator.generate_random_character_config()
	# Bake the character parts
	_bake_hands_to_scene(config)
	_bake_feet_to_scene(config)
	_update_body_in_scene(config)
	print("✅ Character baked! Save the scene to keep changes.")

func _bake_hands_to_scene(config: Dictionary):
	"""Bake hands directly into the scene anchors"""
	var hands_cfg = config.get("hands", {})
	var size = hands_cfg.get("size", 0.08)
	for side in ["Left", "Right"]:
		var anchor = get_node_or_null(side + "HandAnchor")
		if not anchor:
			continue
		# Remove existing hand if any
		var existing_hand = anchor.get_node_or_null(side + "Hand")
		if existing_hand:
			existing_hand.queue_free()
		# Create new hand
		var hand = MeshInstance3D.new()
		hand.name = side + "Hand"
		hand.owner = get_tree().edited_scene_root
		var mesh = BoxMesh.new()
		mesh.size = Vector3(size * 2.5, size * 1.5, size * 2.5)
		hand.mesh = mesh
		hand.rotation_degrees = Vector3(0, 0, 90)
		# Apply material
		var material = StandardMaterial3D.new()
		material.albedo_color = config.get("skin_tone", Color(0.9, 0.7, 0.6))
		material.roughness = 0.7
		hand.material_override = material
		anchor.add_child(hand)
		print("✅ Baked ", side, "Hand")

func _bake_feet_to_scene(config: Dictionary):
	"""Bake feet as children of player"""
	var foot_size = Vector3(0.15, 0.06, 0.25)
	# Remove existing feet
	for side in ["Left", "Right"]:
		var existing_foot = get_node_or_null(side + "Foot")
		if existing_foot:
			existing_foot.queue_free()
	for i in [-1, 1]:
		var foot = MeshInstance3D.new()
		foot.name = "LeftFoot" if i < 0 else "RightFoot"
		foot.owner = get_tree().edited_scene_root
		var mesh = BoxMesh.new()
		mesh.size = Vector3(foot_size.x * 1.7, foot_size.y * 2.5, foot_size.z * 1.7)
		foot.mesh = mesh
		foot.position = Vector3(i * 0.25, -1.05 + 0.2 - 0.05, 0)
		foot.scale = Vector3(0.85 * 0.75, 0.85, 0.85)
		var material = StandardMaterial3D.new()
		material.albedo_color = config.get("skin_tone", Color(0.9, 0.7, 0.6))
		material.roughness = 0.7
		foot.material_override = material
		add_child(foot)
		print("✅ Baked ", foot.name)

func _update_body_in_scene(config: Dictionary):
	"""Update the existing body mesh"""
	var body_mesh_instance = get_node_or_null("MeshInstance3D")
	if not body_mesh_instance:
		return
	# Create body mesh
	var capsule_mesh = CapsuleMesh.new()
	capsule_mesh.radius = config.get("body_radius", 0.3)
	capsule_mesh.height = config.get("body_height", 1.5)
	body_mesh_instance.mesh = capsule_mesh
	# Apply skin material
	var material = StandardMaterial3D.new()
	material.albedo_color = config.get("skin_tone", Color(0.9, 0.7, 0.6))
	material.roughness = 0.7
	body_mesh_instance.material_override = material
	print("✅ Updated body")

# --- Inspector Properties ---
@export_group("Movement")
@export var speed := 5.0
@export var dash_distance := 4.0
@export var dash_duration := 0.3
@export var dash_cooldown := 5.0

@export_group("Combat")
@export var attack_range := 2.0
@export var attack_damage := 10
@export var attack_cooldown := 1.0
@export var attack_cone_angle := 90.0

@export_group("Health")
@export var max_health := 100
@export var health_regen_rate := 2.0
@export var health_regen_delay := 3.0

@export_group("Knockback")
@export var knockback_force := 12.0
@export var knockback_duration := 0.6

@export_group("Dash")
@export var max_dash_charges := 1

@export_group("Experience")
@export var heal_amount_from_potion := 30

@export_group("Animation")
@export var body_lean_strength: float = 0.15
@export var body_sway_strength: float = 0.50
@export var hand_swing_strength: float = 1.0
@export var foot_step_strength: float = 0.10
@export var side_step_modifier: float = 0.4

# --- Node References (using @onready for caching) ---
var left_foot: MeshInstance3D
var right_foot: MeshInstance3D

@onready var movement_component: PlayerMovement = $MovementComponent
@onready var combat_component: PlayerCombat = $CombatComponent
@onready var sword_node: MeshInstance3D = $WeaponAttachPoint/SwordNode
@onready var health_component = $HealthComponent
@onready var progression_component: PlayerProgression = $ProgressionComponent

# Weapon system variables
var weapon_attach_point: Node3D = null
var equipped_weapon_mesh: MeshInstance3D = null

# Base stats for weapon system
var base_attack_damage := 10
var base_attack_range := 2.0
var base_attack_cooldown := 1.0
var base_attack_cone_angle := 90.0

# Player state
var is_dead := false
var nearby_weapon_pickup = null

# --- Health System Component ---
# Removed duplicate declaration of health_component

# Mouse look system
var camera: Camera3D = null
var mouse_position_3d: Vector3

# Visual components
var mesh_instance: MeshInstance3D

# --- FEET ANIMATION SYSTEM ---
var left_foot_original_pos: Vector3
var right_foot_original_pos: Vector3
var left_foot_planted_pos: Vector3
var right_foot_planted_pos: Vector3
var left_foot_is_moving := false
var right_foot_is_moving := false
var left_foot_step_progress := 1.0
var right_foot_step_progress := 1.0

# Visual effects
# var invulnerability_timer := 0.0
# const INVULNERABILITY_DURATION := 0.5

# Node references (cached in _ready)
var attack_area: Area3D

# Constants
const FRICTION_MULTIPLIER := 3.0
const MOVEMENT_THRESHOLD := 0.1

# Signals
signal dash_charges_changed(current_charges: int, max_charges: int)
signal coin_collected(amount: int)
signal xp_changed(xp: int, xp_to_next: int, level: int)

# --- Eye Blinking System ---
var blink_timer := 0.0
var blink_interval := 0.0
const BLINK_MIN_INTERVAL := 2.0
const BLINK_MAX_INTERVAL := 6.0
const BLINK_DURATION := 0.12
var is_blinking := false
var next_blink_time := 0.0

func _on_dash_charges_changed(current_charges: int, max_charges: int):
	dash_charges_changed.emit(current_charges, max_charges)  # Re-emit for UI

func _ready():
	_setup_player()
	# Initialize components
	if movement_component and movement_component.has_method("initialize"):
		movement_component.initialize(self)
	if combat_component and combat_component.has_method("initialize"):
		combat_component.initialize(self, movement_component)
	# Health system setup
	health_component.setup(self, max_health)
	health_component.health_changed.connect(_on_health_changed)
	health_component.player_died.connect(_on_player_died)
	health_component.health_depleted.connect(_on_health_depleted)
	# Progression system setup
	progression_component.setup(self)
	progression_component.coin_collected.connect(_on_coin_collected)
	progression_component.xp_changed.connect(_on_xp_changed)
	# Pass animation settings to movement_component if supported
	if movement_component and movement_component.has_method("set_animation_settings"):
		movement_component.set_animation_settings({
			"body_lean_strength": body_lean_strength,
			"body_sway_strength": body_sway_strength,
			"hand_swing_strength": hand_swing_strength,
			"foot_step_strength": foot_step_strength,
			"side_step_modifier": side_step_modifier
		})
	# Consolidated signal connections
	if movement_component:
		movement_component.dash_charges_changed.connect(_on_dash_charges_changed)
		movement_component.hand_animation_update.connect(_on_hand_animation_update)
		movement_component.foot_animation_update.connect(_on_foot_animation_update)
		movement_component.animation_state_changed.connect(_on_animation_state_changed)
		movement_component.body_animation_update.connect(_on_body_animation_update)
	if combat_component:
		combat_component.attack_state_changed.connect(_on_combat_attack_state_changed)
	# Initialize blinking system
	_reset_blink_timer()

	# Apply random skin tone to player (character appearance)
	var config = CharacterGenerator.generate_random_character_config()
	CharacterAppearanceManager.create_player_appearance(self, config)
	print("🎨 Player skin tone: ", config["skin_tone"])
	# Removed duplicate/overwriting character creation calls

func _setup_player():
	add_to_group("player")
	_configure_collision()
	_create_visual()
	_setup_attack_system()
	_setup_hand_references()
	_setup_weapon_attach_point()
	_connect_weapon_manager_signals()
	_create_arrow_system()

func _configure_collision():
	collision_layer = 1
	collision_mask = 1

func _create_visual():
	var existing_mesh = get_node_or_null("MeshInstance3D")
	if not existing_mesh:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)
		print("🎨 Created MeshInstance3D node for player")
	else:
		mesh_instance = existing_mesh
		print("🎨 Using existing MeshInstance3D node")
	# Only create MeshInstance3D if it doesn't exist; do not call CharacterAppearanceManager or create_random_character here
	print("✅ Player visual created successfully!")

func _setup_attack_system():
	attack_area = Area3D.new()
	attack_area.name = "AttackArea"
	add_child(attack_area)
	var attack_collision = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = attack_range
	attack_collision.shape = sphere_shape
	attack_area.add_child(attack_collision)
	attack_area.collision_layer = 0
	attack_area.collision_mask = 4
	if not attack_area.is_connected("area_entered", _on_area_pickup_entered):
		attack_area.area_entered.connect(_on_area_pickup_entered)

func _setup_hand_references():
	# --- FEET (find them after character creation) ---
	left_foot = get_node_or_null("LeftFoot")
	right_foot = get_node_or_null("RightFoot")
	if left_foot:
		left_foot_original_pos = left_foot.position
		left_foot_planted_pos = left_foot.position
		print("✅ Found LeftFoot at: ", left_foot.get_path())
	else:
		print("❌ LeftFoot not found!")
	if right_foot:
		right_foot_original_pos = right_foot.position
		right_foot_planted_pos = right_foot.position
		print("✅ Found RightFoot at: ", right_foot.get_path())
	else:
		print("❌ RightFoot not found!")


func _setup_weapon_attach_point():
	# --- WEAPON ATTACH POINT (parent to right hand if possible) ---
	var right_hand = get_node_or_null("RightHand")
	if right_hand:
		# Remove existing WeaponAttachPoint from previous parent if needed
		var wap = right_hand.get_node_or_null("WeaponAttachPoint")
		if not wap:
			weapon_attach_point = Node3D.new()
			weapon_attach_point.name = "WeaponAttachPoint"
			right_hand.add_child(weapon_attach_point)
			print("✅ Created WeaponAttachPoint as child of RightHand")
		else:
			weapon_attach_point = wap
			print("✅ Found existing WeaponAttachPoint under RightHand")
		
		# FIXED: Better positioning and rotation for sword orientation
		weapon_attach_point.position = Vector3(0.0, 0.1, 0.0)  # Slightly up from hand center
		weapon_attach_point.rotation_degrees = Vector3(0, 0, -90)  # Rotate so sword points up instead of sideways
	else:
		# Fallback: add to player root
		weapon_attach_point = get_node_or_null("WeaponAttachPoint")
		if not weapon_attach_point:
			weapon_attach_point = Node3D.new()
			weapon_attach_point.name = "WeaponAttachPoint"
			add_child(weapon_attach_point)
			print("⚠️ Created WeaponAttachPoint at player root (RightHand missing)")
		else:
			print("✅ Found existing WeaponAttachPoint at player root")
		weapon_attach_point.position = Vector3(0.44, -0.2, 0)
		weapon_attach_point.rotation_degrees = Vector3(0, 0, -90)  # Same rotation fix

func _connect_weapon_manager_signals():
	if WeaponManager:
		if not WeaponManager.weapon_equipped.is_connected(_on_weapon_equipped):
			WeaponManager.weapon_equipped.connect(_on_weapon_equipped)
		if not WeaponManager.weapon_unequipped.is_connected(_on_weapon_unequipped):
			WeaponManager.weapon_unequipped.connect(_on_weapon_unequipped)
		print("✅ Connected to WeaponManager signals")
	
	# Show weapon if already equipped at start
	if WeaponManager and WeaponManager.is_weapon_equipped():
		_on_weapon_equipped(WeaponManager.get_current_weapon())

func _on_weapon_equipped(weapon_resource):
	_show_weapon_visual(weapon_resource)

func _on_weapon_unequipped():
	_hide_weapon_visual()

func _show_weapon_visual(weapon_resource):
	_hide_weapon_visual()
	if not weapon_resource or not weapon_attach_point:
		return
	# Only show/hide the existing SwordNode for swords
	match int(weapon_resource.weapon_type):
		int(WeaponResource.WeaponType.SWORD):
			if sword_node:
				sword_node.visible = true
				equipped_weapon_mesh = sword_node
			else:
				print("⚠️ SwordNode not found!")
		int(WeaponResource.WeaponType.BOW):
			# Only show the imported BowNode, do not create a procedural mesh
			var bow_node = weapon_attach_point.get_node_or_null("BowNode")
			if bow_node:
				bow_node.visible = true
				equipped_weapon_mesh = bow_node
			else:
				print("⚠️ BowNode not found!")
				# Don't create any fallback mesh - just use imported model
		int(WeaponResource.WeaponType.STAFF):
			var mesh = _create_simple_staff_mesh()
			if mesh:
				weapon_attach_point.add_child(mesh)
				equipped_weapon_mesh = mesh
		_:
			if sword_node:
				sword_node.visible = true
				equipped_weapon_mesh = sword_node
			else:
				print("⚠️ SwordNode not found!")

func _hide_weapon_visual():
	# Hide the SwordNode if it exists
	if sword_node:
		sword_node.visible = false
	
	# Hide the BowNode if it exists (don't delete it!)
	var bow_node = weapon_attach_point.get_node_or_null("BowNode")
	if bow_node:
		bow_node.visible = false
	
	# Hide the StaffNode if it exists
	var staff_node = weapon_attach_point.get_node_or_null("StaffNode")
	if staff_node:
		staff_node.visible = false
	
	# Only remove dynamically created meshes (not imported scene nodes)
	if (equipped_weapon_mesh and 
		is_instance_valid(equipped_weapon_mesh) and 
		equipped_weapon_mesh != sword_node and 
		equipped_weapon_mesh != bow_node and 
		equipped_weapon_mesh != staff_node):
		equipped_weapon_mesh.queue_free()
	
	equipped_weapon_mesh = null

func _create_simple_sword_mesh() -> MeshInstance3D:
	var sword = MeshInstance3D.new()
	var blade = BoxMesh.new()
	blade.size = Vector3(0.08, 0.7, 0.12)
	sword.mesh = blade
	sword.position = Vector3(0, 0.35, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.8, 1.0)
	mat.metallic = 0.8
	mat.roughness = 0.2
	sword.material_override = mat
	return sword

# func _create_simple_bow_mesh() -> MeshInstance3D:
# 	var bow = MeshInstance3D.new()
# 	var bow_mesh = CylinderMesh.new()
# 	bow_mesh.top_radius = 0.03
# 	bow_mesh.bottom_radius = 0.03
# 	bow_mesh.height = 0.7
# 	bow.mesh = bow_mesh
# 	bow.rotation_degrees = Vector3(0, 0, 90)
# 	bow.position = Vector3(0, 0.35, 0)
# 	var mat = StandardMaterial3D.new()
# 	mat.albedo_color = Color(0.5, 0.3, 0.1)
# 	bow.material_override = mat
# 	return bow

func _create_simple_staff_mesh() -> MeshInstance3D:
	var staff = MeshInstance3D.new()
	var staff_mesh = CylinderMesh.new()
	staff_mesh.top_radius = 0.025
	staff_mesh.bottom_radius = 0.035
	staff_mesh.height = 0.9
	staff.mesh = staff_mesh
	staff.position = Vector3(0, 0.45, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.25, 0.1)
	staff.material_override = mat
	return staff

# Coin/XP pickup system
func _on_area_pickup_entered(area: Area3D):
	if area.is_in_group("health_potion"):
		_pickup_health_potion(area)
	elif area.is_in_group("xp_orb"):
		_pickup_xp_orb(area)
	elif area.is_in_group("currency"):
		_pickup_coin(area)

func _pickup_coin(area: Area3D):
	var coin_value = area.get_meta("coin_value") if area.has_meta("coin_value") else 10
	progression_component.add_currency(coin_value)
	coin_collected.emit(coin_value)
	if is_instance_valid(area):
		area.queue_free()

func _pickup_health_potion(area: Area3D):
	if health_component.current_health >= max_health:
		# Don't pick up if at full health
		return
	health_component.heal(heal_amount_from_potion)
	if is_instance_valid(area):
		area.queue_free()

func _pickup_xp_orb(area: Area3D):
	var xp_value = area.get_meta("xp_value") if area.has_meta("xp_value") else 10
	progression_component.add_xp(xp_value)
	if is_instance_valid(area):
		area.queue_free()

# --- Health System Component Handlers ---
func _on_health_changed(_current_health: int, _max_health: int):
	# Update UI or other systems as needed
	pass

func _on_player_died():
	is_dead = true
	# Handle player death logic (animation, input disable, etc.)
	pass

func _on_health_depleted():
	# Handle logic when health reaches zero (game over, respawn, etc.)
	pass

func _on_coin_collected(amount: int):
	coin_collected.emit(amount)  # Re-emit for UI

func _on_xp_changed(xp_val: int, xp_to_next_val: int, level_val: int):
	xp_changed.emit(xp_val, xp_to_next_val, level_val)  # Re-emit for UI

# Animation signal handlers for movement component
func _on_hand_animation_update(left_pos: Vector3, right_pos: Vector3, left_rot: Vector3, right_rot: Vector3) -> void:
	var left_hand = get_node_or_null("LeftHandAnchor/LeftHand")
	if left_hand:
		left_hand.position = left_pos
		left_hand.rotation_degrees = left_rot
	var right_hand = get_node_or_null("RightHandAnchor/RightHand")
	if right_hand:
		right_hand.position = right_pos
		right_hand.rotation_degrees = right_rot

func _on_foot_animation_update(left_pos: Vector3, right_pos: Vector3) -> void:
	if left_foot:
		left_foot.position = left_pos
	if right_foot:
		right_foot.position = right_pos

func _on_animation_state_changed(_is_idle: bool) -> void:
	# Handle animation state changes if needed
	pass

func _on_body_animation_update(body_pos: Vector3, body_rot: Vector3) -> void:
	if mesh_instance:
		mesh_instance.position = body_pos
		mesh_instance.rotation_degrees = body_rot

func _on_combat_attack_state_changed(_state: int) -> void:
	# Handle combat state changes if needed
	pass

func _process(_delta):
	pass

func _schedule_next_blink():
	blink_interval = randf_range(BLINK_MIN_INTERVAL, BLINK_MAX_INTERVAL)
	blink_timer = blink_interval

func _handle_advanced_blinking(delta: float):
	if is_dead or is_blinking:
		return

	blink_timer += delta
	if blink_timer >= next_blink_time:
		# 20% chance for double blink
		if randf() < 0.2:
			_do_double_blink()
		else:
			_do_single_blink()

func _do_single_blink():
	CharacterAppearanceManager.blink_eyes(self, 0.15)
	_reset_blink_timer()

func _do_double_blink():
	CharacterAppearanceManager.blink_eyes(self, 0.1)
	get_tree().create_timer(0.2).timeout.connect(
		func(): CharacterAppearanceManager.blink_eyes(self, 0.1)
	)
	_reset_blink_timer()

func _reset_blink_timer():
	is_blinking = true
	blink_timer = 0.0
	next_blink_time = randf_range(2.0, 7.0)
	get_tree().create_timer(0.3).timeout.connect(
		func(): is_blinking = false
	)

# --- Mouth Expression Test System ---
var _mouth_expression_timer: Timer = null
var _mouth_expression_index := 0
var _mouth_expressions := [
	"neutral",
	"smile",
	"frown",
	"surprise"
]

func _start_mouth_expression_test():
	if not mesh_instance:
		return
	if not _mouth_expression_timer:
		_mouth_expression_timer = Timer.new()
		_mouth_expression_timer.wait_time = 2.0
		_mouth_expression_timer.one_shot = false
		_mouth_expression_timer.autostart = true
		add_child(_mouth_expression_timer)
		_mouth_expression_timer.timeout.connect(_cycle_mouth_expression)
	_mouth_expression_index = 0
	_set_mouth_expression(_mouth_expressions[_mouth_expression_index])

func _cycle_mouth_expression():
	_mouth_expression_index = (_mouth_expression_index + 1) % _mouth_expressions.size()
	_set_mouth_expression(_mouth_expressions[_mouth_expression_index])

func _set_mouth_expression(expr: String):
	if not mesh_instance:
		return
	match expr:
		"neutral":
			CharacterAppearanceManager.set_mouth_neutral(mesh_instance)
		"smile":
			CharacterAppearanceManager.set_mouth_smile(mesh_instance)
		"frown":
			CharacterAppearanceManager.set_mouth_frown(mesh_instance)
		"surprise":
			CharacterAppearanceManager.set_mouth_surprise(mesh_instance)
		_:
			CharacterAppearanceManager.set_mouth_neutral(mesh_instance)

func _input(event):
	# Add this to your existing _input function
	if Input.is_action_just_pressed("toggle_fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.is_action_pressed("ui_text_completion_accept"):  # F1 key
		var warrior_config = CharacterGenerator.generate_character_by_type("warrior")
		set_character_appearance(warrior_config)
	if event.is_action_pressed("drop_weapon"):
		if WeaponManager.is_weapon_equipped():
			var weapon_resource = WeaponManager.get_current_weapon()
			if weapon_resource:
				if LootManager:
					LootManager.drop_weapon(global_position, weapon_resource)
				WeaponManager.unequip_weapon()

func _physics_process(delta):
	if is_dead:
		return

	movement_component.handle_mouse_look()

	if movement_component.is_being_knocked_back:
		movement_component.handle_knockback(delta)
		movement_component.apply_gravity(delta)
		move_and_slide()
		return

	movement_component.handle_movement_and_dash(delta)
	combat_component.handle_attack_input()
	movement_component.handle_dash_cooldown(delta)
	_handle_invulnerability(delta)
	_handle_advanced_blinking(delta)

func _handle_invulnerability(delta: float):
	var still_invulnerable = health_component.update_invulnerability(delta)
	if mesh_instance and mesh_instance.material_override:
		if still_invulnerable:
			var flash_intensity = sin(health_component.invulnerability_timer * 30) * 0.5 + 0.5
			mesh_instance.material_override.albedo_color = Color.RED if flash_intensity > 0.5 else Color(0.9, 0.7, 0.6)
		else:
			mesh_instance.material_override.albedo_color = Color(0.9, 0.7, 0.6)

func set_character_appearance(config: Dictionary):
	if mesh_instance and CharacterAppearanceManager:
		CharacterAppearanceManager.create_player_appearance(self, config)

func randomize_character():
	if mesh_instance and CharacterAppearanceManager:
		var config = CharacterGenerator.generate_random_character_config()
		set_character_appearance(config)

func get_character_seed_config(seed_value: int):
	return CharacterGenerator.generate_character_with_seed(seed_value)

func _create_arrow_system():
	# We'll create arrows on-demand instead of a particle system
	print("🏹 Simple arrow system ready!")

# Change the player's skin tone at runtime
func change_player_skin_tone(skin_color: Color):
	var mesh = get_node_or_null("MeshInstance3D")
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = skin_color
	# Update hands and feet
	for part in ["LeftHand", "RightHand", "LeftFoot", "RightFoot"]:
		var node = get_node_or_null(part)
		if node and node.material_override:
			node.material_override.albedo_color = skin_color
	print("✅ Player skin tone updated to: ", skin_color)
# Disabled staff logic for now
# case int(WeaponResource.WeaponType.STAFF):
# ...existing code...


func test_skin_tones():
	print("=== TESTING SKIN TONES ===")
	for i in range(5):
		var config = CharacterGenerator.generate_random_character_config()
		print("Test ", i, " skin tone: ", config["skin_tone"])

func take_damage(amount: int, from: Node3D = null):
	if health_component:
		health_component.take_damage(amount, from)

func heal(amount: int):
	if health_component:
		health_component.heal(amount)

func get_health() -> int:
	if health_component:
		return health_component.get_health()
	return 0

func get_max_health() -> int:
	if health_component:
		return health_component.get_max_health()
	return 0

func get_health_percentage() -> float:
	if health_component:
		return health_component.get_health_percentage()
	return 0.0
