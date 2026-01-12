-- CREDITS
-- Andyyy7666: https://github.com/overextended/ox_lib/pull/453
-- AvarianKnight: https://forum.cfx.re/t/allow-drawgizmo-to-be-used-outside-of-fxdk/5091845/8?u=demi-automatic

local dataview = require 'client.dataview'

local enableScale = false
local isCursorActive = false
local gizmoEnabled = false
local currentMode = 'translate'
local isRelative = false
local currentEntity
local Scalform = nil
local gizmoResult = nil

lib.locale()

local DetailsGizmo = {}
local KeybindRefs = {}

function SetScaleformParams(scaleform, data)
	data = data or {}
	for k,v in pairs(data) do
		PushScaleformMovieFunction(scaleform, v.name)
		if v.param then
			for _,par in pairs(v.param) do
				if math.type(par) == "integer" then
					PushScaleformMovieFunctionParameterInt(par)
				elseif type(par) == "boolean" then
					PushScaleformMovieFunctionParameterBool(par)
				elseif math.type(par) == "float" then
					PushScaleformMovieFunctionParameterFloat(par)
				elseif type(par) == "string" then
					PushScaleformMovieFunctionParameterString(par)
				end
			end
		end
		if v.func then v.func() end
		PopScaleformMovieFunctionVoid()
	end
end

function CreateScaleform(name, data)
	if not name or string.len(name) <= 0 then return end
	local scaleform = RequestScaleformMovie(name)

	while not HasScaleformMovieLoaded(scaleform) do
		Citizen.Wait(0)
	end

	SetScaleformParams(scaleform, data)
	return scaleform
end

function ActiveScalform()
    local dataSlots = {
        {
            name = "CLEAR_ALL",
            param = {}
        }, 
        {
            name = "TOGGLE_MOUSE_BUTTONS",
            param = { 0 }
        },
        {
            name = "CREATE_CONTAINER",
            param = {}
        } 
    }
    local dataId = 0
    
    for k, v in ipairs(DetailsGizmo) do
        if v.keybind and v.keybind.hash then
            local label = v.label
            if v.keybind == KeybindRefs.cursor then
                label = (isCursorActive and locale("disable_cursor") or locale("enable_cursor"))
            end
            dataSlots[#dataSlots + 1] = {
                name = "SET_DATA_SLOT",
                param = {dataId, GetControlInstructionalButton(2, v.keybind.hash, 0), label}
            }
            dataId = dataId + 1
        end
    end
    dataSlots[#dataSlots + 1] = {
        name = "DRAW_INSTRUCTIONAL_BUTTONS",
        param = { -1 }
    }
    return dataSlots
end

local function normalize(x, y, z)
    local length = math.sqrt(x * x + y * y + z * z)
    if length == 0 then
        return 0, 0, 0
    end
    return x / length, y / length, z / length
end

local function makeEntityMatrix(entity)
    local f, r, u, a = GetEntityMatrix(entity)
    local view = dataview.ArrayBuffer(60)

    view:SetFloat32(0, r[1])
        :SetFloat32(4, r[2])
        :SetFloat32(8, r[3])
        :SetFloat32(12, 0)
        :SetFloat32(16, f[1])
        :SetFloat32(20, f[2])
        :SetFloat32(24, f[3])
        :SetFloat32(28, 0)
        :SetFloat32(32, u[1])
        :SetFloat32(36, u[2])
        :SetFloat32(40, u[3])
        :SetFloat32(44, 0)
        :SetFloat32(48, a[1])
        :SetFloat32(52, a[2])
        :SetFloat32(56, a[3])
        :SetFloat32(60, 1)

    return view
end

local function applyEntityMatrix(entity, view)
    local x1, y1, z1 = view:GetFloat32(16), view:GetFloat32(20), view:GetFloat32(24)
    local x2, y2, z2 = view:GetFloat32(0), view:GetFloat32(4), view:GetFloat32(8)
    local x3, y3, z3 = view:GetFloat32(32), view:GetFloat32(36), view:GetFloat32(40)
    local tx, ty, tz = view:GetFloat32(48), view:GetFloat32(52), view:GetFloat32(56)

    if not enableScale then
        x1, y1, z1 = normalize(x1, y1, z1)
        x2, y2, z2 = normalize(x2, y2, z2)
        x3, y3, z3 = normalize(x3, y3, z3)
    end

    SetEntityMatrix(entity,
        x1, y1, z1,
        x2, y2, z2,
        x3, y3, z3,
        tx, ty, tz
    )
end

local function gizmoLoop(entity)
    if not gizmoEnabled then
        return LeaveCursorMode()
    end

    EnterCursorMode()
    isCursorActive = true
    
    Scalform = CreateScaleform("INSTRUCTIONAL_BUTTONS", ActiveScalform())

    if IsEntityAPed(entity) then
        SetEntityAlpha(entity, 200)
    else
        SetEntityDrawOutline(entity, true)
    end
    
    while gizmoEnabled and DoesEntityExist(entity) do
        Wait(0)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 140, true)
        DisablePlayerFiring(cache.playerId, true)

        local matrixBuffer = makeEntityMatrix(entity)
        local changed = Citizen.InvokeNative(0xEB2EDCA2, matrixBuffer:Buffer(), 'Editor1',
            Citizen.ReturnResultAnyway())

        if changed then
            applyEntityMatrix(entity, matrixBuffer)
        end
        
        if Scalform then
            DrawScaleformMovieFullscreen(Scalform, 255, 255, 255, 255, 0)
        end
    end
    
    if isCursorActive then
        LeaveCursorMode()
    end
    isCursorActive = false

    if DoesEntityExist(entity) then
        if IsEntityAPed(entity) then SetEntityAlpha(entity, 255) end
        SetEntityDrawOutline(entity, false)
    end
    
    if Scalform then
        SetScaleformMovieAsNoLongerNeeded(Scalform)
        Scalform = nil
    end

    gizmoEnabled = false
    currentEntity = nil
end

local function useGizmo(entity)
    gizmoEnabled = true
    currentEntity = entity
    gizmoResult = nil
    gizmoLoop(entity)

    return {
        handle = entity,
        position = GetEntityCoords(entity),
        rotation = GetEntityRotation(entity),
        result = gizmoResult or 'cancel'
    }
end

exports("useGizmo", useGizmo)

lib.addKeybind({
    name = '_gizmoSelect',
    description = locale("select_gizmo_description"),
    defaultMapper = 'MOUSE_BUTTON',
    defaultKey = 'MOUSE_LEFT',
    onPressed = function(self)
        if not gizmoEnabled then return end
        ExecuteCommand('+gizmoSelect')
    end,
    onReleased = function (self)
        ExecuteCommand('-gizmoSelect')
    end
})

KeybindRefs.cursor = lib.addKeybind({
    name = '_gizmoCursor',
    description = locale("enable_cursor"),
    defaultKey = 'G',
    onPressed = function(self)
        if not gizmoEnabled then return end
        if isCursorActive then
            LeaveCursorMode()
            isCursorActive = false
        else
            EnterCursorMode()
            isCursorActive = true
        end
        if Scalform then
            SetScaleformParams(Scalform, ActiveScalform())
        end
    end,
})

KeybindRefs.translate = lib.addKeybind({
    name = '_gizmoTranslation',
    description = locale("translation_mode_description"),
    defaultKey = 'W',
    onPressed = function(self)
        if not gizmoEnabled then return end
        currentMode = 'Translate'
        ExecuteCommand('+gizmoTranslation')
    end,
    onReleased = function (self)
        ExecuteCommand('-gizmoTranslation')
    end
})

KeybindRefs.rotate = lib.addKeybind({
    name = '_gizmoRotation',
    description = locale("rotation_mode_description"),
    defaultKey = 'R',
    onPressed = function(self)
        if not gizmoEnabled then return end
        currentMode = 'Rotate'
        ExecuteCommand('+gizmoRotation')
    end,
    onReleased = function (self)
        ExecuteCommand('-gizmoRotation')
    end
})

KeybindRefs.toggleSpace = lib.addKeybind({
    name = '_gizmoLocal',
    description = locale("toggle_space_description"),
    defaultKey = 'F',
    onPressed = function(self)
        if not gizmoEnabled then return end
        isRelative = not isRelative
        if Scalform then
            SetScaleformParams(Scalform, ActiveScalform())
        end
        ExecuteCommand('+gizmoLocal')
    end,
    onReleased = function (self)
        ExecuteCommand('-gizmoLocal')
    end
})

KeybindRefs.doneEditing = lib.addKeybind({
    name = 'gizmoclose',
    description = locale("close_gizmo_description"),
    defaultKey = 'RETURN',
    onReleased = function(self)
        if not gizmoEnabled then return end
        gizmoResult = 'confirm'
        gizmoEnabled = false
    end,
})

KeybindRefs.cancelEditing = lib.addKeybind({
    name = 'gizmoCancel',
    description = locale("cancel_editing_description"),
    defaultKey = 'BACK',
    onReleased = function(self)
        if not gizmoEnabled then return end
        gizmoResult = 'cancel'
        gizmoEnabled = false
    end,
})

KeybindRefs.snapToGround = lib.addKeybind({
    name = 'gizmoSnapToGround',
    description = locale("snap_to_ground_description"),
    defaultKey = 'LSHIFT',
    onPressed = function(self)
        if not gizmoEnabled then return end
        PlaceObjectOnGroundProperly_2(currentEntity)
    end,
})

if enableScale then
    KeybindRefs.scale = lib.addKeybind({
        name = '_gizmoScale',
        description = locale("scale_mode_description"),
        defaultKey = 'S',
        onPressed = function(self)
            if not gizmoEnabled then return end
            currentMode = 'Scale'
            ExecuteCommand('+gizmoScale')
        end,
        onReleased = function (self)
            ExecuteCommand('-gizmoScale')
        end
    })
end

table.insert(DetailsGizmo, { keybind = KeybindRefs.doneEditing, label = locale("done_editing") })
table.insert(DetailsGizmo, { keybind = KeybindRefs.rotate, label = locale("rotate_mode") })
table.insert(DetailsGizmo, { keybind = KeybindRefs.translate, label = locale("translate_mode") })
table.insert(DetailsGizmo, { keybind = KeybindRefs.toggleSpace, label = locale("toggle_space") })
table.insert(DetailsGizmo, { keybind = KeybindRefs.cursor, label = locale("enable_cursor") })
table.insert(DetailsGizmo, { keybind = KeybindRefs.snapToGround, label = locale("snap_to_ground") })
if enableScale and KeybindRefs.scale then
    table.insert(DetailsGizmo, { keybind = KeybindRefs.scale, label = locale("scale_mode") })
end
table.insert(DetailsGizmo, { keybind = KeybindRefs.cancelEditing, label = locale("cancel_editing") })
