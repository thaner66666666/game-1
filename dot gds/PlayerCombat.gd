extends Node
class_name PlayerCombat

# Signals for combat events and animation coordination
signal attack_started(combo_index: int)
signal attack_finished(combo_index: int)
signal enemy_hit(enemy: Node, damage: int, combo_index: int)
signal attack_state_changed(state: int) # For animation handoff
signal punch_animation_changed(is_animating: bool)

# Combat state enum (expanded)
enum CombatState { IDLE, ATTACKING, COMBO, BLOCKING, COOLDOWN }
var state: CombatState = CombatState.IDLE

# References
var player: CharacterBody3D = null
var weapon: WeaponResource = null
var movement_component: Node = null # Reference to PlayerMovement

# Hand animation references
var left_hand: MeshInstance3D = null
var right_hand: MeshInstance3D = null
var right_hand_original_pos: Vector3 = Vector3.ZERO
var right_hand_original_rot: Vector3 = Vector3.ZERO # <-- Add this line
var is_punch_animating: bool = false

# Attack/combo system
var last_attack_time: float = 0.0
var attack_cooldown: float = 1.0
var combo_index: int = 0
var combo_max: int = 3
var combo_reset_time: float = 1.0
var last_combo_time: float = 0.0

var attack_timer: Timer = null

# --- Audio references ---
var punch_sounds = []
var whoosh_sound = null
var impact_sound = null

func initialize(player_ref: CharacterBody3D, movement_ref: Node = null):
	player = player_ref
	movement_component = movement_ref
	state = CombatState.IDLE
	weapon = null
	last_attack_time = 0.0
	combo_index = 0
	last_combo_time = 0.0
	attack_cooldown = player.attack_cooldown if "attack_cooldown" in player else 1.0
	_setup_hand_references()
	# --- Audio setup ---
	punch_sounds = []
	for i in range(3):
		var node_name = "PunchSound%d" % i
		if player.has_node(node_name):
			punch_sounds.append(player.get_node(node_name))
	whoosh_sound = player.get_node_or_null("WhooshSound")
	impact_sound = player.get_node_or_null("ImpactSound")
	# Connect punch animation signal to movement for hand animation blocking
	if movement_component and movement_component.has_method("set_punch_animating"):
		punch_animation_changed.connect(
			func(is_animating):
				if movement_component and movement_component.has_method("set_punch_animating"):
					movement_component.set_punch_animating(is_animating)
					print("[Combat] punch_animation_changed signal delivered to movement_component: ", is_animating)
				else:
					print("[Combat] movement_component missing set_punch_animating()")
		)
	if not attack_timer:
		attack_timer = Timer.new()
		attack_timer.one_shot = true
		attack_timer.wait_time = 0.01 # Minimum valid timer duration
		if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
			attack_timer.timeout.connect(_on_attack_timer_timeout)
		add_child(attack_timer)

func _setup_hand_references():
	left_hand = player.get_node_or_null("LeftHand")
	right_hand = player.get_node_or_null("RightHand")
	if right_hand:
		right_hand_original_pos = right_hand.position
		right_hand_original_rot = right_hand.rotation # <-- Store original rotation
		print("✅ Combat: Found RightHand!")
	else:
		print("⚠️ Combat: RightHand not found!")
	if left_hand:
		print("✅ Combat: Found LeftHand!")
	else:
		print("⚠️ Combat: LeftHand not found!")

func set_weapon(_new_weapon: WeaponResource):
	# No longer needed; always get weapon from WeaponManager
	pass

func can_attack() -> bool:
	if movement_component and (
		movement_component.is_dashing or movement_component.is_being_knocked_back
	):
		print("[Combat][", Time.get_ticks_msec()/1000.0, "] Attack blocked: dashing or knocked back")
		return false
	# Timer is stopped when ready to attack, running when on cooldown
	return state == CombatState.IDLE and _attack_cooldown_ready()

func _attack_cooldown_ready() -> bool:
	var now = Time.get_ticks_msec() / 1000.0
	# Timer is stopped when ready, running when on cooldown
	if attack_timer == null:
		return true
	return (now - last_attack_time) >= attack_cooldown or attack_timer.is_stopped()

func handle_attack_input():
	if Input.is_action_just_pressed("attack") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		try_attack()

func try_attack():
	if not can_attack():
		return
	_start_attack_sequence()

func _start_attack_sequence():
	# Prevent overlapping attacks
	if state != CombatState.IDLE:
		print("[Combat][", Time.get_ticks_msec()/1000.0, "] Attack blocked: not IDLE (state=", state, ")")
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_combo_time > combo_reset_time:
		combo_index = 0
	else:
		combo_index = (combo_index + 1) % combo_max
	last_combo_time = now
	last_attack_time = now
	state = CombatState.ATTACKING
	print("[Combat][", now, "] State -> ATTACKING (combo ", combo_index, ")")
	attack_state_changed.emit(state)
	attack_started.emit(combo_index)
	_play_attack_animation(combo_index)
	# Windup phase
	attack_timer.stop()
	attack_timer.wait_time = 0.12
	attack_timer.start()

func _on_attack_timer_timeout():
	if state != CombatState.ATTACKING:
		print("[Combat][", Time.get_ticks_msec()/1000.0, "] Timer fired but not in ATTACKING state")
		return
	# Hit phase
	_damage_enemies_in_cone(combo_index)
	state = CombatState.COOLDOWN
	print("[Combat][", Time.get_ticks_msec()/1000.0, "] State -> COOLDOWN (combo ", combo_index, ")")
	attack_state_changed.emit(state)
	attack_finished.emit(combo_index)
	# Recovery/cooldown phase
	attack_timer.wait_time = attack_cooldown
	attack_timer.start()
	# After cooldown, reset to idle
	attack_timer.timeout.disconnect(_on_attack_timer_timeout)
	attack_timer.timeout.connect(_on_attack_cooldown_finished, CONNECT_ONE_SHOT)

func _on_attack_cooldown_finished():
	state = CombatState.IDLE
	print("[Combat][", Time.get_ticks_msec()/1000.0, "] State -> IDLE")
	attack_state_changed.emit(state)
	# Reconnect for next attack
	if attack_timer.timeout.is_connected(_on_attack_cooldown_finished):
		attack_timer.timeout.disconnect(_on_attack_cooldown_finished)
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)

func _play_attack_animation(combo_idx: int):
	# Handles hand animation for attacks (punch, sword, etc.)
	var current_weapon = WeaponManager.get_current_weapon() if WeaponManager.is_weapon_equipped() else null
	if not current_weapon:
		# Unarmed: play punch animation on hand
		if right_hand and right_hand_original_pos != Vector3.ZERO:
			_play_punch_animation(combo_idx)
	else:
		# Armed: play weapon animation using player's weapon_attach_point reference
		if player.weapon_attach_point and is_instance_valid(player.weapon_attach_point):
			print("✅ Using player's weapon_attach_point reference: ", player.weapon_attach_point.get_path())
			WeaponAnimationManager.play_attack_animation(current_weapon, player.weapon_attach_point)
		else:
			print("❌ Player weapon_attach_point is null or invalid!")
			WeaponAnimationManager.play_attack_animation(current_weapon, player)
	
	# Combo feedback (debug only, replace with real effects as needed)
	# --- Combo particle effects ---
	_spawn_combo_particles(combo_idx)
	_update_combo_ui(combo_idx)
	# --- Play punch sound ---
	_play_punch_sound(combo_idx)
	if combo_idx == 0:
		print("[Combat] Combo 1: light punch")
	elif combo_idx == 1:
		print("[Combat] Combo 2: medium punch, particles")
	elif combo_idx == 2:
		print("[Combat] Combo 3: heavy punch, big particles")

func _spawn_combo_particles(combo_idx: int):
	# Spawn different particles for each combo level
	var particle_name = "ComboParticles%d" % combo_idx
	if player.has_node(particle_name):
		var particles = player.get_node(particle_name)
		particles.restart()

func _update_combo_ui(combo_idx: int):
	# Update combo counter UI if available
	if has_node("/root/ComboUI"):
		get_node("/root/ComboUI").show_combo(combo_idx + 1)

func _play_punch_sound(combo_idx: int):
	if combo_idx < punch_sounds.size():
		punch_sounds[combo_idx].play()
	elif whoosh_sound:
		whoosh_sound.play()

func _play_impact_sound():
	if impact_sound:
		impact_sound.play()

func _play_punch_animation(combo_idx := 0):
	if not right_hand or right_hand_original_pos == Vector3.ZERO or is_punch_animating:
		return
	is_punch_animating = true
	punch_animation_changed.emit(true)
	var punch_distance = Vector3(0, 0.08, -1.1)
	var punch_time = 0.06 # Faster punch
	var return_time = 0.2 # Slower return
	var anticipation_time = 0.04
	var anticipation_factor = 0.1 # 10% back
	var anticipation_distance = punch_distance * -anticipation_factor
	var anticipation_rot = Vector3(0, 0, deg_to_rad(-10)) # slight windup
	var punch_rot = Vector3(0, 0, deg_to_rad(60)) # More dramatic rotation

	# Vary punch based on combo
	if combo_idx == 1:
		punch_distance += Vector3(0.05, 0.03, -0.2)
	elif combo_idx == 2:
		punch_distance += Vector3(0.1, 0.06, -0.35)

	var tween = create_tween()
	tween.set_parallel(true)

	# Anticipation: move back slightly and rotate a bit (starts at 0s)
	tween.tween_property(
		right_hand, "position",
		right_hand_original_pos + anticipation_distance, anticipation_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(0.0)
	tween.tween_property(
		right_hand, "rotation",
		right_hand_original_rot + anticipation_rot, anticipation_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(0.0)

	# Punch forward: snap with overshoot (starts after anticipation)
	tween.tween_property(
		right_hand, "position",
		right_hand_original_pos + punch_distance, punch_time
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(anticipation_time)
	tween.tween_property(
		right_hand, "rotation",
		right_hand_original_rot + punch_rot, punch_time
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(anticipation_time)

	# Return: smooth settle (starts after punch)
	tween.tween_property(
		right_hand, "position",
		right_hand_original_pos, return_time
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN).set_delay(anticipation_time + punch_time)
	tween.tween_property(
		right_hand, "rotation",
		right_hand_original_rot, return_time
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN).set_delay(anticipation_time + punch_time)

	tween.tween_callback(_on_punch_animation_finished).set_delay(anticipation_time + punch_time + return_time)

func _on_punch_animation_finished():
	is_punch_animating = false
	punch_animation_changed.emit(false)

func _damage_enemies_in_cone(combo_idx: int):
	# Always get weapon from WeaponManager
	var current_weapon = WeaponManager.get_current_weapon() if WeaponManager.is_weapon_equipped() else null
	var dmg = current_weapon.attack_damage if current_weapon else player.attack_damage
	var rng = current_weapon.attack_range if current_weapon else player.attack_range
	var cone = current_weapon.attack_cone_angle if current_weapon else player.attack_cone_angle
	var enemies = get_tree().get_nodes_in_group("enemies")
	var player_facing = player.get_facing_direction() if player.has_method("get_facing_direction") else -player.transform.basis.z
	var hit_any = false
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue
		var distance = player.global_position.distance_to(enemy.global_position)
		if distance <= rng:
			var direction_to_enemy = (enemy.global_position - player.global_position).normalized()
			direction_to_enemy.y = 0
			var angle_to_enemy = rad_to_deg(player_facing.angle_to(direction_to_enemy))
			if abs(angle_to_enemy) <= cone / 2:
				if enemy.has_method("take_damage"):
					enemy.take_damage(dmg)
				enemy_hit.emit(enemy, dmg, combo_idx)
				# --- Impact effect at enemy location ---
				_spawn_impact_effect(enemy.global_position, current_weapon)
				_play_impact_sound()
				hit_any = true
				# --- Weapon trail effect ---
				_spawn_weapon_trail(current_weapon)
	# Play whoosh if no enemy hit
	if not hit_any:
		if whoosh_sound:
			whoosh_sound.play()

func _spawn_impact_effect(pos: Vector3, weapon_param):
	# Show impact particles at pos, different for weapon type
	var effect_name = "ImpactParticles"
	if weapon_param and "impact_particles" in weapon_param:
		effect_name = weapon_param.impact_particles
	if player.has_node(effect_name):
		var effect = player.get_node(effect_name)
		effect.global_position = pos
		effect.restart()

func _spawn_weapon_trail(weapon_param):
	# Show weapon trail effect if weapon has one
	if weapon_param and "trail_particles" in weapon_param:
		var trail_name = weapon_param.trail_particles
		if player.has_node(trail_name):
			var trail = player.get_node(trail_name)
			trail.restart()
