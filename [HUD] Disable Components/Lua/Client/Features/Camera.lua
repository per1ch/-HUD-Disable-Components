-- Lua/Client/Features/Camera.lua — CLIENT
--
-- Two synced camera controls:
--   LockCameraZoom + CameraZoomLevel   force a zoom level on every client
--   DisableCameraFollow                stop the camera drifting toward the cursor
--
-- Both are phrased so that "off" means vanilla behaviour, which is why the
-- zoom is a lock plus a value rather than a bare number: with the lock off
-- the mod never touches the camera at all.

HDC = HDC or {}

local Safe        = HDC.Safe
local ClientState = HDC.ClientState

local function zoomLocked()
    return ClientState.Get("LockCameraZoom") == true
end

local function targetZoom()
    return ClientState.GetNumber("CameraZoomLevel")
end

local function followDisabled()
    return ClientState.Get("DisableCameraFollow") == true
end

local function activeCamera()
    return Safe.Get(function() return GameMain.GameScreen.Cam end)
        or Safe.Get(function() return Screen.Selected.Cam end)
end

-- Zoom is re-applied every frame: the game continuously recalculates it
-- from input, so setting it once would immediately be overwritten.
Safe.AddHook("think", "HDC.Camera.Apply", function()
    if not zoomLocked() and not followDisabled() then return end

    local camera = activeCamera()
    if camera == nil then return end

    if zoomLocked() then
        local zoom = targetZoom()
        Safe.Set(function() camera.Zoom = zoom end)
        -- Pin the bounds too, otherwise the player can still scroll and the
        -- view fights back visibly every frame.
        Safe.Set(function() camera.MinZoom = zoom end)
        Safe.Set(function() camera.MaxZoom = zoom end)
    end

    if followDisabled() then
        Safe.Set(function() camera.OffsetAmount = 0 end)
    end
end)

-- Block the zoom input path outright while locked, so the scroll wheel
-- does not queue changes that get undone a frame later.
Safe.PatchMethod("Barotrauma.Camera", "set_Zoom", nil, function(instance, ptable)
    if not zoomLocked() then return end
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

-- Restore vanilla bounds when the lock is released, otherwise MinZoom and
-- MaxZoom stay pinned to the locked value for the rest of the session.
local wasLocked = false
local savedBounds = nil

Safe.AddHook("think", "HDC.Camera.RestoreBounds", function()
    local locked = zoomLocked()
    if locked == wasLocked then return end

    local camera = activeCamera()
    if camera ~= nil then
        if locked then
            savedBounds = {
                min = Safe.Get(function() return camera.MinZoom end),
                max = Safe.Get(function() return camera.MaxZoom end),
            }
        elseif savedBounds ~= nil then
            Safe.Set(function() camera.MinZoom = savedBounds.min end)
            Safe.Set(function() camera.MaxZoom = savedBounds.max end)
            savedBounds = nil
        end
    end
    wasLocked = locked
end)
