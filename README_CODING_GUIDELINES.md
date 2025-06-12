# Thane's Godot Coding Guidelines

## Script Structure
- Header comment: purpose, author, last modified, Godot version
- Exported variables at the top, private variables next
- Built-in Godot functions separated from custom functions
- Each function: single responsibility, clear comments

## Code Style
- Descriptive variable names (e.g., player_health)
- Clear comments explaining what and why
- Break complex logic into smaller functions
- Error handling and edge case checks
- Explain Godot-specific concepts (nodes, scenes, signals, etc.)

## Folder & Naming Conventions
- scripts/: All GDScript files
- scenes/: All .tscn scene files
- assets/: Art, models, audio, etc.
- resources/: .tres, .res, and data files
- Use descriptive file names (e.g., PlayerController.gd)

## Godot Best Practices
- Prefer signals over direct calls for loose coupling
- Use .tres resources for data that might change
- Use autoloads sparingly
- Always check if nodes/resources exist before using them
- Use is_valid() checks
- Handle edge cases (e.g., player falls off world)
- Test with different input scenarios

## Debugging & Testing Checklist
- Check error console
- Verify node paths/names
- Confirm exported variables are set
- Test in isolation
- Check Godot version compatibility

## Resources
- Godot Docs: https://docs.godotengine.org/
- GDScript Style Guide
- Common Patterns: Singleton, Observer, State Machine, Object Pooling

---
Use the provided GDScriptTemplate.gd for new scripts. Review this file before submitting or testing new code.
