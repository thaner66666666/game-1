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

func _show_damage_feedback(damage_amount: int):
	# Flash red
	if player_ref.mesh_instance and player_ref.mesh_instance.material_override:
		player_ref.mesh_instance.material_override.albedo_color = Color(1.0, 0.2, 0.2)
	# Show damage numbers
	var damage_system = player_ref.get_tree().get_first_node_in_group("damage_numbers")
	if damage_system:
		damage_system.show_damage(damage_amount, player_ref, "massive") # Use red for player damage
	# Play damage sound
	if player_ref.has_node("DamageSound"):
		player_ref.get_node("DamageSound").play()

func _show_heal_feedback(heal_amount: int):
	# Flash green
	if player_ref.mesh_instance and player_ref.mesh_instance.material_override:
		player_ref.mesh_instance.material_override.albedo_color = Color(0.3, 1.0, 0.3)
	# Show heal numbers
	var damage_system = player_ref.get_tree().get_first_node_in_group("damage_numbers")
	if damage_system:
		damage_system.show_heal(heal_amount, player_ref)

func _handle_player_death():
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
