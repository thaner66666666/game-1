# WeaponManager.gd
# Manages weapon equipping, unequipping, and stat application for the player.
# Uses signals for communication and follows the manager/component pattern.
# Beginner-friendly comments and modular functions included.

extends Node

class_name WeaponManager # For global accessibility and singleton pattern

signal weapon_equipped(weapon_resource)
signal weapon_unequipped()
# New: Signal for stat changes (for UI, etc.)
signal weapon_stats_changed(new_stats: Dictionary)

# Exported variables for designer configuration
@export var default_weapon: Resource = null # Assign a default weapon in the editor
@export var debug_mode: bool = false

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

# --- Modular stat application functions ---

# Caches the player's base stats for restoration later
func cache_base_stats(p: CharacterBody3D) -> void:
	if not base_stats_stored:
		base_stats["attack_damage"] = p.get("attack_damage")
		base_stats["attack_range"] = p.get("attack_range")
		base_stats["attack_cooldown"] = p.get("attack_cooldown")
		base_stats["attack_cone_angle"] = p.get("attack_cone_angle")
		base_stats_stored = true
		if debug_mode:
			print("💾 Player base stats cached.")

# Applies the current weapon's stats to the player
func apply_weapon_stats(p: CharacterBody3D) -> void:
	if current_weapon != null:
		# Add weapon stats to base stats instead of replacing
		p.set("attack_damage", base_stats.attack_damage + current_weapon.attack_damage)
		p.set("attack_range", base_stats.attack_range + current_weapon.attack_range)
		p.set("attack_cooldown", max(0.1, base_stats.attack_cooldown - (current_weapon.attack_cooldown * 0.1)))
		p.set("attack_cone_angle", base_stats.attack_cone_angle + current_weapon.attack_cone_angle)
		if debug_mode:
			print("🗡️ Equipped: ", current_weapon.weapon_name, " (stats added to base)")
		emit_signal("weapon_equipped", current_weapon)
		emit_signal("weapon_stats_changed", {
			"attack_damage": p.get("attack_damage"),
			"attack_range": p.get("attack_range"),
			"attack_cooldown": p.get("attack_cooldown"),
			"attack_cone_angle": p.get("attack_cone_angle")
		})

# Restores the player's base stats when unarmed
func restore_base_stats(p: CharacterBody3D) -> void:
	p.set("attack_damage", base_stats.attack_damage)
	p.set("attack_range", base_stats.attack_range)
	p.set("attack_cooldown", base_stats.attack_cooldown)
	p.set("attack_cone_angle", base_stats.attack_cone_angle)
	if debug_mode:
		print("👊 Unarmed. Player stats restored to base.")
	emit_signal("weapon_unequipped")
	emit_signal("weapon_stats_changed", base_stats)

# Applies or restores stats based on current weapon
def _apply_weapon_to_player() -> void:
	var p = get_player()
	if not p: return
	cache_base_stats(p)
	if current_weapon != null:
		apply_weapon_stats(p)
	else:
		restore_base_stats(p)

# --- End modular stat functions ---

# Example usage:
# WeaponManager.equip_weapon(my_weapon_resource)
# Connect to 'weapon_stats_changed' to update UI when stats change.
#
# For beginners: See comments above each function for what it does.
# Use export variables in the Godot editor to set defaults.
#
# This script is a singleton (autoload) and can be accessed globally.
#
# For more info, see project instructions.
