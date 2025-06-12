# WeaponAnimationManager.gd - Central manager for weapon attack animations
extends Node

# Animation duration constants
const SWORD_DURATION = 0.3
const BOW_DURATION = 0.3
const STAFF_DURATION = 0.22
const FIST_DURATION = 0.2

func play_attack_animation(weapon: WeaponResource, attacker: Node3D):
	"""Main entry point - routes to appropriate animator based on weapon type"""
	if not weapon:
		_play_fist_animation(attacker)
		return
	
	match weapon.weapon_type:
		WeaponResource.WeaponType.SWORD:
			_play_sword_animation(weapon, attacker)
		WeaponResource.WeaponType.BOW:
			_play_bow_animation(weapon, attacker)
		WeaponResource.WeaponType.STAFF:
			_play_staff_animation(weapon, attacker)
		_:
			_play_fist_animation(attacker)

func _play_fist_animation(attacker: Node3D):
	print("🥊 Playing fist animation for: ", attacker.name)
	# No animation here; handled by PlayerCombat punch animation

func _play_sword_animation(weapon: WeaponResource, attacker: Node3D):
	print("⚔️ Playing sword animation for: ", weapon.weapon_name)
	var wap = attacker
	if wap and wap.has_node("WeaponAttachPoint"):
		wap = wap.get_node("WeaponAttachPoint")
	if not wap:
		return
	var orig_pos = wap.position
	var orig_rot = wap.rotation
	var swing_arc = Vector3(0, deg_to_rad(-60), 0)
	var swing_offset = Vector3(0.1, 0, -0.2)
	var tween = wap.create_tween()
	tween.set_parallel(true)
	# Windup
	tween.tween_property(wap, "rotation", orig_rot + Vector3(0, deg_to_rad(-20), 0), SWORD_DURATION * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Swing
	tween.tween_property(wap, "rotation", orig_rot + swing_arc, SWORD_DURATION * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(SWORD_DURATION * 0.2)
	tween.tween_property(wap, "position", orig_pos + swing_offset, SWORD_DURATION * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(SWORD_DURATION * 0.2)
	# Return
	tween.tween_property(wap, "rotation", orig_rot, SWORD_DURATION * 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN).set_delay(SWORD_DURATION * 0.7)
	tween.tween_property(wap, "position", orig_pos, SWORD_DURATION * 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN).set_delay(SWORD_DURATION * 0.7)

func _play_bow_animation(weapon: WeaponResource, attacker: Node3D):
	print("🏹 Playing bow animation for: ", weapon.weapon_name)
	var wap = attacker
	if wap and wap.has_node("WeaponAttachPoint"):
		wap = wap.get_node("WeaponAttachPoint")
	if not wap:
		return
	var orig_pos = wap.position
	var orig_rot = wap.rotation
	var pull_offset = Vector3(0, 0, -0.25)
	var pull_rot = Vector3(deg_to_rad(-10), 0, 0)
	var release_rot = Vector3(deg_to_rad(10), 0, 0)
	var tween = wap.create_tween()
	tween.set_parallel(true)
	# Pull back
	tween.tween_property(wap, "position", orig_pos + pull_offset, BOW_DURATION * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(wap, "rotation", orig_rot + pull_rot, BOW_DURATION * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Release
	tween.tween_property(wap, "position", orig_pos, BOW_DURATION * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(BOW_DURATION * 0.4)
	tween.tween_property(wap, "rotation", orig_rot + release_rot, BOW_DURATION * 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(BOW_DURATION * 0.4)
	tween.tween_property(wap, "rotation", orig_rot, BOW_DURATION * 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN).set_delay(BOW_DURATION * 0.6)

func _play_staff_animation(weapon: WeaponResource, attacker: Node3D):
	print("🔮 Playing staff animation for: ", weapon.weapon_name)
	var wap = attacker
	if wap and wap.has_node("WeaponAttachPoint"):
		wap = wap.get_node("WeaponAttachPoint")
	if not wap:
		return
	var orig_pos = wap.position
	var orig_rot = wap.rotation
	var thrust_offset = Vector3(0, 0, -0.35)
	var thrust_rot = Vector3(deg_to_rad(-20), 0, 0)
	var tween = wap.create_tween()
	tween.set_parallel(true)
	# Windup
	tween.tween_property(wap, "position", orig_pos + Vector3(0, 0, 0.05), STAFF_DURATION * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(wap, "rotation", orig_rot + Vector3(deg_to_rad(10), 0, 0), STAFF_DURATION * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Thrust forward
	tween.tween_property(wap, "position", orig_pos + thrust_offset, STAFF_DURATION * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(STAFF_DURATION * 0.2)
	tween.tween_property(wap, "rotation", orig_rot + thrust_rot, STAFF_DURATION * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(STAFF_DURATION * 0.2)
	# Return
	tween.tween_property(wap, "position", orig_pos, STAFF_DURATION * 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN).set_delay(STAFF_DURATION * 0.7)
	tween.tween_property(wap, "rotation", orig_rot, STAFF_DURATION * 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN).set_delay(STAFF_DURATION * 0.7)
