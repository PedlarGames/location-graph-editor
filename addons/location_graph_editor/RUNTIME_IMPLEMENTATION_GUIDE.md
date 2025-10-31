# LocationGraphRuntime Implementation Guide

This document provides comprehensive guidance for implementing and using the `LocationGraphRuntime` class in your Godot 4 game projects.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [API Reference](#api-reference)
- [Common Use Cases](#common-use-cases)
- [Advanced Features](#advanced-features)
- [Best Practices](#best-practices)
- [Performance Considerations](#performance-considerations)

---

## Overview

The `LocationGraphRuntime` class provides a high-performance interface for interacting with `LocationGraph` resources at runtime. It is designed for narrative-driven games, RPGs, text adventures, and any game that requires structured navigation between interconnected locations.

### Key Features

- **Fast indexed lookups** for nodes, edges, and neighbors (O(1) average time complexity)
- **BFS pathfinding** for finding shortest paths between locations
- **Dynamic edge management** (lock/unlock, hide/unhide edges at runtime)
- **Bidirectional connection support** for two-way travel
- **Port label system** for describing connection types (e.g., "North Door", "Climb Rope")
- **Instanced graphs** for runtime modifications without affecting the original resource

### Resource Types

The runtime works with three core resource types:

- **`LocationGraph`**: Container for the entire graph (nodes + edges)
- **`LocationNodeData`**: Individual location/room with properties (id, title, position, tags, port labels)
- **`LocationEdgeData`**: Connection between two nodes (from_id, to_id, ports, bidirectional, locked, hidden)

---

## Quick Start

### Basic Setup

```gdscript
extends Node

# Preload the runtime class
const LocationGraphRuntime = preload("res://addons/location_graph_editor/runtime/location_graph_runtime.gd")

# Create a runtime instance
var runtime := LocationGraphRuntime.new()
var current_location_id: String = ""

func _ready() -> void:
    # Load your graph
    runtime.load_graph("res://maps/dungeon_level1.tres")
    
    # Start at the designated start location
    current_location_id = runtime.get_start_id()
    
    # Display available exits
    display_exits()

func display_exits() -> void:
    var neighbors := runtime.get_neighbors(current_location_id)
    print("You can go to:")
    for neighbor_id in neighbors:
        var label := runtime.get_port_label_between(current_location_id, neighbor_id)
        var location_name := runtime.get_location_name(neighbor_id)
        print("  - %s: %s" % [label, location_name])
```

---

## Core Concepts

### 1. Loading Graphs

There are three ways to load a graph:

#### A. Static Graph (Read-Only)

```gdscript
# Load a graph for read-only navigation
runtime.load_graph("res://maps/my_map.tres")
```

Use when you don't need to modify edges at runtime (e.g., simple navigation, pathfinding).

#### B. Instanced Graph (Modifiable)

```gdscript
# Load an instance that can be modified at runtime
runtime.load_graph_instanced("res://maps/my_map.tres")

# Now you can lock/unlock edges without affecting the original resource
runtime.lock_edge("room_a", "room_b")
```

Use when you need to lock/unlock/hide edges during gameplay (e.g., locked doors, collapsed passages).

#### C. From Existing Resource

```gdscript
# Load from an already-loaded resource
var graph: LocationGraph = preload("res://maps/my_map.tres")
runtime.set_graph(graph)

# Or create an instance manually
var instance := graph.create_instance()
runtime.set_graph(instance)
```

### 2. Navigation

The runtime provides neighbor lookup for direct connections:

```gdscript
# Get all accessible (unlocked, visible) neighbors
var neighbors: Array[String] = runtime.get_neighbors("room_a")

# Get all neighbors including locked ones
var all_neighbors: Array[String] = runtime.get_all_neighbors("room_a")

# Check if direct connection exists
if runtime.has_edge("room_a", "room_b"):
    print("Room A connects to Room B")
```

### 3. Nodes and Edges

Access node and edge data:

```gdscript
# Get node data
var node: LocationNodeData = runtime.get_location_node("room_a")
print("Location: %s" % node.title)
print("Tags: %s" % str(node.tags))

# Get edge between two nodes
var edge: LocationEdgeData = runtime.get_edge_between("room_a", "room_b")
if edge:
    print("Connection label: %s" % edge.label)
    print("Bidirectional: %s" % edge.bidirectional)
    print("Locked: %s" % edge.locked)
```

### 4. Port Labels

Ports provide descriptive labels for connections:

```gdscript
# Get the label for traveling from room_a to room_b
var label := runtime.get_port_label_between("room_a", "room_b")
# Example: "North Door", "Climb Ladder", "Use Teleporter"

# Access port labels directly
var out_label := runtime.get_out_port_label("room_a", 0)  # First outgoing connection
var in_label := runtime.get_in_port_label("room_a", 0)    # First incoming connection
```

---

## API Reference

### Loading and Initialization

#### `load_graph(path: String) -> void`

Loads a LocationGraph resource from the given file path. Use for read-only access.

**Parameters:**

- `path`: Resource path to the `.tres` file (e.g., `"res://maps/level1.tres"`)

**Example:**

```gdscript
runtime.load_graph("res://maps/dungeon.tres")
```

---

#### `load_graph_instanced(path: String) -> void`

Loads and creates an instance of the LocationGraph for runtime modification. Changes won't affect the original resource.

**Parameters:**

- `path`: Resource path to the `.tres` file

**Example:**

```gdscript
runtime.load_graph_instanced("res://maps/dungeon.tres")
runtime.lock_edge("entrance", "treasury")  # Safe to modify
```

---

#### `set_graph(graph_resource: LocationGraph) -> void`

Sets the active graph from an already loaded LocationGraph resource.

**Parameters:**

- `graph_resource`: A LocationGraph instance

**Example:**

```gdscript
var graph := preload("res://maps/level1.tres")
runtime.set_graph(graph)
```

---

### Navigation and Queries

#### `get_start_id() -> String`

Returns the ID of the designated start location. Returns empty string if not set.

**Example:**

```gdscript
var start := runtime.get_start_id()
if start != "":
    current_location = start
```

---

#### `get_start_or_first_id() -> String`

Returns the start node ID if set, otherwise returns the first node's ID. Convenience method for initialization.

**Example:**

```gdscript
# Always get a valid starting location
current_location = runtime.get_start_or_first_id()
```

---

#### `get_location_node(id: String) -> LocationNodeData`

Retrieves the LocationNodeData for a given location ID. Returns `null` if not found.

**Parameters:**

- `id`: The location ID (e.g., `"room_01"`, `"forest_clearing"`)

**Returns:**

- `LocationNodeData` object or `null`

**Example:**

```gdscript
var node := runtime.get_location_node("treasure_room")
if node:
    print("Title: %s" % node.title)
    print("Tags: %s" % str(node.tags))
```

---

#### `get_location_name(id: String) -> String`

Gets the title/name of a location. Returns "Unknown" if not found.

**Parameters:**

- `id`: The location ID

**Returns:**

- The node's title or "Unknown"

**Example:**

```gdscript
var name := runtime.get_location_name("entrance")
print("You are at: %s" % name)
```

---

#### `get_neighbors(id: String) -> Array[String]`

Returns an array of accessible neighboring location IDs. Only includes unlocked and visible connections.

**Parameters:**

- `id`: The location ID

**Returns:**

- Array of neighbor IDs (String)

**Example:**

```gdscript
var neighbors := runtime.get_neighbors("courtyard")
for neighbor_id in neighbors:
    print("Can travel to: %s" % runtime.get_location_name(neighbor_id))
```

---

#### `get_all_neighbors(id: String) -> Array[String]`

Returns all neighboring location IDs, including locked and hidden connections.

**Parameters:**

- `id`: The location ID

**Returns:**

- Array of all neighbor IDs (String), including inaccessible ones

**Example:**

```gdscript
# Show locked doors as "locked" options in UI
var all_neighbors := runtime.get_all_neighbors("hallway")
for neighbor_id in all_neighbors:
    if runtime.is_edge_locked(current_id, neighbor_id):
        print("[LOCKED] %s" % runtime.get_location_name(neighbor_id))
```

---

#### `has_edge(from_id: String, to_id: String) -> bool`

Checks if a direct accessible connection exists between two locations.

**Parameters:**

- `from_id`: Source location ID
- `to_id`: Destination location ID

**Returns:**

- `true` if accessible connection exists, `false` otherwise

**Example:**

```gdscript
if runtime.has_edge("entrance", "lobby"):
    print("You can go directly to the lobby")
```

---

### Edge Management

#### `get_edges_from(from_id: String) -> Array`

Returns an array of LocationEdgeData objects that originate from the given node.

**Parameters:**

- `from_id`: The source location ID

**Returns:**

- Array of `LocationEdgeData` objects

**Example:**

```gdscript
for edge in runtime.get_edges_from("central_room"):
    print("Connection to: %s" % edge.to_id)
    print("  Locked: %s" % edge.locked)
    print("  Hidden: %s" % edge.hidden)
```

---

#### `get_edges_to(to_id: String) -> Array`

Returns an array of LocationEdgeData objects that target the given node.

**Parameters:**

- `to_id`: The destination location ID

**Returns:**

- Array of `LocationEdgeData` objects

**Example:**

```gdscript
# Find all locations that connect TO the throne room
for edge in runtime.get_edges_to("throne_room"):
    print("Connected from: %s" % edge.from_id)
```

---

#### `get_edge_between(from_id: String, to_id: String) -> LocationEdgeData`

Gets the edge between two nodes, excluding locked and hidden edges.

**Parameters:**

- `from_id`: Source location ID
- `to_id`: Destination location ID

**Returns:**

- `LocationEdgeData` object or `null` if no accessible edge exists

**Example:**

```gdscript
var edge := runtime.get_edge_between("hall", "kitchen")
if edge:
    print("Connection label: %s" % edge.label)
    print("Is bidirectional: %s" % edge.bidirectional)
```

---

#### `get_edge_between_including_locked(from_id: String, to_id: String) -> LocationEdgeData`

Gets the edge between two nodes, including locked and hidden edges.

**Parameters:**

- `from_id`: Source location ID
- `to_id`: Destination location ID

**Returns:**

- `LocationEdgeData` object or `null`

**Example:**

```gdscript
var edge := runtime.get_edge_between_including_locked("gate", "castle")
if edge and edge.locked:
    print("The gate is locked!")
```

---

#### `is_edge_locked(from_id: String, to_id: String) -> bool`

Checks if an edge between two nodes is locked.

**Parameters:**

- `from_id`: Source location ID
- `to_id`: Destination location ID

**Returns:**

- `true` if edge exists and is locked, `false` otherwise

**Example:**

```gdscript
if runtime.is_edge_locked("entrance", "vault"):
    print("You need a key to unlock the vault door")
```

---

#### `is_edge_hidden(from_id: String, to_id: String) -> bool`

Checks if an edge between two nodes is hidden.

**Parameters:**

- `from_id`: Source location ID
- `to_id`: Destination location ID

**Returns:**

- `true` if edge exists and is hidden, `false` otherwise

**Example:**

```gdscript
if runtime.is_edge_hidden("library", "secret_room"):
    print("There's a secret passage here!")
    runtime.unhide_edge("library", "secret_room")
```

---

#### `lock_edge(from_id: String, to_id: String) -> bool`

Locks an edge, preventing travel along that route. **Requires an instanced graph.**

**Parameters:**

- `from_id`: Source location ID
- `to_id`: Destination location ID

**Returns:**

- `true` if successful, `false` if edge not found

**Example:**

```gdscript
# Player triggers a trap that collapses the passage
if runtime.lock_edge("cavern", "underground_lake"):
    print("The passage collapses!")
```

---

#### `unlock_edge(from_id: String, to_id: String) -> bool`

Unlocks an edge, allowing travel along that route. **Requires an instanced graph.**

**Parameters:**

- `from_id`: Source location ID
- `to_id`: Destination location ID

**Returns:**

- `true` if successful, `false` if edge not found

**Example:**

```gdscript
# Player uses a key to unlock a door
if player_has_key and runtime.unlock_edge("hallway", "treasure_room"):
    print("You unlock the door with the golden key")
    player_inventory.remove_item("golden_key")
```

---

#### `hide_edge(from_id: String, to_id: String) -> bool`

Marks an edge as hidden. Hidden edges are excluded from normal navigation and pathfinding. **Requires an instanced graph.**

**Parameters:**

- `from_id`: Source location ID
- `to_id`: Destination location ID

**Returns:**

- `true` if successful, `false` if edge not found

**Example:**

```gdscript
# Conceal a secret passage until player discovers it
runtime.hide_edge("study", "secret_library")
```

---

#### `unhide_edge(from_id: String, to_id: String) -> bool`

Reveals a hidden edge. **Requires an instanced graph.**

**Parameters:**

- `from_id`: Source location ID
- `to_id`: Destination location ID

**Returns:**

- `true` if successful, `false` if edge not found

**Example:**

```gdscript
# Player discovers a hidden passage
if player_examined_bookshelf:
    runtime.unhide_edge("study", "secret_library")
    print("You found a hidden passage behind the bookshelf!")
```

---

### Port Labels

#### `get_port_label_between(node_id: String, neighbor_id: String, include_locked: bool = false, include_hidden: bool = false) -> String`

Gets the port label that describes the connection between two locations.

**Parameters:**

- `node_id`: Current location ID
- `neighbor_id`: Connected location ID
- `include_locked`: Whether to return labels for locked connections (default: `false`)
- `include_hidden`: Whether to return labels for hidden connections (default: `false`)

**Returns:**

- Port label string or empty string if not found/not accessible

**Example:**

```gdscript
var label := runtime.get_port_label_between("entrance", "courtyard")
print("Exit: %s" % label)  # "Main Gate", "North Door", etc.

# Show locked options
var locked_label := runtime.get_port_label_between("hall", "vault", true)
if locked_label != "":
    print("[LOCKED] %s" % locked_label)
```

---

#### `get_out_port_label(node_id: String, port_index: int) -> String`

Gets the outgoing port label by index.

**Parameters:**

- `node_id`: Location ID
- `port_index`: Port index (0-based)

**Returns:**

- Port label string or empty string

**Example:**

```gdscript
var node := runtime.get_location_node("crossroads")
for i in range(node.out_port_labels.size()):
    var label := runtime.get_out_port_label("crossroads", i)
    print("Exit %d: %s" % [i, label])
```

---

#### `get_in_port_label(node_id: String, port_index: int) -> String`

Gets the incoming port label by index.

**Parameters:**

- `node_id`: Location ID
- `port_index`: Port index (0-based)

**Returns:**

- Port label string or empty string

**Example:**

```gdscript
var label := runtime.get_in_port_label("throne_room", 0)
print("Entered through: %s" % label)
```

---

### Pathfinding

#### `find_path_bfs(start_id: String, goal_id: String) -> Array[String]`

Finds the shortest path between two locations using Breadth-First Search. Only considers accessible (unlocked, visible) edges.

**Parameters:**

- `start_id`: Starting location ID
- `goal_id`: Destination location ID

**Returns:**

- Array of location IDs representing the path, or empty array if no path found

**Example:**

```gdscript
# Find path from player's location to quest objective
var path := runtime.find_path_bfs(current_location, "quest_location")
if path.is_empty():
    print("No path available. You may need to unlock doors.")
else:
    print("Route:")
    for step in path:
        print("  -> %s" % runtime.get_location_name(step))
```

---

## Common Use Cases

### 1. Text Adventure Navigation

```gdscript
extends Node

const LocationGraphRuntime = preload("res://addons/location_graph_editor/runtime/location_graph_runtime.gd")

var runtime := LocationGraphRuntime.new()
var current_location: String = ""

func _ready() -> void:
    runtime.load_graph("res://adventure/mansion.tres")
    current_location = runtime.get_start_or_first_id()
    describe_location()

func describe_location() -> void:
    var node := runtime.get_location_node(current_location)
    print("\n=== %s ===" % node.title)
    
    # Get description from node properties (assuming you store it in tags or custom properties)
    print("You are in %s." % node.title.to_lower())
    
    # Show exits
    var neighbors := runtime.get_neighbors(current_location)
    if neighbors.is_empty():
        print("There are no obvious exits.")
    else:
        print("\nExits:")
        for neighbor_id in neighbors:
            var label := runtime.get_port_label_between(current_location, neighbor_id)
            var destination := runtime.get_location_name(neighbor_id)
            if label != "":
                print("  - %s (to %s)" % [label, destination])
            else:
                print("  - %s" % destination)
    
    # Show locked exits as hints
    var all_neighbors := runtime.get_all_neighbors(current_location)
    for neighbor_id in all_neighbors:
        if runtime.is_edge_locked(current_location, neighbor_id):
            var label := runtime.get_port_label_between(current_location, neighbor_id, true)
            print("  - [LOCKED] %s" % label)

func go_to(direction_or_label: String) -> void:
    # Try to match direction/label to a neighbor
    var neighbors := runtime.get_neighbors(current_location)
    for neighbor_id in neighbors:
        var label := runtime.get_port_label_between(current_location, neighbor_id)
        if label.to_lower() == direction_or_label.to_lower():
            current_location = neighbor_id
            describe_location()
            return
    
    print("You can't go that way.")
```

---

### 2. RPG Fast Travel System

```gdscript
extends Control

const LocationGraphRuntime = preload("res://addons/location_graph_editor/runtime/location_graph_runtime.gd")

var runtime := LocationGraphRuntime.new()
var discovered_locations: Array[String] = []
var current_location: String = ""

func _ready() -> void:
    runtime.load_graph("res://world/overworld_map.tres")
    current_location = runtime.get_start_or_first_id()
    discover_location(current_location)

func discover_location(location_id: String) -> void:
    if location_id not in discovered_locations:
        discovered_locations.append(location_id)
        var name := runtime.get_location_name(location_id)
        print("New location discovered: %s" % name)

func can_fast_travel_to(destination_id: String) -> bool:
    # Can only fast travel to discovered locations
    if destination_id not in discovered_locations:
        return false
    
    # Check if path exists
    var path := runtime.find_path_bfs(current_location, destination_id)
    return not path.is_empty()

func fast_travel(destination_id: String) -> void:
    if not can_fast_travel_to(destination_id):
        print("Cannot fast travel to that location")
        return
    
    var path := runtime.find_path_bfs(current_location, destination_id)
    print("Fast traveling via: %s" % " -> ".join(path))
    current_location = destination_id

func show_fast_travel_menu() -> void:
    print("\n=== Fast Travel ===")
    for location_id in discovered_locations:
        if location_id == current_location:
            continue
        var name := runtime.get_location_name(location_id)
        if can_fast_travel_to(location_id):
            print("  [%s] %s" % [location_id, name])
        else:
            print("  [BLOCKED] %s" % name)
```

---

### 3. Dynamic Door Locking System

```gdscript
extends Node

const LocationGraphRuntime = preload("res://addons/location_graph_editor/runtime/location_graph_runtime.gd")

var runtime := LocationGraphRuntime.new()
var locked_doors: Dictionary = {}  # from_to_key -> item_required

func _ready() -> void:
    # Use instanced graph for runtime modifications
    runtime.load_graph_instanced("res://levels/castle.tres")
    
    # Setup locked doors with required keys
    lock_door_with_key("entrance_hall", "throne_room", "golden_key")
    lock_door_with_key("courtyard", "tower", "rusty_key")

func lock_door_with_key(from_id: String, to_id: String, key_item: String) -> void:
    if runtime.lock_edge(from_id, to_id):
        var key := "%s_to_%s" % [from_id, to_id]
        locked_doors[key] = key_item
        print("Locked door between %s and %s (requires %s)" % [from_id, to_id, key_item])

func try_unlock_door(from_id: String, to_id: String, inventory: Array) -> bool:
    var key := "%s_to_%s" % [from_id, to_id]
    if key not in locked_doors:
        return false  # Not a locked door
    
    var required_item: String = locked_doors[key]
    if required_item in inventory:
        if runtime.unlock_edge(from_id, to_id):
            locked_doors.erase(key)
            print("You unlock the door with the %s" % required_item)
            return true
    else:
        print("This door is locked. You need a %s." % required_item)
    
    return false

func get_required_key(from_id: String, to_id: String) -> String:
    var key := "%s_to_%s" % [from_id, to_id]
    return locked_doors.get(key, "")
```

---

### 4. Quest-Based Path Revealing

```gdscript
extends Node

const LocationGraphRuntime = preload("res://addons/location_graph_editor/runtime/location_graph_runtime.gd")

var runtime := LocationGraphRuntime.new()
var completed_quests: Array[String] = []

func _ready() -> void:
    # Use instanced graph
    runtime.load_graph_instanced("res://world/quest_map.tres")
    
    # Hide quest-gated locations initially
    runtime.hide_edge("village", "ancient_temple")
    runtime.hide_edge("forest", "dragon_lair")

func complete_quest(quest_id: String) -> void:
    if quest_id in completed_quests:
        return
    
    completed_quests.append(quest_id)
    print("Quest completed: %s" % quest_id)
    
    # Reveal new areas based on quest completion
    match quest_id:
        "find_map_fragment":
            runtime.unhide_edge("village", "ancient_temple")
            print("A new location has been marked on your map!")
        
        "dragon_rumor":
            runtime.unhide_edge("forest", "dragon_lair")
            print("You've learned the location of the dragon's lair")
        
        "repair_bridge":
            runtime.unlock_edge("town", "mountain_pass")
            print("The bridge has been repaired!")

func is_location_revealed(location_id: String) -> bool:
    # Check if any path to this location is visible
    var all_locations := _get_all_location_ids()
    for from_id in all_locations:
        if runtime.has_edge(from_id, location_id):
            return true
    return false

func _get_all_location_ids() -> Array[String]:
    var ids: Array[String] = []
    if runtime.location_graph:
        for node in runtime.location_graph.nodes:
            ids.append(String(node.id))
    return ids
```

---

### 5. Auto-Navigation with Waypoints

```gdscript
extends Node

const LocationGraphRuntime = preload("res://addons/location_graph_editor/runtime/location_graph_runtime.gd")

signal navigation_step(from_location: String, to_location: String, label: String)
signal navigation_complete()
signal navigation_blocked()

var runtime := LocationGraphRuntime.new()
var current_location: String = ""
var navigation_path: Array[String] = []
var navigation_index: int = 0

func _ready() -> void:
    runtime.load_graph("res://maps/game_world.tres")
    current_location = runtime.get_start_or_first_id()

func navigate_to(destination_id: String) -> bool:
    navigation_path = runtime.find_path_bfs(current_location, destination_id)
    
    if navigation_path.is_empty():
        print("No path to destination")
        navigation_blocked.emit()
        return false
    
    navigation_index = 0
    print("Navigation started: %d steps" % navigation_path.size())
    return true

func advance_navigation() -> bool:
    if navigation_path.is_empty():
        return false
    
    if navigation_index >= navigation_path.size() - 1:
        print("Navigation complete!")
        navigation_complete.emit()
        navigation_path.clear()
        return false
    
    var from_loc := navigation_path[navigation_index]
    var to_loc := navigation_path[navigation_index + 1]
    var label := runtime.get_port_label_between(from_loc, to_loc)
    
    current_location = to_loc
    navigation_index += 1
    
    print("Step %d/%d: %s -> %s (%s)" % [
        navigation_index,
        navigation_path.size() - 1,
        runtime.get_location_name(from_loc),
        runtime.get_location_name(to_loc),
        label
    ])
    
    navigation_step.emit(from_loc, to_loc, label)
    return true

func cancel_navigation() -> void:
    navigation_path.clear()
    navigation_index = 0
    print("Navigation cancelled")

func get_remaining_steps() -> int:
    if navigation_path.is_empty():
        return 0
    return navigation_path.size() - navigation_index - 1
```

---

## Advanced Features

### Custom Edge Conditions

While the runtime doesn't evaluate edge conditions automatically, you can implement custom logic:

```gdscript
func can_traverse_edge(edge: LocationEdgeData, player_stats: Dictionary) -> bool:
    # Edge locked check
    if edge.locked:
        return false
    
    # Edge hidden check
    if edge.hidden:
        return false
    
    # Custom condition evaluation
    if edge.condition != "":
        return evaluate_condition(edge.condition, player_stats)
    
    return true

func evaluate_condition(condition: String, player_stats: Dictionary) -> bool:
    # Example: "has_key:golden" or "level>=5" or "strength>10"
    if condition.begins_with("has_key:"):
        var key_name := condition.substr(8)
        return key_name in player_stats.get("keys", [])
    
    if condition.contains(">="):
        var parts := condition.split(">=")
        var stat := parts[0].strip_edges()
        var value := int(parts[1].strip_edges())
        return player_stats.get(stat, 0) >= value
    
    # Add more condition types as needed
    return true
```

---

### Save/Load System Integration

```gdscript
func save_runtime_state() -> Dictionary:
    var state := {
        "graph_path": _graph_path,  # Store this when loading
        "current_location": current_location,
        "locked_edges": [],
        "hidden_edges": []
    }
    
    # Save locked edges
    for node_id in runtime.nodes.keys():
        for edge in runtime.get_edges_from(node_id):
            if edge.locked:
                state.locked_edges.append({
                    "from": String(edge.from_id),
                    "to": String(edge.to_id)
                })
            if edge.hidden:
                state.hidden_edges.append({
                    "from": String(edge.from_id),
                    "to": String(edge.to_id)
                })
    
    return state

func load_runtime_state(state: Dictionary) -> void:
    # Load instanced graph
    runtime.load_graph_instanced(state.graph_path)
    current_location = state.current_location
    
    # Restore locked edges
    for edge_data in state.get("locked_edges", []):
        runtime.lock_edge(edge_data.from, edge_data.to)
    
    # Restore hidden edges
    for edge_data in state.get("hidden_edges", []):
        runtime.hide_edge(edge_data.from, edge_data.to)
```

---

### Graph Validation

```gdscript
func validate_graph() -> Dictionary:
    var issues := {
        "warnings": [],
        "errors": []
    }
    
    if runtime.location_graph == null:
        issues.errors.append("No graph loaded")
        return issues
    
    # Check for orphaned nodes (no connections)
    for node in runtime.location_graph.nodes:
        var node_id := String(node.id)
        var neighbors := runtime.get_all_neighbors(node_id)
        if neighbors.is_empty():
            issues.warnings.append("Node '%s' has no connections" % node_id)
    
    # Check for unreachable nodes from start
    var start_id := runtime.get_start_or_first_id()
    if start_id != "":
        var reachable := _find_reachable_nodes(start_id)
        for node in runtime.location_graph.nodes:
            var node_id := String(node.id)
            if node_id not in reachable:
                issues.warnings.append("Node '%s' is unreachable from start" % node_id)
    
    # Check for missing port labels
    for node in runtime.location_graph.nodes:
        var node_id := String(node.id)
        for edge in runtime.get_edges_from(node_id):
            var label := runtime.get_out_port_label(node_id, edge.from_port)
            if label.strip_edges() == "":
                issues.warnings.append("Missing out port label: %s port %d" % [node_id, edge.from_port])
    
    return issues

func _find_reachable_nodes(start_id: String) -> Array[String]:
    var reachable: Array[String] = [start_id]
    var queue: Array[String] = [start_id]
    
    while not queue.is_empty():
        var current := queue.pop_front()
        for neighbor in runtime.get_all_neighbors(current):
            if neighbor not in reachable:
                reachable.append(neighbor)
                queue.append(neighbor)
    
    return reachable
```

---

## Best Practices

### 1. Graph Loading Strategy

- **Use `load_graph()`** for static navigation (read-only)
- **Use `load_graph_instanced()`** when you need to modify edges at runtime
- Load graphs during scene transitions, not every frame
- Cache the runtime instance as a member variable

```gdscript
# Good
var runtime := LocationGraphRuntime.new()

func _ready() -> void:
    runtime.load_graph_instanced("res://maps/level1.tres")

# Bad - creates new instance every time
func get_neighbors() -> Array[String]:
    var rt := LocationGraphRuntime.new()  # DON'T DO THIS
    rt.load_graph("res://maps/level1.tres")
    return rt.get_neighbors(current_location)
```

---

### 2. Error Handling

Always check for null returns and empty arrays:

```gdscript
# Check if node exists
var node := runtime.get_location_node(location_id)
if node == null:
    push_error("Location not found: %s" % location_id)
    return

# Check for empty paths
var path := runtime.find_path_bfs(start, goal)
if path.is_empty():
    print("No path available between %s and %s" % [start, goal])
    return

# Check for valid neighbors
var neighbors := runtime.get_neighbors(current_location)
if neighbors.is_empty():
    print("No exits available")
```

---

### 3. Port Label Usage

- Define clear, descriptive port labels in the editor
- Fall back to destination names if labels are missing
- Use labels for UI button text

```gdscript
func create_exit_button(from_id: String, to_id: String) -> Button:
    var button := Button.new()
    var label := runtime.get_port_label_between(from_id, to_id)
    
    if label != "":
        button.text = label  # "North Door", "Climb Ladder"
    else:
        var destination_name := runtime.get_location_name(to_id)
        button.text = "Go to %s" % destination_name
    
    button.pressed.connect(func(): navigate_to(to_id))
    return button
```

---

### 4. Performance Optimization

The runtime uses indexed lookups for fast performance:

- `get_neighbors()`: O(1) average lookup
- `get_location_node()`: O(1) average lookup
- `find_path_bfs()`: O(V + E) where V=nodes, E=edges

**Tips:**

- Avoid calling `load_graph()` repeatedly
- Cache neighbor lists if checking multiple times per frame
- Use `has_edge()` for simple connectivity checks before pathfinding

```gdscript
# Good - cache neighbors
var cached_neighbors := runtime.get_neighbors(current_location)
for neighbor in cached_neighbors:
    if some_condition(neighbor):
        # Process

# Bad - repeated lookups
for i in range(10):
    var neighbors := runtime.get_neighbors(current_location)  # Inefficient
```

---

### 5. Testing and Debugging

Use validation and debug helpers:

```gdscript
func debug_print_graph_info() -> void:
    if runtime.location_graph == null:
        print("No graph loaded")
        return
    
    print("=== Graph Debug Info ===")
    print("Nodes: %d" % runtime.nodes.size())
    print("Start: %s" % runtime.get_start_id())
    
    for node_id in runtime.nodes.keys():
        var node := runtime.get_location_node(node_id)
        var neighbors := runtime.get_neighbors(node_id)
        print("\n[%s] %s" % [node_id, node.title])
        print("  Tags: %s" % str(node.tags))
        print("  Neighbors: %s" % str(neighbors))
        
        for neighbor_id in neighbors:
            var label := runtime.get_port_label_between(node_id, neighbor_id)
            print("    -> %s (%s)" % [neighbor_id, label])
```

---

## Performance Considerations

### Indexed Data Structures

The runtime pre-processes the graph into optimized lookup dictionaries:

```gdscript
# Internal structure (built automatically):
var neighbors: Dictionary = {
    "room_a": ["room_b", "room_c"],
    "room_b": ["room_a", "room_d"]
}

var nodes: Dictionary = {
    "room_a": LocationNodeData,
    "room_b": LocationNodeData
}

var edges_from: Dictionary = {
    "room_a": [EdgeData1, EdgeData2]
}

var edges_to: Dictionary = {
    "room_b": [EdgeData1, EdgeData3]
}
```

This means:

- Looking up neighbors: **O(1)** on average
- Looking up node data: **O(1)** on average
- Finding edges from/to a node: **O(1)** on average

---

### BFS Pathfinding Complexity

The `find_path_bfs()` function has:

- **Time complexity**: O(V + E) where V = number of nodes, E = number of edges
- **Space complexity**: O(V) for the queue and came_from dictionary

For typical game graphs (< 1000 nodes), performance is excellent.

---

### When to Rebuild Indices

Indices are automatically rebuilt when:

- `load_graph()` is called
- `load_graph_instanced()` is called
- `set_graph()` is called
- `lock_edge()` / `unlock_edge()` is called (to update neighbors list)

**Note:** Rebuilding is fast but not free. Avoid excessive locking/unlocking in tight loops.

---

### Memory Usage

- **Static graph**: Minimal overhead (just reference to resource)
- **Instanced graph**: Full deep copy of all nodes and edges
- **Runtime dictionaries**: O(N) where N = number of nodes + edges

For large graphs (1000+ nodes), consider:

- Breaking into smaller sub-graphs
- Lazy loading (load regions as needed)
- Using static graphs when possible

---

## Additional Resources

- **Editor Documentation**: See `README.md` in the plugin folder
- **Example Scene**: `addons/location_graph_editor/example/navigation_example.tscn`
- **Resource Scripts**: `addons/location_graph_editor/resources/`

---

## Version Compatibility

- **Godot Version**: 4.5+
- **Plugin Version**: 1.0
- **Last Updated**: October 2025

---

## License

This plugin and documentation are provided as-is. Check the repository for license details.
