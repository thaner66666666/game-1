# Thane's Godot Quick Reference Guide

## File Structure (Copy These Paths)
```
dot gds/     # All .gd scripts
Scenes/      # All .tscn files  
Weapons/     # .tres resources
```

## Script Template (Copy & Modify)
```gdscript
# script_name.gd - [Purpose]
extends Node3D

# === SIGNALS ===
signal something_happened

# === EXPORTS ===
@export_group("Settings")
@export var setting := 10

# === VARIABLES ===
var player: Node3D
var is_active := false

# === READY ===
func _ready():
    add_to_group("group_name")
    _find_references()
    print("✅ [SystemName]: Ready")

func _find_references():
    player = get_tree().get_first_node_in_group("player")
    if not player:
        print("❌ Player not found!")

# === PUBLIC METHODS ===
func do_something():
    if not _is_valid():
        return
    # Your code here

# === PRIVATE METHODS ===
func _is_valid() -> bool:
    return is_instance_valid(player)
```

## Essential Patterns

### Safe Node Access
```gdscript
# Always use this pattern
var node = get_node_or_null("NodeName")
if not node:
    print("❌ Node missing!")
    return
```

### Quick Logging
```gdscript
print("✅ Success")     # Good news
print("❌ Error")       # Problems  
print("🎮 Game")        # Game events
print("🗡️ Weapon")      # Weapons
print("💎 Loot")        # Loot/Items
print("🌊 Wave")        # Combat waves
```

### Component Setup
```gdscript
# In _ready():
if movement_component:
    movement_component.initialize(self)
    movement_component.signal_name.connect(_on_signal)
```

### Autoload Pattern
```gdscript
# For global systems, check project.godot autoloads:
if LootManager:
    LootManager.drop_loot(position)
```

## Quick Checklists

### New Script Checklist
- [ ] Header comment with purpose
- [ ] `add_to_group("group_name")`  
- [ ] Safe node references in `_find_references()`
- [ ] Error logging with ❌
- [ ] Success logging with ✅

### New Feature Checklist  
- [ ] Create in `dot gds/` folder
- [ ] Test with null references
- [ ] Add to UI if needed
- [ ] Connect to existing signals
- [ ] Test edge cases

### Debug Workflow
1. Check console for ❌ messages
2. Verify `get_node_or_null()` results
3. Add temporary `print()` statements
4. Test one component at a time

## Copy-Paste Code Blocks

### Signal Connection
```gdscript
# In _ready():
if node.has_signal("signal_name"):
    if not node.signal_name.is_connected(_on_signal):
        node.signal_name.connect(_on_signal)
```

### Timer Setup
```gdscript
var timer = Timer.new()
timer.wait_time = 1.0
timer.one_shot = true
timer.timeout.connect(_on_timer)
add_child(timer)
timer.start()
```

### Export Groups
```gdscript
@export_group("Combat")
@export var damage := 10
@export var cooldown := 1.0

@export_group("Movement") 
@export var speed := 5.0
```

### Enum States
```gdscript
enum State { IDLE, MOVING, ATTACKING }
var current_state := State.IDLE
```

## Quick Fixes for Common Issues

**Node not found?**
```gdscript
# Replace get_node() with:
var node = get_node_or_null("Path")
if not node: return
```

**Signal not working?**
```gdscript
# Check if already connected:
if not signal_name.is_connected(method):
    signal_name.connect(method)
```

**Null reference error?**
```gdscript
# Always check first:
if not is_instance_valid(object):
    return
```

## Project-Specific Quick References

### Your Autoloads
- `LootManager` - All loot drops
- `WeaponManager` - Weapon equipping  
- `WeaponPool` - Weapon database
- `DashEffectsManager` - Dash visuals

### Your Groups
- `"player"` - Player character
- `"enemies"` - All enemies
- `"spawner"` - Enemy spawner
- `"terrain"` - Room generator

### Common Node Paths
```gdscript
player = get_tree().get_first_node_in_group("player")
spawner = get_tree().get_first_node_in_group("spawner") 
terrain = get_tree().get_first_node_in_group("terrain")
```

---
**Speed Tips**: Use Ctrl+D to duplicate lines, Ctrl+/ to comment blocks, and keep this guide open in a second window while coding! 🚀