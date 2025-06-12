extends Node2D

export(PackedScene) var enemy_scene
export var wave_size = 5
export var spawn_radius = 300
export var spawn_cooldown = 1.0

var next_spawn_time = 0.0

func _ready():
    next_spawn_time = OS.get_ticks_msec() / 1000.0 + spawn_cooldown

func spawn_wave():
    if enemy_scene == null:
        push_error("enemy_scene is null! Assign a PackedScene in the inspector.")
        return
    
    for i in range(wave_size):
        var enemy = enemy_scene.instance()
        var spawn_position = position + Vector2(randf_range(-spawn_radius, spawn_radius), randf_range(-spawn_radius, spawn_radius))
        enemy.position = spawn_position
        get_parent().add_child(enemy)

func _process(delta):
    if OS.get_ticks_msec() / 1000.0 >= next_spawn_time:
        spawn_wave()
        next_spawn_time += spawn_cooldown