# Object Gizmo Module

This module exports a `useGizmo` function that enables manipulation of entity position and rotation.

## Installation

1. Download the `object_gizmo` resource.
2. Extract the `object_gizmo` folder into your server's `resources` directory.
3. Add `start object_gizmo` to your server's `server.cfg` file.

## Export

`exports.object_gizmo:useGizmo(handle)`

## Usage

Ensure the `object_gizmo` module script is running on your server.

The `useGizmo` export can be used in any Lua script on the client side as follows:

```lua
local handle = --[[Your target entity]]
local result = exports.object_gizmo:useGizmo(handle)
```

`result` will contain the entity handle, final position, and final rotation.

## Test Command

This module includes a test command `testGizmo` that demonstrates how to use the gizmo. 

The command creates an object at the player's location and then activates the gizmo for that object.

```lua
local model = `prop_mp_cone_02`
RegisterCommand('testGizmo', function()
    local offset = GetEntityCoords(cache.ped) + GetEntityForwardVector(cache.ped) * 3
    lib.requestModel(model)
    local obj = CreateObject(model, offset.x, offset.y, offset.z, false, false, false)
    local data = exports.object_gizmo:useGizmo(obj)

    lib.print.info(data)
end)
```

## Controls

While using the gizmo, the following controls apply:
- **[Enter]**: Finish Editing (confirm placement)
- **[R]**: Switch to Rotate Mode
- **[W]**: Switch to Translate Mode
- **[F]**: Switch between Relative and World
- **[G]**: Enable/Disable Cursor
- **[Shift]**: Snap To Ground
- **[S]**: Switch to Scale Mode (if enabled)
- **[Backspace]**: Cancel Editing

The controls are displayed at the bottom of the screen using the Scaleform instructional buttons system.

## Note

The gizmo only works on entities that you have sufficient permissions to manipulate. Make sure you have the correct permissions to move or rotate the entity you are working with.
