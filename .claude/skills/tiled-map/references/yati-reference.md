# YATI Special Custom Properties

These Tiled custom properties on layers or objects are interpreted by YATI and affect the imported Godot node. Set them in the Tiled Properties panel.

| Property | Type | Effect |
|---|---|---|
| `no_import` | bool | Skip the entire layer during import; nothing is created for it |
| `z_index` | int | Sets `z_index` on the produced node |
| `godot_node_type` | string | Overrides the node type that YATI would normally produce |
| `godot_group` | string | Comma-separated group names; node is added to each group persistently |
| `godot_script` | file or string | Attaches a GDScript file to the node |
| `tile_set` | file | Overrides the TileSet resource used by this TileMapLayer |
| `tileset_resource_path` | string | Overrides TileSet path (TileMapLayer only; experimental) |
| `y_sort_origin` | int | Sets Y sort origin on TileMapLayer |
| `x_draw_order_reversed` | bool | Reverses X draw order on TileMapLayer |
| `rendering_quadrant_size` | int | Sets rendering quadrant size on TileMapLayer |
| `collision_enabled` | bool | Enables/disables collision on TileMapLayer |
| `use_kinematic_bodies` | bool | Use kinematic bodies for TileMapLayer collision |
| `navigation_enabled` | bool | Enables/disables navigation on TileMapLayer |
| `modulate` | color | Sets `modulate` on any CanvasItem node |
| `self_modulate` | color | Sets `self_modulate` on any CanvasItem node |
| `show_behind_parent` | bool | Sets `show_behind_parent` on any CanvasItem node |
| `top_level` | bool | Sets `top_level` on any CanvasItem node |
| `y_sort_enabled` | bool | Sets `y_sort_enabled` on any CanvasItem node |
| `texture_filter` | int | Sets `texture_filter` on any CanvasItem node |
| `material` | file | Sets `material` on any CanvasItem node |
