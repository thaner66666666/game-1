extends Node
class_name AllyAI

enum State { FOLLOWING, MOVING_TO_TARGET, ATTACKING, RETREATING }

var ally_ref
var current_state := State.FOLLOWING
var player_target
var enemy_target
var state_update_timer := 0.0
var state_update_interval := 0.1  # Update AI state 10 times per second
var attack_delay_timer := 0.0
var attack_delay := 0.0
var retreat_timer := 0.0

func setup(ally):
	ally_ref = ally

func set_player_target(player):
	player_target = player

func _process(delta):
	state_update_timer += delta
	if state_update_timer >= state_update_interval:
		_update_ai_state()
		state_update_timer = 0.0
	_execute_current_state(delta)

func _update_ai_state():
	if not player_target:
		return
	# Find nearest enemy
	enemy_target = ally_ref.combat_component.find_nearest_enemy()
	var previous_state = current_state
	# Retreat if low health
	if ally_ref.health_component.current_health < ally_ref.max_health * 0.25 and enemy_target:
		current_state = State.RETREATING
		retreat_timer = 1.0 + randf() * 1.5
		return
	# State logic
	if enemy_target:
		var distance_to_enemy = ally_ref.global_position.distance_to(enemy_target.global_position)
		if distance_to_enemy <= ally_ref.combat_component.attack_range:
			current_state = State.ATTACKING
		elif distance_to_enemy <= ally_ref.combat_component.detection_range:
			current_state = State.MOVING_TO_TARGET
		else:
			current_state = State.FOLLOWING
	else:
		current_state = State.FOLLOWING
	if previous_state != current_state:
		print("🤖 Ally AI: ", State.keys()[previous_state], " → ", State.keys()[current_state])

func _execute_current_state(delta: float):
	match current_state:
		State.FOLLOWING:
			_handle_following(delta)
		State.MOVING_TO_TARGET:
			_handle_moving_to_target(delta)
		State.ATTACKING:
			_handle_attacking(delta)
		State.RETREATING:
			_handle_retreating(delta)

func _handle_following(delta: float):
	if not player_target:
		return
	var distance_to_player = ally_ref.global_position.distance_to(player_target.global_position)
	if distance_to_player > ally_ref.movement_component.follow_distance:
		ally_ref.movement_component.move_towards_target(player_target.global_position, delta)
	else:
		ally_ref.movement_component.orbit_around_player(player_target, delta)
	ally_ref.movement_component.apply_separation(delta)

func _handle_moving_to_target(delta: float):
	if not enemy_target:
		current_state = State.FOLLOWING
		return
	# Strafe/circle around enemy
	ally_ref.movement_component.strafe_around_target(enemy_target, delta)
	ally_ref.movement_component.apply_separation(delta)

func _handle_attacking(delta: float):
	if not enemy_target:
		current_state = State.FOLLOWING
		return
	# Add random attack delay for realism
	if attack_delay_timer > 0:
		attack_delay_timer -= delta
		return
	if randf() < 0.1:
		attack_delay = 0.1 + randf() * 0.3
		attack_delay_timer = attack_delay
		return
	ally_ref.combat_component.attack_target(enemy_target)
	ally_ref.velocity.x = move_toward(ally_ref.velocity.x, 0, ally_ref.speed * 2 * delta)
	ally_ref.velocity.z = move_toward(ally_ref.velocity.z, 0, ally_ref.speed * 2 * delta)

func _handle_retreating(delta: float):
	if retreat_timer > 0:
		retreat_timer -= delta
		# Move away from enemy
		if enemy_target:
			ally_ref.movement_component.move_away_from_target(enemy_target.global_position, delta)
		return
	current_state = State.FOLLOWING
