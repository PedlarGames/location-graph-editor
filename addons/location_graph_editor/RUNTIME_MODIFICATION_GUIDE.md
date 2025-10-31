# Runtime Graph Modification Guide

This guide explains how to modify location graphs at runtime (e.g., to lock/unlock routes).

## Overview

The location graph system supports runtime modifications through **instancing**. When you load a graph for runtime use, you should create an instance copy that can be modified without affecting the original resource. This follows the same pattern used for Items and People in the game.

## Key Concepts

### Instancing

- **Original Resource**: The `.tres` file on disk that defines the base graph structure
- **Instance**: A deep copy created at runtime that can be modified independently
- **Why Instance?**: Modifications to instances don't affect the original resource, and instances can be saved/loaded as part of game state

### Graph Components

- **Nodes (LocationNodeData)**: Represent locations in your game world
- **Edges (LocationEdgeData)**: Represent connections/routes between locations
- **Edge.locked**: Boolean flag that determines if a route can be traveled

## Usage Examples

### 1. Loading a Graph for Runtime Modification

```gdscript
# In your game initialization code
var graph_runtime = LocationGraphRuntime.new()

# Load and instance the graph (recommended for games that modify routes)
graph_runtime.load_graph_instanced("res://path/to/your/graph.tres")

# OR load without instancing (if you never modify the graph)
graph_runtime.load_graph("res://path/to/your/graph.tres")
```

### 2. Using the State Autoload (Recommended)

The `State` autoload automatically creates instances when you set the location graph:

```gdscript
# This automatically creates an instance
State.set_location_graph(role.location_graph)
```

The instanced graph is stored in `State.state_data.location_graph` and will be saved/loaded with your game state.

### 3. Locking/Unlocking Routes

#### Using State Autoload (Easiest)

```gdscript
# Lock a route - player can no longer travel from "village" to "forest"
State.lock_route("village", "forest")

# Unlock a route - player can now travel
State.unlock_route("village", "forest")

# Check if a route is locked
if State.is_route_locked("village", "forest"):
    print("The path to the forest is blocked!")
```

#### Using LocationGraphRuntime Directly

```gdscript
var graph_runtime = LocationGraphRuntime.new()
graph_runtime.load_graph_instanced("res://path/to/your/graph.tres")

# Lock an edge
graph_runtime.lock_edge("village", "forest")

# Unlock an edge
graph_runtime.unlock_edge("village", "forest")

# Check if locked
if graph_runtime.is_edge_locked("village", "forest"):
    print("Route is locked")
```

### 4. Direct Edge Manipulation

You can also modify edges directly if you have access to the graph:

```gdscript
# Access the graph from State
var graph = State.state_data.location_graph

# Find and modify an edge
for edge_data in graph.edges:
    var edge := edge_data as LocationEdgeData
    if String(edge.from_id) == "village" and String(edge.to_id) == "forest":
        edge.locked = true
        break

# IMPORTANT: If using LocationGraphRuntime, rebuild indices after direct modification
# graph_runtime._build_internal_indices()  # Private method - use lock/unlock instead
```

## Common Use Cases

### Progression-Based Unlocking

```gdscript
# Player completes a quest to unlock a new area
func _on_quest_completed(quest_name: String) -> void:
    if quest_name == "repair_bridge":
        State.unlock_route("village", "northern_territory")
        show_notification("The bridge has been repaired! You can now travel north.")
```

### Dynamic World Events

```gdscript
# A storm blocks certain routes
func _on_storm_started() -> void:
    State.lock_route("plains", "mountain_pass")
    State.lock_route("coast", "lighthouse")

func _on_storm_ended() -> void:
    State.unlock_route("plains", "mountain_pass")
    State.unlock_route("coast", "lighthouse")
```

### Conditional Travel

```gdscript
# Check if player meets requirements before allowing travel
func try_travel_to(destination: String) -> bool:
    var current_location = State.get_current_location()
    
    # Check if route is locked
    if State.is_route_locked(current_location, destination):
        show_message("This path is currently blocked.")
        return false
    
    # Check custom conditions
    if destination == "secret_cave" and not Globals.player.has_item("ancient_key"):
        show_message("You need the Ancient Key to enter here.")
        State.lock_route(current_location, "secret_cave")
        return false
    
    State.visit_location(destination)
    return true
```

## Important Notes

### Saving and Loading

- The instanced graph in `State.state_data.location_graph` is automatically saved/loaded with your game state
- Locked/unlocked status persists across save/load cycles
- Make sure to call `SaveManager.save_game_state()` after modifying routes (State methods do this automatically)

### Bidirectional Edges

- When you lock a bidirectional edge, it blocks travel in BOTH directions
- The `State.lock_route()` and `unlock_route()` methods handle bidirectional edges automatically

### Performance

- Locking/unlocking edges causes the internal indices to be rebuilt
- This is fast for normal-sized graphs (dozens to hundreds of locations)
- Avoid locking/unlocking edges every frame; do it only when needed

### Thread Safety

- Graph modifications are not thread-safe
- Always modify graphs from the main thread

## API Reference

### LocationGraph

```gdscript
func create_instance() -> LocationGraph
```

Creates a deep copy of the graph that can be modified independently.

### LocationGraphRuntime

```gdscript
func load_graph(path: String) -> void
func load_graph_instanced(path: String) -> void
func lock_edge(from_id: String, to_id: String) -> bool
func unlock_edge(from_id: String, to_id: String) -> bool
func is_edge_locked(from_id: String, to_id: String) -> bool
```

### State Autoload

```gdscript
func set_location_graph(location_graph: LocationGraph) -> void
func lock_route(from_location: String, to_location: String) -> bool
func unlock_route(from_location: String, to_location: String) -> bool
func is_route_locked(from_location: String, to_location: String) -> bool
```

## Troubleshooting

**Q: My route modifications aren't persisting after saving/loading**
A: Make sure you're using `State.set_location_graph()` which creates an instance, not loading the graph directly.

**Q: Changes to routes don't seem to take effect**
A: If you're using `LocationGraphRuntime`, the indices need to be rebuilt. Use the provided `lock_edge()`/`unlock_edge()` methods instead of modifying edges directly.

**Q: Can I modify node properties at runtime?**
A: Yes! The instancing system creates deep copies of nodes too. Just remember that visual editor won't reflect these changes.

**Q: How do I reset a graph to its original state?**
A: Load a fresh instance: `State.set_location_graph(original_graph)` or reload from the resource file.
