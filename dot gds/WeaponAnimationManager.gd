# WeaponAnimationManager.gd - Enhanced weapon animation system with speed scaling
extends Node

func play_attack_animation(weapon: WeaponResource, attacker: Node3D):
	"""Use the existing AnimationPlayer system for weapon animations with speed scaling"""
	if not weapon:
		print("❌ No weapon provided")
		return
	
	# Find the WeaponAnimationPlayer on the attacker
	var anim_player = attacker.get_node_or_null("WeaponAnimationPlayer")
	if not anim_player:
		print("❌ No WeaponAnimationPlayer found on ", attacker.name)
		return
	
	print("✅ Starting animation for ", weapon.weapon_name)
	
	# Choose animation based on weapon type
	var animation_name = ""
	match weapon.weapon_type:
		WeaponResource.WeaponType.SWORD:
			animation_name = "sword_slash"
		WeaponResource.WeaponType.BOW:
			animation_name = "Bow"  # Fixed case to match actual animation name
		WeaponResource.WeaponType.STAFF:
			animation_name = "staff_cast"  # Add this animation to player.tscn if needed
		_:
			animation_name = "punch"  # Fallback
	
	# Play the animation if it exists, otherwise fallback to punch
	if anim_player.has_animation(animation_name):
		anim_player.play(animation_name)
		
		# Calculate animation speed based on weapon attack cooldown
		var speed_scale = _calculate_animation_speed(weapon)
		anim_player.speed_scale = speed_scale
		
		print("✅ Playing ", animation_name, " animation at ", speed_scale, "x speed")
	else:
		print("⚠️ No ", animation_name, " animation found, using punch")
		anim_player.play("punch")
		anim_player.speed_scale = 1.0  # Reset speed for fallback

func _calculate_animation_speed(weapon: WeaponResource) -> float:
	"""Calculate animation speed based on weapon properties"""
	# Special handling for specific weapons
	if weapon.weapon_name == "DEV Rapid Fire Bow":
		return 5.0  # 5x faster for dev rapid fire bow
	
	# General speed scaling based on attack cooldown
	# Faster weapons (lower cooldown) get faster animations
	if weapon.attack_cooldown <= 0.15:
		return 4.0  # Very fast weapons
	elif weapon.attack_cooldown <= 0.25:
		return 2.5  # Fast weapons
	elif weapon.attack_cooldown <= 0.5:
		return 1.5  # Medium-fast weapons
	else:
		return 1.0  # Normal speed

func reset_animation_speed(attacker: Node3D):
	"""Reset animation speed to normal (useful for weapon switching)"""
	var anim_player = attacker.get_node_or_null("WeaponAnimationPlayer")
	if anim_player:
		anim_player.speed_scale = 1.0
		print("🔄 Reset animation speed to normal")

func is_animation_playing(attacker: Node3D) -> bool:
	"""Check if any weapon animation is currently playing"""
	var anim_player = attacker.get_node_or_null("WeaponAnimationPlayer")
	if anim_player:
		return anim_player.is_playing()
	return false

func get_current_animation(attacker: Node3D) -> String:
	"""Get the name of the currently playing animation"""
	var anim_player = attacker.get_node_or_null("WeaponAnimationPlayer")
	if anim_player and anim_player.is_playing():
		return anim_player.current_animation
	return ""
