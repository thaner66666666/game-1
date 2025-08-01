extends Node
class_name AllyCombat

signal attack_started
signal attack_hit(target: Node)

var ally_ref
var attack_damage: int
var attack_range := 2.5
var attack_cooldown := 1.2
var detection_range: float
var attack_timer := 0.0
var is_attacking := false
# Added for safe delayed damage
var pending_damage_target: Node3D = null

func setup(ally, damage: int, detect_range: float):
	ally_ref = ally  # Fix: should be ally, not damage
	attack_damage = damage
	detection_range = detect_range

func _process(delta):
	if attack_timer > 0:
		attack_timer -= delta

func can_attack() -> bool:
	return attack_timer <= 0 and not is_attacking

func find_nearest_enemy() -> Node3D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest_enemy: Node3D = null
	var nearest_distance := 999.0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue
		
		var distance = ally_ref.global_position.distance_to(enemy.global_position)
		if distance < nearest_distance and distance <= detection_range:
			nearest_distance = distance
			nearest_enemy = enemy
	
	return nearest_enemy

func attack_target(target: Node3D):
	if not can_attack() or not target:
		return
	
	var distance = ally_ref.global_position.distance_to(target.global_position)
	if distance > attack_range:
		return
	
	is_attacking = true
	attack_timer = attack_cooldown
	attack_started.emit()
	
	# Play attack animation
	_play_attack_animation(target)
	
	# Deal damage after short delay (Godot 4.1 best practice)
	pending_damage_target = target
	get_tree().create_timer(0.2).timeout.connect(_execute_pending_damage, CONNECT_ONE_SHOT)

# New function for safe delayed damage
func _execute_pending_damage():
	if pending_damage_target and is_instance_valid(pending_damage_target):
		_deal_damage(pending_damage_target)
	pending_damage_target = null

func _play_attack_animation(target: Node3D):
	# Simple punch animation using right hand
	var right_hand = ally_ref.right_hand_anchor.get_child(0) if ally_ref.right_hand_anchor.get_child_count() > 0 else null
	if not right_hand:
		is_attacking = false  # Fixed: was incomplete
		return                # Fixed: was missing

	# Make sure hand is visible during animation
	right_hand.visible = true

	var original_pos = right_hand.position
	var punch_dir = (target.global_position - ally_ref.global_position).normalized()
	punch_dir = ally_ref.global_transform.basis.inverse() * punch_dir

	# Animate punch
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(right_hand, "position", original_pos + punch_dir * 0.6, 0.2)
	tween.tween_property(right_hand, "position", original_pos, 0.2).set_delay(0.2)
	tween.tween_callback(func(): is_attacking = false).set_delay(0.4)

func _deal_damage(target: Node3D):
	if not is_instance_valid(target):
		return
	
	var distance = ally_ref.global_position.distance_to(target.global_position)
	if distance > attack_range * 1.2:  # Slight tolerance
		return
	
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
		attack_hit.emit(target)
	
	# Show damage numbers
	var damage_system = get_tree().get_first_node_in_group("damage_numbers")
	if damage_system and damage_system.has_method("show_damage"):
		damage_system.show_damage(attack_damage, target, "normal")
