extends CharacterBody3D

# Export max_health property so it can be accessed by other scripts
@export var max_health: float = 100.0

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
@export var health_regen_rate := 2.0
@export var health_regen_delay := 3.0

@export_group("Knockback")
@export var knockback_force := 12.0
@export var knockback_duration := 0.6

@export_group("Dash")
@export var max_dash_charges := 1

@export_group("Experience")

@export_group("Animation")
@export var body_lean_strength: float = 0.15
@export var body_sway_strength: float = 0.50
@export var hand_swing_strength: float = 1.0
@export var foot_step_strength: float = 0.10
@export var side_step_modifier: float = 0.4

# --- Node References (using @onready for caching) ---
var left_foot: MeshInstance3D
var right_foot: MeshInstance3D

@onready var movement_component: PlayerMovement = $PlayerMovement
@onready var combat_component: PlayerCombat = $CombatComponent
@onready var health_component = $HealthComponent
@onready var progression_component = $ProgressionComponent
@onready var inventory_component: PlayerInventoryComponent = get_node_or_null("InventoryComponent")
@onready var stats_component: PlayerStats = get_node_or_null("PlayerStats")
@onready var ui = get_tree().get_root().find_child("HealthUI", true, false)

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
	if stats_component and stats_component.has_method("get_max_health"):
		health_component.setup(self, stats_component.get_max_health())
	else:
		health_component.setup(self, 100)
	health_component.health_changed.connect(_on_health_changed)
	health_component.player_died.connect(_on_player_died)
	health_component.health_depleted.connect(_on_health_depleted)
	progression_component.setup(self)
	progression_component.show_level_up_choices.connect(_on_show_level_up_choices)
	progression_component.stat_choice_made.connect(_on_stat_choice_made)
	progression_component.xp_changed.connect(_on_xp_changed)
	progression_component.coin_collected.connect(_on_coin_collected)
	# Inventory system setup
	if inventory_component and inventory_component.has_method("setup"):
		inventory_component.setup(self)
	if stats_component and stats_component.has_method("setup"):
		stats_component.setup(self)
	if movement_component and movement_component.has_method("set_animation_settings"):
		movement_component.set_animation_settings({
			"body_lean_strength": body_lean_strength,
			"body_sway_strength": body_sway_strength,
			"hand_swing_strength": hand_swing_strength,
			"foot_step_strength": foot_step_strength,
			"side_step_modifier": side_step_modifier
		})
	if movement_component:
		movement_component.dash_charges_changed.connect(_on_dash_charges_changed)
		movement_component.hand_animation_update.connect(_on_hand_animation_update)
		movement_component.foot_animation_update.connect(_on_foot_animation_update)
		movement_component.animation_state_changed.connect(_on_animation_state_changed)
		movement_component.body_animation_update.connect(_on_body_animation_update)
	if combat_component:
		combat_component.attack_state_changed.connect(_on_combat_attack_state_changed)
	_reset_blink_timer()
	var config = CharacterGenerator.generate_random_character_config()
	CharacterAppearanceManager.create_player_appearance(self, config)
	print("🎨 Player skin tone: ", config["skin_tone"])
	movement_component.reinitialize_feet()
	# Connect upgrade_choice_requested signal
	progression_component.upgrade_choice_requested.connect(_on_upgrade_choice_requested)

func _on_upgrade_choice_requested(options: Array):
	var levelup_ui = get_tree().get_first_node_in_group("levelupui")
	if levelup_ui and levelup_ui.has_method("show_upgrade_choices"):
		levelup_ui.show_upgrade_choices(options)
	else:
		print("⚠️ LevelUpUI not found - unpausing game")
		get_tree().paused = false

func _setup_player():
	add_to_group("player")
	_configure_collision()
	_create_visual()
	_setup_attack_system()
	_setup_hand_references()
	_setup_weapon_attach_point()
	# Ensure WeaponAnimationPlayer exists
	if not has_node("WeaponAnimationPlayer"):
		var weapon_anim_player = AnimationPlayer.new()
		weapon_anim_player.name = "WeaponAnimationPlayer"
		add_child(weapon_anim_player)
		print("✅ Created WeaponAnimationPlayer node")
	else:
		print("✅ WeaponAnimationPlayer node already exists")
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
	if not has_node("WeaponAttachPoint"):
		var attach_point = Node3D.new()
		attach_point.name = "WeaponAttachPoint"
		add_child(attach_point)
		weapon_attach_point = attach_point
		print("✅ Created WeaponAttachPoint node")
	else:
		weapon_attach_point = get_node("WeaponAttachPoint")
		print("✅ Found existing WeaponAttachPoint node")

var weapon_attach_point: Node3D = null

# --- Removed old weapon management functions ---
# func _connect_weapon_manager_signals():
# func _on_weapon_equipped(weapon_resource):
# func _on_weapon_unequipped():
# func _show_weapon_visual(weapon_resource):
# func _hide_weapon_visual():
# func _create_simple_sword_mesh() -> MeshInstance3D:
# func _create_simple_staff_mesh() -> MeshInstance3D:

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
	# coin_collected.emit(coin_value)  # Now handled by PlayerProgression
	if is_instance_valid(area):
		area.queue_free()

func _pickup_health_potion(area: Area3D):
	if stats_component.get_health() >= stats_component.get_max_health():
		# Don't pick up if at full health
		return
	health_component.heal(health_component.heal_amount_from_potion)
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
	if ui:
		pass  # UI updates automatically in _process()

func _on_player_died():
	is_dead = true
	# Handle player death logic (animation, input disable, etc.)
	pass

func _on_health_depleted():
	# Handle logic when health reaches zero (game over, respawn, etc.)
	pass

# Update max health through health component and heal player
func _on_level_up_stats(health_increase: int, _damage_increase: int):
	max_health += health_increase
	health_component.heal(health_increase)  # Heal player when leveling up
	# Update the health component's max health if it has that method
	if health_component.has_method("set_max_health"):
		health_component.set_max_health(max_health)
	print("Level up! Health increased by ", health_increase)

func _on_xp_changed(xp: int, xp_to_next: int, level: int):
	# Forward XP signal to UI
	get_tree().call_group("UI", "_on_player_xp_changed", xp, xp_to_next, level)

func _on_coin_collected(amount: int):
	# Forward coin signal to UI  
	get_tree().call_group("UI", "_on_player_coin_collected", amount)

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

func get_xp() -> int:
	return stats_component.get_xp() if stats_component else 0

func get_level() -> int:
	return stats_component.get_level() if stats_component else 1

func get_xp_to_next_level() -> int:
	return stats_component.get_xp_to_next_level() if stats_component else 100

func _on_show_level_up_choices(options: Array):
	var level_up_ui = get_tree().get_first_node_in_group("levelupui")
	if level_up_ui:
		level_up_ui.show_upgrade_choices(options)

func _on_stat_choice_made(stat_name: String):
	match stat_name:
		"damage":
			attack_damage += 5
			print("✅ Attack damage increased by 5")
		"speed":
			speed += 1.0
			print("✅ Speed increased by 1.0")
		"attack_speed":
			attack_cooldown -= 0.1
			print("✅ Attack speed increased")
		"health":
			max_health += 20
			health_component.heal(20)
			if health_component.has_method("set_max_health"):
				health_component.set_max_health(max_health)
			print("✅ Max health increased by 20")
