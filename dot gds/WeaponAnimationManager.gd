# WeaponAnimationManager.gd - BARE BONES: Start simple and build up
extends Node

func play_attack_animation(weapon: WeaponResource, attacker: Node3D):
	"""Main entry point - only handle sword for now"""
	if not weapon:
		print("❌ No weapon provided")
		return
	
	# Updated hand finding logic
	var right_hand = attacker.get_node_or_null("RightHandAnchor/RightHand")
	if not right_hand:
		print("❌ No RightHand found on ", attacker.name)
		return
	
	print("✅ Starting animation for ", weapon.weapon_name)
	
	# Only handle sword for now
	if weapon.weapon_type == WeaponResource.WeaponType.SWORD:
		_simple_sword_animation(right_hand)
	else:
		print("⚠️ Only sword animations implemented so far")


func _simple_sword_animation(right_hand: Node3D):
	"""SMOOTH CARTOONY SWORD SLASH - Exaggerated with bouncy easing!"""
	print("🗡️ Starting SMOOTH CARTOONY sword slash!")
	# Find the weapon attachment point
	var weapon_attach = right_hand.get_node_or_null("WeaponAttachPoint")
	if not weapon_attach:
		print("⚠️ No weapon attachment point found")
		return
	# Remember where we started
	var original_position = right_hand.position
	var original_rotation = Vector3(0, 0, -90)
	weapon_attach.rotation_degrees = original_rotation
	print("✅ Creating SMOOTH CARTOONY arcing sword slash!")
	# Create the animation with smooth easing
	var tween = right_hand.create_tween()
	tween.set_parallel(true)
	# STEP 1: ANTICIPATION - Wind up REALLY far back and up (more anticipation)
	var windup_position = original_position + Vector3(0.6, 0.5, 0.3)   # WAY up, right, and BACK
	var windup_rotation = original_rotation + Vector3(0, 0, 80)        # Really cocked back
	# Use BACK easing for cartoony anticipation
	var windup_pos_tween = tween.tween_property(right_hand, "position", windup_position, 0.25)
	windup_pos_tween.set_trans(Tween.TRANS_BACK)
	windup_pos_tween.set_ease(Tween.EASE_OUT)
	var windup_rot_tween = tween.tween_property(weapon_attach, "rotation_degrees", windup_rotation, 0.25)
	windup_rot_tween.set_trans(Tween.TRANS_BACK)
	windup_rot_tween.set_ease(Tween.EASE_OUT)
	print("⚔️ ANTICIPATION: Winding up REALLY far back and UP!")
	# STEP 2: CIRCULAR SWOOPING SLASH - Create multiple points for smooth arc
	print("⚔️ SWOOSH: Starting circular swooping motion!")
	# Point 1: Start of arc (high right) - HIGHER up
	var arc1_position = original_position + Vector3(0.3, 0.4, 0.4)    # Much higher
	var arc1_rotation = original_rotation + Vector3(0, 0, -20)
	var arc1_pos_tween = tween.tween_property(right_hand, "position", arc1_position, 0.08)
	arc1_pos_tween.set_delay(0.25)
	arc1_pos_tween.set_trans(Tween.TRANS_SINE)
	arc1_pos_tween.set_ease(Tween.EASE_IN)
	var arc1_rot_tween = tween.tween_property(weapon_attach, "rotation_degrees", arc1_rotation, 0.08)
	arc1_rot_tween.set_delay(0.25)
	arc1_rot_tween.set_trans(Tween.TRANS_SINE)
	arc1_rot_tween.set_ease(Tween.EASE_IN)
	# Point 2: Middle of arc (center forward) - HIGHER up
	var arc2_position = original_position + Vector3(0, 0.2, 0.7)       # Much higher
	var arc2_rotation = original_rotation + Vector3(0, 0, -60)
	var arc2_pos_tween = tween.tween_property(right_hand, "position", arc2_position, 0.08)
	arc2_pos_tween.set_delay(0.33)
	arc2_pos_tween.set_trans(Tween.TRANS_SINE)
	arc2_pos_tween.set_ease(Tween.EASE_IN_OUT)
	var arc2_rot_tween = tween.tween_property(weapon_attach, "rotation_degrees", arc2_rotation, 0.08)
	arc2_rot_tween.set_delay(0.33)
	arc2_rot_tween.set_trans(Tween.TRANS_SINE)
	arc2_rot_tween.set_ease(Tween.EASE_IN_OUT)
	# Point 3: End of arc (low left) - Start the 180 spin here
	var arc3_position = original_position + Vector3(-0.4, -0.1, 0.8)   # Not as low, preparing for spin
	var arc3_rotation = original_rotation + Vector3(0, 0, -100)
	var arc3_pos_tween = tween.tween_property(right_hand, "position", arc3_position, 0.08)
	arc3_pos_tween.set_delay(0.41)
	arc3_pos_tween.set_trans(Tween.TRANS_SINE)
	arc3_pos_tween.set_ease(Tween.EASE_OUT)
	var arc3_rot_tween = tween.tween_property(weapon_attach, "rotation_degrees", arc3_rotation, 0.08)
	arc3_rot_tween.set_delay(0.41)
	arc3_rot_tween.set_trans(Tween.TRANS_SINE)
	arc3_rot_tween.set_ease(Tween.EASE_OUT)
	print("⚔️ HIGH CIRCULAR ARC: Swooping in smooth HIGH circle!")
	# STEP 3: BIG FOLLOW-THROUGH with 180-degree SWORD SPIN!
	var followthrough_position = original_position + Vector3(-0.9, -0.3, 0.6)  # Way out but not as low
	var followthrough_rotation = original_rotation + Vector3(0, 180, -130)      # 180-degree Y-axis SPIN!
	var followthrough_pos_tween = tween.tween_property(right_hand, "position", followthrough_position, 0.15)
	followthrough_pos_tween.set_delay(0.49)
	followthrough_pos_tween.set_trans(Tween.TRANS_QUART)
	followthrough_pos_tween.set_ease(Tween.EASE_OUT)
	var followthrough_rot_tween = tween.tween_property(weapon_attach, "rotation_degrees", followthrough_rotation, 0.15)
	followthrough_rot_tween.set_delay(0.49)
	followthrough_rot_tween.set_trans(Tween.TRANS_BACK)  # Back easing for the dramatic spin
	followthrough_rot_tween.set_ease(Tween.EASE_OUT)
	print("⚔️ BIG FOLLOW-THROUGH: 180-degree sword SPIN for dramatic slash!")
	# STEP 4: BOUNCE BACK - Return with bouncy easing from the big follow-through
	var return_pos_tween = tween.tween_property(right_hand, "position", original_position, 0.5)
	return_pos_tween.set_delay(0.64)  # After all the arc motion and follow-through
	return_pos_tween.set_trans(Tween.TRANS_ELASTIC)
	return_pos_tween.set_ease(Tween.EASE_OUT)
	var return_rot_tween = tween.tween_property(weapon_attach, "rotation_degrees", original_rotation, 0.5)
	return_rot_tween.set_delay(0.64)
	return_rot_tween.set_trans(Tween.TRANS_ELASTIC)
	return_rot_tween.set_ease(Tween.EASE_OUT)
	print("⚔️ BOUNCE BACK: Returning with cartoony bounce after big follow-through!")
	print("🗡️ DRAMATIC SWOOPING SLASH with 180° SPIN complete - should feel like a powerful slash with sword flip!")
