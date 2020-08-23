# Todos

## Autotiling
- [ ] Autotile algorithm should check the current tile type against the neighboring tile type to determine what type of tile to use for autotiling. This can allow us to vary our designs when we have tiles regions next to each other but are of different types. For example, we can go from regular floor to bridge and then back to regular floor.

## Game Session loading/saving
- [ ] option in main menu to create a new game which generates a new session reference.
- [ ] on game load
  1. process session log and update the state
  2. save the newly processed state to disk
  3. delete session file? (or maybe keep x most recent session files)

## Skill tree editor
- [ ] tree node tooltips
- [x] skill tree point counter
- [x] mousewheel zoom
- [x] panning via drag
