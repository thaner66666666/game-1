extends Resource
class_name WeaponResource

# WeaponType enum for cross-script compatibility
enum WeaponType { UNARMED, SWORD, BOW, STAFF }

@export var weapon_name: String = "Fist"
@export var attack_damage: int = 10
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.0
@export var attack_cone_angle: float = 90.0

# Store weapon_type as int for compatibility with hand system
@export var weapon_type: int = WeaponType.SWORD

@export var visual_scene_path: String = ""
