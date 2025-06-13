extends CharacterBody3D

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
@export var current_health := 100
@export var health_regen_rate := 2.0
@export var health_regen_delay := 3.0

@export_group("Knockback")
@export var knockback_force := 12.0
@export var knockback_duration := 0.6

@export_group("Dash")
@export var max_dash_charges := 1

@export_group("Experience")
@export var xp := 0
@export var level := 1
@export var xp_to_next_level := 100
@export var xp_growth := 1.5
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

# Weapon system variables
var weapon_attach_point: Node3D = null
var equipped_weapon_mesh: MeshInstance3D = null

# Base stats for weapon system
var base_attack_damage := 10
var base_attack_range := 2.0
var base_attack_cooldown := 1.0
var base_attack_cone_angle := 90.0

# Player state
var currency := 0
var total_coins_collected := 0
var is_dead := false
var nearby_weapon_pickup = null

# Health system state
var last_damage_time := 0.0

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
var invulnerability_timer := 0.0
const INVULNERABILITY_DURATION := 0.5

# Node references (cached in _ready)
var attack_area: Area3D

# Constants
const FRICTION_MULTIPLIER := 3.0
const MOVEMENT_THRESHOLD := 0.1

# Signals
signal health_changed(current_health: int, max_health: int)
signal dash_charges_changed(current_charges: int, max_charges: int)
signal player_died
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

func _setup_player():
	add_to_group("player")
	_configure_collision()
	_create_visual()
	_setup_attack_system()
	_setup_health_system()
	_initialize_currency()
	_initialize_base_stats()
	_setup_hand_references()
	_setup_weapon_attach_point()
	_connect_weapon_manager_signals()

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
	mesh_instance = CharacterAppearanceManager.create_random_character(self)
	print("✅ Player visual created successfully!")

func _initialize_base_stats():
	base_attack_damage = attack_damage
	base_attack_range = attack_range
	base_attack_cooldown = attack_cooldown
	base_attack_cone_angle = attack_cone_angle

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

func _setup_health_system():
	current_health = max_health
	last_damage_time = 0.0
	is_dead = false
	health_changed.emit(current_health, max_health)

func _initialize_currency():
	currency = 0
	total_coins_collected = 0

func _setup_hand_references():
	# --- FEET (find them after character creation) ---
	left_foot = get_node_or_null("LeftFootAnchor/LeftFoot")
	right_foot = get_node_or_null("RightFootAnchor/RightFoot")
	if left_foot:
		left_foot_original_pos = left_foot.position
		left_foot_planted_pos = left_foot.position
		print("✅ Found LeftFoot!")
	else:
		print("⚠️ LeftFoot node not found!")
	if right_foot:
		right_foot_original_pos = right_foot.position
		right_foot_planted_pos = right_foot.position
		print("✅ Found RightFoot!")
	else:
		print("⚠️ RightFoot node not found!")


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
	var mesh = null
	match int(weapon_resource.weapon_type):
		int(WeaponResource.WeaponType.SWORD):
			mesh = _create_simple_sword_mesh()
		int(WeaponResource.WeaponType.BOW):
			mesh = _create_simple_bow_mesh()
		int(WeaponResource.WeaponType.STAFF):
			mesh = _create_simple_staff_mesh()
		_:
			mesh = _create_simple_sword_mesh()
	if mesh:
		# Attach weapon visual to WeaponAttachPoint (not directly to hand)
		weapon_attach_point.add_child(mesh)
		equipped_weapon_mesh = mesh

func _hide_weapon_visual():
	if equipped_weapon_mesh and is_instance_valid(equipped_weapon_mesh):
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

func _create_simple_bow_mesh() -> MeshInstance3D:
	var bow = MeshInstance3D.new()
	var bow_mesh = CylinderMesh.new()
	bow_mesh.top_radius = 0.03
	bow_mesh.bottom_radius = 0.03
	bow_mesh.height = 0.7
	bow.mesh = bow_mesh
	bow.rotation_degrees = Vector3(0, 0, 90)
	bow.position = Vector3(0, 0.35, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.3, 0.1)
	bow.material_override = mat
	return bow

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
	_add_currency(coin_value)
	coin_collected.emit(coin_value)
	if is_instance_valid(area):
		area.queue_free()

func _add_currency(amount: int):
	currency += amount
	total_coins_collected += amount
	coin_collected.emit(currency)

func _pickup_health_potion(area: Area3D):
	heal(heal_amount_from_potion)
	if is_instance_valid(area):
		area.queue_free()

func _pickup_xp_orb(area: Area3D):
	var xp_value = area.get_meta("xp_value") if area.has_meta("xp_value") else 10
	add_xp(xp_value)
	if is_instance_valid(area):
		area.queue_free()

func add_xp(amount: int):
	xp += amount
	xp_changed.emit(xp, xp_to_next_level, level)
	if xp >= xp_to_next_level:
		_level_up()

func _level_up():
	xp -= xp_to_next_level
	level += 1
	xp_to_next_level = int(xp_to_next_level * xp_growth)
	current_health = max_health
	health_changed.emit(current_health, max_health)
	xp_changed.emit(xp, xp_to_next_level, level)

# --- Health System Methods ---
func heal(heal_amount: int):
	if is_dead or current_health >= max_health:
		return
	var old_health = current_health
	current_health = min(current_health + heal_amount, max_health)
	if current_health != old_health:
		health_changed.emit(current_health, max_health)
		_show_heal_feedback(heal_amount)

func take_damage(amount: int, from: Node3D = null):
	if is_dead or invulnerability_timer > 0:
		return
	var old_health = current_health
	current_health = max(current_health - amount, 0)
	last_damage_time = Time.get_ticks_msec() / 1000.0
	invulnerability_timer = INVULNERABILITY_DURATION
	health_changed.emit(current_health, max_health)
	if from and movement_component:
		movement_component.apply_knockback_from_enemy(from)
	if current_health <= 0 and not is_dead:
		_handle_player_death()
	if current_health != old_health:
		_show_damage_feedback(amount)

func _show_heal_feedback(heal_amount: int):
	# Flash green
	if mesh_instance and mesh_instance.material_override:
		mesh_instance.material_override.albedo_color = Color(0.3, 1.0, 0.3)
	
	# FIXED: Use the correct damage numbers system for healing
	var damage_system = get_tree().get_first_node_in_group("damage_numbers")
	if damage_system:
		damage_system.show_heal(heal_amount, self)
	
	# Play heal sound (if available)
	if has_node("HealSound"):
		$HealSound.play()

func _show_damage_feedback(damage_amount: int):
	# Flash red
	if mesh_instance and mesh_instance.material_override:
		mesh_instance.material_override.albedo_color = Color(1.0, 0.2, 0.2)
	
	# FIXED: Use the correct damage numbers system
	var damage_system = get_tree().get_first_node_in_group("damage_numbers")
	if damage_system:
		damage_system.show_damage(damage_amount, self, "normal")
	
	# Play damage sound (if available)
	if has_node("DamageSound"):
		$DamageSound.play()
	
	# Screen shake (if camera exists and supports it)
	if camera and camera.has_method("shake"):
		camera.shake(0.2, 4.0)
	
	# Damage particles (if available)
	if has_node("DamageParticles"):
		$DamageParticles.restart()

func _handle_player_death():
	is_dead = true
	player_died.emit()
	# Play death animation if available
	if mesh_instance and mesh_instance.has_animation("death"):
		mesh_instance.play("death")
	# Disable input (if using an input component)
	if has_node("InputComponent"):
		$InputComponent.set_process(false)
	# Show death/game over screen (if available)
	if has_node("/root/DeathScreen"):
		get_node("/root/DeathScreen").show()

# Public API / Getters
func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func get_health_percentage() -> float:
	return float(current_health) / float(max_health) if max_health > 0 else 0.0

func set_max_health(new_max_health: int):
	max_health = new_max_health
	current_health = max_health
	health_changed.emit(current_health, max_health)

func get_dash_charges() -> int:
	return movement_component.current_dash_charges

func get_max_dash_charges() -> int:
	return max_dash_charges

func upgrade_dash_charges(increase: int):
	max_dash_charges += increase
	movement_component.current_dash_charges = min(movement_component.current_dash_charges + increase, max_dash_charges)
	dash_charges_changed.emit(movement_component.current_dash_charges, max_dash_charges)

func get_currency() -> int:
	return currency

func get_xp() -> int:
	return xp

func get_facing_direction() -> Vector3:
	# Ensure facing direction is -Z (forward)
	return -transform.basis.z

func is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > MOVEMENT_THRESHOLD

func get_position_2d() -> Vector2:
	return Vector2(global_position.x, global_position.z)

func get_player_stats() -> Dictionary:
	var current_weapon = WeaponManager.get_current_weapon() if WeaponManager.is_weapon_equipped() else null
	var current_weapon_name = current_weapon.weapon_name if current_weapon and "weapon_name" in current_weapon else ""
	var nearby_weapon_name = ""
	
	if nearby_weapon_pickup:
		if "weapon_name" in nearby_weapon_pickup:
			nearby_weapon_name = nearby_weapon_pickup.weapon_name
		elif nearby_weapon_pickup.has_meta("weapon_name"):
			nearby_weapon_name = str(nearby_weapon_pickup.get_meta("weapon_name"))
	
	return {
		"health": current_health,
		"max_health": max_health,
		"dash_charges": movement_component.current_dash_charges,
		"max_dash_charges": max_dash_charges,
		"currency": currency,
		"total_coins": total_coins_collected,
		"attack_damage": attack_damage,
		"speed": speed,
		"is_dashing": movement_component.is_dashing,
		"is_attacking": combat_component.state != combat_component.CombatState.IDLE,
		"is_dead": is_dead,
		"knockback_force": knockback_force,
		"knockback_duration": knockback_duration,
		"is_being_knocked_back": movement_component.is_being_knocked_back,
		"xp": xp,
		"level": level,
		"current_weapon_name": current_weapon_name,
		"nearby_weapon_name": nearby_weapon_name,
		"can_drop_weapon": WeaponManager.is_weapon_equipped(),
		"can_swap_weapon": is_instance_valid(nearby_weapon_pickup),
		"combat_state": combat_component.state
	}

#region Animation Functions

# --- Animation signal handlers ---
func _on_hand_animation_update(_left_pos: Vector3, _right_pos: Vector3, _left_rot: Vector3, _right_rot: Vector3) -> void:
	pass

func _on_foot_animation_update(left_pos: Vector3, right_pos: Vector3) -> void:
	if left_foot:
		left_foot.position = left_pos
	if right_foot:
		right_foot.position = right_pos

func _on_animation_state_changed(_is_idle: bool) -> void:
	pass

func _on_combat_attack_state_changed(_state: int) -> void:
	pass

func _on_body_animation_update(body_pos: Vector3, body_rot: Vector3) -> void:
	if mesh_instance:
		mesh_instance.position = body_pos
		mesh_instance.rotation = body_rot

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
	_handle_health_regen(delta)
	movement_component.handle_dash_cooldown(delta)
	_handle_invulnerability(delta)
	_handle_advanced_blinking(delta)

func _handle_health_regen(delta: float):
	if is_dead or current_health >= max_health:
		return
	if combat_component and combat_component.state != combat_component.CombatState.IDLE:
		return
	var time_since_damage = Time.get_ticks_msec() / 1000.0 - last_damage_time
	if time_since_damage >= health_regen_delay:
		var old_health = current_health
		current_health = min(current_health + (health_regen_rate * delta), max_health)
		if current_health != old_health:
			health_changed.emit(current_health, max_health)

func _handle_invulnerability(delta: float):
	if invulnerability_timer > 0:
		invulnerability_timer -= delta
		if mesh_instance and mesh_instance.material_override:
			var flash_intensity = sin(invulnerability_timer * 30) * 0.5 + 0.5
			mesh_instance.material_override.albedo_color = Color.RED if flash_intensity > 0.5 else Color(0.9, 0.7, 0.6)
	else:
		if mesh_instance and mesh_instance.material_override:
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
