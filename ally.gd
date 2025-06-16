extends CharacterBody3D

# Combat properties
var attack_cooldown := 1.0
var attack_damage := 10
var attack_range := 2.5
var _attack_timer := 0.0

# XP and Leveling properties
signal ally_xp_changed(new_xp, new_level)

var ally_xp := 0
var ally_level := 1
var ally_xp_to_next_level := 100

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    if _attack_timer > 0:
        _attack_timer -= delta

func try_attack():
    if _attack_timer <= 0:
        _play_attack_animation()
        _damage_enemies_in_cone()
        _attack_timer = attack_cooldown

func _play_attack_animation():
    # Simple swing animation
    if has_node("AnimationPlayer"):
        $AnimationPlayer.play("swing")
    # ...or trigger a basic animation if available...

func add_xp(amount: int) -> void:
    ally_xp += amount
    emit_signal("ally_xp_changed", ally_xp, ally_level)
    while ally_xp >= ally_xp_to_next_level:
        ally_xp -= ally_xp_to_next_level
        _level_up()

func _level_up() -> void:
    ally_level += 1
    ally_xp_to_next_level = int(ally_xp_to_next_level * 1.2)
    attack_damage += 2
    if has_method("increase_max_health"):
        increase_max_health(10)
    emit_signal("ally_xp_changed", ally_xp, ally_level)
    # Optionally: play level up animation/effects

func _damage_enemies_in_cone():
    var origin = global_transform.origin
    var forward = -global_transform.basis.z
    var cone_angle = deg2rad(60)
    var hit = false
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if not enemy.has_method("take_damage"):
            continue
        var to_enemy = enemy.global_transform.origin - origin
        var dist = to_enemy.length()
        if dist > attack_range:
            continue
        var dir = to_enemy.normalized()
        if forward.dot(dir) < cos(cone_angle * 0.5):
            continue
        var killed = enemy.take_damage(attack_damage)
        if killed:
            var xp = enemy.xp_value if enemy.has("xp_value") else 10
            add_xp(xp)
        hit = true
    return hit

func _gain_xp_from_enemy(enemy):
    if has_method("add_xp"):
        add_xp(enemy.xp_value if enemy.has("xp_value") else 10)