extends Node
class_name PlayerHealth

signal health_changed(current_health: int, max_health: int)
signal player_died
signal health_depleted

var current_health: int
var max_health: int
var last_damage_time: float
var invulnerability_timer: float

const INVULNERABILITY_DURATION := 0.5
const heal_amount_from_potion := 30

var player_ref: CharacterBody3D

func setup(player_ref_in: CharacterBody3D, starting_health: int):
	player_ref = player_ref_in
	max_health = starting_health
	current_health = starting_health
	last_damage_time = 0.0
	invulnerability_timer = 0.0
	print("🔧 PlayerHealth setup complete - Max: ", max_health, " Current: ", current_health)
	# Emit initial health state
	health_changed.emit(current_health, max_health)

func take_damage(amount: int, _from: Node3D = null):
	print("🔧 PlayerHealth: take_damage called - amount: ", amount, " current_health: ", current_health, " invuln_timer: ", invulnerability_timer)
	if current_health <= 0 or invulnerability_timer > 0:
		print("🔧 Damage blocked - health: ", current_health, " invuln: ", invulnerability_timer)
		return
	var old_health = current_health
	current_health = max(current_health - amount, 0)
	last_damage_time = Time.get_ticks_msec() / 1000.0
	invulnerability_timer = INVULNERABILITY_DURATION
	print("🔧 Health changed from ", old_health, " to ", current_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		_handle_player_death()
	if current_health != old_health:
		_show_damage_feedback(amount)

func heal(heal_amount: int):
	if current_health <= 0 or current_health >= max_health:
		return
	var old_health = current_health
	current_health = min(current_health + heal_amount, max_health)
	if current_health != old_health:
		health_changed.emit(current_health, max_health)
		_show_heal_feedback(heal_amount)

func update_invulnerability(delta: float):
	if invulnerability_timer > 0:
		invulnerability_timer -= delta
		# Return true if still invulnerable, false if finished
		return invulnerability_timer > 0
	return false

# Show visual and audio feedback for taking damage
var _original_skin_colors := {}
var _flash_timer: Timer = null
var _flash_count := 0
const FLASH_TOTAL := 4
const FLASH_ON_TIME := 0.08
const FLASH_OFF_TIME := 0.08

func _show_damage_feedback(damage_amount: int):
	_flash_count = 0
	_start_flash_sequence()
	# Show damage numbers if the damage system exists and the tree is valid
	var tree = player_ref.get_tree() if player_ref else null
	if tree:
		var damage_system = tree.get_first_node_in_group("damage_numbers")
		if damage_system:
			damage_system.show_damage(damage_amount, player_ref, "massive")
	# Play damage sound if available
	if player_ref.has_node("DamageSound"):
		player_ref.get_node("DamageSound").play()

func _start_flash_sequence():
	if _flash_timer == null:
		_flash_timer = Timer.new()
		_flash_timer.one_shot = true
		player_ref.add_child(_flash_timer)
	if not _flash_timer.is_connected("timeout", Callable(self, "_do_flash_step")):
		_flash_timer.timeout.connect(_do_flash_step)
	_do_flash_step()

func _do_flash_step():
	var color = player_ref.current_skin_color if player_ref.has_method("current_skin_color") or "current_skin_color" in player_ref else Color(1,1,1)
	var parts = ["MeshInstance3D", "LeftHand", "RightHand", "LeftFoot", "RightFoot"]
	if _flash_count % 2 == 0:
		# Flash red
		for part in parts:
			var node = player_ref.get_node_or_null(part)
			if node and node.material_override:
				node.material_override.albedo_color = Color(1.0, 0.2, 0.2)
		_flash_timer.wait_time = FLASH_ON_TIME
	else:
		# Restore color
		for part in parts:
			var node = player_ref.get_node_or_null(part)
			if node and node.material_override:
				node.material_override.albedo_color = color
		_flash_timer.wait_time = FLASH_OFF_TIME
	_flash_count += 1
	if _flash_count < FLASH_TOTAL * 2:
		_flash_timer.start()
	else:
		# Ensure final color is restored
		for part in parts:
			var node = player_ref.get_node_or_null(part)
			if node and node.material_override:
				node.material_override.albedo_color = color

func _restore_skin_color():
	# Use the player's current_skin_color for all parts
	var color = player_ref.current_skin_color if player_ref.has_method("current_skin_color") or "current_skin_color" in player_ref else Color(1,1,1)
	var parts = ["MeshInstance3D", "LeftHand", "RightHand", "LeftFoot", "RightFoot"]
	for part in parts:
		var node = player_ref.get_node_or_null(part)
		if node and node.material_override:
			node.material_override.albedo_color = color
	if _flash_timer:
		_flash_timer.stop()


# Show visual and audio feedback for healing
func _show_heal_feedback(heal_amount: int):
	# Flash green for heal feedback
	if player_ref.mesh_instance and player_ref.mesh_instance.material_override:
		player_ref.mesh_instance.material_override.albedo_color = Color(0.3, 1.0, 0.3)
	# Show heal numbers if the heal system exists and the tree is valid
	# Reuse the 'tree' variable to avoid redeclaration in the same scope
	var tree = player_ref.get_tree() if player_ref else null
	if tree:
		var heal_system = tree.get_first_node_in_group("damage_numbers")
		if heal_system:
			heal_system.show_heal(heal_amount, player_ref)
	# Play heal sound if available (uncomment if you add a sound)
	# if player_ref.has_node("HealSound"):
	# 	player_ref.get_node("HealSound").play()

# Handles player death: emits signals and logs for debugging
func _handle_player_death():
	print("💀 Player death triggered! Emitting signals...")
	# Emit signals for other systems to respond (UI, respawn, etc.)
	health_depleted.emit()
	player_died.emit()


	health_depleted.emit()
	player_died.emit()

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func get_health_percentage() -> float:
	return float(current_health) / float(max_health) if max_health > 0 else 0.0

func set_max_health(new_max_health: int):
	max_health = new_max_health
	# Don't reset current_health - just ensure it doesn't exceed new max
	current_health = min(current_health, max_health)
	health_changed.emit(current_health, max_health)

func _setup_health_system():
	current_health = max_health
	last_damage_time = 0.0
	health_changed.emit(current_health, max_health)

func _initialize_base_stats():
	# Add health-related base stat initialization if needed
	pass

func _process(delta: float):
	update_invulnerability(delta)
