# Location Graph Editor - Godot 4 Plugin

A handy Godot 4 plugin for creating, managing, and utilizing node-based location graphs. Useful for narrative-driven games, RPGs, adventure games, text-based games, or any project requiring structured navigation between interconnected locations.

![Godot 4.5+](https://img.shields.io/badge/Godot-4.5+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## Features

### Visual Editor

- **Dedicated Dock**: GraphEdit-based visual editor integrated into the Godot editor
- **Drag & Drop**: Intuitive node placement and connection creation
- **Multi-Port Connections**: Create complex locations with multiple entry and exit points
- **Port Labels**: Label each connection with descriptive text (e.g., "North Door", "Climb Ladder")

### Smart Connection System

- **Bidirectional Connections**: Toggle connections as two-way or one-way
- **Visual Feedback**:
  - Green lines/ports = Bidirectional connections
  - Amber lines/ports = One-way connections
  - Red ports = Locked connections
  - Blue ports = Hidden connections
  - Purple ports = Locked + Hidden
- **Connection Rules**: Each port can only have one connection, preventing conflicts
- **Context Menu**: Right-click connections to lock/unlock/hide them

### Runtime Features

- **Optimized Performance**: Indexed lookups for O(1) neighbor queries
- **BFS Pathfinding**: Built-in shortest path algorithm
- **Dynamic Edge Management**: Lock/unlock/hide edges at runtime (doors, passages, etc.)
- **Save/Load**: Store graphs as `.tres` resource files
- **Instance Support**: Modify graphs at runtime without affecting original resources

### Developer Friendly

- **Comprehensive API**: Clean, well-documented runtime interface
- **Example Scene**: Ready-to-use navigation demo
- **Resource-Based**: Integrates seamlessly with Godot's resource system
- **Type-Safe**: Full GDScript type hints for better IDE support

## Installation

### Option 1: From Godot Asset Library (Recommended)

1. Open your Godot project
2. Go to **AssetLib** tab
3. Search for "Location Graph Editor"
4. Click **Download** and **Install**

### Option 2: Manual Installation

1. Download or clone this repository
2. Copy the `addons/location_graph_editor` folder into your project's `addons/` directory
3. Enable the plugin in **Project → Project Settings → Plugins**

## Quick Start

### 1. Create a Location Graph

1. In Godot editor, go to **Project → Tools → Location Graph Editor** (or use the dock)
2. Click **New Graph** to create a new LocationGraph resource
3. Add nodes by clicking **Add Node** or right-clicking in the graph area
4. Connect nodes by dragging from one port to another
5. Configure node properties (title, tags, port labels) in the inspector, or by double-clicking node title bars
6. Save your graph as a `.tres` file

### 2. Use the Graph in Your Game

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

func move_to(destination_id: String) -> void:
    if runtime.has_edge(current_location, destination_id):
        current_location = destination_id
        print("Moved to: %s" % runtime.get_location_name(destination_id))
```

### 3. Dynamic Edge Management

```gdscript
# Use instanced graph for runtime modifications
runtime.load_graph_instanced("res://maps/my_map.tres")

# Lock a door (requires a key)
runtime.lock_edge("entrance", "treasure_room")

# Later, unlock it when player gets the key
if player_has_key:
    runtime.unlock_edge("entrance", "treasure_room")

# Hide a secret passage until discovered
runtime.hide_edge("library", "secret_room")

# Reveal when player finds it
if player_found_secret:
    runtime.unhide_edge("library", "secret_room")
```

### 4. Pathfinding

```gdscript
# Find shortest path between two locations
var path := runtime.find_path_bfs(current_location, "boss_room")
if path.is_empty():
    print("No path available!")
else:
    print("Route: %s" % " → ".join(path))
```

## Documentation

- **[Runtime Implementation Guide](addons/location_graph_editor/RUNTIME_IMPLEMENTATION_GUIDE.md)** - Comprehensive API reference with examples
- **[Plugin README](addons/location_graph_editor/README.md)** - Editor usage and features
- **[Example Scene](addons/location_graph_editor/example/)** - Working demo project

## Use Cases

### Text Adventures

Create interconnected rooms with descriptive exits. Perfect for Zork-style games.

### RPG World Maps

Design overworld maps with cities, dungeons, and travel routes. Support fast travel systems.

### Puzzle Games

Build complex spatial puzzles with conditional pathways.

### Quest Systems

Gate locations behind quest completion. Reveal new areas as players progress.

### Dynamic Environments

Lock/unlock doors, collapse passages, or reveal secrets based on game events.

## API Highlights

### Core Navigation

- `get_neighbors(id)` - Get accessible locations from current position
- `has_edge(from_id, to_id)` - Check if direct connection exists
- `find_path_bfs(start, goal)` - Find shortest path between locations

### Edge Management

- `lock_edge(from_id, to_id)` - Lock a connection (requires instanced graph)
- `unlock_edge(from_id, to_id)` - Unlock a connection
- `hide_edge(from_id, to_id)` - Hide a connection
- `unhide_edge(from_id, to_id)` - Reveal a hidden connection

### Data Access

- `get_location_node(id)` - Get node data (title, tags, properties)
- `get_edge_between(from_id, to_id)` - Get edge data
- `get_port_label_between(from_id, to_id)` - Get connection label

See the [Runtime Implementation Guide](addons/location_graph_editor/RUNTIME_IMPLEMENTATION_GUIDE.md) for complete API documentation.

## Performance

The runtime uses optimized indexed lookups:

- **Neighbor queries**: O(1) average
- **Node/edge lookups**: O(1) average
- **Pathfinding**: O(V + E) using BFS

Suitable for graphs with 1000+ nodes.

## Examples Included

The plugin includes a complete example scene demonstrating:

- Graph loading
- Navigation UI with exit buttons
- Fast travel menu
- Pathfinding visualization
- Location listing

Find it at: `addons/location_graph_editor/example/navigation_example.tscn`

## Resource Types

### LocationGraph

Container for the entire graph. Stores nodes and edges as arrays.

### LocationNodeData

Individual location/room with properties:

- `id` - Unique identifier
- `title` - Display name
- `position` - Editor position
- `tags` - Custom tags for categorization
- `out_port_labels` - Labels for outgoing connections
- `in_port_labels` - Labels for incoming connections

### LocationEdgeData

Connection between two nodes:

- `from_id` / `to_id` - Connected node IDs
- `from_port` / `to_port` - Port indices
- `label` - Connection description
- `bidirectional` - Two-way travel flag
- `locked` - Accessibility flag
- `hidden` - Visibility flag
- `condition` - Custom condition string (for your game logic)

## Contributing

Contributions are welcome! Please feel free to submit issues or feature requests.

## License

MIT License - See LICENSE file for details.

## Credits

Created for the Godot game development community.

## Support

- **Issues**: Report bugs via GitHub Issues
- **Documentation**: See the docs folder for detailed guides
- **Examples**: Check the example folder for working code

## Changelog

### Version 1.0 (October 2025)

- Initial release
- Visual graph editor
- Runtime navigation API
- BFS pathfinding
- Dynamic edge management (lock/unlock/hide)
- Bidirectional connections
- Port label system
- Example scene

---
