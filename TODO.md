# Todos

## Lighting system
  - [ ] We can try using painter's algorithm (y sort) for properly stacking the lights. Anything that doesn't emit light should be painted as black (zero out all color channels) which could then be painted in another step using an additive blend mode. This way, all the black areas will never get painted and the bright areas will get stenciled out.

## Entity Collision
  - [x] Add rectangle collision support. We should create a static method for testing collisions so it can handle various collision types.

## Unit tests
  - [x] Add unit test for checking memory leaks when creating new game and tearing it down.

## Bugs
  - [ ] `gameState` can sometimes end up in a bad state which cannot be loaded up next time. Its possible that the thread did not finish processing the most recent event.

## Quests
  - [ ] When boss is killed, activate quest to `talk to the bounty provider in town`. Upon interacting with bounty provider, reward the player with a new passive skill point and trigger the `level up` effect but say `new skill point gained`.
  - [x] Show indicator above npc when there is something new for the player to do.

## Game state
  - [x] Integrate inventory state

## Projectile abilities
  - [x] `channelBeam` ability should have a tick cooldown per target. This way the first hit will hit immediately on each new target. Currently the tick cooldown is a global which can cause undesirable situations when hitting things like interactable props.
  - [x] Remove `damage` property on all classes and instead use the `EntityStats.StatsRef.damage` property for damage calculation.

## Skill tree editor
  - [ ] tree node tooltips
  - [x] skill tree point counter
  - [x] mousewheel zoom
  - [x] panning via drag

## UI
  - [ ] See if we can get rid of hover state since it adds too much complexity for ui state management. There simply is just too many possible combinations which causes a problem of state mutation.

## SpriteBatch System
  - [ ] Use a global particle pool which should give a pretty large performance boost since we don't have to recreate new objects each frame. This will be especially important when we're using flashy particles.


## Game Session loading/saving
  - [ ] [PERFORMANCE ENHANCEMENT] save updated state to disk upon processing and loading the file. Currently the only time it gets saved is when a new session begins. This means each time we read the latest game file, it will re-process it again, which will slow the home screen down since we are always re-reading the file.
  - [x] option to clear an existing game slot by pressing a `delete` button to the right of the game slot
  - [x] option in main menu to create a new game which generates a new session reference.
    1. create new session based on previous session
  - [x] on game load
    1. process session log and update the state
    2. save the newly processed state to disk
    3. delete session file? (or maybe keep x most recent session files)

## Autotiling
  - [ ] Autotile algorithm should check the current tile type against the neighboring tile type to determine what type of tile to use for autotiling. This can allow us to vary our designs when we have tiles regions next to each other but are of different types. For example, we can go from regular floor to bridge and then back to regular floor.

## Entity System Performance
  - [x] Replace all base stats on `Entity` class such as `health` and `speed` with the `EntityStats.StatsRef` data structure. This way all stats are being handled by the stats system instead and keeps things nicely data driven with support for modifier events as well.
  - [ ] [PERFORMANCE ENHANCEMENT] We can reuse `EntityStats.StatsRef` instances by pooling them and releasing them back to the pool when an entity is destroyed. This way we can don't have to create a bunch of garbage which will be useful for when we want to create things like a multiple bullet spread. (Be sure to benchmark to validate that this will increase performance).

## Treasure Chest
  - [x] Interacting with treasure chest drops loot

