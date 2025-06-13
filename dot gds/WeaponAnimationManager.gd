# WeaponAnimationManager.gd - DRAMATIC weapon animations that move the hand
extends Node

const SWORD_DURATION = 0.8
const BOW_DURATION = 0.6
const STAFF_DURATION = 0.7

func play_attack_animation(weapon: WeaponResource, attacker: Node3D):
	"""Main entry point - use direct weapon_attach_point reference"""
	if not weapon:
		return
	
	# Get the RightHand node instead of just WeaponAttachPoint
	var right_hand = attacker.get_node_or_null("RightHand")
	if not right_hand or not is_instance_valid(right_hand):
		print("❌ RightHand not found on ", attacker.name)
		return
	
	print("✅ Found RightHand at: ", right_hand.get_path())
	
	match weapon.weapon_type:
		WeaponResource.WeaponType.SWORD:
			_play_dramatic_sword_animation(right_hand, attacker)
		WeaponResource.WeaponType.BOW:
			_play_dramatic_bow_animation(right_hand, attacker)
		WeaponResource.WeaponType.STAFF:
			_play_dramatic_staff_animation(right_hand, attacker)

func _play_dramatic_sword_animation(right_hand: Node3D, player: Node3D):
	"""REALISTIC SLASH: hand moves in a horizontal arc, sword rotates to face target during swing"""
	var orig_hand_pos = right_hand.position
	var orig_hand_rot = right_hand.rotation_degrees

	# Get body for additional drama
	var body = player.get_node_or_null("MeshInstance3D")
	var orig_body_pos = Vector3.ZERO
	var orig_body_rot = Vector3.ZERO
	if body:
		orig_body_pos = body.position
		orig_body_rot = body.rotation_degrees

	var tween = right_hand.create_tween()
	tween.set_parallel(true)

	# === PHASE 1: WINDUP (back and right, blade angled back) ===
	print("⚔️ SWORD: Realistic slash windup!")
	var windup_pos = orig_hand_pos + Vector3(0.7, 0.0, 0.3) # back and right
	var windup_rot = orig_hand_rot + Vector3(0, 70, 60) # blade edge angled back, wrist cocked
	var windup_time = SWORD_DURATION * 0.4
	tween.tween_property(right_hand, "position", windup_pos, windup_time)
	tween.tween_property(right_hand, "rotation_degrees", windup_rot, windup_time)
	if body:
		var body_windup_rot = orig_body_rot + Vector3(0, 40, 0)
		var body_windup_pos = orig_body_pos + Vector3(0.12, 0, 0.0)
		tween.tween_property(body, "rotation_degrees", body_windup_rot, windup_time)
		tween.tween_property(body, "position", body_windup_pos, windup_time)

	# === PHASE 2: SLASH (right to left, blade rotates to face target) ===
	var swing_delay = windup_time
	var swing_time = SWORD_DURATION * 0.32
	# Hand sweeps flat across the body, sword rotates to point at target
	var swing_pos = orig_hand_pos + Vector3(-0.9, 0.0, -0.3) # far left, same height
	var swing_rot = orig_hand_rot + Vector3(0, -110, -60) # blade edge now forward, wrist rotated
	var swing_pos_tween = tween.tween_property(right_hand, "position", swing_pos, swing_time)
	swing_pos_tween.set_delay(swing_delay)
	swing_pos_tween.set_trans(Tween.TRANS_ELASTIC)
	swing_pos_tween.set_ease(Tween.EASE_OUT)
	var swing_rot_tween = tween.tween_property(right_hand, "rotation_degrees", swing_rot, swing_time)
	swing_rot_tween.set_delay(swing_delay)
	swing_rot_tween.set_trans(Tween.TRANS_ELASTIC)
	swing_rot_tween.set_ease(Tween.EASE_OUT)
	if body:
		var body_swing_rot = orig_body_rot + Vector3(0, -70, 0)
		var body_swing_pos = orig_body_pos + Vector3(-0.18, 0, 0.0)
		var body_swing_rot_tween = tween.tween_property(body, "rotation_degrees", body_swing_rot, swing_time)
		body_swing_rot_tween.set_delay(swing_delay)
		body_swing_rot_tween.set_trans(Tween.TRANS_ELASTIC)
		body_swing_rot_tween.set_ease(Tween.EASE_OUT)
		var body_swing_pos_tween = tween.tween_property(body, "position", body_swing_pos, swing_time)
		body_swing_pos_tween.set_delay(swing_delay)

	# === PHASE 3: RECOVERY & RETURN ===
	var recovery_delay = swing_delay + swing_time
	var recovery_time = SWORD_DURATION * 0.28
	var return_pos_tween = tween.tween_property(right_hand, "position", orig_hand_pos, recovery_time)
	return_pos_tween.set_delay(recovery_delay)
	return_pos_tween.set_trans(Tween.TRANS_QUART)
	return_pos_tween.set_ease(Tween.EASE_IN_OUT)
	var return_rot_tween = tween.tween_property(right_hand, "rotation_degrees", orig_hand_rot, recovery_time)
	return_rot_tween.set_delay(recovery_delay)
	return_rot_tween.set_trans(Tween.TRANS_QUART)
	return_rot_tween.set_ease(Tween.EASE_IN_OUT)
	if body:
		var body_return_rot_tween = tween.tween_property(body, "rotation_degrees", orig_body_rot, recovery_time)
		body_return_rot_tween.set_delay(recovery_delay)
		body_return_rot_tween.set_trans(Tween.TRANS_QUART)
		body_return_rot_tween.set_ease(Tween.EASE_IN_OUT)
		var body_return_pos_tween = tween.tween_property(body, "position", orig_body_pos, recovery_time)
		body_return_pos_tween.set_delay(recovery_delay)
		body_return_pos_tween.set_trans(Tween.TRANS_QUART)
		body_return_pos_tween.set_ease(Tween.EASE_IN_OUT)
	_add_camera_shake(player, swing_delay + 0.1)

func _play_dramatic_bow_animation(right_hand: Node3D, player: Node3D):
	"""Dramatic bow draw and release"""
	var orig_pos = right_hand.position
	var orig_rot = right_hand.rotation_degrees
	
	var tween = right_hand.create_tween()
	tween.set_parallel(true)
	
	var draw_time = BOW_DURATION * 0.6
	var release_time = BOW_DURATION * 0.4
	
	# Draw back with tension
	var draw_pos = orig_pos + Vector3(-0.3, 0.1, -0.4)
	var draw_rot = orig_rot + Vector3(-20, -30, -10)
	
	var draw_pos_tween = tween.tween_property(right_hand, "position", draw_pos, draw_time)
	draw_pos_tween.set_trans(Tween.TRANS_QUART)
	draw_pos_tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(right_hand, "rotation_degrees", draw_rot, draw_time)
	
	# Snap release
	var release_pos = orig_pos + Vector3(0.1, 0, 0.1)
	
	var release_pos_tween = tween.tween_property(right_hand, "position", release_pos, release_time)
	release_pos_tween.set_delay(draw_time)
	release_pos_tween.set_trans(Tween.TRANS_BACK)
	release_pos_tween.set_ease(Tween.EASE_OUT)
	
	var release_rot_tween = tween.tween_property(right_hand, "rotation_degrees", orig_rot, release_time)
	release_rot_tween.set_delay(draw_time)

func _play_dramatic_staff_animation(right_hand: Node3D, player: Node3D):
	"""Dramatic staff thrust with magical energy"""
	var orig_pos = right_hand.position
	var orig_rot = right_hand.rotation_degrees
	
	var body = player.get_node_or_null("MeshInstance3D")
	var orig_body_rot = Vector3.ZERO
	if body:
		orig_body_rot = body.rotation_degrees
	
	var tween = right_hand.create_tween()
	tween.set_parallel(true)
	
	var charge_time = STAFF_DURATION * 0.4
	var thrust_time = STAFF_DURATION * 0.4
	var return_time = STAFF_DURATION * 0.2
	
	# Charge up
	var charge_pos = orig_pos + Vector3(0, 0.3, 0.2)
	var charge_rot = orig_rot + Vector3(-30, 0, 0)
	
	tween.tween_property(right_hand, "position", charge_pos, charge_time)
	tween.tween_property(right_hand, "rotation_degrees", charge_rot, charge_time)
	
	# Powerful thrust
	var thrust_pos = orig_pos + Vector3(0, -0.1, -0.6)
	var thrust_rot = orig_rot + Vector3(45, 0, 0)
	
	var thrust_pos_tween = tween.tween_property(right_hand, "position", thrust_pos, thrust_time)
	thrust_pos_tween.set_delay(charge_time)
	thrust_pos_tween.set_trans(Tween.TRANS_BACK)
	thrust_pos_tween.set_ease(Tween.EASE_OUT)
	
	var thrust_rot_tween = tween.tween_property(right_hand, "rotation_degrees", thrust_rot, thrust_time)
	thrust_rot_tween.set_delay(charge_time)
	
	# Body leans into the thrust
	if body:
		var body_thrust_rot = orig_body_rot + Vector3(0, 0, 15)
		var body_thrust_tween = tween.tween_property(body, "rotation_degrees", body_thrust_rot, thrust_time)
		body_thrust_tween.set_delay(charge_time)
	
	# Return
	var return_delay = charge_time + thrust_time
	
	var return_pos_tween = tween.tween_property(right_hand, "position", orig_pos, return_time)
	return_pos_tween.set_delay(return_delay)
	
	var return_rot_tween = tween.tween_property(right_hand, "rotation_degrees", orig_rot, return_time)
	return_rot_tween.set_delay(return_delay)
	
	if body:
		var body_return_tween = tween.tween_property(body, "rotation_degrees", orig_body_rot, return_time)
		body_return_tween.set_delay(return_delay)

func _add_camera_shake(player: Node3D, delay: float):
	"""Add camera shake for impact"""
	var camera = player.get_viewport().get_camera_3d()
	if camera and camera.has_method("shake"):
		var timer = player.get_tree().create_timer(delay)
		timer.timeout.connect(func(): _shake_camera(camera))

func _shake_camera(camera: Camera3D):
	"""Actually shake the camera if it supports it"""
	if camera.has_method("shake"):
		camera.shake(0.3, 8.0)
