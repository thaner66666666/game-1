// Enhanced godot-mcp-server.js with project knowledge

// Add project-specific metadata
const PROJECT_CONFIG = {
  name: "Game Version 3",
  engine: "Godot 4.x",
  genre: "3D Action RPG",
  architecture: "Component-based with Manager pattern",
  
  // Key systems and their relationships
  systems: {
    combat: ["PlayerCombat.gd", "WeaponManager.gd", "damage_numbers.gd"],
    loot: ["LootManager.gd", "treasure_chest.gd", "weapon_pickup.gd"],
    ui: ["UI.gd", "health_potion.gd", "loading_screen.gd"],
    world: ["terrain_generator.gd", "simple_room_generator.gd"],
    player: ["player.gd", "PlayerMovement.gd", "DashEffectsManager.gd"]
  },
  
  // Coding standards for this project
  standards: {
    naming: "PascalCase for scripts, snake_case for scenes",
    patterns: ["Manager pattern", "Signal-based communication", "Resource files for data"],
    priorities: ["Beginner-friendly", "Modular design", "Export variables for configuration"]
  },
  
  // Current development focus
  currentGoals: [
    "Enhanced combat feedback",
    "Better UI/UX systems", 
    "Player progression",
    "Audio/visual polish"
  ]
};

// Function to provide context about file relationships
function getFileContext(filename) {
  // Analyze which system this file belongs to
  for (const [system, files] of Object.entries(PROJECT_CONFIG.systems)) {
    if (files.some(f => filename.includes(f.replace('.gd', '')))) {
      return {
        system: system,
        relatedFiles: files,
        description: `Part of ${system} system`
      };
    }
  }
  return null;
}

// Enhanced file reading with context
function readFileWithContext(filename) {
  const content = readFile(filename);
  const context = getFileContext(filename);
  
  return {
    filename,
    content,
    context,
    projectStandards: PROJECT_CONFIG.standards,
    currentGoals: PROJECT_CONFIG.currentGoals
  };
}