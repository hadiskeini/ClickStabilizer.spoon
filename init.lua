-- ClickStabilizer Spoon
local obj = {}
obj.__index = obj

-- Metadata
obj.name    = "ClickStabilizer"
obj.version = "1.2.0"
obj.author  = "Hadi Skeini hadiskeini@icloud.com"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Modules
local hs_eventtap = require("hs.eventtap")
local hs_mouse    = require("hs.mouse")
local hs_console  = require("hs.console")
local hs_settings = require("hs.settings")
local hs_hotkey   = require("hs.hotkey")
local hs_menubar  = require("hs.menubar")
local hs_image    = require("hs.image")
local hs_dialog   = require("hs.dialog")
local hs_webview  = require("hs.webview")
local hs_urlevent = require("hs.urlevent")
local hs_timer    = require("hs.timer")
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
    local hot = params.hotkey
    if hot then
        obj.hotkeyString = hot
        hs_settings.set(obj.persistKeyHotkey, hot)
        obj:bindHotkey()
    end
    
    -- Apply threshold if provided (with clamping)
    local thresh = params.threshold
    if thresh then
        local threshVal = tonumber(thresh)
        if threshVal then
            -- Clamp value to [5,100]
            local clampedVal = threshVal
            if clampedVal < 5 then clampedVal = 5 end
            if clampedVal > 100 then clampedVal = 100 end
            obj.dragThreshold = clampedVal
            obj.dragThreshold2 = clampedVal * clampedVal
            hs_settings.set(obj.persistKeyThreshold, clampedVal)
        end
    end

        -- Apply time threshold if provided
        local timeThresh = params.timeThreshold
        if timeThresh then
            local timeVal = tonumber(timeThresh)
            if timeVal and timeVal >= 10 and timeVal <= 5000 then  -- now in ms
                obj.timeThreshold = timeVal
                hs_settings.set(obj.persistKeyTimeThreshold, timeVal)
            end
        end
        -- Apply debug console toggle if provided
        local debugParam = params.debug
        if debugParam then
            local debugEnabled = (debugParam == "true")
            obj.debugConsole = debugEnabled
            hs_settings.set(obj.persistKeyDebugConsole, debugEnabled)
        end
    
    -- refresh the config window to reflect updated settings without closing
    obj:configure("✅ Settings saved!")
end)

-- Persistence keys
obj.persistKeyFlags     = "ClickStabilizer.EVENT_FLAGS"
obj.persistKeyHotkey    = "ClickStabilizer.HOTKEY"
obj.hotkeyString        = hs_settings.get(obj.persistKeyHotkey) or "cmd+alt+L"
obj.persistKeyThreshold = "ClickStabilizer.DRAG_THRESHOLD_PX"
obj.dragThreshold       = tonumber(hs_settings.get(obj.persistKeyThreshold)) or 32
obj.dragThreshold2      = obj.dragThreshold * obj.dragThreshold

-- Persist and default for time-based drag threshold
obj.persistKeyTimeThreshold = "ClickStabilizer.DRAG_TIME_THRESHOLD_S"
obj.timeThreshold           = tonumber(hs_settings.get(obj.persistKeyTimeThreshold)) or 150  -- default in milliseconds

-- Persist and default for debug console output
obj.persistKeyDebugConsole  = "ClickStabilizer.DEBUG_CONSOLE"
obj.debugConsole            = false

-- Defaults (overwritten by previous settings)
obj.eventFlags = hs_settings.get(obj.persistKeyFlags) or 0x20000100

-- Event types
local types = hs_eventtap.event.types
local DOWN    = types.leftMouseDown
local MOVE    = types.mouseMoved
local DRAG_L  = types.leftMouseDragged
local DRAG_R  = types.rightMouseDragged
local DRAG_O  = types.otherMouseDragged
local UP      = types.leftMouseUp

-- Initialize state
function obj:init()
    self.state = nil
    self.startPosition = nil
    self.currentPosition = nil
    self.flagFinderTap = nil
    self.thresholdCrossed = false
end

function obj:setEventFlags(flag)
    local num = tonumber(flag)
    if not num then
        print("Oops! That code doesn't look right. Try a number like '0x20000100'.")
        return
    end
    self.eventFlags = num
    hs_settings.set(self.persistKeyFlags, num)
    print("✅ Great! ClickStabilizer is now functional!")
end

function obj:resetDefaults()
    local defaultFlags  = 0x20000100
    local defaultHotkey = "cmd+alt+L"
    local defaultThresh = 32

    self.eventFlags    = defaultFlags
    self.hotkeyString  = defaultHotkey
    self.dragThreshold = defaultThresh
    self.dragThreshold2= defaultThresh * defaultThresh

    hs_settings.set(self.persistKeyFlags, defaultFlags)
    hs_settings.set(self.persistKeyHotkey, defaultHotkey)
    hs_settings.set(self.persistKeyThreshold, defaultThresh)

    -- Reset time threshold to default (ms)
    local defaultTimeThresh = 150
    self.timeThreshold = defaultTimeThresh
    hs_settings.set(self.persistKeyTimeThreshold, defaultTimeThresh)

    print("✅ ClickStabilizer settings have been reset to defaults!")
end

function obj:isDeviceTapEvent(event)
    local raw = event:getRawEventData()
    return raw and raw.CGEventData and raw.CGEventData.flags == self.eventFlags
end

-- Modified click/drag handling algorithm
function obj:masterEventCallback(event)
    local eventType = event:getType()
    local clickProp = hs_eventtap.event.properties.mouseEventClickState
    -- Helper to finish a click
    local function finishClick()
        local clickCount = event:getProperty(clickProp) or 1
        hs_eventtap.event.newMouseEvent(UP, self.startPosition):setProperty(clickProp, clickCount):post()
        self.state = nil
    end

    if eventType == DOWN and self:isDeviceTapEvent(event) then
        self.state = "PotentialClick"
        self.startPosition = hs_mouse.absolutePosition()
        self.currentPosition = self.startPosition
        self.thresholdCrossed = false
        self.mouseDownTime = hs_timer.secondsSinceEpoch() * 1000
        local clickCount = event:getProperty(clickProp) or 1
        hs_eventtap.event.newMouseEvent(DOWN, self.startPosition):setProperty(clickProp, clickCount):post()
        return true
    end

    if self.state == "PotentialClick" then
        if eventType == DRAG_L or eventType == DRAG_R or eventType == DRAG_O then
            self.currentPosition = hs_mouse.absolutePosition()
            local now = hs_timer.secondsSinceEpoch() * 1000
            local dx = self.currentPosition.x - self.startPosition.x
            local dy = self.currentPosition.y - self.startPosition.y
            local distSquared = dx*dx + dy*dy

            if not self.thresholdCrossed then
                if distSquared > self.dragThreshold2 or (now - self.mouseDownTime) > self.timeThreshold then
                    self.thresholdCrossed = true
                    if self.debugConsole then
                        local metric = distSquared > self.dragThreshold2 and math.sqrt(distSquared) or (now - self.mouseDownTime)
                        print(string.format("%s: drag triggered by %s threshold at %.2f%s", obj.name,
                            distSquared > self.dragThreshold2 and "distance" or "time",
                            metric,
                            distSquared > self.dragThreshold2 and " px" or " ms"))
                    end
                end
            end
            return not self.thresholdCrossed
        elseif eventType == UP then
            if not self.thresholdCrossed then
                finishClick()
                return true
            end
            self.state = nil
            return false
        end
    end

    return false
end

function obj:start()
    if self.eventTap then return end
    self:init()
    
    self.eventTap = hs_eventtap.new({DOWN, MOVE, DRAG_L, DRAG_R, DRAG_O, UP}, function(e)
        return self:masterEventCallback(e)
    end)
    
    self.eventTap:start()
    
    if self.menuBar then
        local lockedIconPath = hs.spoons.resourcePath("csmenubar_locked.svg")
        local lockedIcon = hs_image.imageFromPath(lockedIconPath)
        if lockedIcon then self.menuBar:setIcon(lockedIcon) end
    end
    
    print("=== ClickStabilizer — How to use ===")
    print("cs:setDevice()        → Set up the pointing device that should be affected")
    print("cs:resetDefaults()    → Reset all settings")
    print("cs:stop()             → Stop the ClickStabilizer Spoon")
    print("cs:configure()        → Open configuration panel")
    print("====================================")
end

function obj:stop()
    if self.eventTap then self.eventTap:stop(); self.eventTap = nil end
    if self.flagFinderTap then self.flagFinderTap:stop(); self.flagFinderTap = nil end
    self.state = nil
    self.startPosition = nil
    
    print("ClickStabilizer stopped.")
    
    if self.menuBar then
        local unlockedIconPath = hs.spoons.resourcePath("csmenubar_unlocked.svg")
        local unlockedIcon = hs_image.imageFromPath(unlockedIconPath)
        if unlockedIcon then self.menuBar:setIcon(unlockedIcon) end
    end
end

function obj:setDevice()
    if self.flagFinderTap and self.flagFinderTap:isEnabled() then
        print("We're already waiting for your click. Go ahead! 👆")
        return
    end
    
    print("Let's identify your pointing device!")
    self.flagFinderTap = hs_eventtap.new({DOWN}, function(e)
        local raw = e:getRawEventData()
        local msg
        if raw and raw.CGEventData and raw.CGEventData.flags then
            local f = raw.CGEventData.flags
            self:setEventFlags(f)
            msg = "✅ Great! ClickStabilizer is now functional!"
        else
            msg = "I couldn't detect a code. Try clicking again."
        end
        self.flagFinderTap:stop()
        self.flagFinderTap = nil
        self:configure(msg)
        return false
    end)
    
    self.flagFinderTap:start()
    print("Click your pointing device once...")
end

function obj:toggle()
    if self.eventTap then self:stop() else self:start() end
end

function obj:bindHotkey()
    if self.hotkey then self.hotkey:delete() end
    local parts = {}
    for part in string.gmatch(self.hotkeyString, "([^+]+)") do table.insert(parts, part) end
    local key = parts[#parts]
    local mods = {}
    for i=1, #parts-1 do table.insert(mods, parts[i]) end
    self.hotkey = hs_hotkey.bind(mods, key, function() self:toggle() end)
end

function obj:configure(message)
    local outputMsg = message or ""
    -- recalc dependent values based on current in-memory settings
    self.dragThreshold2 = self.dragThreshold * self.dragThreshold
    local html = [[
<!DOCTYPE html>
<html>
<head>
<style>
body { background-color: #1e1e1e; color: #ddd; user-select: none; }
input, button { background-color: #333; color: #eee; border: 1px solid #555; user-select: text; caret-color: #eee; }
input:focus { outline: 1px solid #888; }
</style>
</head>
<body style="font-family: sans-serif; padding: 20px;">
<h3>ClickStabilizer Configuration</h3>
<button id="set-device-button" onclick="startDeviceSetup()" style="margin-bottom: 8px;">Identify Device</button>
<div style="margin-bottom: 15px;">
    <label>Drag threshold (px): <input type="number" id="threshold" min="5" max="100" onblur="clampThreshold()" value="]] .. tostring(self.dragThreshold) .. [[" style="width: 50px;" /></label>
</div>
      <div style="margin-bottom: 15px;">
          <label>Time threshold (ms): <input type="number" id="timeThreshold" min="10" max="1000" onblur="clampTimeThreshold()" step="1" value="]] .. tostring(self.timeThreshold) .. [[" style="width: 60px;" /></label>
      </div>
      <div style="margin-bottom: 15px;">
          <label><input type="checkbox" id="debugConsole" ]] .. (self.debugConsole and "checked" or "") .. [[ /> Enable debug console output</label>
      </div>
<label>Toggle hotkey: cmd+option+<input type="text" id="hotkey-letter" value="]]..(self.hotkeyString:match("[^+]+$") or "")..[[" maxlength="1" pattern="[A-Za-z]" oninput="this.value=this.value.replace(/[^A-Za-z]/g,'').toUpperCase()" onblur="clampLetter()" /></label><br/><br/>
<button onclick="apply()">Save</button><button onclick="resetDefaults()">Reset</button>
<div id="device-output" style="margin-top: 15px;">]] .. outputMsg .. [[</div>
<script>
function clampLetter(){ var letterInput=document.getElementById('hotkey-letter'); var letter=letterInput.value.toUpperCase(); if(!letter.match(/^[A-Z]$/)) letter=letterInput.defaultValue.toUpperCase(); letterInput.value=letter; }
function clampThreshold(){
    var input = document.getElementById('threshold');
    var val = parseInt(input.value, 10) || input.defaultValue;
    if (val < 5) val = 5;
    if (val > 100) val = 100;
    input.value = val;
}
function clampTimeThreshold(){
    var input = document.getElementById('timeThreshold');
    var val = parseInt(input.value, 10) || input.defaultValue;
    if (val < 10) val = 10;
    if (val > 1000) val = 1000;
    input.value = val;
}
function apply(){
    clampThreshold();
    clampTimeThreshold();
    var letter = document.getElementById('hotkey-letter').value.toUpperCase() || document.getElementById('hotkey-letter').defaultValue.toUpperCase();
    var threshold = document.getElementById('threshold').value;
    var timeThresh = document.getElementById('timeThreshold').value;
    var debugChecked = document.getElementById('debugConsole').checked ? 'true' : 'false';
    window.location = 'hammerspoon://ClickStabilizerConfig?hotkey=' + encodeURIComponent('cmd+alt+' + letter)
        + '&threshold=' + encodeURIComponent(threshold)
        + '&timeThreshold=' + encodeURIComponent(timeThresh)
        + '&debug=' + encodeURIComponent(debugChecked);
}
function resetDefaults(){ window.location='hammerspoon://ClickStabilizerConfig?reset=1'; }
function startDeviceSetup(){ window.location='hammerspoon://ClickStabilizerConfig?device=1'; }
</script>
</body>
</html>
]]
    -- calculate center-screen position
    local screenFrame = hs.screen.mainScreen():frame()
    local winWidth, winHeight = 400, 380
    local xPos = screenFrame.x + math.floor((screenFrame.w - winWidth) / 2)
    local yPos = screenFrame.y + math.floor((screenFrame.h - winHeight) / 2)
    if not self.webview then
        self.webview = hs_webview.new({x=xPos, y=yPos, w=winWidth, h=winHeight},{developerExtrasEnabled=false})
            :windowTitle(obj.name.." Configuration")
            :allowTextEntry(true)
            :windowStyle(masks.titled+masks.closable):shadow(true)
            :html(html):show()
    else
        self.webview:html(html):show()
    end
end

function obj:bindHotkeyAndMenu()
    self:bindHotkey()
    self.menuBar = hs_menubar.new()
    if self.menuBar then
        local iconPath = hs.spoons.resourcePath("csmenubar_unlocked.svg")
        local iconImage = hs_image.imageFromPath(iconPath)
        if iconImage then self.menuBar:setIcon(iconImage) else self.menuBar:setTitle("🖱") end
        self.menuBar:setClickCallback(function() self:toggle() end)
        self.menuBar:setMenu(function()
            local title = self.eventTap and "Stop ClickStabilizer" or "Start ClickStabilizer"
            return {
                { title = title, fn = function() self:toggle() end },
                { title = "Configure...", fn = function() self:configure() end }
            }
        end)
    end
end

-- Setup when Spoon loads
obj:bindHotkeyAndMenu()
return obj