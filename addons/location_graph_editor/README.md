# Location Graph Editor for Godot 4

A visual editor for creating and managing node-based location graphs. Useful for text adventures, RPGs, narrative-driven games, and any project requiring structured navigation between interconnected locations.

## Features

- **Visual GraphEdit-based editor** integrated into the Godot editor dock
- **Multi-port connections** with custom labels (e.g., "North Door", "Climb Ladder")
- **Bidirectional connections** for two-way travel
- **Locked and hidden edges** for dynamic gameplay (locked doors, secret passages)
- **Runtime API** with optimized O(1) lookups and BFS pathfinding
- **Save/Load** graphs as `.tres` resource files
- **Example scene** demonstrating navigation, pathfinding, and edge management

## Quick Start

### 1. Enable the Plugin

1. Go to **Project → Project Settings → Plugins**
2. Enable "Location Graph Editor"

### 2. Create Your First Graph

1. Open the **Location Graph Editor** dock (usually on the bottom panel)
2. Click **New Graph** or **Load Graph** to get started
3. Add nodes by clicking **Add Node** or right-clicking in the graph area
4. Connect nodes by dragging from output ports to input ports
5. Double-click node title bars to edit properties (title, tags, port labels)
6. Right-click connections to lock/unlock or hide/unhide them
7. Save your graph as a `.tres` file

### 3. Use in Your Game

```gdscript
extends Node

const LocationGraphRuntime = preload("res://addons/location_graph_editor/runtime/location_graph_runtime.gd")

var runtime := LocationGraphRuntime.new()
var current_location: String = ""

func _ready() -> void:
	# Load your graph
	runtime.load_graph("res://maps/my_map.tres")
	
	# Start at the designated start location
	current_location = runtime.get_start_id()
	
	# Get available exits
	var neighbors := runtime.get_neighbors(current_location)
	for neighbor_id in neighbors:
		var label := runtime.get_port_label_between(current_location, neighbor_id)
		print("Exit: %s -> %s" % [label, runtime.get_location_name(neighbor_id)])
```

## Documentation

- **[Runtime Implementation Guide](RUNTIME_IMPLEMENTATION_GUIDE.md)** - Comprehensive API reference with examples and use cases
- **[Example Scene](example/navigation_example.tscn)** - Complete working demo

## Visual Indicators

### Connection Colors
- **Green** lines/ports = Bidirectional connections
- **Amber** lines/ports = One-way connections
- **Red** ports = Locked connections
- **Blue** ports = Hidden connections
- **Purple** ports = Both locked and hidden

### Connection Context Menu
Right-click on connection lines to:
- Toggle bidirectional
- Lock/unlock (prevents travel at runtime)
- Hide/unhide (marks as secret/discoverable)

## Runtime Features

### Core Navigation
```gdscript
# Get accessible neighbors
var neighbors := runtime.get_neighbors(location_id)

# Check for direct connection
if runtime.has_edge(from_id, to_id):
	# Move player

# Find shortest path
var path := runtime.find_path_bfs(start_id, goal_id)
```

### Dynamic Edge Management
```gdscript
# Use instanced graph for runtime modifications
runtime.load_graph_instanced("res://maps/dungeon.tres")

# Lock a door (requires a key)
runtime.lock_edge("entrance", "treasure_room")

# Unlock when player has key
if player_has_key:
	runtime.unlock_edge("entrance", "treasure_room")

# Hide secret passages
runtime.hide_edge("library", "secret_room")

# Reveal when discovered
if player_examined_bookshelf:
	runtime.unhide_edge("library", "secret_room")
```

### Performance
- **Neighbor queries**: O(1) average
- **Node/edge lookups**: O(1) average  
- **Pathfinding**: O(V + E) using BFS
- Suitable for graphs with 1000+ nodes

## Resource Types

### LocationGraph
Container for the entire graph with nodes and edges arrays.

### LocationNodeData
Individual location/room with:
- `id` - Unique identifier
- `title` - Display name
- `tags` - Custom categorization
- `out_port_labels` / `in_port_labels` - Connection labels

### LocationEdgeData
Connection between nodes with:
- `from_id` / `to_id` - Connected node IDs
- `bidirectional` - Two-way travel flag
- `locked` - Accessibility state
- `hidden` - Visibility state
- `label` - Connection description
- `condition` - Custom condition string

## Example Use Cases

- **Text Adventures** - Interconnected rooms with descriptive exits
- **RPG World Maps** - Cities, dungeons, and fast travel systems
- **Puzzle Games** - Spatial puzzles with conditional pathways
- **Quest Systems** - Gate locations behind quest completion
- **Dynamic Environments** - Lock/unlock doors based on game events

## Support

- **Documentation**: See RUNTIME_IMPLEMENTATION_GUIDE.md for detailed API reference
- **Example**: Check the `example/` folder for working code
- **Issues**: Report bugs on the plugin's GitHub repository

## License

MIT License - See LICENSE file for details.

Copyright (c) 2025 Pedlar Games

---

**Made with ❤️ for Godot 4.5+**
