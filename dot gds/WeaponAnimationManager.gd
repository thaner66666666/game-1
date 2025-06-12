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

func _find_weapon_attach_point(attacker: Node3D) -> Node3D:
	"""FIXED: Find WeaponAttachPoint wherever it is"""
	# Try direct path first
	var wap = attacker.get_node_or_null("WeaponAttachPoint")
	if wap:
		return wap
	
	# Try under RightHand (current setup)
	wap = attacker.get_node_or_null("RightHand/WeaponAttachPoint")
	if wap:
		return wap
	
	# Search recursively
	return _search_for_weapon_attach_point(attacker)

func _search_for_weapon_attach_point(node: Node3D) -> Node3D:
	"""Recursively search for WeaponAttachPoint"""
	for child in node.get_children():
		if child.name == "WeaponAttachPoint":
			return child
		if child.get_child_count() > 0:
			var result = _search_for_weapon_attach_point(child)
			if result:
				return result
	return null

func _play_fist_animation(attacker: Node3D):
	print("🥊 Playing fist animation for: ", attacker.name)
	# No animation here; handled by PlayerCombat punch animation

func _play_sword_animation(weapon: WeaponResource, attacker: Node3D):
	print("⚔️ Playing sword animation for: ", weapon.weapon_name)
	
	var wap = _find_weapon_attach_point(attacker)
	if not wap:
		print("❌ WeaponAttachPoint not found!")
		return
	
	print("✅ Found WeaponAttachPoint at: ", wap.get_path())
	
	var orig_pos = wap.position
	var orig_rot = wap.rotation
	
	# Enhanced sword swing with proper arc
	var swing_arc = Vector3(deg_to_rad(-15), deg_to_rad(-60), deg_to_rad(10))  # More dramatic swing
	var swing_offset = Vector3(0.1, 0.1, -0.3)  # Forward and slightly up
	
	var tween = wap.create_tween()
	tween.set_parallel(true)
	
	# Windup - pull back slightly
	tween.tween_property(wap, "rotation", orig_rot + Vector3(deg_to_rad(10), deg_to_rad(-20), deg_to_rad(-5)), SWORD_DURATION * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(wap, "position", orig_pos + Vector3(-0.05, 0.05, 0.1), SWORD_DURATION * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Swing - dramatic arc motion
	tween.tween_property(wap, "rotation", orig_rot + swing_arc, SWORD_DURATION * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(SWORD_DURATION * 0.2)
	tween.tween_property(wap, "position", orig_pos + swing_offset, SWORD_DURATION * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(SWORD_DURATION * 0.2)
	
	# Return to original position
	tween.tween_property(wap, "rotation", orig_rot, SWORD_DURATION * 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN).set_delay(SWORD_DURATION * 0.7)
	tween.tween_property(wap, "position", orig_pos, SWORD_DURATION * 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN).set_delay(SWORD_DURATION * 0.7)

func _play_bow_animation(weapon: WeaponResource, attacker: Node3D):
	print("🏹 Playing bow animation for: ", weapon.weapon_name)
	
	var wap = _find_weapon_attach_point(attacker)
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
	
	var wap = _find_weapon_attach_point(attacker)
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
