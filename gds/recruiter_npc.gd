extends StaticBody3D

var player_in_range := false

func _ready():
    $Area3D.connect("body_entered", self, "_on_player_entered")
    $Area3D.connect("body_exited", self, "_on_player_exited")
    # Set up appearance using CharacterAppearanceManager
    var appearance_manager = CharacterAppearanceManager.new()
    appearance_manager.apply_recruiter_appearance(self)

func _on_player_entered(body):
    if body.name == "Player":
        player_in_range = true

func _on_player_exited(body):
    if body.name == "Player":
        player_in_range = false

func _input(event):
    if player_in_range and event.is_action_pressed("interaction"):
        _recruit_footman()

func _recruit_footman():
    var ally_scene = load("res://Scenes/ally.tscn")
    var ally = ally_scene.instantiate()
    ally.global_transform = self.global_transform
    # Set up ally with basic equipment
    ally.equip_weapon(load("res://Weapons/iron_sword.tres"))
    # Optionally set other properties or appearance
    get_parent().add_child(ally)
    queue_free()