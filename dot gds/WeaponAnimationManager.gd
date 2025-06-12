# WeaponAnimationManager.gd - FIXED: Simplified weapon animations
extends Node

const SWORD_DURATION = 0.4
const BOW_DURATION = 0.4
const STAFF_DURATION = 0.4

func play_attack_animation(weapon: WeaponResource, attacker: Node3D):
	"""Main entry point - use direct weapon_attach_point reference"""
	if not weapon:
		print("[WeaponAnimationManager] No weapon provided!")
		return
	if not weapon.has_method("get_visual_node"):
		print("[WeaponAnimationManager] Weapon missing get_visual_node() method!")
		return
	var weapon_visual = weapon.get_visual_node() if weapon.has_method("get_visual_node") else null
	if not weapon_visual or not is_instance_valid(weapon_visual):
		print("[WeaponAnimationManager] Weapon visual node is missing or invalid!")
		return
	
	# Get WeaponAttachPoint directly from player
	var wap = null
	if attacker.has_method("get") and "weapon_attach_point" in attacker:
		wap = attacker.weapon_attach_point
	
	if not wap or not is_instance_valid(wap):
		print("❌ WeaponAttachPoint not found or invalid on ", attacker.name)
		return
	
	print("✅ Found WeaponAttachPoint at: ", wap.get_path())
	print("[WeaponAnimationManager] Calling animation for weapon type: ", weapon.weapon_type)
	
	match weapon.weapon_type:
		WeaponResource.WeaponType.SWORD:
			_play_sword_animation(wap)
		WeaponResource.WeaponType.BOW:
			_play_bow_animation(wap)
		WeaponResource.WeaponType.STAFF:
			_play_staff_animation(wap)

func _play_sword_animation(wap: Node3D):
	var orig_pos = wap.position
	var orig_rot = wap.rotation_degrees
	
	var tween = wap.create_tween()
	tween.set_parallel(true)
	
	# Windup
	tween.tween_property(wap, "rotation_degrees", orig_rot + Vector3(10, -20, -5), SWORD_DURATION * 0.2)
	tween.tween_property(wap, "position", orig_pos + Vector3(-0.05, 0.05, 0.1), SWORD_DURATION * 0.2)
	
	# Swing
	tween.tween_property(wap, "rotation_degrees", orig_rot + Vector3(-15, -60, 10), SWORD_DURATION * 0.5).set_delay(SWORD_DURATION * 0.2)
	tween.tween_property(wap, "position", orig_pos + Vector3(0.1, 0.1, -0.3), SWORD_DURATION * 0.5).set_delay(SWORD_DURATION * 0.2)
	
	# Return
	tween.tween_property(wap, "rotation_degrees", orig_rot, SWORD_DURATION * 0.3).set_delay(SWORD_DURATION * 0.7)
	tween.tween_property(wap, "position", orig_pos, SWORD_DURATION * 0.3).set_delay(SWORD_DURATION * 0.7)

func _play_bow_animation(wap: Node3D):
	var orig_pos = wap.position
	var orig_rot = wap.rotation_degrees
	
	var tween = wap.create_tween()
	tween.set_parallel(true)
	
	# Pull back
	tween.tween_property(wap, "position", orig_pos + Vector3(0, 0, -0.25), BOW_DURATION * 0.4)
	tween.tween_property(wap, "rotation_degrees", orig_rot + Vector3(-10, 0, 0), BOW_DURATION * 0.4)
	
	# Release
	tween.tween_property(wap, "position", orig_pos, BOW_DURATION * 0.6).set_delay(BOW_DURATION * 0.4)
	tween.tween_property(wap, "rotation_degrees", orig_rot, BOW_DURATION * 0.6).set_delay(BOW_DURATION * 0.4)

func _play_staff_animation(wap: Node3D):
	var orig_pos = wap.position
	var orig_rot = wap.rotation_degrees
	
	var tween = wap.create_tween()
	tween.set_parallel(true)
	
	# Thrust
	tween.tween_property(wap, "position", orig_pos + Vector3(0, 0, -0.35), STAFF_DURATION * 0.6)
	tween.tween_property(wap, "rotation_degrees", orig_rot + Vector3(-20, 0, 0), STAFF_DURATION * 0.6)
	
	# Return
	tween.tween_property(wap, "position", orig_pos, STAFF_DURATION * 0.4).set_delay(STAFF_DURATION * 0.6)
	tween.tween_property(wap, "rotation_degrees", orig_rot, STAFF_DURATION * 0.4).set_delay(STAFF_DURATION * 0.6)

# Debug/test function to manually trigger weapon animation
func test_play_animation(attacker: Node3D):
	print("[WeaponAnimationManager] test_play_animation called!")
	var weapon = WeaponManager.get_current_weapon() if WeaponManager.is_weapon_equipped() else null
	if not weapon:
		print("[WeaponAnimationManager] No weapon equipped for test!")
		return
	play_attack_animation(weapon, attacker)
