extends Node

signal weapon_equipped(weapon_resource)
signal weapon_unequipped()

static var instance: WeaponManager

var base_stats: Dictionary = {}
var base_stats_stored: bool = false

var current_weapon: WeaponResource = null
var player: CharacterBody3D = null

func _enter_tree():
	if instance != null and instance != self:
		queue_free()
	else:
		instance = self

func get_player() -> CharacterBody3D:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		if not is_instance_valid(player):
			return null
	return player

func equip_weapon(weapon_resource: WeaponResource) -> void:
	if not get_player(): return
	current_weapon = weapon_resource
	_apply_weapon_to_player()
	var hand_manager = player.get_node_or_null("WeaponAttachPoint/SimpleHandManager")
	if hand_manager and hand_manager.has_method("refresh_weapon_hands"):
		hand_manager.refresh_weapon_hands()

func unequip_weapon() -> void:
	if not get_player(): return
	current_weapon = null
	_apply_weapon_to_player()
	var hand_manager = player.get_node_or_null("WeaponAttachPoint/SimpleHandManager")
	if hand_manager and hand_manager.has_method("refresh_weapon_hands"):
		hand_manager.refresh_weapon_hands()

func get_current_weapon() -> WeaponResource:
	return current_weapon

func is_weapon_equipped() -> bool:
	return current_weapon != null

func _apply_weapon_to_player() -> void:
	var p = get_player()
	if not p: return
	if not base_stats_stored:
		base_stats["attack_damage"] = p.get("attack_damage")
		base_stats["attack_range"] = p.get("attack_range")
		base_stats["attack_cooldown"] = p.get("attack_cooldown")
		base_stats["attack_cone_angle"] = p.get("attack_cone_angle")
		base_stats_stored = true
		print("💾 Player base stats cached.")

	if current_weapon != null:
		# ADD weapon stats to base stats instead of replacing
		p.set("attack_damage", base_stats.attack_damage + current_weapon.attack_damage)
		p.set("attack_range", base_stats.attack_range + current_weapon.attack_range)
		p.set("attack_cooldown", max(0.1, base_stats.attack_cooldown - (current_weapon.attack_cooldown * 0.1)))
		p.set("attack_cone_angle", base_stats.attack_cone_angle + current_weapon.attack_cone_angle)
		print("🗡️ Equipped: ", current_weapon.weapon_name, " (stats added to base)")
		emit_signal("weapon_equipped", current_weapon)
	else:
		# Restore base stats when unarmed
		p.set("attack_damage", base_stats.attack_damage)
		p.set("attack_range", base_stats.attack_range)
		p.set("attack_cooldown", base_stats.attack_cooldown)
		p.set("attack_cone_angle", base_stats.attack_cone_angle)
		print("👊 Unarmed. Player stats restored to base.")
		emit_signal("weapon_unequipped")
