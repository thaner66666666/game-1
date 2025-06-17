extends Node
class_name AllyHealth

signal health_changed(current: int, maximum: int)
signal ally_died

var ally_ref
var current_health: int
var max_health: int
var invuln_timer := 0.0
var invuln_duration := 0.5

func setup(ally, max_hp: int):
	ally_ref = ally
	max_health = max_hp
	current_health = max_health
	health_changed.emit(current_health, max_health)

func _process(delta):
	if invuln_timer > 0:
		invuln_timer -= delta

func take_damage(amount: int, attacker: Node = null):
	if current_health <= 0 or invuln_timer > 0:
		return
	
	invuln_timer = invuln_duration
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	
	# Show damage numbers if system exists
	var damage_system = get_tree().get_first_node_in_group("damage_numbers")
	if damage_system and damage_system.has_method("show_damage"):
		damage_system.show_damage(amount, ally_ref, "normal")
	
	# Knockback from attacker
	if attacker and current_health > 0:
		_apply_knockback(attacker)
	
	if current_health <= 0:
		ally_died.emit()

func _apply_knockback(attacker: Node):
	if not attacker.has_method("get_global_position"):
		return
	
	var knockback_dir = ally_ref.global_position - attacker.global_position
	knockback_dir.y = 0
	if knockback_dir.length() > 0.1:
		knockback_dir = knockback_dir.normalized() * 8.0
		ally_ref.velocity.x = knockback_dir.x
		ally_ref.velocity.z = knockback_dir.z

func heal(amount: int):
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func _die():
	queue_free()
