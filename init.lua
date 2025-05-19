-- ClickStabilizer Spoon
local obj = {}
obj.__index = obj

-- Metadata
obj.name    = "ClickStabilizer"
obj.version = "1.2.0"
obj.author  = "Hadi Skeini <hadiskeini@icloud.com>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Modules
local hs_eventtap = require("hs.eventtap")
local hs_mouse    = require("hs.mouse")
local hs_timer    = require("hs.timer")
local hs_console  = require("hs.console")
local hs_settings = require("hs.settings")
local hs_hotkey   = require("hs.hotkey")
local hs_menubar  = require("hs.menubar")
local hs_image    = require("hs.image")
local hs_dialog   = require("hs.dialog")
local hs_webview  = require("hs.webview")
local hs_urlevent = require("hs.urlevent")
local masks = hs.webview.windowMasks

hs_urlevent.bind("ClickStabilizerConfig", function(scheme, params)
    if params.reset then
        obj:resetDefaults()
        obj.hotkeyString = hs_settings.get(obj.persistKeyHotkey) or "cmd+alt+L"
        obj:bindHotkey()
        -- Refresh the form with updated defaults
        obj:configure()
        return
    end
    if params.device then
        obj:setDevice()
        local msg = "Let's identify your pointing device! Click your pointing device once..."
        obj:configure(msg)
        return
    end
    -- apply new settings
    local dur = tonumber(params.lock)
    local hot = params.hotkey
    if dur then obj:setLock(dur) end
    if hot then
        obj.hotkeyString = hot
        hs_settings.set(obj.persistKeyHotkey, hot)
        obj:bindHotkey()
    end
    -- close the config window
    if obj.webview then obj.webview:delete() obj.webview = nil end
end)

-- Persistence keys
obj.persistKeyFlags = "ClickStabilizer.EVENT_FLAGS"
obj.persistKeyLock  = "ClickStabilizer.LOCK_MS"
obj.persistKeyHotkey = "ClickStabilizer.HOTKEY"
obj.hotkeyString    = hs_settings.get(obj.persistKeyHotkey) or "cmd+alt+L"

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
function obj:init()
    self.isActive      = false
    self.startPosition = nil
    self.releaseTimer  = nil
    self.isDeviceTap   = false
    self.flagFinderTap = nil
    self.lockSeconds   = self.lockMs / 1000
end

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

function obj:resetDefaults()
    local defaultFlags = 0x20000100
    local defaultLock  = 100
    local defaultHotkey = "cmd+alt+L"
    self.eventFlags    = defaultFlags
    self.lockMs        = defaultLock
    self.lockSeconds   = defaultLock / 1000
    self.hotkeyString  = defaultHotkey
    hs_settings.set(self.persistKeyFlags, defaultFlags)
    hs_settings.set(self.persistKeyLock, defaultLock)
    hs_settings.set(self.persistKeyHotkey, defaultHotkey)
    print("✅ ClickStabilizer settings have been reset to defaults!")
end

function obj:isDeviceTapEvent(event)
    local raw = event:getRawEventData()
    return raw and raw.CGEventData and raw.CGEventData.flags == self.eventFlags
end

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

function obj:start()
    if self.eventTap then return end
    self:init()
    self.eventTap = hs_eventtap.new({DOWN, MOVE, DRAG_L, DRAG_R, DRAG_O}, function(e)
        return self:masterEventCallback(e)
    end)
    self.eventTap:start()
    if self.menuBar then
        local lockedIconPath = hs.spoons.resourcePath("csmenubar_locked.svg")
        local lockedIcon = hs_image.imageFromPath(lockedIconPath)
        if lockedIcon then
            self.menuBar:setIcon(lockedIcon)
        end
    end
    print("=== ClickStabilizer — How to use ===")
    print("cs:setDevice()        → Set up the pointing device that should be affected")
    print("cs:setLock(ms)        → Set the click-lock duration in milliseconds (default: 100)")
    print("cs:resetDefaults()    → Reset all settings")
    print("cs:stop()             → Stop the ClickStabilizer Spoon")
    print("====================================")
end

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
    self.isActive      = false
    self.startPosition = nil
    print("ClickStabilizer stopped.")
    if self.menuBar then
        local unlockedIconPath = hs.spoons.resourcePath("csmenubar_unlocked.svg")
        local unlockedIcon = hs_image.imageFromPath(unlockedIconPath)
        if unlockedIcon then
            self.menuBar:setIcon(unlockedIcon)
        end
    end
end

function obj:setDevice()
    if self.flagFinderTap and self.flagFinderTap:isEnabled() then
        print("We’re already waiting for your click. Go ahead! 👆")
        return
    end
    print("Let’s identify your pointing device!")
    self.flagFinderTap = hs_eventtap.new({DOWN}, function(e)
        local raw = e:getRawEventData()
        local msg
        if raw and raw.CGEventData and raw.CGEventData.flags then
            local f = raw.CGEventData.flags
            self:setEventFlags(f)
            msg = "✅ Great! ClickStabilizer is now functional!"
        else
            msg = "I couldn’t detect a code. Try clicking again."
        end
        self.flagFinderTap:stop()
        self.flagFinderTap = nil
        self:configure(msg)
        return false
    end)
    if self.flagFinderTap then
        self.flagFinderTap:start()
        print("Click your pointing device once...")
    else
        print("Oops! Couldn’t start. Check your permissions.")
    end
end

--- Toggles the ClickStabilizer on or off
function obj:toggle()
    if self.eventTap then
        self:stop()
    else
        self:start()
    end
end

--- Binds or rebinds the global hotkey based on `hotkeyString`
function obj:bindHotkey()
    -- Disable previous hotkey if exists
    if self.hotkey then
        self.hotkey:disable()
    end
    -- Parse hotkeyString into mods and key
    local parts = {}
    for part in string.gmatch(self.hotkeyString, "([^+]+)") do
        table.insert(parts, part)
    end
    local key = parts[#parts]
    local mods = {}
    for i=1, #parts-1 do table.insert(mods, parts[i]) end
    -- Bind the new hotkey
    self.hotkey = hs_hotkey.bind(mods, key, function()
        self:toggle()
    end)
end

--- Opens a WebView-based configuration dialog
function obj:configure(message)
    local outputMsg = message or ""
    local html = [[
<!DOCTYPE html>
<html>
<head>
<style>
body { background-color: #1e1e1e; color: #ddd; -webkit-user-select: none; user-select: none; }
input, button { background-color: #333; color: #eee; border: 1px solid #555; -webkit-user-select: text; user-select: text; }
</style>
</head>
<body style="font-family: sans-serif; padding: 20px;">
<h3>ClickStabilizer Configuration</h3>
    <button id="set-device-button" onclick="startDeviceSetup()" style="margin-bottom: 8px;">Identify Device</button>
    <div id="device-output" style="margin-bottom: 15px;">]] .. outputMsg .. [[</div>
<label>Click-lock duration (ms): <input type="number" id="lock" value="]]..self.lockMs..[[" min="10" max="2000" step="1" oninput="this.value=this.value.replace(/[^0-9]/g,'')" onblur="clampLock()" /></label><br/><br/>
<label>Toggle hotkey: cmd+option+<input type="text" id="hotkey-letter" value="]]..(self.hotkeyString:match("[^+]+$") or "")..[[" maxlength="1" pattern="[A-Za-z]" oninput="this.value=this.value.replace(/[^A-Za-z]/g,'').toUpperCase()" onblur="clampLetter()" /></label><br/><br/>
<button onclick="apply()">OK</button>
<button onclick="resetDefaults()">Reset</button>
<script>
function clampLock(){
    var lockInput = document.getElementById('lock');
    var lock = parseInt(lockInput.value, 10);
    if (isNaN(lock) || lock < 10) {
        lock = 10;
    } else if (lock > 2000) {
        lock = 2000;
    }
    lockInput.value = lock;
}
function clampLetter(){
    var letterInput = document.getElementById('hotkey-letter');
    var letter = letterInput.value.toUpperCase();
    if (!letter.match(/^[A-Z]$/)) {
        letter = letterInput.defaultValue.toUpperCase();
    }
    letterInput.value = letter;
}
function apply(){
    var lockInput = document.getElementById('lock');
    var lock = parseInt(lockInput.value, 10);
    if (isNaN(lock) || lock < 10) {
        lock = 10;
    } else if (lock > 2000) {
        lock = 2000;
    }
    lockInput.value = lock;
    var letterInput = document.getElementById('hotkey-letter');
    var letter = letterInput.value.toUpperCase();
    if (!letter) {
        letter = letterInput.defaultValue.toUpperCase();
    }
    var hotkey = 'cmd+alt+' + letter;
    window.location = 'hammerspoon://ClickStabilizerConfig?lock='+lock+'&hotkey='+encodeURIComponent(hotkey);
}
function resetDefaults(){
    window.location = 'hammerspoon://ClickStabilizerConfig?reset=1';
}
function startDeviceSetup(){
    window.location = 'hammerspoon://ClickStabilizerConfig?device=1';
}
</script>
</body>
</html>
]]
    if not self.webview then
        self.webview = hs_webview.new({x=100, y=100, w=400, h=320}, {developerExtrasEnabled = false})
            :windowTitle(obj.name .. " Configuration")
            :allowTextEntry(true)
            :windowStyle(masks.titled + masks.closable):shadow(true)
            :html(html)
            :show()
    else
        self.webview
            :allowTextEntry(true)
            :windowStyle(masks.titled + masks.closable):shadow(true)
            :html(html)
            :show()
    end
end

--- Binds the global hotkey and creates a menubar icon
function obj:bindHotkeyAndMenu()
    -- Bind global hotkey based on settings
    self:bindHotkey()

    -- Menubar icon
    self.menuBar = hs_menubar.new()
    if self.menuBar then
        -- Load custom menubar icon from Spoon resources
        local iconPath = hs.spoons.resourcePath("csmenubar_unlocked.svg")
        local iconImage = hs_image.imageFromPath(iconPath)
        -- Only check for non-nil image; remove isNil() call which is not defined
        if iconImage then
            self.menuBar:setIcon(iconImage)
        else
            self.menuBar:setTitle("🖱")
        end
        self.menuBar:setClickCallback(function()
            self:toggle()
        end)
        self.menuBar:setMenu(function()
            local title = self.eventTap and "Stop ClickStabilizer" or "Start ClickStabilizer"
            return {
              { title = title, fn = function() self:toggle() end },
              { title = "Configure...", fn = function() self:configure() end }
            }
        end)
    end
end

-- Setup hotkey and menubar when Spoon loads
obj:bindHotkeyAndMenu()

return obj
