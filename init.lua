-- ClickStabilizer Spoon
local obj = {}
obj.__index = obj

-- Metadata
obj.name    = "ClickStabilizer"
obj.version = "1.0.1"
obj.author  = "Hadi Skeini <hadiskeini@icloud.com>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Modules
local hs_eventtap = require("hs.eventtap")
local hs_mouse    = require("hs.mouse")
local hs_timer    = require("hs.timer")
local hs_console  = require("hs.console")
local hs_settings = require("hs.settings")

-- Persistence keys
obj.persistKeyFlags = "ClickStabilizer.EVENT_FLAGS"
obj.persistKeyLock  = "ClickStabilizer.LOCK_MS"

-- Defaults (overwritten by previous settings)
obj.eventFlags = hs_settings.get(obj.persistKeyFlags) or 0x20000100
obj.lockMs     = hs_settings.get(obj.persistKeyLock)  or 100

-- Event types
local types = hs_eventtap.event.types
local DOWN    = types.leftMouseDown
local MOVE    = types.mouseMoved
local DRAG_L  = types.leftMouseDragged
local DRAG_R  = types.rightMouseDragged
local DRAG_O  = types.otherMouseDragged

-- Initialize state
--- Initializes internal state for the Spoon
function obj:init()
    self.isActive      = false
    self.startPosition = nil
    self.releaseTimer  = nil
    self.isDeviceTap   = false
    self.flagFinderTap = nil
    self.lockSeconds   = self.lockMs / 1000
end

--- Sets the event flags to identify your pointing device
-- @param flag A number (e.g. 0x20000100) representing the device flags
function obj:setEventFlags(flag)
    local num = tonumber(flag)
    if not num then
        print("Oops! That code doesn’t look right. Try a number like '0x20000100'.")
        return
    end
    self.eventFlags = num
    hs_settings.set(self.persistKeyFlags, num)
    print("✅ Great! ClickStabilizer is now functional!")
end

--- Sets the lock duration in milliseconds
-- @param ms Number of milliseconds to lock the cursor after click
function obj:setLock(ms)
    local num = tonumber(ms)
    if not num or num < 0 then
        print("Hmm, that value doesn’t work. Please give a positive number of milliseconds.")
        return
    end
    self.lockMs      = num
    self.lockSeconds = num / 1000
    hs_settings.set(self.persistKeyLock, num)
    print(string.format("✅ When you click, your cursor position is now locked for %d ms.", num))
end

--- Resets all settings to their default values
function obj:resetDefaults()
    local defaultFlags = 0x20000100
    local defaultLock  = 100
    self.eventFlags    = defaultFlags
    self.lockMs        = defaultLock
    self.lockSeconds   = defaultLock / 1000
    hs_settings.set(self.persistKeyFlags, defaultFlags)
    hs_settings.set(self.persistKeyLock, defaultLock)
    print("✅ ClickStabilizer settings have been reset to defaults!")
end

--- Checks if the incoming event matches the configured device flags
-- @param event The HS eventtap event object
-- @return boolean True if the event is from the configured device
function obj:isDeviceTapEvent(event)
    local raw = event:getRawEventData()
    return raw and raw.CGEventData and raw.CGEventData.flags == self.eventFlags
end

--- Core event callback enforcing the click lock
-- @param event The HS eventtap event
-- @return boolean True to swallow the event, false to pass it through
function obj:masterEventCallback(event)
    local t = event:getType()

    if t == DOWN then
        if self:isDeviceTapEvent(event) and not self.isActive then
            self.startPosition = hs_mouse.absolutePosition()
            self.isActive      = true
            self.isDeviceTap   = true
            if self.releaseTimer then self.releaseTimer:stop() end
            self.releaseTimer = hs_timer.doAfter(self.lockSeconds, function()
                self.isActive      = false
                self.startPosition = nil
                self.releaseTimer  = nil
                self.isDeviceTap   = false
            end)
        end
        return false
    end

    if (t == MOVE or t == DRAG_L or t == DRAG_R or t == DRAG_O)
    and self.isActive and self.isDeviceTap
    and self:isDeviceTapEvent(event) then
        hs_mouse.absolutePosition(self.startPosition)
        return true
    end

    return false
end

--- Starts the ClickStabilizer Spoon by registering the event tap
function obj:start()
    if self.eventTap then return end
    self:init()
    self.eventTap = hs_eventtap.new({DOWN, MOVE, DRAG_L, DRAG_R, DRAG_O}, function(e)
        return self:masterEventCallback(e)
    end)
    self.eventTap:start()
    print("=== ClickStabilizer — How to use ===")
    print("cs:setDevice()        → Set up the pointing device that should be affected")
    print("cs:setLock(ms)        → Set the click-lock duration in milliseconds (default: 100)")
    print("cs:resetDefaults()    → Reset all settings")
    print("cs:stop()             → Stop the ClickStabilizer Spoon")
    print("====================================")
end

--- Stops the ClickStabilizer Spoon, cleaning up event taps and timers
function obj:stop()
    if self.eventTap then
        self.eventTap:stop()
        self.eventTap = nil
    end
    if self.releaseTimer then
        self.releaseTimer:stop()
        self.releaseTimer = nil
    end
    if self.flagFinderTap then
        self.flagFinderTap:stop()
        self.flagFinderTap = nil
    end
    self.isActive    = false
    self.startPosition = nil
    print("ClickStabilizer stopped.")
end

--- Initiates a one-time listener to detect and save the current device flags
function obj:setDevice()
    if self.flagFinderTap and self.flagFinderTap:isEnabled() then
        print("We’re already waiting for your click. Go ahead! 👆")
        return
    end

    print("Let’s identify your pointing device!")

    self.flagFinderTap = hs_eventtap.new({DOWN}, function(e)
        local raw = e:getRawEventData()
        if raw and raw.CGEventData and raw.CGEventData.flags then
            local f = raw.CGEventData.flags
            self:setEventFlags(f)
        else
            hs_console.printStyledtext("I couldn’t detect a code. Try clicking again.")
        end
        self.flagFinderTap:stop()
        self.flagFinderTap = nil
        return false
    end)

    if self.flagFinderTap then
        self.flagFinderTap:start()
        print("Click your pointing device once...")
    else
        print("Oops! Couldn’t start. Check your permissions.")
    end
end

return obj
