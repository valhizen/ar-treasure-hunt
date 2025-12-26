## Project Guidelines

### Folder Structure
- "Scenes" must be stored in "/Scenes".
- "Scripts" must be stored in "/Scripts".

### File Naming Conventions
- Scene resource names use PascalCase (e.g., "CameraArm").
- Saved file names for scenes and scripts use snake_case (e.g., "main_character.tscn"). Godot saves files in snake_case by default.

### Scene Organization
- Keep scenes distinct and descriptive to make them easy to find and understand.
- Prefer self-contained scenes with clear purposes.

### Branching Strategy
- "dev" branch contains the most recent changes.
- "master" branch is the stable branch.

### Contribution Workflow
- Fork the repository.
- Work on your fork and submit pull requests to "dev".
- Changes will be merged into "master" after validation.
- The repository is updated periodically.


#### MiniGames
- keep all the components of the minigame in itself in MiniGames/
- prefix the main scene of the minigame with a "_" (eg: "_maze_mini_game.tscn" )
- see MiniGames/Maze for example

#### TODOS
- music and sfx in maze game
- music , sfx and particles in wood carving game
- better assets
- better UI in wood carving game