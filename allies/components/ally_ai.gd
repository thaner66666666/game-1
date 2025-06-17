extends Node
class_name AllyAI

enum State { FOLLOWING, MOVING_TO_TARGET, ATTACKING }

var ally_ref
var current_state := State.FOLLOWING
var player_target
var enemy_target
var state_update_timer := 0.0
var state_update_interval := 0.1  # Update AI state 10 times per second

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
	
	# Debug state changes
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

func _handle_following(delta: float):
	if not player_target:
		return
	
	var distance_to_player = ally_ref.global_position.distance_to(player_target.global_position)
	
	if distance_to_player > ally_ref.movement_component.follow_distance:
		# Move towards player
		ally_ref.movement_component.move_towards_target(player_target.global_position, delta)
	else:
		# Orbit around player
		ally_ref.movement_component.orbit_around_player(player_target, delta)
	
	# Always apply separation
	ally_ref.movement_component.apply_separation(delta)

func _handle_moving_to_target(delta: float):
	if not enemy_target:
		current_state = State.FOLLOWING
		return
	
	ally_ref.movement_component.move_towards_target(enemy_target.global_position, delta)
	ally_ref.movement_component.apply_separation(delta)

func _handle_attacking(delta: float):
	if not enemy_target:
		current_state = State.FOLLOWING
		return
	
	# Try to attack
	ally_ref.combat_component.attack_target(enemy_target)
	
	# Stop moving while attacking
	ally_ref.velocity.x = move_toward(ally_ref.velocity.x, 0, ally_ref.speed * 2 * delta)
	ally_ref.velocity.z = move_toward(ally_ref.velocity.z, 0, ally_ref.speed * 2 * delta)
