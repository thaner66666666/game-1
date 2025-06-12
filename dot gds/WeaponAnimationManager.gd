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

func _play_sword_animation(weapon: WeaponResource, _attacker: Node3D):
	print("⚔️ Playing sword animation for: ", weapon.weapon_name)

func _play_bow_animation(weapon: WeaponResource, _attacker: Node3D):
	print("🏹 Playing bow animation for: ", weapon.weapon_name)

func _play_staff_animation(weapon: WeaponResource, _attacker: Node3D):
	print("🔮 Playing staff animation for: ", weapon.weapon_name)
