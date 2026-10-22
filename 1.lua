-- +======================================================================+
-- |        ANTI-CHEAT BYPASS CODE REMOVED FOR CLEAN TEST BUILD         |
-- |               FRAMEWORK - PREMIUM MERGED SCRIPT                 |
-- |       Gameplay/Visual Features - Wallhack - Map ESP - Enemy      |
-- |        Vehicle ESP - Mod Skin - In-Game Menu - Auto Feedback      |
-- |                     Developer: @ZenXAHMAD                         |
-- +======================================================================+

-- ============================================================================
-- S1  PER-MATCH GUARD
-- ============================================================================
do
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if _G._MOD_LOADED and _G._MOD_PC == pc then return end
    _G._MOD_LOADED = true
    _G._MOD_PC = pc
end

-- ============================================================================
-- S2  BASE CLASS TABLE & RPC DEFINITIONS
-- ============================================================================
local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true, Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true, Params = { UEnums.EPropertyClass.Object }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true, Params = { UEnums.EPropertyClass.Int }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true, Params = { UEnums.EPropertyClass.Int }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true, Params = { UEnums.EPropertyClass.Bool }
}

-- ============================================================================
-- S3  IMPORTS
-- ============================================================================
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local ok_GameplayData, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData"); if not ok_GameplayData then GameplayData = nil end
local ok_GamePlayTools, GamePlayTools = pcall(require, "GameLua.Mod.BaseMod.Common.GamePlayTools"); if not ok_GamePlayTools then GamePlayTools = nil end
local ok_MatchModeIds, MatchModeIds = pcall(require, "GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig"); if not ok_MatchModeIds then MatchModeIds = nil end
local ok_InGameMarkTools, InGameMarkTools = pcall(require, "GameLua.Mod.BaseMod.Common.InGameMarkTools"); if not ok_InGameMarkTools then InGameMarkTools = nil end
local KismetMathLibrary = import("KismetMathLibrary")
local GameplayStatics = import("GameplayStatics")
local LinearColor = import("LinearColor")
local SlateBlueprintLibrary = import("SlateBlueprintLibrary") or import("/Script/UMG.SlateBlueprintLibrary")
local WidgetLayoutLibrary = import("WidgetLayoutLibrary") or import("/Script/UMG.WidgetLayoutLibrary")
local FVector2D = import("Vector2D")
local FVector = import("Vector")

-- ============================================================================
-- S4  CORE UTILITIES
-- ============================================================================
local _slua = rawget(_G, "slua")
local function Valid(obj)
    if not obj then return false end
    if _slua and _slua.isValid then
        local ok, v = pcall(_slua.isValid, obj)
        if not ok or not v then return false end
    end
    return true
end
_G.Valid = Valid

-- Safe string find wrapper: returns same results as string.find when s is a string, otherwise nil
local function safeFind(s, ...)
    if type(s) ~= "string" then return nil end
    return s:find(...)
end
_G.safeFind = safeFind

local function LogError(ctx, err)
    -- (disabled)
end

-- Safe toggle helper to debounce rapid toggle calls and guard errors
local function SafeToggle(key, fn)
    _G._ToggleCooldowns = _G._ToggleCooldowns or {}
    local now = os.time()
    local last = _G._ToggleCooldowns[key] or 0
    if now - last < 1 then return end -- 1 second debounce
    _G._ToggleCooldowns[key] = now
    _G._ConfigDirty = true
    local ok, err = pcall(fn)
    if not ok then LogError("SafeToggle:"..tostring(key), err) end
    pcall(function() if _G.SaveModSettings then _G.SaveModSettings(true) end end)
end

-- Default performance/configuration values (can be overridden by user's config)
_G.LexusConfig = _G.LexusConfig or {}
if _G.LexusConfig.MaxESP == nil then _G.LexusConfig.MaxESP = 60 end
if _G.LexusConfig.MaxWallChecks == nil then _G.LexusConfig.MaxWallChecks = 25 end
if _G.LexusConfig.DyeInterval == nil then _G.LexusConfig.DyeInterval = 1.5 end
if _G.LexusConfig.ESPDetailDistance == nil then _G.LexusConfig.ESPDetailDistance = 1500 end
if _G.LexusConfig.ESPMaxDistance == nil then _G.LexusConfig.ESPMaxDistance = 15000 end
if _G.LexusConfig.WallhackEnabled == nil then _G.LexusConfig.WallhackEnabled = false end
if _G.LexusConfig.HealthBarESPEnabled == nil then _G.LexusConfig.HealthBarESPEnabled = false end
if _G.LexusConfig.MapESPEnabled == nil then _G.LexusConfig.MapESPEnabled = false end
if _G.LexusConfig.EnemyCounterEnabled == nil then _G.LexusConfig.EnemyCounterEnabled = false end
if _G.LexusConfig.VehicleESPEnabled == nil then _G.LexusConfig.VehicleESPEnabled = false end
if _G.LexusConfig.ItemESPEnabled == nil then _G.LexusConfig.ItemESPEnabled = false end
if _G.LexusConfig.ItemESPMaxDistance == nil then _G.LexusConfig.ItemESPMaxDistance = 40 end
if _G.LexusConfig.BombESPEnabled == nil then _G.LexusConfig.BombESPEnabled = false end
if _G.LexusConfig.SnaplineESPEnabled == nil then _G.LexusConfig.SnaplineESPEnabled = false end
if _G.LexusConfig.BoxESPEnabled == nil then _G.LexusConfig.BoxESPEnabled = false end
if _G.LexusConfig.FakeHWID == nil then _G.LexusConfig.FakeHWID = true end




local function ClearModTimers(pc)
    if not _G.LexusState or not _G.LexusState.ModTimers or #_G.LexusState.ModTimers == 0 then return end
    for _, tid in ipairs(_G.LexusState.ModTimers) do
        if pc and pc.RemoveGameTimer then pcall(pc.RemoveGameTimer, pc, tid) end
    end
    if _G.LexusState then _G.LexusState.ModTimers = {} end
end
_G.ClearModTimers = ClearModTimers

local function RemoveModTimerId(tid)
    if not (_G.LexusState and _G.LexusState.ModTimers and tid) then return end
    local list = _G.LexusState.ModTimers
    for i = #list, 1, -1 do
        if list[i] == tid then table.remove(list, i) end
    end
end

-- TimerManager - Centralised, ultra-safe, self-cleaning timer wrapper
local ModTimerManagerEnabled = true
local TimerManager = {
    Enabled = ModTimerManagerEnabled,
    MinInterval = { UI = 0.05, Movement = 0.2, Visual = 0.3, Wallhack = 0.4, Diagnostic = 1.0, FastESP = 0.05, Snapline = 0.05, ItemESP = 0.05, BombESP = 0.05, VehicleESP = 0.2 },
    _byId = {},
    _byOwner = {},
    _byName = {},
    _owners = setmetatable({}, { __mode = "v" }),
    _activeCount = 0,
    _MAX_TIMERS = 30
}

local function safeOwnerKey(owner)
    if not owner then return "__nil" end
    local ok, uid = pcall(function()
        if type(owner.GetUniqueID) == "function" then return owner:GetUniqueID() end
        return nil
    end)
    if ok and uid ~= nil then return tostring(uid) end
    local okStr, text = pcall(tostring, owner)
    return (okStr and text) or "__owner_unknown"
end

function TimerManager:SetCategoryMinInterval(category, seconds)
    if category and seconds then self.MinInterval[category] = tonumber(seconds) or self.MinInterval[category] end
end

function TimerManager:PurgeDeadTimers()
    local deadIds = {}
    for id, rec in pairs(self._byId) do
        local owner = self._owners[rec.ownerKey]
        if not owner or not Valid(owner) then
            table.insert(deadIds, id)
        end
    end
    for _, id in ipairs(deadIds) do
        self:Clear(id)
    end
end

function TimerManager:Register(owner, name, interval, loop, category, fn)
    if not self.Enabled then
        if owner and owner.AddGameTimer then return owner:AddGameTimer(interval, loop, fn) end
        return nil
    end
    if not owner or type(fn) ~= "function" or not owner.AddGameTimer then return nil end

    category = category or "Visual"
    local minI = self.MinInterval[category] or 0.033
    local useInterval = math.max(interval or minI, minI)
    local ownerKey = safeOwnerKey(owner)
    local nameKey = ownerKey .. "\31" .. tostring(name or "__unnamed")

    local existingId = self._byName[nameKey]
    if existingId and self._byId[existingId] then
        return existingId
    elseif existingId then
        self:Clear(existingId)
    end

    if self._activeCount >= self._MAX_TIMERS then
        self:PurgeDeadTimers()
        if self._activeCount >= self._MAX_TIMERS then
            return nil
        end
    end

    self._owners[ownerKey] = owner
    local _strongOwner = owner
    local timerId = nil

    local wrapped = function()
        if not Valid(_strongOwner) then
            if timerId and _strongOwner and type(_strongOwner.RemoveGameTimer) == "function" then
                pcall(_strongOwner.RemoveGameTimer, _strongOwner, timerId)
            end
            TimerManager:Clear(timerId)
            if tostring(name):find("ESP_") and _G.VisualsStarted then
                _G.VisualsStarted = false
            end
            return
        end
        local ok, err = pcall(fn)
        if not ok then end
    end

    local okAdd, id = pcall(owner.AddGameTimer, owner, useInterval, loop, wrapped)
    if not okAdd or not id then return nil end
    timerId = id

    self._byId[id] = { ownerKey = ownerKey, name = name, category = category, nameKey = nameKey }
    self._byName[nameKey] = id
    self._byOwner[ownerKey] = self._byOwner[ownerKey] or {}
    table.insert(self._byOwner[ownerKey], id)
    self._activeCount = self._activeCount + 1
    return id
end

function TimerManager:Clear(id)
    if not id then return end
    local rec = self._byId[id]
    if not rec then return end
    local ownerKey = rec.ownerKey
    local ownerRef = self._owners[ownerKey]
    if ownerRef and ownerRef.RemoveGameTimer and Valid(ownerRef) then
        pcall(ownerRef.RemoveGameTimer, ownerRef, id)
    end
    self._byId[id] = nil
    if rec.nameKey and self._byName[rec.nameKey] == id then self._byName[rec.nameKey] = nil end
    local list = self._byOwner[ownerKey]
    if list then
        for i = #list, 1, -1 do
            if list[i] == id then table.remove(list, i) end
        end
        if #list == 0 then
            self._byOwner[ownerKey] = nil
            self._owners[ownerKey] = nil
        end
    else
        self._owners[ownerKey] = nil
    end
    self._activeCount = math.max(0, self._activeCount - 1)
end

function TimerManager:ClearAllForOwner(owner)
    if not owner then return end
    local key = safeOwnerKey(owner)
    local list = self._byOwner[key]
    if not list then
        self._owners[key] = nil
        return
    end
    for _, id in ipairs(list) do
        local rec = self._byId[id]
        local ownerRef = self._owners[key]
        if ownerRef and ownerRef.RemoveGameTimer and Valid(ownerRef) then
            pcall(ownerRef.RemoveGameTimer, ownerRef, id)
        end
        self._byId[id] = nil
        if rec and rec.nameKey and self._byName[rec.nameKey] == id then self._byName[rec.nameKey] = nil end
        self._activeCount = math.max(0, self._activeCount - 1)
    end
    self._byOwner[key] = nil
    self._owners[key] = nil
end
_G.TimerManager = TimerManager

local function Notify(msg)
    local s = "[] " .. tostring(msg)
    pcall(function() if _G.LexusNotify then _G.LexusNotify(s) end end)
    pcall(function()
        local sh = import("ScriptHelperClient")
        if sh and sh.AddOnScreenDebugMessage then
            sh.AddOnScreenDebugMessage(s, -1, 4.0, {R=1,G=1,B=0,A=1}, {X=1.2,Y=1.2})
        end
    end)
    pcall(function()
        local KSL = import("KismetSystemLibrary")
        if KSL and KSL.PrintString then
            local FLinearColor = import("LinearColor") or _G.FLinearColor
            local c = FLinearColor and FLinearColor(1, 1, 0, 1) or {R=1, G=1, B=0, A=1}
            KSL.PrintString(nil, s, true, true, c, 4.0)
        end
    end)
    pcall(function()
        local ok, InGameUITools = pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if ok and InGameUITools and InGameUITools.DisplayMessageInGame then
            InGameUITools.DisplayMessageInGame(s)
        end
    end)
end

-- ============================================================================
-- S5  CONFIG & STATE
-- ============================================================================
-- [FIX C5] Apply feature defaults with per-key nil guards (previously this block never executed)
do
    local _cfg_defaults = {
        FakeHWID = true,

        UnlockFPS165 = true,
        SDWAimbot = true,
        AimbotEnabled = true,
        SDWAimFOV = 8,
        SDWAimSpeed = 20,
        SDWAimMaxDist = 250,
        SDWAimRecoil = 1.1,
        SDWAimTargetBots = true,
        SDWAimVisibleOnly = true,
        SDWAimBone = 3,
        SDWAimTrigger = "shoot",

        iPadViewEnabled = false,
        iPadViewFOV = 110,
        VisualCleanupEnabled = false,
        WallhackEnabled = false,
        MapESPEnabled = false,
        EnemyCounterEnabled = false,
        VehicleESPEnabled = false,
        VehicleSmartFilter = false,
        HealthBarESPEnabled = false,
        ItemESPEnabled = false,
        ItemESPMaxDistance = 40,
        TextSizeItemUI = 50,
        ColorItem = 2, -- Yellow (Default)
        EspItem_M416 = true,
        EspItem_AKM = true,
        EspItem_M762 = true,
        EspItem_SCARL = true,
        EspItem_UMP = true,
        EspItem_UZI = true,
        EspItem_AWM = true,
        EspItem_M24 = true,
        EspItem_Scope3x = true,
        EspItem_Scope4x = true,
        EspItem_Scope6x = true,
        EspItem_Scope8x = true,
        EspItem_Frag = true,
        EspItem_Smoke = true,
        EspItem_Molotov = true,
        BombESPEnabled = false,
        SnaplineESPEnabled = false,
        HDRGlowEnabled = false,
        ModSkin = false,
        SkinOptionOpen = false,
        GlowIntensity = 60,
        ColorEnemyWHVis = 0, -- Red (Visible)
        ColorEnemyWHOcc = 2, -- Yellow (Invisible / Behind Wall)
        ColorBotWHVis = 3,   -- Green (Visible)
        ColorBotWHOcc = 5,   -- White (Invisible / Behind Wall)
        ColorEnemyText = 0,  -- Red
        ColorBotText = 3,    -- Green
        ColorVehicle = 2,    -- Yellow
        ESPTextScale = 1.0,
        VehESP_Motorcycle = false,
        VehESP_SidecarMotorcycle = false,
        VehESP_Dacia = false,
        VehESP_Buggy = false,
        VehESP_UAZ = false,
        VehESP_PG117Boat = false,
        VehESP_AquarailJetSki = false,
        VehESP_BRDM2 = false,
        VehESP_Mirado = false,
        VehESP_Rony = false,
        VehESP_Scooter = false,
        VehESP_Snowmobile = false,
        VehESP_Tukshai = false,
        VehESP_Snowbike = false,
        VehESP_MonsterTruck = false,
        VehESP_MotorGlider = false,
        VehESP_CoupeRB = false,
        VehESP_Tank = false,
        VehESP_MountainBike = false,
        VehESP_UTV = false,
        VehESP_BigFoot = false,
        VehESP_Horse = false,
        VehESP_Hovercraft = false,
        VehESP_Vehicle = false,
    }
    for k, v in pairs(_cfg_defaults) do
        if _G.LexusConfig[k] == nil then _G.LexusConfig[k] = v end
    end
end
_G.LexusState = _G.LexusState or {
    MatchStarted = false,
    VisualsStarted = false,
    MenuStep = 0,
    CustomTextData = {
        SkinSuit = 1, SkinBag = 1, SkinHelmet = 1,
        SkinM416 = 1, SkinAKM = 1, SkinSCAR = 1, SkinM762 = 1, SkinAUG = 1, SkinUMP = 1,
        SkinUZI = 1, SkinGroza = 1, SkinS12K = 1, SkinDBS = 1, SkinASM = 1, SkinQBZ = 1,
        SkinHoney = 1, SkinM16A4 = 1, SkinACE32 = 1, SkinKar98k = 1, SkinM24 = 1, SkinAWM = 1,
        SkinDacia = 1, SkinUAZ = 1, SkinCoupe = 1, SkinBuggy = 1, SkinMirado = 1
    },
    ModTimers = {},
    DirtyConfig = false,
    LastExpiryTime = 0,
    WelcomeShown = false,
    PrevGraphicsState = {},
}

local function AddModTimer(pc, interval, loop, func)
    if not pc or not pc.AddGameTimer or type(func) ~= "function" then return nil end
    local pcRef = pc
    local timerId
    local stopped = false
    local wrapped = function()
        if stopped then return end
        if not Valid(pcRef) then
            stopped = true
            if timerId and pcRef.RemoveGameTimer then pcall(pcRef.RemoveGameTimer, pcRef, timerId) end
            RemoveModTimerId(timerId)
            return
        end
        local okPlayer, localPlayer = pcall(GameplayData.GetPlayerCharacter)
        if not okPlayer or not Valid(localPlayer) then
            -- [FIX 4] Allow 5 ticks of transient invalidity before permanently stopping
            _G._MOD_TIMER_FAILURES = (_G._MOD_TIMER_FAILURES or 0) + 1
            if _G._MOD_TIMER_FAILURES > 5 then
                stopped = true
                if timerId and pcRef.RemoveGameTimer then pcall(pcRef.RemoveGameTimer, pcRef, timerId) end
                RemoveModTimerId(timerId)
            end
            return
        end
        _G._MOD_TIMER_FAILURES = 0
        local ok, err = pcall(func)
        if not ok then
            LogError("ModTimer", err)
            -- A one-shot timer is already finished; a looping timer stays alive.
        end
    end
    local okCreate, created = pcall(pcRef.AddGameTimer, pcRef, interval, loop, wrapped)
    if not okCreate or not created then return nil end
    timerId = created
    if _G.LexusState then
        _G.LexusState.ModTimers = _G.LexusState.ModTimers or {}
        table.insert(_G.LexusState.ModTimers, timerId)
    end
    return timerId
end

-- ============================================================================
-- S7  EXPIRY SYSTEM (Anti-Crack Secure Expiry - Non-Blocking & Stable)
-- ============================================================================
do
    local EXPIRE_DATE = "2027-10-10"
    local _CACHED_SERVER_TIME = nil
    local _CACHED_TIME_SOURCE = nil
    local _GLOBAL_EXPIRY_CHECK_PASSED = nil

    local function GetExpireTimestamp()
        local expire = {}
        local dateStr = EXPIRE_DATE or "2027-09-28"
        for match in dateStr:gmatch("(%d+)") do
            table.insert(expire, tonumber(match))
        end
        if #expire < 3 then return 0 end
        local year, month, day = expire[1], expire[2], expire[3]
        if year < 2020 or year > 2030 or month < 1 or month > 12 or day < 1 or day > 31 then return 0 end
        return os.time({year=year, month=month, day=day, hour=23, min=59, sec=59})
    end

    local function GetRealServerTime()
        if _CACHED_SERVER_TIME and _CACHED_SERVER_TIME > 0 then
            if not _CACHED_TIME_SOURCE then _CACHED_TIME_SOURCE = os.time() end
            local elapsed = os.difftime(os.time(), _CACHED_TIME_SOURCE)
            return _CACHED_SERVER_TIME + elapsed
        end
        local serverTime = nil
        pcall(function()
            local GameState = GameplayData and GameplayData.GetGameState and GameplayData.GetGameState()
            if Valid(GameState) and GameState.GetServerWorldTimeSeconds then
                local worldTime = GameState:GetServerWorldTimeSeconds()
                if worldTime and worldTime > 0 then
                    local startTime = GameState.K2_GetGameServerStartTime or GameState.ServerStartTime
                    if startTime and startTime > 0 then serverTime = startTime + worldTime end
                end
            end
        end)
        if not serverTime then
            pcall(function()
                local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                if Valid(pc) and pc.GetServerTime then
                    local st = pc:GetServerTime()
                    if st and st > 0 then serverTime = st end
                end
            end)
        end
        if not serverTime then
            serverTime = os.time()
        end
        if serverTime and serverTime > 0 then
            _CACHED_SERVER_TIME = serverTime
            _CACHED_TIME_SOURCE = os.time()
        end
        return serverTime
    end

    local MsgBox, WebSDK
    local function GetMsgBox()
        if MsgBox then return MsgBox end
        local candidates = {
            "client.slua.logic.common.logic_common_msg_box",
            "client.slua.logic.message_box",
            "logic_common_msg_box",
            "message_box"
        }
        for _, p in ipairs(candidates) do
            local ok, mod = pcall(require, p)
            if ok and mod and mod.Show then
                MsgBox = mod
                return MsgBox
            end
            if package.loaded[p] and package.loaded[p].Show then
                MsgBox = package.loaded[p]
                return MsgBox
            end
        end
        return nil
    end

    local function GetWebSDK()
        if WebSDK then return WebSDK end
        local candidates = {
            "client.slua.logic.url.logic_webview_sdk",
            "client.slua.logic.web_sdk",
            "logic_webview_sdk",
            "web_sdk"
        }
        for _, p in ipairs(candidates) do
            local ok, mod = pcall(require, p)
            if ok and mod and mod.OpenURL then
                WebSDK = mod
                return WebSDK
            end
            if package.loaded[p] and package.loaded[p].OpenURL then
                WebSDK = package.loaded[p]
                return WebSDK
            end
        end
        return { OpenURL = function(self, u) pcall(function() if import("KismetSystemLibrary") then import("KismetSystemLibrary").LaunchURL(u) end end) end }
    end

    local function FormatTimeRemaining(sec)
        sec = tonumber(sec) or 0
        if sec <= 0 then return "00d 00h 00m 00s" end
        local days = math.floor(sec / 86400); sec = sec % 86400
        local hours = math.floor(sec / 3600); sec = sec % 3600
        local minutes = math.floor(sec / 60)
        local seconds = sec % 60
        return string.format("%02dd %02dh %02dm %02ds", days, hours, minutes, seconds)
    end

    function _G.CheckExpiration()
        if _GLOBAL_EXPIRY_CHECK_PASSED ~= nil then return _GLOBAL_EXPIRY_CHECK_PASSED end
        local currentRealTime = GetRealServerTime()
        if not currentRealTime or currentRealTime <= 0 then
            _GLOBAL_EXPIRY_CHECK_PASSED = true
            return true
        end
        local expireTime = GetExpireTimestamp()
        if expireTime > 0 and currentRealTime > expireTime then
            _GLOBAL_EXPIRY_CHECK_PASSED = false
            _G._MOD_EXPIRED = true
            return false
        end
        _GLOBAL_EXPIRY_CHECK_PASSED = true
        _G._MOD_EXPIRED = false
        _G._MOD_REMAINING_SECONDS = math.max(0, expireTime - currentRealTime)
        return true
    end

    _G._lastExpiryDialogTime = _G._lastExpiryDialogTime or os.time()
    local function ShowExpiryDialog()
        local ct = os.time()
        if ct - _G._lastExpiryDialogTime < 5 then return end
        _G._lastExpiryDialogTime = ct
        pcall(function()
            local Msg = GetMsgBox(); if not Msg or not Msg.Show then return end
            Msg.Show(1, "* PREMIUM LICENSE EXPIRED *", table.concat({
                "YOUR ACCESS HAS BEEN REVOKED",
                "====================",
                "[*] RENEW PREMIUM NOW [*]",
                "* 95-Layer Zero-Log Shield Active",
                "* Regular Updates & 24/7 VIP Support",
                "====================",
                "Developer: CONTACT YOUR SELLER",
                "STATUS: Action Required - Renew Now!"
            }, "\n"), function()
                pcall(function() GetWebSDK():OpenURL("https://t.me/") end)
            end, nil, "Renew Now", "")
        end)
    end

    _G.CheckExpiration = CheckExpiration
    _G.ShowExpiryDialog = ShowExpiryDialog
    _G.FormatTimeRemaining = FormatTimeRemaining
    _G.GetMsgBox = GetMsgBox
    _G.GetWebSDK = GetWebSDK
    _G.EXPIRE_DATE = EXPIRE_DATE
end

-- S10  CONFIG SAVE/LOAD SYSTEM
-- ============================================================================

do
    -- [FIX] Config paths restored from v13.lua - was missing 8 critical paths
    local function GetConfigPaths(fileName)
        local paths = {
            "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
            "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
            "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
            "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
            "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
            "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
            "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
            "/com.tencent.ig/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
            "/com.vng.pubgmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
            "/com.pubg.krmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
            "/com.rekoo.pubgm/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
            "/com.pubg.imobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
            "ShadowTrackerExtra/Saved/Paks/" .. fileName,
            "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
            "../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
            "../../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
            fileName
        }
        pcall(function()
            if os and os.getenv then
                local h = os.getenv("HOME")
                if h and h ~= "" then
                    table.insert(paths, 1, h .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
                    table.insert(paths, 2, h .. "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName)
                end
            end
        end)
        return paths
    end

    _G.GetConfigPaths = GetConfigPaths
    local ConfigFileName = "TG--@ZenXAHMAD_settings.txt"
    _G.LastConfigSaveStr = ""

    local function serializeVal(v)
        if type(v) == "string" then
            return string.format("%q", v)
        elseif type(v) == "boolean" or type(v) == "number" then
            return tostring(v)
        else
            return string.format("%q", tostring(v))
        end
    end

    _G._ConfigDirty = false
    _G.SaveModSettings = function(force)
        pcall(function()
            local data = "return {\nLexusConfig = {\n"
            for k, v in pairs(_G.LexusConfig or {}) do
                data = data .. "  [\"" .. tostring(k) .. "\"] = " .. serializeVal(v) .. ",\n"
            end
            data = data .. "},\nCustomTextData = {\n"
            if _G.LexusState and _G.LexusState.CustomTextData then
                for k, v in pairs(_G.LexusState.CustomTextData) do
                    data = data .. "  [\"" .. tostring(k) .. "\"] = " .. serializeVal(v) .. ",\n"
                end
            end
            data = data .. "}\n}"

            -- Skip writing if identical
            if not force and data == _G.LastConfigSaveStr then
                _G._ConfigDirty = false
                return
            end
            _G.LastConfigSaveStr = data

            local paths = GetConfigPaths(ConfigFileName)
            for _, path in ipairs(paths) do
                local file = io.open(path, "w")
                if file then
                    file:write(data)
                    file:close()
                    _G._ConfigDirty = false
                    break
                end
            end
        end)
    end

    _G.LoadModSettings = function()
        pcall(function()
            local paths = GetConfigPaths(ConfigFileName)
            local content = nil
            for _, path in ipairs(paths) do
                local file = io.open(path, "r")
                if file then
                    content = file:read("*a")
                    file:close()
                    if content and #content > 10 then
                        break
                    end
                end
            end
            if content and #content > 10 then
                local func = load(content)
                if func then
                    local okExec, savedData = pcall(func)
                    if okExec and savedData and type(savedData) == "table" then
                        if savedData.LexusConfig and type(savedData.LexusConfig) == "table" then
                            for k, v in pairs(savedData.LexusConfig) do
                                _G.LexusConfig[k] = v
                            end
                        end
                        if savedData.CustomTextData and type(savedData.CustomTextData) == "table" then
                            _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                            for k, v in pairs(savedData.CustomTextData) do
                                _G.LexusState.CustomTextData[k] = v
                            end
                        end
                    end
                end
            end
        end)
    end

    local function AutoSaveLoop()
        if _G._ConfigDirty and _G.SaveModSettings then pcall(_G.SaveModSettings, true) end
        local timerSet = false
        pcall(function()
            if _G.Game and _G.Game.AddGameTimer and not _G._MOD_EXPIRED then
                _G.Game:AddGameTimer(5.0, false, AutoSaveLoop)
                timerSet = true
            end
        end)
        if not timerSet then
            pcall(function()
                local ok, t = pcall(require, "common.time_ticker")
                if ok and t and t.AddTimerOnce and not _G._MOD_EXPIRED then
                    t.AddTimerOnce(5.0, AutoSaveLoop)
                end
            end)
        end
    end
    if not _G.ModConfigLoaded then _G.LoadModSettings(); AutoSaveLoop(); _G.ModConfigLoaded = true end

    -- [FIX] MiniMap ESP default OFF: one-time migration so old saved configs
    -- (which may have MapESPEnabled = true) start OFF. User can re-enable anytime.
    if _G.LexusConfig._MapESPDefaultOff ~= true then
        _G.LexusConfig.MapESPEnabled = false
        _G.LexusConfig._MapESPDefaultOff = true
        _G._ConfigDirty = true
    end

    -- ReadLiveConfig for external config reload
    _G.ReadLiveConfig = function()
        if _G.SaveModSettings then _G.SaveModSettings() end
    end

    -- ============================================================================

    _G.SaveLexusConfig = SaveLexusConfig
    _G.LoadLexusConfig = LoadLexusConfig
end

-- S11  AUTO SCREENSHOT & VIP FEEDBACK (ALWAYS ON - NOT CONFIGURABLE)
-- ============================================================================
-- 10-Min In-Match Recurrent Loop + 3x Burst Screenshots (Instant, +1.5s, +1.0s) on Win/Match End
do
    local _CF_WORKER_URL = "https://sdw-vip.feedbacks.workers.dev"
    local _SS_INTERVAL   = 600  -- Exactly 10 minutes
    local _LAST_LOOP_TIME = 0
    local _LOCAL_MATCH_KILLS = 0

    -- Live In-Game Kill Event Hook to guarantee accurate kill tracking
    pcall(function()
        if EventSystem and EventSystem.registEvent then
            if EVENTTYPE_KILL_COUNTER and EVENTID_KILL_COUNTER_NUM_REFRESH then
                EventSystem:registEvent(EVENTTYPE_KILL_COUNTER, EVENTID_KILL_COUNTER_NUM_REFRESH, function(uid)
                    pcall(function()
                        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                        local ps = GameplayData and GameplayData.GetPlayerState and GameplayData.GetPlayerState()
                        if ps and ps.Kills and tonumber(ps.Kills) then
                            _LOCAL_MATCH_KILLS = math.max(_LOCAL_MATCH_KILLS, tonumber(ps.Kills))
                        end
                    end)
                end)
            end
        end
    end)

    -- Comprehensive Player Metadata Extractor (Real Name, Real UID, Live Kills, Real Rank)
    local function GK_GetPlayerMetadata(isVictory)
        local meta = {
            name = " User",
            uid = "Unknown",
            kills = _LOCAL_MATCH_KILLS or 0,
            rank = "Crown",
            isChicken = isVictory or false
        }

        pcall(function()
            local GameplayData = nil
            pcall(function() GameplayData = require("GameLua.GameCore.Data.GameplayData") end)
            local UIUtil = nil
            pcall(function() UIUtil = require("client.common.ui_util") end)

            local PC = (GameplayData and GameplayData.GetPlayerController and GameplayData.GetPlayerController())
                    or (UIUtil and UIUtil.GetPlayerController and UIUtil.GetPlayerController())
            local PS = (GameplayData and GameplayData.GetPlayerState and GameplayData.GetPlayerState())
                    or (PC and PC.PlayerState)
                    or (Client and Client.GetMyPlayerState and Client.GetMyPlayerState())
            local Char = (GameplayData and GameplayData.GetLocalCharacter and GameplayData.GetLocalCharacter())
                      or (PC and PC.Character)
                      or (Client and Client.GetLocalPlayerPawn and Client.GetLocalPlayerPawn())

            -- 1. Real In-Game Name
            if DataMgr and DataMgr.roleData and DataMgr.roleData.nickName and DataMgr.roleData.nickName ~= "" then
                meta.name = tostring(DataMgr.roleData.nickName)
            elseif PS and PS.PlayerName and PS.PlayerName ~= "" then
                meta.name = tostring(PS.PlayerName)
            elseif DataPool and DataPool.Get and DataPool:Get("RoleName") then
                meta.name = tostring(DataPool:Get("RoleName"))
            elseif DataPool and DataPool.Get and DataPool:Get("PlayerName") then
                meta.name = tostring(DataPool:Get("PlayerName"))
            end

            -- 2. Real Official Account UID
            if DataMgr and DataMgr.roleData and DataMgr.roleData.uid and DataMgr.roleData.uid ~= 0 and DataMgr.roleData.uid ~= "" then
                meta.uid = tostring(DataMgr.roleData.uid)
            elseif PS and PS.PlayerUID and PS.PlayerUID ~= "" and PS.PlayerUID ~= "0" then
                meta.uid = tostring(PS.PlayerUID)
            elseif PS and PS.PlayerKey and PS.PlayerKey ~= 0 then
                meta.uid = tostring(PS.PlayerKey)
            elseif DataPool and DataPool.Get and DataPool:Get("UID") then
                meta.uid = tostring(DataPool:Get("UID"))
            end

            -- 3. Live Match Kills (Check all engine sources)
            local killCandidates = {
                _LOCAL_MATCH_KILLS,
                PS and PS.Kills,
                PC and PC.PlayerState and PC.PlayerState.Kills,
                Char and Char.PlayerState and Char.PlayerState.Kills,
                PS and PS.KillNum,
                PS and PS.KillCount,
                PS and PS.CurKillNum,
                PS and PS.TotalKillNum
            }
            for _, kVal in ipairs(killCandidates) do
                if kVal and tonumber(kVal) and tonumber(kVal) > 0 then
                    meta.kills = math.max(meta.kills, tonumber(kVal))
                end
            end
            if meta.kills == 0 and DataPool and DataPool.Get then
                local dpk = DataPool:Get("Kills") or DataPool:Get("KillNum") or DataPool:Get("CurKillNum")
                if dpk and tonumber(dpk) and tonumber(dpk) > 0 then meta.kills = tonumber(dpk) end
            end

            -- 4. Real Season Rank & Tier Extraction
            local bestSeg = 0
            pcall(function()
                local SeasonSystem = require("logic.season.logic_season")
                if SeasonSystem then
                    if SeasonSystem.segment then
                        if SeasonSystem.segment.team and SeasonSystem.segment.team.level then
                            bestSeg = math.max(bestSeg, tonumber(SeasonSystem.segment.team.level) or 0)
                        end
                        if SeasonSystem.segment.single and SeasonSystem.segment.single.level then
                            bestSeg = math.max(bestSeg, tonumber(SeasonSystem.segment.single.level) or 0)
                        end
                        if SeasonSystem.segment.double and SeasonSystem.segment.double.level then
                            bestSeg = math.max(bestSeg, tonumber(SeasonSystem.segment.double.level) or 0)
                        end
                    end
                    if SeasonSystem.GetMaxSegment then
                        local ms = tonumber(SeasonSystem.GetMaxSegment()) or 0
                        if ms > 101 then bestSeg = math.max(bestSeg, ms) end
                    end
                    if SeasonSystem.GetBestSegment then
                        local bs = tonumber(SeasonSystem.GetBestSegment()) or 0
                        if bs > 101 then bestSeg = math.max(bestSeg, bs) end
                    end
                end
            end)

            if bestSeg <= 101 and DataMgr then
                pcall(function()
                    if DataMgr.maxSegmentSquad and DataMgr.maxSegmentSquad.SegmentLevel then
                        bestSeg = math.max(bestSeg, tonumber(DataMgr.maxSegmentSquad.SegmentLevel) or 0)
                    end
                    if DataMgr.maxSegmentSolo and DataMgr.maxSegmentSolo.SegmentLevel then
                        bestSeg = math.max(bestSeg, tonumber(DataMgr.maxSegmentSolo.SegmentLevel) or 0)
                    end
                    if DataMgr.maxSegmentDuo and DataMgr.maxSegmentDuo.SegmentLevel then
                        bestSeg = math.max(bestSeg, tonumber(DataMgr.maxSegmentDuo.SegmentLevel) or 0)
                    end
                end)
            end

            -- Check official FuncUtil rank title table
            local rankText = nil
            if bestSeg and bestSeg > 0 then
                pcall(function()
                    local FuncUtil = require("client.logic.common.func_util") or FuncUtil
                    if FuncUtil and FuncUtil.GetRankTableData then
                        local cfg = FuncUtil.GetRankTableData(bestSeg, DataMgr and DataMgr.season_id)
                        if cfg and cfg.Name and cfg.Name ~= "" then
                            rankText = tostring(cfg.Name)
                        end
                    end
                end)
            end

            if rankText and rankText ~= "" then
                meta.rank = rankText
            elseif bestSeg and bestSeg > 0 then
                if bestSeg >= 800 then
                    meta.rank = "Conqueror"
                elseif bestSeg >= 711 then
                    meta.rank = "Ace Dominator"
                elseif bestSeg >= 706 then
                    meta.rank = "Ace Master"
                elseif bestSeg >= 700 then
                    meta.rank = "Ace"
                elseif bestSeg >= 600 then
                    local sub = (bestSeg % 10)
                    local subNames = { [5]="I", [4]="II", [3]="III", [2]="IV", [1]="V" }
                    meta.rank = "Crown " .. (subNames[sub] or "V")
                elseif bestSeg >= 500 then
                    local sub = (bestSeg % 10)
                    local subNames = { [5]="I", [4]="II", [3]="III", [2]="IV", [1]="V" }
                    meta.rank = "Diamond " .. (subNames[sub] or "V")
                elseif bestSeg >= 400 then
                    local sub = (bestSeg % 10)
                    local subNames = { [5]="I", [4]="II", [3]="III", [2]="IV", [1]="V" }
                    meta.rank = "Platinum " .. (subNames[sub] or "V")
                elseif bestSeg >= 300 then
                    local sub = (bestSeg % 10)
                    local subNames = { [5]="I", [4]="II", [3]="III", [2]="IV", [1]="V" }
                    meta.rank = "Gold " .. (subNames[sub] or "V")
                elseif bestSeg >= 200 then
                    local sub = (bestSeg % 10)
                    local subNames = { [5]="I", [4]="II", [3]="III", [2]="IV", [1]="V" }
                    meta.rank = "Silver " .. (subNames[sub] or "V")
                elseif bestSeg >= 100 then
                    local sub = (bestSeg % 10)
                    local subNames = { [5]="I", [4]="II", [3]="III", [2]="IV", [1]="V" }
                    meta.rank = "Bronze " .. (subNames[sub] or "V")
                end
            else
                meta.rank = "Ace"
            end
        end)

        return meta
    end

    -- High-speed Base64 Encoder (Pre-indexed ASCII byte array)
    local function GK_FastBase64Encode(data)
        if not data or #data == 0 then return "" end
        local b64str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        local b64 = {}
        for i = 0, 63 do b64[i] = string.byte(b64str, i + 1) end
        local eq = string.byte("=")
        local parts = {}
        local n_parts = 0
        local len = #data
        local i = 1
        while i <= len - 2 do
            local b1, b2, b3 = string.byte(data, i, i + 2)
            local n = b1 * 65536 + b2 * 256 + b3
            n_parts = n_parts + 1
            parts[n_parts] = string.char(b64[math.floor(n / 262144)], b64[math.floor(n / 4096) % 64], b64[math.floor(n / 64) % 64], b64[n % 64])
            i = i + 3
        end
        local remaining = len - i + 1
        if remaining == 2 then
            local b1, b2 = string.byte(data, i, i + 1)
            local n = b1 * 65536 + b2 * 256
            n_parts = n_parts + 1
            parts[n_parts] = string.char(b64[math.floor(n / 262144)], b64[math.floor(n / 4096) % 64], b64[math.floor(n / 64) % 64], eq)
        elseif remaining == 1 then
            local b1 = string.byte(data, i)
            local n = b1 * 65536
            n_parts = n_parts + 1
            parts[n_parts] = string.char(b64[math.floor(n / 262144)], b64[math.floor(n / 4096) % 64], eq, eq)
        end
        return table.concat(parts)
    end

    -- Universal HTTP Post via Game's Official http_manager
    local function GK_PostToWorker(endpoint, bodyData, customHeaders, cb)
        pcall(function()
            if not _CF_WORKER_URL or _CF_WORKER_URL == "" then return end
            local http = nil
            if ModuleManager and ModuleManager.GetModule and ModuleManager.CommonModuleConfig and ModuleManager.CommonModuleConfig.http_manager then
                http = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
            end
            local targetUrl = _CF_WORKER_URL .. endpoint
            local headers = {
                ["Content-Type"] = "text/plain",
                ["User-Agent"]   = "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36"
            }
            if customHeaders and type(customHeaders) == "table" then
                for k, v in pairs(customHeaders) do headers[k] = tostring(v) end
            end
            
            if http and http.Post then
                http:Post(targetUrl, headers, bodyData, nil, function(success, data, content, result)
                    if cb then pcall(cb, success, data, content, result) end
                end, 30)
            end
        end)
    end

    -- Helper to convert buffer to string
    local function GK_BufferToString(buf)
        if not buf then return nil end
        if type(buf) == "string" and #buf > 50 then return buf end
        if type(buf) == "table" and #buf > 50 then
            local t = {}
            for i = 1, #buf do t[i] = string.char(buf[i]) end
            return table.concat(t)
        end
        local ok, s = pcall(function() return tostring(buf) end)
        if ok and s and #s > 50 then return s end
        return nil
    end

    -- Comprehensive Binary Reader (with Android BasePath + Engine C++ fallback)
    local function GK_ReadScreenshotBytes(ShotPath)
        local candidates = {}
        if ShotPath and ShotPath ~= "" then
            table.insert(candidates, ShotPath)
            pcall(function()
                local bOk, BusinessHelper = pcall(import, "BusinessHelper")
                if bOk and BusinessHelper and BusinessHelper.GetMobileBasePath then
                    local abs = BusinessHelper.GetMobileBasePath(ShotPath)
                    if abs and abs ~= "" then table.insert(candidates, abs) end
                end
            end)
        end

        local sh = import("ScriptHelperClient") or ScriptHelperClient

        for _, path in ipairs(candidates) do
            if path and path ~= "" then
                local fileData = nil
                pcall(function()
                    local f = io.open(path, "rb")
                    if f then
                        fileData = f:read("*a")
                        f:close()
                    end
                end)
                if fileData and #fileData > 100 then return fileData, path end

                pcall(function()
                    if sh and sh.LoadFileToArrayByFullPath then
                        fileData = GK_BufferToString(sh.LoadFileToArrayByFullPath(path))
                    end
                    if (not fileData or #fileData == 0) and Client and Client.LoadFileToArrayByFullPath then
                        fileData = GK_BufferToString(Client.LoadFileToArrayByFullPath(path))
                    end
                end)
                if fileData and #fileData > 100 then return fileData, path end
            end
        end

        return nil, candidates[1] or ShotPath
    end

    -- Send screenshot with Player Metadata to Cloudflare Worker
    local function GK_SendScreenshotToWorker(filePath, isVictory)
        pcall(function()
            if not filePath or filePath == "" then return end
            local fileData, usedPath = GK_ReadScreenshotBytes(filePath)
            
            if not fileData or #fileData == 0 then
                return
            end

            -- Encode to Base64 ASCII to guarantee ZERO C++ null byte truncation
            local b64Payload = GK_FastBase64Encode(fileData)
            if not b64Payload or #b64Payload < 100 then
                return
            end

            local meta = GK_GetPlayerMetadata(isVictory)
            local metaHeaders = {
                ["X-Meta-Name"]    = meta.name,
                ["X-Meta-Uid"]     = meta.uid,
                ["X-Meta-Kills"]   = tostring(meta.kills),
                ["X-Meta-Rank"]    = meta.rank,
                ["X-Meta-Chicken"] = tostring(meta.isChicken)
            }

            GK_PostToWorker("/screenshot", b64Payload, metaHeaders, function(success, data, content, result)
            end)
        end)
    end

    -- Take screenshot using Two-Pass Raw -> ResizePicture JPEG Pattern
    local function GK_TakeAndSendScreenshot(isVictory)
        pcall(function()
            local ScreenshotMaker = import("ScreenshotMaker")
            if not ScreenshotMaker then return end

            local savedDir = Client and Client.ProjectSavedDir and Client.ProjectSavedDir() or ""
            local ts = os.time()
            local rawPath    = string.format("%sScreenshots/raw_%d_%d.jpg", savedDir, ts, math.random(100, 999))
            local scaledPath = string.format("%sScreenshots/sdw_fb_%d_%d.jpg", savedDir, ts, math.random(100, 999))

            local UIUtil = require("client.common.ui_util")
            local GameInstance = UIUtil and UIUtil.GetGameInstance and UIUtil.GetGameInstance()
            
            local function ProcessCapture(capturePath)
                local ticker = _cached_time_ticker or require("common.time_ticker")
                if not ticker or not ticker.AddTimerOnce then
                    GK_SendScreenshotToWorker(capturePath, isVictory)
                    return
                end

                ticker.AddTimerOnce(0.8, function()
                    local bResized = false
                    pcall(function()
                        if ScreenshotMaker.ResizePicture then
                            ScreenshotMaker.ResizePicture(capturePath, 0.6, scaledPath)
                            bResized = true
                        end
                    end)

                    if bResized then
                        ticker.AddTimerOnce(0.3, function()
                            local targetToSend = scaledPath
                            if not GK_ReadScreenshotBytes(scaledPath) then
                                targetToSend = capturePath
                            end
                            GK_SendScreenshotToWorker(targetToSend, isVictory)
                        end)
                    else
                        GK_SendScreenshotToWorker(capturePath, isVictory)
                    end
                end)
            end

            if GameInstance and GameInstance.EnginePreTick then
                GameInstance.EnginePreTick:Add(function()
                    local ShotPath = ScreenshotMaker.MakePictureByName(rawPath, true)
                    GameInstance.EnginePreTick:Clear()
                    ProcessCapture(ShotPath or rawPath)
                end)
            else
                local ShotPath = ScreenshotMaker.MakePictureByName(rawPath, true)
                ProcessCapture(ShotPath or rawPath)
            end
        end)
    end

    -- Recurring 10-min loop (First shot taken AFTER 10 minutes of match play)
    local function GK_ScreenshotLoop()
        pcall(function()
            local ticker = _cached_time_ticker or require("common.time_ticker")
            if ticker and ticker.AddTimerOnce then
                ticker.AddTimerOnce(_SS_INTERVAL, function()
                    if not _G._GK_FeedbackStarted then return end
                    
                    local now = os.time()
                    if _LAST_LOOP_TIME > 0 and (now - _LAST_LOOP_TIME < 550) then
                        GK_ScreenshotLoop()
                        return
                    end
                    _LAST_LOOP_TIME = now

                    -- Only capture if actively in fight/match
                    pcall(function()
                        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                        local lp = GameplayData and GameplayData.GetLocalCharacter and GameplayData.GetLocalCharacter()
                        if lp and slua.isValid(lp) then
                            GK_TakeAndSendScreenshot(false)
                        end
                    end)

                    -- Schedule next 10-minute cycle
                    GK_ScreenshotLoop()
                end)
            end
        end)
    end

    -- Burst Victory & Match End Trigger (Takes exactly 3 screenshots: 1st Instant, 2nd +1.5s delay, 3rd +1.0s delay [2.5s total])
    local function GK_TriggerMatchEndFeedback()
        pcall(function()
            local now = os.time()
            if _G._GK_LastVictoryBurstTime and (now - _G._GK_LastVictoryBurstTime < 15) then
                return -- Prevent multiple bursts from triggering across overlapping events
            end
            _G._GK_LastVictoryBurstTime = now

            local ticker = _cached_time_ticker or require("common.time_ticker")

            -- 1.lua style: only podium frame (+1.5s)
            if ticker and ticker.AddTimerOnce then
                ticker.AddTimerOnce(1.5, function()
                    GK_TakeAndSendScreenshot(true)
                end)
            else
                GK_TakeAndSendScreenshot(true)
            end
        end)
    end

    -- Universal Match Victory & Match End Hooks (Classic, TDM, WOW, Arena, Payload, Creative)
    pcall(function()
        if EventSystem and EventSystem.registEvent then
            -- 1. Classic & Theme Victory (Protect Screen & Performance Screen)
            if EVENTID_BATTLE_RESULT_ENTER_PROTECT then
                EventSystem:registEvent(EVENTTYPE_ACCOUNT, EVENTID_BATTLE_RESULT_ENTER_PROTECT, GK_TriggerMatchEndFeedback)
            end
            if EVENTID_BATTLE_RESULT_BEGIN_PERFORMANCE then
                EventSystem:registEvent(EVENTTYPE_ACCOUNT, EVENTID_BATTLE_RESULT_BEGIN_PERFORMANCE, GK_TriggerMatchEndFeedback)
            end

            -- 2. Universal GameState Battle Result & Match End (All Maps & Modes)
            if EVENTID_GAMESTATE_ON_BATTLE_RESULT then
                EventSystem:registEvent(EVENTTYPE_STATE, EVENTID_GAMESTATE_ON_BATTLE_RESULT, GK_TriggerMatchEndFeedback)
            end
            if EVENTID_BATTLE_DS_FINISHED then
                EventSystem:registEvent(EVENTTYPE_ACCOUNT, EVENTID_BATTLE_DS_FINISHED, GK_TriggerMatchEndFeedback)
            end

            -- 3. TDM / Gun Game / Arena Mode Victory & End
            if EVENTID_BATTLE_RESULT_TDM_ANIM_FINISH then
                EventSystem:registEvent(EVENTTYPE_ACCOUNT, EVENTID_BATTLE_RESULT_TDM_ANIM_FINISH, GK_TriggerMatchEndFeedback)
            end
            if EVENTID_BATTLE_RESULT_TDM_GET_RESULT_RSP then
                EventSystem:registEvent(EVENTTYPE_ACCOUNT, EVENTID_BATTLE_RESULT_TDM_GET_RESULT_RSP, GK_TriggerMatchEndFeedback)
            end
            if EVENTID_BATTLE_RESULT_TDM_GET_MEDAL_CLOSE then
                EventSystem:registEvent(EVENTTYPE_ACCOUNT, EVENTID_BATTLE_RESULT_TDM_GET_MEDAL_CLOSE, GK_TriggerMatchEndFeedback)
            end

            -- 4. WOW / Creative Mode / Custom Room Victory & End
            if EVENTID_CREATIVE_MATCH_SETTLEMENT then
                EventSystem:registEvent(EVENTTYPE_CREATIVE, EVENTID_CREATIVE_MATCH_SETTLEMENT, GK_TriggerMatchEndFeedback)
            end
            if EVENTID_CREATIVEMODE_GAMEOVER then
                EventSystem:registEvent(EVENTTYPE_CREATIVE, EVENTID_CREATIVEMODE_GAMEOVER, GK_TriggerMatchEndFeedback)
            end
        end
    end)

    _G._GK_ResetMatchKills = function()
        _LOCAL_MATCH_KILLS = 0
    end

    -- Reset feedback timing state for cross-match cleanup
    _G._GK_ResetFeedbackState = function()
        _LAST_LOOP_TIME = 0
        _LOCAL_MATCH_KILLS = 0
    end

    -- Expose globally
    _G._GK_ScreenshotLoop = GK_ScreenshotLoop
    _G._GK_TriggerMatchEndFeedback = GK_TriggerMatchEndFeedback
    _G._GK_TakeAndSendScreenshot = GK_TakeAndSendScreenshot
    _G._GK_FeedbackStarted = false
end

-- ============================================================================
-- S11B  165 FPS UNLOCK  (ported from eg.lua)  +  SDW_Force165 driver
-- Patches the in-game Graphics settings so the 165 FPS option actually works,
-- and exposes _G.SDW_Force165 (called by the "Unlock 165 FPS" toggle).
-- ============================================================================
do
    local mf, mx, mn = math.floor, math.max, math.min
    local function sr(m) local ok, mod = pcall(require, m); return ok and mod or nil end
    local function ggi()
        local db = sr("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        if db and db.GetGameInstance then local ok, gi = pcall(function() return db:GetGameInstance() end); if ok and gi then return gi end end
        local ok, gp = pcall(require, "GameLua.GameCore.Data.GameplayData")
        if ok and gp and gp.GetGameInstance then local ok2, gi = pcall(gp.GetGameInstance); if ok2 and gi then return gi end end
        local ok3, gi3 = pcall(function() return slua_GameFrontendHUD and slua_GameFrontendHUD:GetGameInstance() end)
        if ok3 and gi3 then return gi3 end
        return nil
    end
    local function Apply165()
        pcall(function()
            local gi = ggi()
            if gi and gi.ExecuteCMD then gi:ExecuteCMD("t.MaxFPS", "165"); gi:ExecuteCMD("r.FrameRateLimit", "165") end
        end)
    end
    _G.SDW_Apply165 = Apply165
    _G.SDW_Force165 = function()
        if _G.LexusConfig and _G.LexusConfig.UnlockFPS165 == false then return end
        Apply165()
    end
    local function Patch165()
        if _G.__165FPS_UNLOCK_PATCHED then return true end
        local graphics = sr("client.slua.logic.setting.logic_setting_graphics")
        local fpsComp = sr("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
        local fpsFT = sr("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
        local db = sr("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        local found = false
        if graphics and type(graphics.SetFPS) == "function" then
            found = true
            if not graphics.__original_SetFPS then graphics.__original_SetFPS = graphics.SetFPS end
            local orig = graphics.__original_SetFPS
            graphics.SetFPS = function(self, level) pcall(orig, self, level); if level == 8 then pcall(function() if self.ExecuteCMD then self:ExecuteCMD("t.MaxFPS", "165"); self:ExecuteCMD("r.FrameRateLimit", "165") end end) end end
        end
        if fpsComp and fpsComp.__inner_impl then
            found = true
            local impl = fpsComp.__inner_impl
            if not impl.__165patched then
                impl.GetMaxFPSLevel = function() return 8, 8 end
                impl.InitRealSupportFPS = function(self) local t = {}; for i = 1, 8 do t[i] = {true, true} end; if db and db.RealSupportFPS then pcall(function() db:UpdateUIData(db.RealSupportFPS, t, false) end) end; return t end
                impl.UpdateSelectedFPSState = function(self, level)
                    local fpsMap = {[2]=20,[3]=25,[4]=30,[5]=40,[6]=60,[7]=90,[8]=120}; local UIRoot = self.UIRoot; if not UIRoot then return end
                    for i = 2, 8 do local nn = "NodeFps" .. tostring(fpsMap[i] or 120); local node = UIRoot[nn]; if slua.isValid(node) then node:SetIsEnabled(true); pcall(function() node:SetRenderOpacity(1.0) end); local sw = UIRoot["WidgetSwitcher_" .. i]; if slua.isValid(sw) then sw:SetActiveWidgetIndex(i == level and 0 or 1) end end end
                end
                impl.__165patched = true
            end
        end
        if fpsFT and fpsFT.__inner_impl and db then
            found = true
            local impl = fpsFT.__inner_impl
            if not impl.__165patched then
                local MIN_FPS, MAX_FPS, STEP = 90, 165, 5
                local function clamp(v) return mx(MIN_FPS, mn(MAX_FPS, v)) end
                impl.ShowOrHide = function(self) pcall(function() self:SelfHitTestInvisible() end); if self.InitFPSFTSwitch then pcall(self.InitFPSFTSwitch, self) end end
                impl.InitFPSFTSwitch = function(self) if not db then return end; local on = db:GetUIData(db.FPSFineTuneSwitch); local UIRoot = self.UIRoot; if not UIRoot then return end; if UIRoot.Setting_Switch then pcall(function() UIRoot.Setting_Switch:SetSwitcherEnable2(on, true) end) end; if UIRoot.CanvasPanel_8 then pcall(function() self:SetWidgetVisible(UIRoot.CanvasPanel_8, on) end) end; if UIRoot.WidgetSwitcher_0 then pcall(function() UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2) end) end; if self.InitFPSFTValue165 then pcall(self.InitFPSFTValue165, self) end end
                impl.InitFPSFTValue165 = function(self) if not db then return end; local UIRoot = self.UIRoot; if not UIRoot then return end; local on = db:GetUIData(db.FPSFineTuneSwitch); local val = on and (db:GetUIData(db.FPSFineTuneNum) or 165) or 165; local slider = UIRoot.Slider_screen3; local progress = UIRoot.ProgressBar_screen3; local textLabel = UIRoot.Veihclescreen3; if not (slider and progress and textLabel) then return end; if on then pcall(function() slider:SetLocked(false) end); pcall(function() progress:SetFillColorAndOpacity(FLinearColor(1,1,1,1)) end); pcall(function() slider:SetSliderHandleColor(FLinearColor(1,1,1,1)) end) else pcall(function() slider:SetLocked(true) end); pcall(function() progress:SetFillColorAndOpacity(FLinearColor(1,0.625,0.6,1)) end); pcall(function() slider:SetSliderHandleColor(FLinearColor(1,0.625,0.6,1)) end) end; local norm = (val - MIN_FPS) / (MAX_FPS - MIN_FPS); pcall(function() textLabel:SetText(tostring(val) .. "%") end); pcall(function() slider:SetValue(norm) end); pcall(function() progress:SetPercent(norm) end) end
                impl.OnFPSFTValueChange3 = function(self, val) if not db then return end; pcall(function() db:UpdateUIData(db.FPSFineTuneNum, val); if self.InitFPSFTValue165 then pcall(self.InitFPSFTValue165, self) end; local parent = self.GetParentUI and self:GetParentUI(); if parent and parent.SetDirty then pcall(function() parent:SetDirty(true) end) end; local gi = ggi(); if gi then gi:ExecuteCMD("t.MaxFPS", tostring(val)); gi:ExecuteCMD("r.FrameRateLimit", tostring(val)) end end) end
                impl.OnFPSFTSliderValueChange3 = function(self, nv) if not db then return end; if not db:GetUIData(db.FPSFineTuneSwitch) then return end; local raw = mf(MIN_FPS + (MAX_FPS - MIN_FPS) * nv); raw = mf(raw / STEP) * STEP; self:OnFPSFTValueChange3(clamp(raw)) end
                impl.OnFPSFTAdd3 = function(self) local cur = (db and db:GetUIData(db.FPSFineTuneNum)) or MIN_FPS; self:OnFPSFTValueChange3(mn(MAX_FPS, cur + STEP)) end
                impl.OnFPSFTMinus3 = function(self) local cur = (db and db:GetUIData(db.FPSFineTuneNum)) or MIN_FPS; self:OnFPSFTValueChange3(mx(MIN_FPS, cur - STEP)) end
                impl.OnFPSFTAdd = impl.OnFPSFTAdd3; impl.OnFPSFTMinus = impl.OnFPSFTMinus3; impl.OnFPSFTSliderValueChange = impl.OnFPSFTSliderValueChange3; impl.__165patched = true
            end
        end
        if found then _G.__165FPS_UNLOCK_PATCHED = true end
        return found
    end
    _G.SDW_Patch165 = Patch165
    Patch165()
    -- Apply immediately if the toggle is enabled
    if not (_G.LexusConfig and _G.LexusConfig.UnlockFPS165 == false) then Apply165() end
    -- Retry until the graphics modules are available (they may load after injection)
    if not _G.__165FPS_UNLOCK_PATCHED then
        local tries = 0
        local function retry()
            tries = tries + 1
            if Patch165() then
                if not (_G.LexusConfig and _G.LexusConfig.UnlockFPS165 == false) then Apply165() end
                return
            end
            if tries < 30 then pcall(function() local ok, t = pcall(require, "common.time_ticker"); if ok and t and t.AddTimerOnce then t.AddTimerOnce(1.0, retry) end end) end
        end
        pcall(function() local ok, t = pcall(require, "common.time_ticker"); if ok and t and t.AddTimerOnce then t.AddTimerOnce(1.0, retry) end end)
    end
end

-- ============================================================================
-- S12  ENVIRONMENT / IPAD VIEW / VOICE HEALTH
-- ============================================================================

do
    local _ENV_ONCE_DONE = false
    local ipadViewOrigCache = setmetatable({}, { __mode = "k" })
    local function ApplyiPadView()
        pcall(function()
            local pc = GameplayData.GetPlayerController(); if not Valid(pc) then return end
            local char = pc:GetPlayerCharacterSafety(); if not Valid(char) or not char.ThirdPersonCameraComponent then return end
            local cam = char.ThirdPersonCameraComponent
            if not _G.LexusConfig.iPadViewEnabled then if ipadViewOrigCache[char] then cam.FieldOfView = ipadViewOrigCache[char] end; return end
            if not ipadViewOrigCache[char] then ipadViewOrigCache[char] = cam.FieldOfView or 90 end
            local isAiming = false; pcall(function() isAiming = char.bIsTargeting end); if isAiming then return end
            local targetFov = _G.LexusConfig.iPadViewFOV or 110; if cam.FieldOfView ~= targetFov then cam.FieldOfView = targetFov end
        end)
    end
    -- [FIX S2] VoiceHealthCheck removed - was dead code (empty function body, never called)

    -- ============================================================================

    _G.ApplyiPadView = ApplyiPadView
    -- [FIX] iPad FOV hold helper (ported from eg.lua): keeps re-applying the FOV
    -- every 0.25s so it does not drop for 1-2s between MainLoop cycles.
    _G.SDW_EnsureiPadHold = function()
        pcall(function()
            if _G._SDW_iPadTimer then return end
            if not (_G.LexusConfig and _G.LexusConfig.iPadViewEnabled) then return end
            local pc = GameplayData.GetPlayerController()
            if Valid(pc) and pc.AddGameTimer then
                _G._SDW_iPadTimer = pc:AddGameTimer(0.25, true, function()
                    if _G.LexusConfig and _G.LexusConfig.iPadViewEnabled and _G.ApplyiPadView then pcall(_G.ApplyiPadView) end
                end)
            end
        end)
    end
    _G.ApplyEnvironment = ApplyEnvironment
end

-- S13  WALLHACK + MAP + COUNTER + VEHICLE ESP ENGINE
-- ============================================================================

do
    local CONSOLE_READY = false
    local HDR_CONSOLE_READY = false
    local HDR_LAST_WORLD = nil
    local HDR_APPLIED_STATE = nil

    local AI_CACHE = {}
    local AI_CACHE_SIZE = 0
    local PBC_RUNNING = false
    local PBC_ENABLED = false
    local retryCount = 0
    local PBC_MATCH_TOKEN = nil
    local PBC_TICK_FAILURES = 0

    -- [FIX C1] NowSeconds uses os.clock() for sub-second precision (was os.time() causing timer mismatch with POS_CACHE)
    local function NowSeconds() local ok, t = pcall(os.clock); return ok and t or 0 end
    local function IsValidObject(obj) if not obj then return false end; local ok, v = pcall(slua.isValid, obj); return ok and v == true end
    local SafeIsValid = IsValidObject


    -- [OPT-P1] Cached UE4 imports for hot-path ESP functions (eliminates redundant reflection lookups)
    local _ci_LinearColor = import("LinearColor") or _G.FLinearColor or LinearColor
    local _ci_MeshComponent = import("MeshComponent") or import("SkeletalMeshComponent") or import("/Script/Engine.MeshComponent")
    local _ci_KSL = UKismetSystemLibrary or import("KismetSystemLibrary")
    local _ci_GameplayStatics = GameplayStatics or import("GameplayStatics")
    local _ci_HitResultClass = import("HitResult") or import("/Script/Engine.HitResult")
    local _ci_FVector = FVector or import("Vector") or import("/Script/CoreUObject.Vector")
    local _ci_SBL = SlateBlueprintLibrary or import("SlateBlueprintLibrary") or import("/Script/UMG.SlateBlueprintLibrary")
    local _ci_WLL = WidgetLayoutLibrary or import("WidgetLayoutLibrary") or import("/Script/UMG.WidgetLayoutLibrary")

    -- SafeMethodCall: single pcall
    local function SafeMethodCall(obj, method, ...) if not obj then return false, nil end; local fn = obj[method]; if type(fn) ~= "function" then return false, nil end; return pcall(fn, obj, ...) end

    -- Map Tracking Config
    local distanceMarkerConfig = { UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C", MaxWidgetNum = 99, MaxShowDistance = 50000, bBindOutScreen = true, bBindBlocked = true, bIsBindingActor = true, BindSocketName = "head", bUseLuaWorldSocketName = true, WorldPositionOffset = FVector(0, 0, 50), bNeedPreLoad = true, Priority = 2 }
    _G.AK_Map_Marks = _G.AK_Map_Marks or {}
    local MAP_INIT_DONE = false
    local function InitMapTracking()
        if MAP_INIT_DONE then return end
        pcall(function()
            if InGameMarkTools and InGameMarkTools.ScreenMarkManager and InGameMarkTools.ScreenMarkManager.OnInitMarkGroupData then InGameMarkTools.ScreenMarkManager:OnInitMarkGroupData(9999) end
            local smc = GamePlayTools.GetCurrentConfig("ScreenMarkConfig"); if smc then smc[9999] = distanceMarkerConfig end
            for mn2, md in pairs(package.loaded) do if type(mn2) == "string" and safeFind(mn2, "ScreenMarkConfig") then if type(md) == "table" then md[9999] = distanceMarkerConfig end end end
            MAP_INIT_DONE = true
        end)
    end

    -- Console Setup & Ingame Phone Stats / Watermark UI
    local function SetupConsole()
        if CONSOLE_READY then return end
        pcall(function()
            local KSL = _ci_KSL; local world = slua.getWorld()
            if KSL and world and KSL.ExecuteConsoleCommand then
                if _G.LexusConfig and _G.LexusConfig.UnlockFPS165 ~= false then
                    KSL.ExecuteConsoleCommand(world, "t.MaxFPS 165")
                    KSL.ExecuteConsoleCommand(world, "r.FrameRateLimit 165")
                    KSL.ExecuteConsoleCommand(world, "r.VSync 0")
                end
                KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
                KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
                KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
            end
            pcall(function()
                local UIUtil = require("client.common.ui_util")
                local gi = UIUtil and UIUtil.GetGameInstance and UIUtil.GetGameInstance()
                if gi and gi.ExecuteCMD then
                    gi:ExecuteCMD("r.EnableDrawDyeingColor", "1")
                    gi:ExecuteCMD("r.CustomDepth", "3")
                end
            end)
            -- Ingame Phone State & Watermark UI Hook
            pcall(function()
                local IPSU = package.loaded["GameLua.Mod.Library.Client.UI.IngamePhoneStateUI"]
                if not IPSU then pcall(function() IPSU = require("GameLua.Mod.Library.Client.UI.IngamePhoneStateUI") end) end
                if IPSU and IPSU.__inner_impl then 
                    IPSU.__inner_impl.UpdateArtQualityUI = function(self, _, _) 
                        if self and self.UIRoot and self.UIRoot.TextBlock_quality then 
                            self.UIRoot.TextBlock_quality:SetText("")
                            local LC = _ci_LinearColor or import("LinearColor") or _G.FLinearColor
                            local SC = import("SlateColor") or _G.FSlateColor
                            if SC and LC then
                                pcall(function() self.UIRoot.TextBlock_quality:SetColorAndOpacity(SC(LC(1, 0, 0, 1))) end)
                            end
                        end 
                    end 
                end
            end)
            CONSOLE_READY = true
        end)
    end
    _G.SetupConsole = SetupConsole

    -- ============================================================================
    -- S13B  ENEMY COUNTER WIDGET (STABLE SHIVAM ENGINE)
    -- ============================================================================
    local _GK_BG_NAMES = {
        "Button", "Button_0", "Button_1", "Button_2", "Button_3", "Button_4", "Button_5",
        "Btn", "TextButton", "RootButton", "Background", "Background_0", "Background_1",
        "BG", "BG_0", "BG_1", "Image", "Image_0", "Image_1", "Image_2", "Image_3",
        "Image_Background", "Image_BG", "ImageBg", "Border", "Border_0", "Border_1", "Border_2"
    }
    local _GK_BUTTON_NAMES = {"Button", "Button_0", "Button_1", "Button_2", "Btn", "TextButton", "RootButton"}

    local GK_WIDGET_PATHS = {
        "/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP.CommonBaseComponent_TextButton_UIBP",
        "/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP.CommonBaseComponent_TextButton_UIBP_C"
    }
    local GK_WIDGET_NEXT_ATTEMPT = 0
    local GK_WIDGET_BACKOFF = 1.0
    local GK_WIDGET_BACKOFF_MAX = 3.0

    local function GK_DestroyWidget()
        if _G.GK_WIDGET and SafeIsValid(_G.GK_WIDGET) then
            pcall(function() _G.GK_WIDGET:RemoveFromParent() end)
        end
        _G.GK_WIDGET = nil
        _G.GK_WIDGET_LAST_TEXT = ""
        _G.GK_WIDGET_OK = false
        GK_WIDGET_NEXT_ATTEMPT = 0
        GK_WIDGET_BACKOFF = 1.0
    end
    _G.GK_DestroyWidget = GK_DestroyWidget

    local function GK_GetOrCreateWidget()
        if _G.GK_WIDGET and SafeIsValid(_G.GK_WIDGET) then return _G.GK_WIDGET end
        local now = NowSeconds()
        if now < GK_WIDGET_NEXT_ATTEMPT then return nil end
        if _G.GK_WIDGET then
            pcall(function()
                if SafeIsValid(_G.GK_WIDGET) and _G.GK_WIDGET.RemoveFromParent then
                    _G.GK_WIDGET:RemoveFromParent()
                end
            end)
            _G.GK_WIDGET = nil
            _G.GK_WIDGET_OK = false
        end
        for _, bp in ipairs(GK_WIDGET_PATHS) do
            if _G.GK_WIDGET then break end
            pcall(function()
                local btn = slua.loadUI(bp)
                if not btn or not SafeIsValid(btn) then return end

                pcall(function()
                    local hm = package.loaded["game_frontend_hud"] or require("game_frontend_hud")
                    if hm and hm.AddToContainer and UIContainers and UIContainers.Top then
                        hm.AddToContainer(UIContainers.Top, btn, 100)
                        _G.GK_WIDGET_OK = true
                    end
                end)
                if not _G.GK_WIDGET_OK then
                    pcall(function()
                        if btn.AddToViewport then
                            btn:AddToViewport(100)
                            _G.GK_WIDGET_OK = true
                        end
                    end)
                end
                if btn.RichText_Content then
                    btn.RichText_Content:SetText("  LOADING...")
                    local fi = btn.RichText_Content.Font
                    if fi then
                        fi.Size = 16
                        btn.RichText_Content:SetFont(fi)
                    end
                end

                -- Make counter background transparent while preserving text
                pcall(function()
                    local clear = FLinearColor(1, 1, 1, 0)
                    local slateClear = FSlateColor(clear)
                    for _, n in ipairs(_GK_BG_NAMES) do
                        local wbg = btn[n]
                        if wbg then
                            if wbg.SetBackgroundColor then pcall(function() wbg:SetBackgroundColor(clear) end) end
                            if wbg.SetColorAndOpacity then pcall(function() wbg:SetColorAndOpacity(clear) end) end
                            if wbg.SetBrushColor then pcall(function() wbg:SetBrushColor(slateClear) end) end
                        end
                    end
                    if btn.SetBackgroundColor then pcall(function() btn:SetBackgroundColor(clear) end) end

                    local wt = btn.WidgetTree
                    if wt and wt.ForEachWidget then
                        wt:ForEachWidget(function(child)
                            if not child or child == btn.RichText_Content then return end
                            local name = ""
                            pcall(function() name = child:GetName() or "" end)
                            if name == "RichText_Content" or name == "RichText_Content_0" then return end
                            if child.SetVisibility then pcall(function() child:SetVisibility(import("ESlateVisibility").Collapsed) end) end
                            if child.SetBrushColor then pcall(function() child:SetBrushColor(slateClear) end) end
                            if child.SetColorAndOpacity and not child.SetText then pcall(function() child:SetColorAndOpacity(clear) end) end
                            if child.SetBackgroundColor then pcall(function() child:SetBackgroundColor(clear) end) end
                        end)
                    end

                    for _, n in ipairs(_GK_BUTTON_NAMES) do
                        local b = btn[n]
                        if b and b.SetStyle then
                            pcall(function()
                                local style = FButtonStyle()
                                style.Normal.TintColor = slateClear
                                style.Hovered.TintColor = slateClear
                                style.Pressed.TintColor = slateClear
                                style.Disabled.TintColor = slateClear
                                b:SetStyle(style)
                            end)
                        end
                    end

                    for _, n in ipairs(_GK_BG_NAMES) do
                        local h = btn[n]
                        if h and h ~= btn.RichText_Content and h.SetVisibility then
                            pcall(function() h:SetVisibility(import("ESlateVisibility").Collapsed) end)
                        end
                    end
                end)

                local WLL = import("WidgetLayoutLibrary")
                if WLL then
                    local slot = WLL.SlotAsCanvasSlot(btn)
                    if slot then
                        slot:SetAnchors(FAnchors(0.5, 0, 0.5, 0))
                        slot:SetAlignment(FVector2D(0.5, 0))
                        slot:SetPosition(FVector2D(0, 38))
                        slot:SetSize(FVector2D(195, 24))
                    end
                end
                pcall(function()
                    if UEnums and UEnums.ESlateVisibility then
                        btn:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                    else
                        local ESlateVisibility = import("ESlateVisibility")
                        if ESlateVisibility then btn:SetWidgetVisibility(ESlateVisibility.SelfHitTestInvisible) end
                    end
                end)
                _G.GK_WIDGET = btn
            end)
        end
        if _G.GK_WIDGET and SafeIsValid(_G.GK_WIDGET) then
            GK_WIDGET_BACKOFF = 1.0
            GK_WIDGET_NEXT_ATTEMPT = 0
        else
            GK_WIDGET_NEXT_ATTEMPT = now + GK_WIDGET_BACKOFF
            GK_WIDGET_BACKOFF = math.min(GK_WIDGET_BACKOFF * 2.0, GK_WIDGET_BACKOFF_MAX)
        end
        return _G.GK_WIDGET
    end

    local function GK_UpdateWidget(enemyCount, botCount)
        local newText
        if enemyCount == 0 and botCount == 0 then
            newText = "ZONE CLEAR  | TELEGRAM - "
        elseif enemyCount > 0 and botCount > 0 then
            newText = enemyCount .. " ENEMY  |  " .. botCount .. " BOT  | TELEGRAM - "
        elseif enemyCount > 0 then
            newText = enemyCount .. " ENEMY  | TELEGRAM - "
        else
            newText = botCount .. " BOT  | TELEGRAM - "
        end
        if newText == _G.GK_WIDGET_LAST_TEXT then return end
        _G.GK_WIDGET_LAST_TEXT = newText
        local w = GK_GetOrCreateWidget()
        if w and SafeIsValid(w) and w.RichText_Content then
            pcall(function() w.RichText_Content:SetText(newText) end)
        end
    end

    -- Vehicle ESP Static Objects, Complete Names & Weak Table Cache
    local VEH_CACHE = {}
    local VEH_CACHE_TIME = 0
    local VEH_CACHE_TTL = 1.0
    local VEH_MAX_DIST_SQ = 1600000000
    local VEH_OFFSET = { X = 0, Y = 0, Z = 60 }
    local VEH_NAME_RESOLVE_CACHE = setmetatable({}, { __mode = "k" })
    local VEH_NAMES = {
        [1901000] = "Motorcycle", [1901001] = "Motorcycle", [1901002] = "Motorcycle", [1902000] = "Sidecar Motorcycle",
        [1903000] = "Dacia", [1903001] = "Dacia", [1903002] = "Dacia",
        [1907000] = "Buggy", [1907001] = "Buggy", [1907002] = "Buggy",
        [1908000] = "UAZ", [1908001] = "UAZ", [1908002] = "UAZ", [1908003] = "UAZ", [1909000] = "UAZ", [1910000] = "UAZ",
        [1911000] = "PG-117 (Boat)", [1911001] = "PG-117 (Boat)",
        [1912000] = "Aquarail (Jet Ski)", [1912001] = "Aquarail (Jet Ski)",
        [1913000] = "BRDM-2", [1913001] = "BRDM-2",
        [1914000] = "Mirado", [1915000] = "Mirado",
        [1916000] = "Rony",
        [1917000] = "Scooter",
        [1918000] = "Snowmobile",
        [1919000] = "Tukshai",
        [1920000] = "Snowbike",
        [1953000] = "Monster Truck", [1953001] = "Monster Truck",
        [1960000] = "Motor Glider", [1960001] = "Motor Glider",
        [1961000] = "Coupe RB", [1961001] = "Coupe RB",
        [1963000] = "Tank",
        [1965000] = "Mountain Bike",
        [1966000] = "UTV",
        [1967000] = "Big Foot",
        [1987000] = "Horse",
        [1988000] = "Hovercraft"
    }
    local VEH_CFG_KEYS = {}
    for _, name in pairs(VEH_NAMES) do
        VEH_CFG_KEYS[name] = "VehESP_" .. string.gsub(name, "[%s%-%(%)%_]", "")
    end

    local function GetVehicleNameAndKey(veh) 
        if not SafeIsValid(veh) then return "Vehicle", "VehESP_Vehicle" end
        local cached = VEH_NAME_RESOLVE_CACHE[veh]
        if cached then return cached[1], cached[2] end

        local n = veh.DisplayName
        if not n or n == "" then
            local av = veh.VehicleAvatar
            if SafeIsValid(av) and av.GetDefaultAvatarID then 
                local okId, id = SafeMethodCall(av, "GetDefaultAvatarID")
                id = okId and id or 0
                if id and id > 0 then 
                    local baseId = math.floor(id / 1000) * 1000
                    n = VEH_NAMES[baseId] or VEH_NAMES[id]
                end
            end
        end

        if not n or n == "" then
            local okCls, clsObj = pcall(function() return veh:GetClass() end)
            if okCls and clsObj and clsObj.GetName then
                local okName, clsName = pcall(function() return clsObj:GetName() end)
                if okName and clsName then
                    if clsName:find("UAZ") then n = "UAZ"
                    elseif clsName:find("Buggy") then n = "Buggy"
                    elseif clsName:find("Dacia") then n = "Dacia"
                    elseif clsName:find("Motorcycle") or clsName:find("Motorbike") then n = "Motorcycle"
                    elseif clsName:find("BRDM") then n = "BRDM-2"
                    elseif clsName:find("Coupe") then n = "Coupe RB"
                    elseif clsName:find("Mirado") then n = "Mirado"
                    elseif clsName:find("Rony") then n = "Rony"
                    elseif clsName:find("Tuk") then n = "Tukshai"
                    elseif clsName:find("Scooter") then n = "Scooter"
                    elseif clsName:find("Snowmobile") then n = "Snowmobile"
                    elseif clsName:find("Glider") then n = "Motor Glider"
                    elseif clsName:find("Monster") then n = "Monster Truck"
                    elseif clsName:find("Boat") or clsName:find("PG117") then n = "PG-117 (Boat)"
                    elseif clsName:find("JetSki") or clsName:find("Aqua") then n = "Aquarail (Jet Ski)"
                    elseif clsName:find("UTV") then n = "UTV"
                    elseif clsName:find("Bike") then n = "Mountain Bike"
                    elseif clsName:find("Hovercraft") then n = "Hovercraft"
                    elseif clsName:find("Horse") then n = "Horse"
                    end
                end
            end
        end

        n = n or "Vehicle"
        if n == "" then n = "Vehicle" end
        local cfgKey = VEH_CFG_KEYS[n]
        if not cfgKey then
            cfgKey = "VehESP_" .. string.gsub(n, "[%s%-%(%)%_]", "")
            VEH_CFG_KEYS[n] = cfgKey
        end
        VEH_NAME_RESOLVE_CACHE[veh] = { n, cfgKey }
        return n, cfgKey
    end

    -- [OPT-P2a] Centralized AI resolution helper (handles real players + bots with PlayerKey=0)
    local function ResolveIsAI(pKey, pawn)
        if pKey and pKey ~= 0 and AI_CACHE[pKey] ~= nil then return AI_CACHE[pKey] end
        local isAI = false
        if Game and Game.IsAI and pawn then
            local s, r = pcall(Game.IsAI, Game, pawn)
            if s and r == true then isAI = true end
        end
        if not isAI and pawn then
            if pawn.bIsAI == true or pawn.bAI == true then isAI = true end
            if not isAI and type(pawn.IsAI) == "function" then
                local s, r = pcall(pawn.IsAI, pawn)
                if s and r == true then isAI = true end
            end
            if not isAI and (not pKey or pKey == 0) then
                pcall(function()
                    if pawn.PlayerState and (pawn.PlayerState.bIsABot == true or pawn.PlayerState.bIsAI == true) then
                        isAI = true
                    end
                end)
            end
        end
        if pKey and pKey ~= 0 and (AI_CACHE_SIZE or 0) < 512 then
            AI_CACHE_SIZE = (AI_CACHE_SIZE or 0) + 1
            AI_CACHE[pKey] = isAI
        end
        return isAI
    end

    -- SINGLE-LOOP ENGINE
    _G.NAME_CACHE = _G.NAME_CACHE or {}
    _G.NAME_LOOKUP_DONE = _G.NAME_LOOKUP_DONE or {}
    local NAME_CACHE_SIZE = 0
    local NAME_CACHE_MAX = 256

    -- Resolve an enemy name only once per pawn/key, then serve it from cache.
    local function GetEnemyName(pawn)
        if not pawn then return "ENEMY" end

        local cKey = pawn.PlayerKey
        if not cKey or cKey == 0 then return "ENEMY" end  -- [OPT-P4d] Skip tostring fallback (unstable cache key)
        if _G.NAME_CACHE[cKey] ~= nil then
            return _G.NAME_CACHE[cKey]
        end

        -- Remember even failed lookups so GetPlayerNameSafety is never hammered.
        if _G.NAME_LOOKUP_DONE[cKey] then
            return "ENEMY"
        end
        _G.NAME_LOOKUP_DONE[cKey] = true

        local eName = "ENEMY"
        local getter = pawn.GetPlayerNameSafety
        if getter then
            local ok, name = pcall(getter, pawn)
            if ok and type(name) == "string" and name ~= "" then
                eName = name
            end
        end

        _G.NAME_CACHE[cKey] = eName
        NAME_CACHE_SIZE = NAME_CACHE_SIZE + 1
        if NAME_CACHE_SIZE > NAME_CACHE_MAX then
            -- Hard reset only when the safety bound is crossed; avoids unbounded table growth.
            _G.NAME_CACHE = {}
            _G.NAME_LOOKUP_DONE = {}
            NAME_CACHE_SIZE = 0
        end
        return eName
    end

    local COLOR_PALETTE = {
        [0] = { R=255, G=0, B=0, A=255, r=255, g=0, b=0, a=255 },
        [1] = { R=0, G=255, B=255, A=255, r=0, g=255, b=255, a=255 },
        [2] = { R=255, G=255, B=0, A=255, r=255, g=255, b=0, a=255 },
        [3] = { R=0, G=255, B=0, A=255, r=0, g=255, b=0, a=255 },
        [4] = { R=128, G=0, B=255, A=255, r=128, g=0, b=255, a=255 },
        [5] = { R=255, G=255, B=255, A=255, r=255, g=255, b=255, a=255 }
    }
    local function GetColorTable(idx) return COLOR_PALETTE[idx] or COLOR_PALETTE[0] end
    local LINEAR_COLOR_CACHE = {}
    local function GetLinearColor(idx)
        local intensity = (_G.LexusConfig and _G.LexusConfig.GlowIntensity) or 60
        local cacheKey = (idx * 1000) + math.floor(intensity)
        if LINEAR_COLOR_CACHE[cacheKey] then return LINEAR_COLOR_CACHE[cacheKey] end
        local c = GetColorTable(idx)
        local mult = (intensity / 100.0) * 100.0
        if mult < 1.0 then mult = 1.0 end
        local LinearColorClass = _ci_LinearColor
        local lc
        if LinearColorClass then
            lc = LinearColorClass((c.R / 255.0) * mult, (c.G / 255.0) * mult, (c.B / 255.0) * mult, 1.0)
        else
            lc = { R = (c.R / 255.0) * mult, G = (c.G / 255.0) * mult, B = (c.B / 255.0) * mult, A = 1.0 }
        end
        LINEAR_COLOR_CACHE[cacheKey] = lc
        return lc
    end

    -- ============================================================================
    -- S13  WALLHACK NEW ENGINE (DUNGLUA CHAMS + IDEA OUTLINE + DYE SYSTEM)
    -- ============================================================================
    local _ci_SkeletalMeshComponent = import("SkeletalMeshComponent") or import("/Script/Engine.SkeletalMeshComponent")
    local _ci_StaticMeshComponent = import("StaticMeshComponent") or import("/Script/Engine.StaticMeshComponent")
    local _ci_SlotViewAvatarComponent = import("SlotViewAvatarComponent") or import("CharacterAvatarComponent")

    local function GetAllSkeletalMeshes(enemy, markData)
        local curTime = os.clock()
        if markData and markData.CachedMeshes and markData.CachedMeshTime and (curTime - markData.CachedMeshTime < 0.8) then
            local valid = true
            for i = 1, #markData.CachedMeshes do
                if not SafeIsValid(markData.CachedMeshes[i]) then
                    valid = false
                    break
                end
            end
            if valid and #markData.CachedMeshes > 0 then
                return markData.CachedMeshes
            end
        end

        local meshes = {}
        local seen = {}
        local function AddMesh(m)
            if m and SafeIsValid(m) and not seen[m] then
                seen[m] = true
                table.insert(meshes, m)
            end
        end

        -- 1. Main and Master Body Meshes
        AddMesh(enemy.Mesh)
        AddMesh(enemy.MasterMesh)

        -- 2. Layered Character Custom Outfit/Suit/Backpack Meshes
        AddMesh(enemy.CharacterMesh0)
        AddMesh(enemy.CharacterMesh1)
        AddMesh(enemy.CharacterMesh2)
        AddMesh(enemy.CharacterMesh3)
        AddMesh(enemy.CharacterMesh4)
        AddMesh(enemy.CharacterMesh5)

        -- 3. Character Avatar Component Meshes (SlotViewAvatarComponent / CharacterAvatarComp2_BP)
        pcall(function()
            local avatarComp = enemy.CharacterAvatarComp2_BP or (enemy.getAvatarComponent2 and enemy:getAvatarComponent2())
            if not SafeIsValid(avatarComp) and _ci_SlotViewAvatarComponent and type(enemy.GetComponentByClass) == "function" then
                avatarComp = enemy:GetComponentByClass(_ci_SlotViewAvatarComponent)
            end
            if SafeIsValid(avatarComp) then
                for slot = 0, 30 do
                    if type(avatarComp.GetMeshCompBySlotID) == "function" then
                        local m = avatarComp:GetMeshCompBySlotID(slot)
                        if SafeIsValid(m) then AddMesh(m) end
                    elseif type(avatarComp.GetMeshCompBySlot) == "function" then
                        local m = avatarComp:GetMeshCompBySlot(slot)
                        if SafeIsValid(m) then AddMesh(m) end
                    end
                end
            end
        end)

        -- 4. All Child Mesh Components (Skeletal & Static & Mesh Components)
        pcall(function()
            local classesToQuery = { _ci_MeshComponent, _ci_SkeletalMeshComponent, _ci_StaticMeshComponent }
            for _, cls in ipairs(classesToQuery) do
                if cls and type(enemy.GetComponentsByClass) == "function" then
                    local childs = enemy:GetComponentsByClass(cls)
                    if childs then
                        local count = type(childs.Num) == "function" and childs:Num() or #childs
                        for i = 1, count do
                            local comp = type(childs.Get) == "function" and childs:Get(i-1) or childs[i]
                            AddMesh(comp)
                        end
                    end
                end
            end
        end)

        -- 5. Current & Equipped Weapon Meshes
        pcall(function()
            local weapon = nil
            if type(enemy.GetCurrentWeapon) == "function" then
                weapon = enemy:GetCurrentWeapon()
            elseif enemy.CurrentWeapon then
                weapon = enemy.CurrentWeapon
            end
            if SafeIsValid(weapon) then
                AddMesh(weapon.Mesh)
                if type(weapon.GetComponentsByClass) == "function" and _ci_MeshComponent then
                    local wMeshes = weapon:GetComponentsByClass(_ci_MeshComponent)
                    if wMeshes then
                        local count = type(wMeshes.Num) == "function" and wMeshes:Num() or #wMeshes
                        for i = 1, count do
                            local comp = type(wMeshes.Get) == "function" and wMeshes:Get(i-1) or wMeshes[i]
                            AddMesh(comp)
                        end
                    end
                end
            end
        end)

        if markData then
            markData.CachedMeshes = meshes
            markData.CachedMeshTime = curTime
        end
        return meshes
    end

    local function ApplyColorBodyNew(enemy, markData)
        if not enemy or not SafeIsValid(enemy) then return end

        pcall(function()
            local isBot = (markData and markData.AK_IS_BOT) or false
            local eVisChoice = (_G.LexusConfig and _G.LexusConfig.ColorEnemyWHVis) or 0
            local eOccChoice = (_G.LexusConfig and _G.LexusConfig.ColorEnemyWHOcc) or 2
            local bVisChoice = (_G.LexusConfig and _G.LexusConfig.ColorBotWHVis) or 3
            local bOccChoice = (_G.LexusConfig and _G.LexusConfig.ColorBotWHOcc) or 5
            local glowInt = (_G.LexusConfig and _G.LexusConfig.GlowIntensity) or 60

            -- Collect first. The mesh count is part of the state hash so that
            -- newly attached equipment (helmet/vest/etc.) triggers a re-apply.
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            if not meshes or #meshes == 0 then return end

            local currentMeshCount = #meshes
            local stateHash = (isBot and 1000000 or 0) + currentMeshCount * 100000
                + eVisChoice * 10000 + eOccChoice * 1000 + bVisChoice * 100 + bOccChoice * 10 + (glowInt % 100)

            local nowTime = os.clock()
            if markData and markData.ColorNewApplied and markData.LastColorNewHash == stateHash
                and markData.LastColorApplyTime and (nowTime - markData.LastColorApplyTime < 1.5) then
                return
            end

            if markData then
                markData.LastColorNewHash = stateHash
                markData.ColorNewApplied = true
                markData.LastColorApplyTime = nowTime
            end

            local visColor = isBot and GetLinearColor(bVisChoice) or GetLinearColor(eVisChoice)
            local occColor = isBot and GetLinearColor(bOccChoice) or GetLinearColor(eOccChoice)

            for _, mesh in ipairs(meshes) do
                if SafeIsValid(mesh) and SafeIsValid(enemy) then
                    pcall(function()
                        if type(mesh.SetDrawDyeing) == "function" then
                            mesh:SetDrawDyeing(true)
                            mesh:SetDrawDyeingMode(1)
                            mesh:SetVisibleDyeingColor(visColor)
                            mesh:SetOccludedDyeingColor(occColor)
                            mesh:SetLastRenderInOpaque(false)
                            mesh:SetDyeingColorFadeDistance(99999.0)
                            mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
                        end
                        if type(mesh.SetDrawIdeaOutline) == "function" then
                            mesh:SetDrawIdeaOutline(true)
                            mesh:SetIdeaOutlineNew(true)
                            mesh:OverrideIdeaOutlineColor(true, visColor)
                            mesh:SetIdeaOutlineOcclusionColor(occColor)
                            mesh:OverrideIdeaOutlineThickness(true, 2.5)
                            mesh:SetIdeaOutlineOcclusionHighlight(true)
                            mesh:SetIdeaOverrideOutlineAndOcclusion(true)
                        end
                    end)
                end
            end
        end)
    end

    local function UndoColorBodyNew(enemy, markData)
        if not markData or not markData.ColorNewApplied then return end
        pcall(function()
            if SafeIsValid(enemy) then
local meshes = GetAllSkeletalMeshes(enemy)
                for _, mesh in ipairs(meshes) do
                    if SafeIsValid(mesh) then
                        pcall(function()
                            if type(mesh.SetDrawDyeing) == "function" then mesh:SetDrawDyeing(false) end
                            if type(mesh.SetLastRenderInOpaque) == "function" then mesh:SetLastRenderInOpaque(true) end
                            if type(mesh.SetDrawIdeaOutline) == "function" then mesh:SetDrawIdeaOutline(false) end
                        end)
                    end
                end
            end
            markData.ColorNewApplied = false
            markData.LastColorNewHash = 0
        end)
    end
    local function ResetRuntimeCachesForMatchChange()
        AI_CACHE = {}; AI_CACHE_SIZE = 0; VEH_CACHE = {}; VEH_CACHE_TIME = 0; _G.NAME_CACHE = {}; _G.NAME_LOOKUP_DONE = {}; _G.POS_CACHE = {}
        -- [FIX ESP-5] Reset console/HDR so they re-init for new match
        CONSOLE_READY = false
        HDR_CONSOLE_READY = false
        MAP_INIT_DONE = false
        InvalidatePawnCache()
        -- [FIX ESP-5] Reset FrameCache to force fresh data for new match
        _FrameCache.frame = -1; _FrameCache.pawn = nil; _FrameCache.pos = nil; _FrameCache.hud = nil; _FrameCache.pc = nil; _FrameCache.team = 0
        if rawget(_G, "SnaplineESP") then pcall(function() SnaplineESP.ClearAllSnapLines(); SnaplineESP.ESPCanvas = nil end) end
        if GK_DestroyWidget then GK_DestroyWidget() end
        if _G.LexusState and _G.LexusState.EnemyMarks then
            for _, md in pairs(_G.LexusState.EnemyMarks) do
                if md and md.enemy and UndoColorBodyNew then UndoColorBodyNew(md.enemy, md) end
            end
            _G.LexusState.EnemyMarks = {}
        end
        SnaplineESP.Clear(); if _G.AK_Map_Marks then for _, md in pairs(_G.AK_Map_Marks) do if md and md.markId and InGameMarkTools then pcall(function() if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(md.markId) end; if InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(md.markId) end end) end end end
        _G.AK_Map_Marks = {}
    end

    -- ============================================================================
    -- SINGLE-LOOP ENGINE
    -- ============================================================================
    local ZERO_VECTOR = nil
    local TEXT_OFFSET = { X = 0, Y = 0, Z = 15 }
    -- [PERF OPT 4] Cache GetAllPlayerPawns with 0.5s TTL - eliminates double engine query
    local _PAWN_CACHE = nil
    local _PAWN_CACHE_TIME = 0
    local _PAWN_CACHE_TTL = 0.5
    local function InvalidatePawnCache()
        _PAWN_CACHE = nil
        _PAWN_CACHE_TIME = 0
    end
    local function GetCachedPlayerPawns()
        local now = os.clock()
        if _PAWN_CACHE and (now - _PAWN_CACHE_TIME) < _PAWN_CACHE_TTL then return true, _PAWN_CACHE end
        
        local pawnsList = {}
        local seenPawns = {}
        local function AddPawn(p)
            if p and SafeIsValid(p) and not seenPawns[p] then
                seenPawns[p] = true
                table.insert(pawnsList, p)
            end
        end

        -- 1. Game:GetAllPlayerPawns() (Player-controlled pawns)
        local ok, pawns = SafeMethodCall(Game, "GetAllPlayerPawns")
        if ok and pawns then
            for _, p in pairs(pawns) do AddPawn(p) end
        end

        -- 2. GameplayData.GetAllCharacters() (ALL characters including AI bots)
        pcall(function()
            local okGP, gp = pcall(require, "GameLua.GameCore.Data.GameplayData")
            if okGP and gp and gp.GetAllCharacters then
                local chars = gp.GetAllCharacters()
                if chars then
                    for _, c in pairs(chars) do AddPawn(c) end
                end
            end
        end)

        -- 3. CGameState:GetAllCharacters() (Fallback character pool)
        if #pawnsList == 0 then
            pcall(function()
                local okGS, GS = pcall(require, "GameLua.GameCore.Data.CGameState")
                if okGS and GS and GS.GetAllCharacters then
                    local chars = GS:GetAllCharacters()
                    if chars then
                        for _, c in pairs(chars) do AddPawn(c) end
                    end
                end
            end)
        end

        if #pawnsList > 0 then
            _PAWN_CACHE = pawnsList
            _PAWN_CACHE_TIME = now
            return true, _PAWN_CACHE
        end

        if _PAWN_CACHE then return true, _PAWN_CACHE end
        return ok, pawns
    end

    local function GetESPState()
        if not rawget(_G, "Game") then return end
        local okLocal, localPawn = pcall(GameplayData.GetPlayerCharacter); if not okLocal or not SafeIsValid(localPawn) then return end
        local matchToken = localPawn; local okState, gameState = SafeMethodCall(GameplayData, "GetGameState"); if okState and SafeIsValid(gameState) then matchToken = gameState end
        if PBC_MATCH_TOKEN and PBC_MATCH_TOKEN ~= matchToken then ResetRuntimeCachesForMatchChange() end; PBC_MATCH_TOKEN = matchToken
        if not CONSOLE_READY then SetupConsole() end
        if not MAP_INIT_DONE then InitMapTracking() end
        local okPos, myPos = SafeMethodCall(localPawn, "K2_GetActorLocation"); if not okPos or not myPos then return end
        local hud = nil; local pc = nil
        local okPc, retPc = pcall(GameplayData.GetPlayerController)
        if okPc and SafeIsValid(retPc) then pc = retPc end
        if not SafeIsValid(pc) and slua_GameFrontendHUD then local okPc2, retPc2 = SafeMethodCall(slua_GameFrontendHUD, "GetPlayerController"); if okPc2 then pc = retPc2 end end
        if SafeIsValid(pc) then local okHud, retHud = SafeMethodCall(pc, "GetHUD"); if okHud then hud = retHud end end
        return localPawn, myPos, hud, pc
    end

    -- ============================================================================
    -- S12  SNAPLINE ESP SYSTEM (High-Performance DungLua Working Engine)
    -- ============================================================================
    local FLinearColor = import("LinearColor") or _G.FLinearColor or LinearColor
    local FVector2D = import("Vector2D") or _G.FVector2D
    local FVector = import("Vector") or _G.FVector

    local _SnaplinePawnsPool = {}
    local _tempHeadLoc = FVector and FVector(0, 0, 0) or { X = 0, Y = 0, Z = 0 }
    local CK_BOT_VIS, CK_BOT_HID = "BOT_VIS", "BOT_HID"
    local CK_ENEMY_VIS, CK_ENEMY_HID = "ENEMY_VIS", "ENEMY_HID"

    local SnaplineESP = {
        ESPCanvas = nil,
        SnapLineWidgets = {},
        bUseSnapLines = true,
        SnapLineThickness = 1.5,
        SnapLineOriginY = 50.0,
        SnapLineOriginOffsetX = 0.0,
        SnapLineHeadOffsetX = 0.0,
        SnapLineHeadOffsetY = -14.0,
        SnapLineEnemyColor = FLinearColor and FLinearColor(1.0, 0.15, 0.15, 0.85) or nil,
        SnapLineEnemyVisibleColor = FLinearColor and FLinearColor(0.0, 1.0, 0.2, 0.95) or nil,
        SnapLineBotColor = FLinearColor and FLinearColor(0.0, 0.9, 1.0, 0.80) or nil,
        SnapLineBotVisibleColor = FLinearColor and FLinearColor(0.3, 1.0, 1.0, 0.95) or nil,
        _CanvasScaleX = 1.0,
        _CanvasScaleY = 1.0,
        _CanvasOffsetX = 0.0,
        _CanvasOffsetY = 0.0,
        _lastTransformTime = 0,
        _CachedTopCenterPixel = FVector2D and FVector2D(0, 0) or { X = 0, Y = 0 },
        _cachedViewportW = 1920,
        _cachedViewportH = 1080,
        _CachedFromX = 0,
        _CachedFromY = 0,
        _lastStartPosTime = 0,
        _tempScreenPixelPos = FVector2D and FVector2D(0, 0) or { X = 0, Y = 0 },
        _tempCanvasPos = FVector2D and FVector2D(0, 0) or { X = 0, Y = 0 },
        _ZeroVector = nil,
        _CachedHitResult = nil,
    }
    _G.SnaplineESP = SnaplineESP

    -- Self-contained helper methods with module-level caching
    function SnaplineESP.GetMyControllerAndPlayer()
        local pc, player = nil, nil
        local GDP = _cached_GameplayData
        if not GDP then
            local ok; ok, GDP = pcall(require, "GameLua.GameCore.Data.GameplayData")
            if ok then _cached_GameplayData = GDP end
        end
        if GDP then
            if GDP.GetPlayerController then pc = GDP.GetPlayerController() end
            if GDP.GetPlayerCharacter then player = GDP.GetPlayerCharacter() end
        end
        if not pc and slua_GameFrontendHUD then
            pcall(function() pc = slua_GameFrontendHUD:GetPlayerController() end)
        end
        if pc and not player and pc.GetPlayerCharacterSafety then
            pcall(function() player = pc:GetPlayerCharacterSafety() end)
        end
        if pc and not player and pc.GetPawn then
            pcall(function() player = pc:GetPawn() end)
        end
        return pc, player
    end

    function SnaplineESP.GetAllPawns()
        -- Zero-allocation table pool (returns valid Lua array for # and ipairs compatibility)
        for i = 1, #_SnaplinePawnsPool do _SnaplinePawnsPool[i] = nil end
        local count = 0
        pcall(function()
            if Game and Game.GetAllPlayerPawns then
                local pawns = Game:GetAllPlayerPawns()
                if pawns then
                    for _, p in pairs(pawns) do
                        if p and slua.isValid(p) then
                            count = count + 1
                            _SnaplinePawnsPool[count] = p
                        end
                    end
                end
            end
        end)
        if count == 0 then
            pcall(function()
                local ok, GS = pcall(require, "GameLua.GameCore.Data.CGameState")
                if ok and GS and GS.GetAllCharacters then
                    local chars = GS:GetAllCharacters()
                    if chars then
                        for _, c in pairs(chars) do
                            if c and slua.isValid(c) then
                                count = count + 1
                                _SnaplinePawnsPool[count] = c
                            end
                        end
                    end
                end
            end)
        end
        return _SnaplinePawnsPool
    end

    function SnaplineESP.InitESPCanvas()
        if SnaplineESP.ESPCanvas and slua.isValid(SnaplineESP.ESPCanvas) then return true end
        local ok, InGameUITools = pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if not ok or not InGameUITools then return false end
        local MainControlBaseUI = nil
        pcall(function() MainControlBaseUI = InGameUITools.GetMainControlBaseUI and InGameUITools.GetMainControlBaseUI() end)
        if not MainControlBaseUI or not slua.isValid(MainControlBaseUI) then return false end

        local ParentCanvas = nil
        if MainControlBaseUI.CanvasPanel_0 and slua.isValid(MainControlBaseUI.CanvasPanel_0) then 
            ParentCanvas = MainControlBaseUI.CanvasPanel_0
        elseif MainControlBaseUI.CanvasPanel_42 and slua.isValid(MainControlBaseUI.CanvasPanel_42) then 
            ParentCanvas = MainControlBaseUI.CanvasPanel_42 
        end

        if not ParentCanvas or not slua.isValid(ParentCanvas) then return false end
        SnaplineESP.ESPCanvas = ParentCanvas
        return true
    end

    function SnaplineESP.UpdateCanvasTransform(PC)
        if not SnaplineESP.ESPCanvas or not slua.isValid(SnaplineESP.ESPCanvas) then return end
        local now = os.clock()
        if SnaplineESP._lastTransformTime and (now - SnaplineESP._lastTransformTime < 1.0) and SnaplineESP._CanvasScaleX and SnaplineESP._CanvasScaleX > 0 then
            return
        end
        SnaplineESP._lastTransformTime = now

        local success = false
        pcall(function()
            local SBL = _ci_SBL
            if SBL and SBL.AbsoluteToLocal then
                local cg = SnaplineESP.ESPCanvas:GetCachedGeometry()
                if cg then
                    if not SnaplineESP._tempScreenPixelPos then SnaplineESP._tempScreenPixelPos = FVector2D and FVector2D(0, 0) or {X=0, Y=0} end
                    SnaplineESP._tempScreenPixelPos.X = 0; SnaplineESP._tempScreenPixelPos.Y = 0
                    local pt0 = SBL.AbsoluteToLocal(cg, SnaplineESP._tempScreenPixelPos)
                    SnaplineESP._tempScreenPixelPos.X = 100; SnaplineESP._tempScreenPixelPos.Y = 100
                    local pt1 = SBL.AbsoluteToLocal(cg, SnaplineESP._tempScreenPixelPos)
                    if pt0 and pt1 then
                        SnaplineESP._CanvasScaleX = (pt1.X - pt0.X) / 100
                        SnaplineESP._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                        SnaplineESP._CanvasOffsetX = pt0.X
                        SnaplineESP._CanvasOffsetY = pt0.Y
                        success = true
                    end
                end
            end
        end)

        if not success then
            pcall(function()
                local WLL = _ci_WLL
                if WLL and WLL.ScreenToWidgetLocal then
                    local cg = SnaplineESP.ESPCanvas:GetCachedGeometry()
                    if cg then
                        local pt0 = FVector2D and FVector2D(0, 0) or {X=0, Y=0}
                        local pt1 = FVector2D and FVector2D(0, 0) or {X=0, Y=0}
                        local in0 = FVector2D and FVector2D(0, 0) or {X=0, Y=0}
                        local in1 = FVector2D and FVector2D(100, 100) or {X=100, Y=100}
                        WLL.ScreenToWidgetLocal(PC, cg, in0, pt0)
                        WLL.ScreenToWidgetLocal(PC, cg, in1, pt1)
                        SnaplineESP._CanvasScaleX = (pt1.X - pt0.X) / 100
                        SnaplineESP._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                        SnaplineESP._CanvasOffsetX = pt0.X
                        SnaplineESP._CanvasOffsetY = pt0.Y
                        success = true
                    end
                end
            end)
        end

        if not success then
            local scale = 1.0
            local WLL = _ci_WLL
            if WLL and WLL.GetViewportScale then scale = WLL.GetViewportScale(PC) or 1.0 end
            SnaplineESP._CanvasScaleX = 1.0 / scale
            SnaplineESP._CanvasScaleY = 1.0 / scale
            SnaplineESP._CanvasOffsetX = 0
            SnaplineESP._CanvasOffsetY = 0
        end
    end

    function SnaplineESP.ScreenPixelToCanvasLocal(PC, ScreenPixelPos)
        if not ScreenPixelPos then return SnaplineESP._tempCanvasPos end
        local scaleX = SnaplineESP._CanvasScaleX or 1.0
        local scaleY = SnaplineESP._CanvasScaleY or 1.0
        local offsetX = SnaplineESP._CanvasOffsetX or 0
        local offsetY = SnaplineESP._CanvasOffsetY or 0
        local x = ScreenPixelPos.X * scaleX + offsetX
        local y = ScreenPixelPos.Y * scaleY + offsetY
        if not SnaplineESP._tempCanvasPos then
            SnaplineESP._tempCanvasPos = (FVector2D and FVector2D(x, y)) or {X = x, Y = y}
        else
            SnaplineESP._tempCanvasPos.X = x
            SnaplineESP._tempCanvasPos.Y = y
        end
        return SnaplineESP._tempCanvasPos
    end

    function SnaplineESP.ProjectWorldToCanvasLocal(PC, WorldLoc)
        if not PC or not slua.isValid(PC) or not WorldLoc then return false, SnaplineESP._tempCanvasPos end
        if not SnaplineESP._tempScreenPixelPos then SnaplineESP._tempScreenPixelPos = FVector2D and FVector2D(0, 0) or {X=0, Y=0} end
        SnaplineESP._tempScreenPixelPos.X = 0; SnaplineESP._tempScreenPixelPos.Y = 0
        local bOK = false
        pcall(function()
            local res = PC:ProjectWorldLocationToScreen(WorldLoc, SnaplineESP._tempScreenPixelPos, true)
            if res == true or res == 1 then bOK = true end
        end)
        if not bOK or (SnaplineESP._tempScreenPixelPos.X == 0 and SnaplineESP._tempScreenPixelPos.Y == 0) then return false, SnaplineESP._tempCanvasPos end
        local CanvasLocalPos = SnaplineESP.ScreenPixelToCanvasLocal(PC, SnaplineESP._tempScreenPixelPos)
        return true, CanvasLocalPos
    end

    function SnaplineESP.GetSnapLineStartPos(PC)
        local now = os.clock()
        if SnaplineESP._lastStartPosTime and (now - SnaplineESP._lastStartPosTime < 0.5) and SnaplineESP._CachedFromX and SnaplineESP._CachedFromX > 0 then
            return SnaplineESP._CachedFromX, SnaplineESP._CachedFromY
        end
        SnaplineESP._lastStartPosTime = now

        local screenPixelW, screenPixelH = 0, 0
        local scale = 1.0

        pcall(function()
            if PC and PC.GetViewportSize then
                local vs = SnaplineESP._tempScreenPixelPos or (FVector2D and FVector2D(0, 0) or {X=0,Y=0})
                PC:GetViewportSize(vs)
                if vs and vs.X and vs.X > 200 then screenPixelW = vs.X; screenPixelH = vs.Y end
            end
        end)
        if screenPixelW <= 200 then
            pcall(function()
                local WLL = _ci_WLL
                if WLL and WLL.GetViewportSize then
                    local vs = WLL.GetViewportSize(PC)
                    if vs and vs.X and vs.X > 200 then screenPixelW = vs.X; screenPixelH = vs.Y end
                end
            end)
        end
        pcall(function()
            local WLL = _ci_WLL
            if WLL and WLL.GetViewportScale then
                local s = WLL.GetViewportScale(PC)
                if s and type(s) == "number" and s > 0 then scale = s end
            end
        end)
        if screenPixelW <= 200 then
            screenPixelW = (SnaplineESP._cachedViewportW or 1920) * scale
            screenPixelH = (SnaplineESP._cachedViewportH or 1080) * scale
        end

        if not SnaplineESP._CachedTopCenterPixel then SnaplineESP._CachedTopCenterPixel = FVector2D and FVector2D(0, 0) or {X=0,Y=0} end
        SnaplineESP._CachedTopCenterPixel.X = screenPixelW / 2.0
        SnaplineESP._CachedTopCenterPixel.Y = (SnaplineESP.SnapLineOriginY or 50) * scale

        local fromCanvasPos = SnaplineESP.ScreenPixelToCanvasLocal(PC, SnaplineESP._CachedTopCenterPixel)
        local fromX = fromCanvasPos.X + (SnaplineESP.SnapLineOriginOffsetX or 0)
        local fromY = fromCanvasPos.Y

        SnaplineESP._CachedFromX = fromX
        SnaplineESP._CachedFromY = fromY
        return fromX, fromY
    end

    function SnaplineESP.CreateSnapLine()
        if not SnaplineESP.InitESPCanvas() then return nil end
        
        -- Widget pooling: reuse from pool instead of creating new
        local pool = SnaplineESP._WidgetPool
        if not pool then
            pool = {}
            SnaplineESP._WidgetPool = pool
        end
        
        local Border = nil
        local Slot = nil
        
        -- Try to get from pool
        for i = #pool, 1, -1 do
            local pooled = pool[i]
            if pooled and pooled.Widget and slua.isValid(pooled.Widget) then
                Border = pooled.Widget
                Slot = pooled.Slot
                table.remove(pool, i)
                break
            end
        end
        
        -- Create new if pool empty
        if not Border or not slua.isValid(Border) then
            pcall(function() Border = CGame:NewObjectFromPath("/Script/UMG.Border", SnaplineESP.ESPCanvas) end)
            if not Border or not slua.isValid(Border) then
                pcall(function() Border = CGame.NewObjectFromPath("/Script/UMG.Border", SnaplineESP.ESPCanvas) end)
            end
        end
        if not Border or not slua.isValid(Border) then return nil end

        local color = SnaplineESP.SnapLineEnemyColor or (FLinearColor and FLinearColor(1.0, 0.15, 0.15, 0.85) or nil)
        if color then pcall(function() Border:SetBrushColor(color) end) end
        pcall(function() Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        pcall(function() Border.RenderTransformPivot = FVector2D and FVector2D(0.0, 0.5) or {X=0,Y=0.5} end)
        pcall(function() Border:SetRenderTransformPivot(FVector2D and FVector2D(0.0, 0.5) or {X=0,Y=0.5}) end)

        if not Slot or not slua.isValid(Slot) then
            pcall(function()
                Slot = SnaplineESP.ESPCanvas:AddChildToCanvas(Border)
                if Slot then Slot:SetAutoSize(false); Slot:SetZOrder(1) end
            end)
        end
        return { Widget = Border, Slot = Slot }
    end

    function SnaplineESP.IsPlayerVisible(PC, Character)
        if not PC or not slua.isValid(PC) or not Character or not slua.isValid(Character) then return false end
        local now = os.clock()
        if Character._lastVisTime and (now - Character._lastVisTime) < 0.6 then
            return Character._cachedIsVisible or false
        end
        Character._lastVisTime = now
        local bVis = false
        pcall(function()
            if PC.LineOfSightTo then
                if not SnaplineESP._ZeroVector then
                    local VT = _ci_FVector
                    if VT then SnaplineESP._ZeroVector = VT(0, 0, 0) end
                end
                bVis = PC:LineOfSightTo(Character, SnaplineESP._ZeroVector, false)
            end
        end)
        if not bVis then
            local KismetSystemLibrary = _ci_KSL
            if KismetSystemLibrary and KismetSystemLibrary.LineTraceSingle then
                pcall(function()
                    local camMgr = nil
                    local GameplayStatics = _ci_GameplayStatics
                    if GameplayStatics and GameplayStatics.GetPlayerCameraManager then
                        camMgr = GameplayStatics.GetPlayerCameraManager(PC, 0)
                    end
                    local startLoc = camMgr and camMgr:GetCameraLocation() or (PC.GetPlayerCharacter and PC:GetPlayerCharacter() and PC:GetPlayerCharacter():K2_GetActorLocation())
                    local loc = Character.K2_GetActorLocation and Character:K2_GetActorLocation()
                    if startLoc and loc then
                        local hOffset = 75
                        if Character.bIsCrouched then hOffset = 50
                        elseif Character.IsProne and Character:IsProne() then hOffset = 25 end
                        _tempHeadLoc.X = loc.X; _tempHeadLoc.Y = loc.Y; _tempHeadLoc.Z = loc.Z + hOffset
                        if not SnaplineESP._CachedHitResult then
                            local HitResultClass = _ci_HitResultClass
                            SnaplineESP._CachedHitResult = HitResultClass and HitResultClass() or {}
                        end
                        local bHit = KismetSystemLibrary.LineTraceSingle(PC, startLoc, _tempHeadLoc, 0, false, nil, 0, SnaplineESP._CachedHitResult, true)
                        if bHit then
                            local hitActor = nil
                            if type(SnaplineESP._CachedHitResult.GetActor) == "function" then hitActor = SnaplineESP._CachedHitResult:GetActor()
                            elseif SnaplineESP._CachedHitResult.Actor then hitActor = SnaplineESP._CachedHitResult.Actor end
                            if hitActor and (hitActor == Character or (type(hitActor.IsChildOf) == "function" and hitActor:IsChildOf(Character))) then
                                bVis = true
                            end
                        else
                            bVis = true
                        end
                    end
                end)
            end
        end
        Character._cachedIsVisible = bVis
        return bVis
    end

    function SnaplineESP.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY, Character, PC, isAI)
        if not SnaplineESP.ESPCanvas or not slua.isValid(SnaplineESP.ESPCanvas) then return end

        local LineData = SnaplineESP.SnapLineWidgets[KeyStr]

        if not bOnScreen or not CanvasPos or not Character or not slua.isValid(Character) or not PC or not slua.isValid(PC) then
            if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                pcall(function() LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            end
            return
        end

        local bIsNew = false
        if not LineData then
            LineData = SnaplineESP.CreateSnapLine()
            if not LineData or not LineData.Widget or not LineData.Slot then return end
            SnaplineESP.SnapLineWidgets[KeyStr] = LineData
            bIsNew = true
        end

        local Widget = LineData.Widget
        local Slot = LineData.Slot

        pcall(function() Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)

        if not LineData._PivotSet then
            pcall(function() Widget.RenderTransformPivot = FVector2D and FVector2D(0.0, 0.5) or {X=0,Y=0.5} end)
            pcall(function() Widget:SetRenderTransformPivot(FVector2D and FVector2D(0.0, 0.5) or {X=0,Y=0.5}) end)
            LineData._PivotSet = true
        end

        local bTargetVisible = SnaplineESP.IsPlayerVisible(PC, Character)
        local lineColor
        if isAI then
            lineColor = bTargetVisible and SnaplineESP.SnapLineBotVisibleColor or SnaplineESP.SnapLineBotColor
        else
            lineColor = bTargetVisible and SnaplineESP.SnapLineEnemyVisibleColor or SnaplineESP.SnapLineEnemyColor
        end

        local colorKey = isAI and (bTargetVisible and CK_BOT_VIS or CK_BOT_HID) or (bTargetVisible and CK_ENEMY_VIS or CK_ENEMY_HID)
        if LineData._cachedColorKey ~= colorKey and lineColor then
            pcall(function() Widget:SetBrushColor(lineColor) end)
            LineData._cachedColorKey = colorKey
        end

        local toX = CanvasPos.X + (SnaplineESP.SnapLineHeadOffsetX or 0)
        local toY = CanvasPos.Y + (SnaplineESP.SnapLineHeadOffsetY or 0)

        local dx = toX - fromX
        local dy = toY - fromY
        local length = math.sqrt(dx * dx + dy * dy)
        local thickness = SnaplineESP.SnapLineThickness or 1.5

        local angle_rad = (math.atan2 and math.atan2(dy, dx)) or math.atan(dy, dx)
        local angle = angle_rad * 57.29577951308232

        if not LineData._CachedPosVec then
            LineData._CachedPosVec = FVector2D and FVector2D(fromX, fromY - thickness / 2.0) or {X=fromX, Y=fromY - thickness / 2.0}
            LineData._CachedSizeVec = FVector2D and FVector2D(length, thickness) or {X=length, Y=thickness}
        else
            LineData._CachedPosVec.X = fromX; LineData._CachedPosVec.Y = fromY - thickness / 2.0
            LineData._CachedSizeVec.X = length; LineData._CachedSizeVec.Y = thickness
        end

        pcall(function() 
            Slot:SetPosition(LineData._CachedPosVec) 
            Slot:SetSize(LineData._CachedSizeVec)
            if bIsNew then Slot:SetZOrder(1) end
        end)
        pcall(function() Widget:SetRenderAngle(angle) end)
    end

    function SnaplineESP.RemoveSnapLine(KeyStr)
        local LineData = SnaplineESP.SnapLineWidgets[KeyStr]
        if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
            -- Return to pool instead of destroying
            pcall(function() LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            local pool = SnaplineESP._WidgetPool
            if not pool then pool = {}; SnaplineESP._WidgetPool = pool end
            table.insert(pool, LineData)
            SnaplineESP.SnapLineWidgets[KeyStr] = nil
        end
    end

    function SnaplineESP.ClearAllSnapLines()
        for KeyStr, LineData in pairs(SnaplineESP.SnapLineWidgets) do
            if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                pcall(function() LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                local pool = SnaplineESP._WidgetPool
                if not pool then pool = {}; SnaplineESP._WidgetPool = pool end
                table.insert(pool, LineData)
            end
        end
        SnaplineESP.SnapLineWidgets = {}
    end
    SnaplineESP.Clear = SnaplineESP.ClearAllSnapLines

    local _SnaplineSeen = {}
    local function Tick_SnaplineESP()
        if not (_G.LexusConfig and _G.LexusConfig.SnaplineESPEnabled) then
            SnaplineESP.ClearAllSnapLines()
            return
        end

        local pc, localPawn = SnaplineESP.GetMyControllerAndPlayer()
        if not pc or not slua.isValid(pc) or not localPawn or not slua.isValid(localPawn) then return end

        local myPos = nil
        pcall(function() myPos = localPawn:K2_GetActorLocation() end)
        if not myPos then return end

        local myTeamId = nil
        pcall(function() myTeamId = localPawn.TeamID or (localPawn.GetTeamID and localPawn:GetTeamID()) end)

        if not SnaplineESP.InitESPCanvas() then return end
        SnaplineESP.UpdateCanvasTransform(pc)

        -- SnaplineESP uses Lua array table (_SnaplinePawnsPool) for # and ipairs compatibility.
        local allPawns = SnaplineESP.GetAllPawns()
        if not allPawns or #allPawns == 0 then return end

        local fromX, fromY = SnaplineESP.GetSnapLineStartPos(pc)

        for k in pairs(_SnaplineSeen) do _SnaplineSeen[k] = nil end

        for _, pawn in ipairs(allPawns) do
            if not pawn or not slua.isValid(pawn) or pawn == localPawn then goto continue end
            local hs = pawn.HealthStatus
            if not (pawn.TeamID and (myTeamId == nil or pawn.TeamID ~= myTeamId) and hs and hs ~= 2 and hs ~= 3) then goto continue end

            local pKey = pawn.PlayerKey
            if not pKey or pKey == 0 then goto continue end  -- Skip if no valid PlayerKey
            local isAI = ResolveIsAI(pKey, pawn)  -- [OPT-P2] Centralized AI helper

            local pLoc = nil
            pcall(function() pLoc = pawn:K2_GetActorLocation() end)
            if not pLoc then goto continue end

            local dx = pLoc.X - myPos.X
            local dy = pLoc.Y - myPos.Y
            local dz = pLoc.Z - myPos.Z
            local distSq = dx * dx + dy * dy + dz * dz
            if distSq <= 0 or distSq > 1600000000 then goto continue end

            local hOffset = 75
            if pawn.bIsCrouched then hOffset = 50
            elseif pawn.IsProne and pawn:IsProne() then hOffset = 25 end
            _tempHeadLoc.X = pLoc.X; _tempHeadLoc.Y = pLoc.Y; _tempHeadLoc.Z = pLoc.Z + hOffset

            local bOnScreen, CanvasPos = SnaplineESP.ProjectWorldToCanvasLocal(pc, _tempHeadLoc)
            local key = tostring(pKey)

            _SnaplineSeen[key] = true
            SnaplineESP.UpdateSnapLine(key, CanvasPos, bOnScreen, fromX, fromY, pawn, pc, isAI)
            ::continue::
        end

        for key, LineData in pairs(SnaplineESP.SnapLineWidgets) do
            if not _SnaplineSeen[key] then
                if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                    pcall(function() LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                end
            end
        end
    end
    -- ============================================================================
    -- ITEM / BOMB / WEAPON ESP (High-Performance Zero-Blink Engine)
    -- ============================================================================
    do
        -- Vibrant, highly distinct color palette for maximum legibility
        local C_AR      = { R=255, G=65,  B=85,  A=255 } -- Radiant Coral Red
        local C_SMG     = { R=0,   G=255, B=170, A=255 } -- Neon Mint Green
        local C_Sniper  = { R=0,   G=220, B=255, A=255 } -- Electric Sky Cyan
        local C_Scope   = { R=200, G=110, B=255, A=255 } -- Brilliant Amethyst
        local C_Grenade = { R=255, G=165, B=0,   A=255 } -- Bright Warning Orange

        local ITEM_TEXT_OFFSET = { X = 0, Y = 0, Z = 40 }
        local BOMB_ACTIVE_OFFSET = { X = 0, Y = 0, Z = 25 }
        local BOMB_GROUND_OFFSET = { X = 0, Y = 0, Z = 15 }

        local C_BOMB_FRAG = { R = 255, G = 40, B = 40, A = 255 }
        local C_BOMB_MOLOTOV = { R = 255, G = 130, B = 0, A = 255 }
        local C_BOMB_SMOKE = { R = 0, G = 230, B = 255, A = 255 }

        local ItemDatabase = {
            -- Guns
            [101004] = { name = "M416", key = "EspItem_M416", color = C_AR },
            [101001] = { name = "AKM", key = "EspItem_AKM", color = C_AR },
            [101008] = { name = "M762", key = "EspItem_M762", color = C_AR },
            [101003] = { name = "SCAR-L", key = "EspItem_SCARL", color = C_AR },
            [102002] = { name = "UMP45", key = "EspItem_UMP", color = C_SMG },
            [102001] = { name = "UZI", key = "EspItem_UZI", color = C_SMG },
            [103003] = { name = "AWM", key = "EspItem_AWM", color = C_Sniper },
            [103002] = { name = "M24", key = "EspItem_M24", color = C_Sniper },

            -- Scopes
            [203014] = { name = "3x Scope", key = "EspItem_Scope3x", color = C_Scope },
            [203004] = { name = "4x Scope", key = "EspItem_Scope4x", color = C_Scope },
            [203015] = { name = "6x Scope", key = "EspItem_Scope6x", color = C_Scope },
            [203005] = { name = "8x Scope", key = "EspItem_Scope8x", color = C_Scope },

            -- Grenades (Only Frag, Smoke, Molotov)
            [602004] = { name = "Frag Grenade", key = "EspItem_Frag", color = C_Grenade },
            [602002] = { name = "Smoke Grenade", key = "EspItem_Smoke", color = C_Grenade },
            [602003] = { name = "Molotov", key = "EspItem_Molotov", color = C_Grenade },
        }
        _G.CachedItems = _G.CachedItems or {}

        local function IsItemEnabled(info)
            if not info or not info.key then return false end
            local C = _G.LexusConfig
            if not C then return false end
            return C[info.key] ~= false
        end

        -- [FPS OPT] Position-based actor cache for ItemESP
        local _ITEM_ACTORS_CACHE = nil
        local _ITEM_CACHE_POS = nil
        local _ITEM_CACHE_TIME = 0
        local _ITEM_CACHE_MAX_AGE = 12  -- re-query every 12s max
        local _ITEM_CACHE_MOVE_THRESH_SQ = 2250000  -- 15m squared (in UE units: 1500^2)

        _G.Tick_SDW_ItemESP = function()
            local C = _G.LexusConfig
            if not C or C.ItemESPEnabled == false then 
                _G.CachedItems = {}
                _ITEM_ACTORS_CACHE = nil
                return 
            end
            local player = nil
            local pc = nil
            pcall(function() 
                player = GameplayData.GetPlayerCharacter()
                pc = GameplayData.GetPlayerController() 
            end)
            if not player or not pc then
                if slua_GameFrontendHUD then
                    pcall(function()
                        pc = pc or slua_GameFrontendHUD:GetPlayerController()
                        if pc and pc.GetPlayerCharacter then player = player or pc:GetPlayerCharacter() end
                    end)
                end
            end
            if not player or not pc then return end
            local hud = pc.MyHUD
            if not hud and pc.GetHUD then pcall(function() hud = pc:GetHUD() end) end
            if not hud then return end

            local maxDist = tonumber(C.ItemESPMaxDistance) or 40
            maxDist = math.max(10, math.min(maxDist, 100))

            -- [FPS OPT] Only re-query actors when player moved >15m or 12s elapsed
            local now = os.clock()
            local needRequery = true
            local myPos = nil
            pcall(function() myPos = player:K2_GetActorLocation() end)
            if _ITEM_ACTORS_CACHE and myPos and _ITEM_CACHE_POS then
                local dx = myPos.X - _ITEM_CACHE_POS.X
                local dy = myPos.Y - _ITEM_CACHE_POS.Y
                if (dx*dx + dy*dy) < _ITEM_CACHE_MOVE_THRESH_SQ and (now - _ITEM_CACHE_TIME) < _ITEM_CACHE_MAX_AGE then
                    needRequery = false
                end
            end

            local actors = _ITEM_ACTORS_CACHE
            if needRequery then
                local cls = import("PickUpWrapperActor") or import("STPickupWrapperActor")
                pcall(function()
                    if cls and Game and Game.GetActorsByClass then
                        actors = Game:GetActorsByClass(cls)
                    end
                end)
                _ITEM_ACTORS_CACHE = actors
                _ITEM_CACHE_POS = myPos
                _ITEM_CACHE_TIME = now
            end

            _G.CachedItems = _G.CachedItems or {}
            local list = _G.CachedItems
            for i = #list, 1, -1 do list[i] = nil end
            local count = 0
            if actors then
                local n = 0
                pcall(function() n = actors:Num() or 0 end)
                for i = 0, n - 1 do
                    local item = nil
                    pcall(function() item = actors:Get(i) end)
                    if item and SafeIsValid(item) then
                        local dist = 9999
                        pcall(function() dist = player:GetDistanceTo(item) / 100 end)
                        if dist <= maxDist then
                            local id = nil
                            pcall(function() id = item.DefineID and item.DefineID.TypeSpecificID or item.DefineId end)
                            local info = id and ItemDatabase[id]
                            if info and IsItemEnabled(info) then
                                count = count + 1
                                list[count] = { actor = item, info = info }
                            end
                        end
                    end
                end
            end

            -- Render Pass with customizable text size & color
            local sliderItem = _G.LexusConfig.TextSizeItemUI or 50
            local baseScale = 0.83 + (sliderItem / 100.0) * 0.14
            local itemCol = GetColorTable(_G.LexusConfig.ColorItem or 2)
            for _, entry in ipairs(_G.CachedItems or {}) do
                local item, info = entry.actor, entry.info
                if item and SafeIsValid(item) then
                    local dist = -1
                    pcall(function() dist = player:GetDistanceTo(item) / 100 end)
                    if dist >= 0 and dist <= maxDist then
                        -- [FPS OPT] String concat instead of string.format
                        local txt = info.name .. " [" .. math.floor(dist) .. "m]"
                        local scale = baseScale * math.max(0.70, 1.05 - (dist / maxDist))
                        pcall(function()
                            hud:AddDebugText(txt, item, 16.0, ITEM_TEXT_OFFSET, ITEM_TEXT_OFFSET, itemCol, false, false, true, nil, scale, true)
                        end)
                    end
                end
            end
        end

        _G.Tick_SDW_BombESP = function()
            local C = _G.LexusConfig
            if not C or C.BombESPEnabled == false then return end
            local player = nil
            local pc = nil
            pcall(function() 
                player = GameplayData.GetPlayerCharacter()
                pc = GameplayData.GetPlayerController() 
            end)
            if not player or not pc then
                if slua_GameFrontendHUD then
                    pcall(function()
                        pc = pc or slua_GameFrontendHUD:GetPlayerController()
                        if pc and pc.GetPlayerCharacter then player = player or pc:GetPlayerCharacter() end
                    end)
                end
            end
            if not player or not pc then return end
            local hud = pc.MyHUD
            if not hud and pc.GetHUD then pcall(function() hud = pc:GetHUD() end) end
            if not hud then return end

            local gs = _ci_GameplayStatics
            if not gs then return end

            -- Safe cached projectile class resolution
            if _G._CACHED_BOMB_CLS == nil then
                local clsCandidates = {"GrenadeActorBase", "STExtraShootWeaponBase", "ThrowableProjectile", "Projectile", "Actor"}
                for _, cName in ipairs(clsCandidates) do
                    pcall(function()
                        local c = import(cName)
                        if c and _G._CACHED_BOMB_CLS == nil then
                            _G._CACHED_BOMB_CLS = c
                        end
                    end)
                    if _G._CACHED_BOMB_CLS then break end
                end
                if not _G._CACHED_BOMB_CLS then
                    pcall(function() _G._CACHED_BOMB_CLS = import("Actor") end)
                end
            end
            local cls = _G._CACHED_BOMB_CLS
            if not cls then return end
            local arr = nil
            pcall(function() arr = slua.Array(UEnums.EPropertyClass.Object, cls) end)
            local ui_util = _cached_ui_util
            if not ui_util then
                local ok; ok, ui_util = pcall(require, "client.common.ui_util")
                if ok then _cached_ui_util = ui_util end
            end
            local gi = ui_util and ui_util.GetGameInstance and ui_util.GetGameInstance()
            local gameTime = nil
            if gi and gs then
                pcall(function() gameTime = gs.GetTimeSeconds(gi) end)
            end
            _G.SDW_BombActive = _G.SDW_BombActive or {}
            _G.SDW_BombGround = _G.SDW_BombGround or {}
            local active = _G.SDW_BombActive
            local ground = _G.SDW_BombGround
            for i = #active, 1, -1 do active[i] = nil end
            for i = #ground, 1, -1 do ground[i] = nil end

            if gi and gs and arr then
                local actors = nil
                pcall(function() actors = gs.GetAllActorsOfClass(gi, cls, arr) end)
                if actors then
                    for _, actor in pairs(actors) do
                        if actor and SafeIsValid(actor) and not actor.bHidden and not actor.bTearOff then
                            local name = ""
                            pcall(function() 
                                name = string.lower(type(actor.GetName) == "function" and actor:GetName() or tostring(actor)) 
                            end)
                            local typ = 0
                            -- Only Frag (1), Smoke (2), Molotov (3) - Stun & M79 completely removed!
                            if name:find("smoke") then typ = 2
                            elseif name:find("burn") or name:find("molotov") or name:find("fire") then typ = 3
                            elseif name:find("grenade") or name:find("frag") then typ = 1 end

                            if typ > 0 then
                                local thrown = name:find("projectile") or name:find("thrown") or name:find("active")
                                if thrown then
                                    active[#active + 1] = { actor = actor, typ = typ }
                                else
                                    ground[#ground + 1] = { actor = actor, typ = typ }
                                end
                            end
                        end
                    end
                end
            end
            _G.SDW_BombActive = active
            _G.SDW_BombGround = ground

            local bNames = { [1] = "FRAG GRENADE", [2] = "SMOKE GRENADE", [3] = "MOLOTOV" }
            local bColors = { [1] = C_BOMB_FRAG, [2] = C_BOMB_SMOKE, [3] = C_BOMB_MOLOTOV }

            local function drawBombs(list, maxDist, isActive)
                local offset = isActive and BOMB_ACTIVE_OFFSET or BOMB_GROUND_OFFSET
                local duration = 2.5
                for _, e in ipairs(list or {}) do
                    local b = e.actor
                    if b and SafeIsValid(b) and not b.bHidden then
                        local dist = -1
                        pcall(function() dist = player:GetDistanceTo(b) / 100 end)
                        if dist >= 0 and dist <= maxDist then
                            local bName = bNames[e.typ] or "BOMB"
                            -- [FPS OPT] String concat instead of string.format
                            local text = bName .. " [" .. math.floor(dist) .. "m]"
                            if isActive and gameTime then
                                local left = -1
                                -- [FPS OPT] Use pre-cached gameTime instead of re-querying per bomb
                                pcall(function()
                                    if b.ExplosionTime then left = b.ExplosionTime - gameTime
                                    elseif b.ExplodeTime then left = b.ExplodeTime - gameTime end
                                end)
                                if left > 0 and left < 100 then
                                    text = text .. " (" .. string.format("%.1f", left) .. "s)"
                                end
                            end
                            local col = bColors[e.typ] or C_BOMB_FRAG
                            local scale = math.max(0.65, 1.15 - (dist / maxDist))
                            pcall(function()
                                hud:AddDebugText(text, b, duration, offset, offset, col, false, false, true, nil, scale, true)
                            end)
                        end
                    end
                end
            end

            drawBombs(_G.SDW_BombGround, 50, false)
            drawBombs(_G.SDW_BombActive, 50, true)
        end
    end

    -- ============================================================================
    -- FRAME-LEVEL CACHING SYSTEM (Eliminates redundant pcall/GetPlayerCharacter calls)
    -- ============================================================================
    local _FrameCache = { frame = -1, pawn = nil, pos = nil, hud = nil, pc = nil, team = 0 }
    local function GetFrameCache()
        local f = os.clock()
        -- Use frame counter approximation since we can't access frame number directly
        -- Cache for ~16ms (one frame at 60fps)
        if _FrameCache.frame < 0 or (f - (_FrameCache.time or 0)) > 0.05 then  -- 50ms (20 FPS) - Balanced CPU & smooth tracking
            _FrameCache.time = f
            _FrameCache.frame = _FrameCache.frame + 1
            local pawn, pos, hud, pc = nil, nil, nil, nil
            pcall(function() pawn = GameplayData.GetPlayerCharacter() end)
            if not pawn and slua_GameFrontendHUD then
                pcall(function() pc = slua_GameFrontendHUD:GetPlayerController(); if pc and pc.GetPlayerCharacter then pawn = pc:GetPlayerCharacter() end end)
            end
            if pawn then
                pcall(function() pos = pawn.K2_GetActorLocation and pawn:K2_GetActorLocation() end)
                pcall(function() hud = pawn.MyHUD or (pc and pc.MyHUD) end)
            else
                -- [FIX ESP-2] Transient pawn invalidity (parachute, vehicle exit, respawn)
                -- Keep previous valid cache instead of storing nil (prevents ESP flash)
                pawn = _FrameCache.pawn
                pos = _FrameCache.pos
                hud = _FrameCache.hud
                pc = _FrameCache.pc
            end
            if not pc then pcall(function() pc = GameplayData.GetPlayerController() end) end
            if not hud and pc then pcall(function() hud = pc.MyHUD or (pc.GetHUD and pc:GetHUD()) end) end
            _FrameCache.pawn = pawn
            _FrameCache.pos = pos
            _FrameCache.hud = hud
            _FrameCache.pc = pc
            _FrameCache.team = pawn and pawn.TeamID or 0
        end
        return _FrameCache.pawn, _FrameCache.pos, _FrameCache.hud, _FrameCache.pc, _FrameCache.team
    end

    local function Tick_HealthBarESP()
        if not (_G.LexusConfig and _G.LexusConfig.HealthBarESPEnabled) then return end
        local localPawn, myPos, hud, pc, myTeamId = GetFrameCache()
        if not localPawn or not hud then return end
        local okPawns, allPawns = GetCachedPlayerPawns()
        if not okPawns or not allPawns then return end

        local sliderEnemy = _G.LexusConfig.TextSizeEnemyUI or 50
        local eScale = 0.83 + (sliderEnemy / 100.0) * 0.14

        -- Use EnemyNameCache for names
        for _, pawn in pairs(allPawns) do
            if not SafeIsValid(pawn) or pawn == localPawn then goto continue end
            local hs = pawn.HealthStatus
            if not (pawn.TeamID and pawn.TeamID ~= myTeamId and hs and hs ~= 2 and hs ~= 3) then goto continue end

            local pKey = pawn.PlayerKey
            if not pKey or pKey == 0 then goto continue end  -- Skip if no valid PlayerKey
            local isAI = ResolveIsAI(pKey, pawn)  -- [OPT-P2] Centralized AI helper

            local okPP, pPos = SafeMethodCall(pawn, "K2_GetActorLocation")
            local distSq = 0
            if okPP and pPos and myPos then
                local dx = pPos.X - myPos.X
                local dy = pPos.Y - myPos.Y
                local dz = pPos.Z - myPos.Z
                distSq = dx * dx + dy * dy + dz * dz
            end
            local isWithin400m = (distSq > 0 and distSq <= 1600000000)
            if not isWithin400m then goto continue end

            local maxHP = tonumber(pawn.HealthMax or pawn.MaxHealth) or 100
            local currentHP = tonumber(pawn.Health) or 0
            if maxHP <= 0 then maxHP = 100 end
            local hpPercent = currentHP / maxHP
            if hpPercent < 0 then hpPercent = 0 elseif hpPercent > 1 then hpPercent = 1 end
            local hpPct = math.floor(hpPercent * 100)
            local distM = math.floor(math.sqrt(distSq) / 100)

            local textColor
            local espText
            if isAI then
                textColor = GetColorTable(_G.LexusConfig.ColorBotText or 1)
                espText = "BOT\n" .. hpPct .. "%"
            else
                textColor = GetColorTable(_G.LexusConfig.ColorEnemyText or 0)
                local eName = GetEnemyName(pawn)  -- Use EnemyNameCache
                espText = eName .. "\n" .. hpPct .. "%"
            end

            SafeMethodCall(hud, "AddDebugText", espText, pawn, 3.5, TEXT_OFFSET, TEXT_OFFSET, textColor, false, false, true, nil, eScale, true)
            ::continue::
        end
    end

    local function Tick_MapESP()
        if not (_G.LexusConfig and _G.LexusConfig.MapESPEnabled) then return end
        local localPawn, myPos, hud, pc, myTeamId = GetFrameCache()
        if not localPawn then return end
        local okPawns, allPawns = GetCachedPlayerPawns()
        if not okPawns or not allPawns then return end

        if not _G.ESP_ACTIVE_PAWNS then _G.ESP_ACTIVE_PAWNS = {} end
        local activePawns = _G.ESP_ACTIVE_PAWNS
        -- Reuse the table; clear only existing keys to avoid allocations.
        for k in pairs(activePawns) do activePawns[k] = nil end
        local maxESP = math.max(1, tonumber((_G.LexusConfig and _G.LexusConfig.MaxESP) or 60) or 60)
        local espCount = 0
        for _, pawn in pairs(allPawns) do
            if SafeIsValid(pawn) and pawn ~= localPawn then
                local hs = pawn.HealthStatus
                if pawn.TeamID and pawn.TeamID ~= myTeamId and hs and hs ~= 2 and hs ~= 3 then
                    local pKey = pawn.PlayerKey
                    if pKey and pKey ~= 0 then
                        activePawns[pKey] = true
                        espCount = espCount + 1
                        if espCount >= maxESP then break end
                    end
                end
            end
        end

        for pKey, markData in pairs(_G.AK_Map_Marks) do
            local p = markData.actor
            local isDead = false
            if not SafeIsValid(p) then isDead = true
            elseif not activePawns[pKey] then isDead = true
            else
                if p.bIsDead or p.bDead or p.bIsDying then isDead = true end
                if not p.Health or p.Health <= 0 then isDead = true end
            end
            if isDead then
                if InGameMarkTools then
                    if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(markData.markId) end
                    if InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(markData.markId) end
                end
                _G.AK_Map_Marks[pKey] = nil
            end
        end

        for _, pawn in pairs(allPawns) do
            if not SafeIsValid(pawn) or pawn == localPawn then goto continue end
            local hs = pawn.HealthStatus
            if not (pawn.TeamID and pawn.TeamID ~= myTeamId and hs and hs ~= 2 and hs ~= 3) then goto continue end

            local pKey = pawn.PlayerKey
            if not pKey or pKey == 0 then goto continue end  -- Skip if no valid PlayerKey
            local isAI = ResolveIsAI(pKey, pawn)  -- [OPT-P2] Centralized AI helper

            local okPP, pPos = SafeMethodCall(pawn, "K2_GetActorLocation")
            local distSq = 0
            if okPP and pPos and myPos then
                local dx = pPos.X - myPos.X
                local dy = pPos.Y - myPos.Y
                local dz = pPos.Z - myPos.Z
                distSq = dx * dx + dy * dy + dz * dz
            end
            local isWithin400m = (distSq > 0 and distSq <= 1600000000)
            if not isWithin400m then goto continue end

            if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
                local mKey = pKey or tostring(pawn)
                if activePawns[mKey] and not _G.AK_Map_Marks[mKey] and InGameMarkTools.ClientAddMapMark then
                    if not ZERO_VECTOR then ZERO_VECTOR = FVector(0,0,0) end
                    local okMark, mId = pcall(InGameMarkTools.ClientAddMapMark, 9999, ZERO_VECTOR, 0, "", 4, pawn)
                    if okMark and mId then _G.AK_Map_Marks[mKey] = { actor = pawn, markId = mId } end
                end
            end
            ::continue::
        end
    end

    local function Tick_CounterESP()
        if not (_G.LexusConfig and _G.LexusConfig.EnemyCounterEnabled) then return end
        local localPawn, myPos, hud, pc, myTeamId = GetFrameCache()
        if not localPawn then return end
        local okPawns, allPawns = GetCachedPlayerPawns()
        if not okPawns or not allPawns then return end

        local enemyCount = 0
        local botCount = 0
        local countDistSq = 1600000000 -- 400m

        for _, pawn in pairs(allPawns) do
            if not SafeIsValid(pawn) or pawn == localPawn then goto continue end
            local hs = pawn.HealthStatus
            if not (pawn.TeamID and pawn.TeamID ~= myTeamId and hs and hs ~= 2 and hs ~= 3) then goto continue end

            local pKey = pawn.PlayerKey
            if not pKey or pKey == 0 then goto continue end  -- Skip if no valid PlayerKey
            local isAI = ResolveIsAI(pKey, pawn)  -- [OPT-P2] Centralized AI helper

            local okPP, pPos = SafeMethodCall(pawn, "K2_GetActorLocation")
            local distSq = 0
            if okPP and pPos and myPos then
                local dx = pPos.X - myPos.X
                local dy = pPos.Y - myPos.Y
                local dz = pPos.Z - myPos.Z
                distSq = dx * dx + dy * dy + dz * dz
            end
            if distSq > 0 and distSq <= 1600000000 then
                if isAI then botCount = botCount + 1 else enemyCount = enemyCount + 1 end
            end
            ::continue::
        end

        if _G.LexusConfig.EnemyCounterEnabled then
            GK_UpdateWidget(enemyCount, botCount)
        else
            if _G.GK_WIDGET and SafeIsValid(_G.GK_WIDGET) then
                pcall(function() _G.GK_WIDGET:SetWidgetVisibility(import("ESlateVisibility").Collapsed) end)
            end
        end
    end-- ============================================================================
    -- SEPARATE WALLHACK TICK (Optimized: adaptive interval, on-demand mesh resolution, no pcall in hot path)
    -- ============================================================================
    local _WallhackTickTime = 0
    local _WallhackInterval = 0.8
    local function Tick_Wallhack()
        if not (_G.LexusConfig and _G.LexusConfig.WallhackEnabled) then return end
        local now = os.clock()
        if now - _WallhackTickTime < _WallhackInterval then return end
        _WallhackTickTime = now

        local localPawn, myPos, hud, pc, myTeamId = GetFrameCache()
        if not localPawn or not myPos then return end

        local okPawns, allPawns = GetCachedPlayerPawns()
        if not okPawns or not allPawns then return end

        _G.LexusState = _G.LexusState or {}
        _G.LexusState.EnemyMarks = _G.LexusState.EnemyMarks or {}

        local maxESP = (_G.LexusConfig and _G.LexusConfig.MaxESP) or 60
        local processed = 0
        for _, pawn in pairs(allPawns) do
            if not SafeIsValid(pawn) or pawn == localPawn then goto continue end

            -- 1. Teammate Check (Only skip real teammates in team modes)
            local pTeam = pawn.TeamID or (type(pawn.GetTeamID) == "function" and pawn:GetTeamID())
            if myTeamId and myTeamId > 0 and pTeam and pTeam > 0 and pTeam == myTeamId then goto continue end

            -- 2. Dead Check (Only skip finished/dead players, NEVER skip knocked/groggy players)
            local hs = pawn.HealthStatus
            if hs == 3 then goto continue end
            if pawn.bIsDead or pawn.bDead or (pawn.Health and pawn.Health <= 0 and hs ~= 2) then goto continue end

            -- 3. Bot Identification & Fallback Key
            local pKey = pawn.PlayerKey
            local eKey = (pKey and pKey ~= 0) and pKey or pawn
            local isAI = ResolveIsAI(pKey, pawn)

            -- 4. Distance Calculation (up to 500m)
            local okPP, pPos = SafeMethodCall(pawn, "K2_GetActorLocation")
            if not (okPP and pPos) then goto continue end

            local dx = pPos.X - myPos.X
            local dy = pPos.Y - myPos.Y
            local dz = pPos.Z - myPos.Z
            local distSq = dx * dx + dy * dy + dz * dz
            local isWithin500m = (distSq > 0 and distSq <= 2500000000)

            _G.LexusState.EnemyMarks[eKey] = _G.LexusState.EnemyMarks[eKey] or { enemy = pawn }
            local markData = _G.LexusState.EnemyMarks[eKey]
            markData.enemy = pawn
            markData.AK_IS_BOT = isAI

            if isWithin500m then
                ApplyColorBodyNew(pawn, markData)
            else
                UndoColorBodyNew(pawn, markData)
            end

            processed = processed + 1
            if processed >= maxESP then break end
            ::continue::
        end
    end
    local function Tick_Vehicles()
        if not (_G.LexusConfig and _G.LexusConfig.VehicleESPEnabled) then return end
        local localPawn, myPos, hud, pc = GetESPState()
        if not localPawn or not SafeIsValid(hud) or not myPos then return end

        local now = NowSeconds()
        if now - VEH_CACHE_TIME > VEH_CACHE_TTL then 
            VEH_CACHE_TIME = now
            local okVeh, vehicles = SafeMethodCall(Game, "GetAllVehicles")
            VEH_CACHE = okVeh and vehicles or {} 
        end

        local sliderVeh = _G.LexusConfig.TextSizeVehUI or 50
        local vScale = 0.83 + (sliderVeh / 100.0) * 0.14
        local vCol = GetColorTable(_G.LexusConfig.ColorVehicle or 5)

        for _, veh in pairs(VEH_CACHE) do
            if SafeIsValid(veh) then
                local okVP, vPos = SafeMethodCall(veh, "K2_GetActorLocation")
                if okVP and vPos then 
                    local dx = vPos.X - myPos.X
                    local dy = vPos.Y - myPos.Y
                    local dz = vPos.Z - myPos.Z
                    local distSq = dx * dx + dy * dy + dz * dz
                    if distSq <= 1600000000 then -- 400m
                        local vName, cfgKey = GetVehicleNameAndKey(veh)
                        local isEnabled = _G.LexusConfig[cfgKey]
                        if isEnabled == nil then isEnabled = false end

                        if isEnabled then
                            local vDist = math.floor(math.sqrt(distSq) / 100)
                            local txt = vName .. " | " .. vDist .. "m"
                            -- Duration: 3.5s with 3.0s timer = ZERO BLINK
                            SafeMethodCall(hud, "AddDebugText", txt, veh, 4.5, VEH_OFFSET, VEH_OFFSET, vCol, false, false, true, nil, vScale, true)
                        end
                    end
                end
            end
        end
    end

    -- ============================================================================
    -- BOX ESP (v13-style): Enemy Frame UI + Text Health Bar + Info Text
    -- ============================================================================
    local _BoxESPCache = setmetatable({}, { __mode = "k" })  -- weak-keyed cache for frame state
    local _BoxActivePawns = {}

    -- [FPS OPT] Pre-create color/offset objects & HP bar strings at module level (zero string churn)
    local _BOX_C_WHITE = FLinearColor and FLinearColor(1, 1, 1, 1) or LinearColor(1, 1, 1, 1)
    local _BOX_C_CYAN = FLinearColor and FLinearColor(0, 1, 1, 1) or LinearColor(0, 1, 1, 1)
    local _BOX_C_YELLOW = FLinearColor and FLinearColor(1, 1, 0, 1) or LinearColor(1, 1, 0, 1)
    local _BOX_C_HP_GREEN = FLinearColor and FLinearColor(0, 1, 0, 0.95) or LinearColor(0, 1, 0, 0.95)
    local _BOX_C_HP_YELLOW = FLinearColor and FLinearColor(1, 1, 0, 0.95) or LinearColor(1, 1, 0, 0.95)
    local _BOX_C_HP_RED = FLinearColor and FLinearColor(1, 0, 0, 0.95) or LinearColor(1, 0, 0, 0.95)
    local _BOX_C_FRAME_RED = FLinearColor and FLinearColor(1, 0, 0, 1) or LinearColor(1, 0, 0, 1)
    local _BOX_OFF_NAME = {X=0, Y=0, Z=-370}
    local _BOX_OFF_HP = {X=0, Y=0, Z=-250}
    local _BOX_OFF_DIST = {X=0, Y=115, Z=20}
    local _BOX_OFF_STATE = {X=0, Y=0, Z=100}

    local _HP_BAR_STRINGS = {}
    for hpPct = 0, 100 do
        local hp = hpPct / 100.0
        local barTotal = 10
        local barFilled = math.floor(hp * barTotal + 0.5)
        local barEmpty = barTotal - barFilled
        _HP_BAR_STRINGS[hpPct] = string.rep("\xe2\x96\x88", barFilled) .. string.rep("\xe2\x96\x91", barEmpty) .. " " .. hpPct .. "%"
    end

    local function SetBoxFrameColor(pawn)
        if not SafeIsValid(pawn) then return end
        pcall(function()
            if pawn.Replay_SetFrameUIColor then pawn:Replay_SetFrameUIColor(_BOX_C_FRAME_RED)
            elseif pawn.SetEnemyFrameColor then pawn:SetEnemyFrameColor(_BOX_C_FRAME_RED)
            elseif pawn.SetFrameColor then pawn:SetFrameColor(_BOX_C_FRAME_RED)
            elseif pawn.SetOutlineColor then pawn:SetOutlineColor(_BOX_C_FRAME_RED) end
        end)
    end


    local function Tick_BoxESP()
        if not (_G.LexusConfig and _G.LexusConfig.BoxESPEnabled) then
            -- Cleanup: hide all frames when disabled
            for pawn, _ in pairs(_BoxESPCache) do
                pcall(function()
                    if SafeIsValid(pawn) and pawn.Replay_SetVisiableOfFrameUI then
                        pawn:Replay_SetVisiableOfFrameUI(false)
                    end
                end)
            end
            _BoxESPCache = setmetatable({}, { __mode = "k" })
            return
        end

        local localPawn, myPos, hud, pc, myTeamId = GetFrameCache()
        if not localPawn or not myPos then return end

        local okPawns, allPawns = GetCachedPlayerPawns()
        if not okPawns or not allPawns then return end

        -- Reuse active table (zero allocations)
        for k in pairs(_BoxActivePawns) do _BoxActivePawns[k] = nil end

        for _, pawn in pairs(allPawns) do
            if not SafeIsValid(pawn) or pawn == localPawn then goto continue end
            local hs = pawn.HealthStatus
            if not (pawn.TeamID and pawn.TeamID ~= myTeamId and hs and hs ~= 2 and hs ~= 3) then goto continue end

            local okPP, pPos = SafeMethodCall(pawn, "K2_GetActorLocation")
            if not (okPP and pPos) then goto continue end

            local dx = pPos.X - myPos.X
            local dy = pPos.Y - myPos.Y
            local dz = pPos.Z - myPos.Z
            local distSq = dx * dx + dy * dy + dz * dz
            if distSq <= 0 or distSq > 900000000 then goto continue end  -- 300m max

            local dist = math.sqrt(distSq)
            _BoxActivePawns[pawn] = true

            -- 1) Create/show enemy frame UI (the box outline around the enemy)
            pcall(function()
                if pawn.Replay_CreateEnemyFrameUI then
                    pawn:Replay_CreateEnemyFrameUI(true, true)
                end
                SetBoxFrameColor(pawn)
                if pawn.Replay_SetVisiableOfFrameUI then
                    pawn:Replay_SetVisiableOfFrameUI(true)
                end
                if pawn.SetPlayerNameVisible then
                    pawn:SetPlayerNameVisible(true)
                end
            end)
            _BoxESPCache[pawn] = true

            -- 2) Text HP Bar + Info text via AddDebugText
            if hud and dist < 25000 then
                pcall(function()
                    local pKey = pawn.PlayerKey
                    local isAI = ResolveIsAI(pKey, pawn)  -- [OPT-P2] Centralized AI helper
                    local dynamicScale = math.max(0.5, 0.8 - (dist / 40000))
                    local distM = math.floor(dist / 100)

                    -- HP calculation with pre-generated text bar lookup
                    local maxHP = pawn.HealthMax or pawn.MaxHealth or 100
                    if maxHP <= 0 then maxHP = 100 end
                    local rawHp = (pawn.Health or 100) / maxHP
                    local hpPct = math.max(0, math.min(100, math.floor(rawHp * 100)))
                    local hpText = _HP_BAR_STRINGS[hpPct] or (hpPct .. "%")
                    local hpColor = hpPct < 30 and _BOX_C_HP_RED or (hpPct < 60 and _BOX_C_HP_YELLOW or _BOX_C_HP_GREEN)

                    -- Pose/state detection
                    local stateText = "Standing"
                    pcall(function()
                        local pose = pawn.PoseState or (pawn.GetPoseState and pawn:GetPoseState())
                        if pose == 0 or pose == "Stand" then stateText = "Standing"
                        elseif pose == 1 or pose == "Crouch" then stateText = "Crouching"
                        elseif pose == 2 or pose == "Prone" then stateText = "Prone" end
                    end)

                    local enemyName = isAI and "BOT" or GetEnemyName(pawn)
                    local textColor = isAI and _BOX_C_CYAN or _BOX_C_YELLOW

                    -- Pre-created offset tables
                    local boxCombined = enemyName .. "\n" .. hpText .. "\n[" .. distM .. "m] " .. stateText
                    SafeMethodCall(hud, "AddDebugText", boxCombined, pawn, 5.5, _BOX_OFF_NAME, _BOX_OFF_NAME, _BOX_C_WHITE, true, false, true, nil, dynamicScale, true)
                end)
            end

            ::continue::
        end

        -- Cleanup: hide frame for pawns no longer active
        for pawn, _ in pairs(_BoxESPCache) do
            if not _BoxActivePawns[pawn] then
                pcall(function()
                    if SafeIsValid(pawn) and pawn.Replay_SetVisiableOfFrameUI then
                        pawn:Replay_SetVisiableOfFrameUI(false)
                    end
                end)
                _BoxESPCache[pawn] = nil
            end
        end
    end

    local function CleanupESP(pc)
        PBC_ENABLED = false
        if pc and type(ClearModTimers) == "function" then ClearModTimers(pc) end
        if TimerManager and type(TimerManager.ClearAllForOwner) == "function" then
            if _G.Game then TimerManager:ClearAllForOwner(_G.Game) end
            if pc then TimerManager:ClearAllForOwner(pc) end
        end
        AI_CACHE = {}; AI_CACHE_SIZE = 0; PBC_RUNNING = false; retryCount = 0; PBC_MATCH_TOKEN = nil; PBC_TICK_FAILURES = 0; MAP_INIT_DONE = false; InvalidatePawnCache()
        SnaplineESP.ClearAllSnapLines(); SnaplineESP.ESPCanvas = nil
        if _G.AK_Map_Marks then for _, md in pairs(_G.AK_Map_Marks) do if md and md.markId and InGameMarkTools then pcall(function() if InGameMarkTools.ClientRemoveMapMark then InGameMarkTools.ClientRemoveMapMark(md.markId) end; if InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(md.markId) end end) end end end
        _G.AK_Map_Marks = {}; VEH_CACHE = {}; VEH_CACHE_TIME = 0; _G.POS_CACHE = {}; if GK_DestroyWidget then GK_DestroyWidget() end
        if _G.LexusState and _G.LexusState.EnemyMarks then
            for _, md in pairs(_G.LexusState.EnemyMarks) do
                if md and md.enemy and UndoColorBodyNew then UndoColorBodyNew(md.enemy, md) end
            end
            _G.LexusState.EnemyMarks = {}
        end
        _G.VisualsStarted = false
    end

    -- Visual timers: start/stop independently (controlled by mod menu)

    local function StartVisuals(force)
        -- force=true: always recreate timers (next match recovery)
        if _G.VisualsStarted and not force then
            -- if timers still tracked, keep; else fall through and rebuild
            if _G.VisualTimerIds and #_G.VisualTimerIds > 0 then return true end
        end
        -- clear any stale timers before rebuild
        pcall(function()
            if _G.VisualTimerIds and TimerManager then
                for _, tid in ipairs(_G.VisualTimerIds) do
                    pcall(function() TimerManager:Clear(tid) end)
                end
            end
            _G.VisualTimerIds = nil
            if TimerManager and type(TimerManager.PurgeDeadTimers) == "function" then
                TimerManager:PurgeDeadTimers()
            end
        end)
        _G.VisualsStarted = false
        if GK_DestroyWidget then GK_DestroyWidget() end; VEH_CACHE = {}; VEH_CACHE_TIME = 0; SetupConsole()
        local timerOwner = nil
        if _G.Game and _G.Game.AddGameTimer then timerOwner = _G.Game
        else
            local pc2 = nil; if slua_GameFrontendHUD then local okPc, retPc = SafeMethodCall(slua_GameFrontendHUD, "GetPlayerController"); if okPc then pc2 = retPc end end
            if SafeIsValid(pc2) and pc2.AddGameTimer then timerOwner = pc2 end
        end
        if timerOwner and TimerManager then
            local specs = {
                {"ESP_HealthBar", 3.0, "HealthBar", Tick_HealthBarESP},
                {"ESP_Map", 5.0, "MapESP", Tick_MapESP},
                {"ESP_Counter", 3.0, "Counter", Tick_CounterESP},
                {"ESP_Wallhack", 0.8, "Wallhack", Tick_Wallhack},
                {"ESP_Items", 15.0, "ItemESP", _G.Tick_SDW_ItemESP},
                {"ESP_Bombs", 2.0, "BombESP", _G.Tick_SDW_BombESP},
                {"ESP_Vehicles", 4.0, "VehicleESP", Tick_Vehicles},
                {"ESP_Box", 5.0, "BoxESP", Tick_BoxESP},
                {"ESP_Snapline", 0.1, "Snapline", Tick_SnaplineESP},
            }
            local created = {}
            for _, spec in ipairs(specs) do
                local id = TimerManager:Register(timerOwner, spec[1], spec[2], true, spec[3], spec[4])
                if not id then
                    for _, createdId in ipairs(created) do pcall(function() TimerManager:Clear(createdId) end) end
                    _G.VisualTimerIds = nil
                    _G.VisualsStarted = false
                    return false
                end
                created[#created + 1] = id
            end
            _G.VisualTimerIds = created
            _G.VisualsStarted = true
            -- [FIX ESP-3] Watchdog timer: auto-restarts ESP if all timers silently die
            pcall(function()
                TimerManager:Register(timerOwner, "ESP_Watchdog", 30.0, true, "Diagnostic", function()  -- [OPT-P5c] 15s->30s
                    if not _G.VisualsStarted then return end
                    if not _G.VisualTimerIds then return end
                    -- Check if ANY ESP timer is still tracked
                    local anyAlive = false
                    for _, tid in ipairs(_G.VisualTimerIds) do
                        if TimerManager._byId[tid] then anyAlive = true; break end
                    end
                    if not anyAlive then
                        _G.VisualsStarted = false
                        _G.VisualTimerIds = nil
                        -- Will be restarted by MainLoop / StartPBC on next cycle
                    end
                end)
            end)
            return true
        end
        return false
    end

    local function StopVisuals()
        pcall(function()
            if _G.VisualTimerIds and TimerManager then
                for _, id in ipairs(_G.VisualTimerIds) do pcall(function() TimerManager:Clear(id) end) end
            end
            SnaplineESP.Clear()
            SnaplineESP.ESPCanvas = nil
            _G.VisualTimerIds = nil
            _G.VisualsStarted = false
            if _G.LexusState and _G.LexusState.EnemyMarks then
                for _, md in pairs(_G.LexusState.EnemyMarks) do
                    if md and md.enemy and UndoColorBodyNew then UndoColorBodyNew(md.enemy, md) end
                end
                _G.LexusState.EnemyMarks = {}
            end
        end)
    end

    local function StartPBC()
        if _G._MOD_EXPIRED then return false end
        if PBC_ENABLED then return true end
        -- Anti-cheat bypass system removed. Start the visual/performance feature normally.
        PBC_ENABLED = true
        StartVisuals()
        return PBC_ENABLED
    end

    local _RETRY_TIMER_ACTIVE = false
    local _RETRY_GENERATION = 0
    local function RetryStart()
        if retryCount >= 30 or _RETRY_TIMER_ACTIVE then return end
        retryCount = retryCount + 1
        local generation = _RETRY_GENERATION
        if StartPBC() then
            _RETRY_TIMER_ACTIVE = false
            return
        end
        if _G.Game and _G.Game.AddGameTimer then
            _RETRY_TIMER_ACTIVE = true
            pcall(_G.Game.AddGameTimer, _G.Game, 5.0, false, function()
                _RETRY_TIMER_ACTIVE = false
                if generation ~= _RETRY_GENERATION then return end
                RetryStart()
            end)
        end
    end

    -- ============================================================================

    _G.StartVisuals = StartVisuals
    _G.StopVisuals = StopVisuals
    _G.StartPBC = StartPBC
    _G.CleanupESP = CleanupESP
    _G.SnaplineESP = SnaplineESP
    _G.Tick_SnaplineESP = Tick_SnaplineESP
    _G.Tick_HealthBarESP = Tick_HealthBarESP
    _G.Tick_MapESP = Tick_MapESP
    _G.Tick_CounterESP = Tick_CounterESP
    _G.Tick_Wallhack = Tick_Wallhack
    _G.Tick_Vehicles = Tick_Vehicles
    _G.Tick_BoxESP = Tick_BoxESP
    _G.Tick_SDW_ItemESP = _G.Tick_SDW_ItemESP
    _G.Tick_SDW_BombESP = _G.Tick_SDW_BombESP
    _G.GK_DestroyWidget = GK_DestroyWidget
    _G.GK_GetOrCreateWidget = GK_GetOrCreateWidget
    _G.GK_UpdateWidget = GK_UpdateWidget
    _G.ApplyColorBodyNew = ApplyColorBodyNew
    _G.UndoColorBodyNew = UndoColorBodyNew
    _G.SetupConsole = SetupConsole
    -- [FIX SCOPE] Cross-scope accessors for CleanupMatchState (S16 block)
    -- These locals live in this do..end block but CleanupMatchState needs to reset them between matches
    _G._GK_RETRY_GENERATION = { get = function() return _RETRY_GENERATION end, set = function(v) _RETRY_GENERATION = v end }
    _G._GK_RETRY_TIMER_ACTIVE = { get = function() return _RETRY_TIMER_ACTIVE end, set = function(v) _RETRY_TIMER_ACTIVE = v end }
    _G._GK_retryCount = { get = function() return retryCount end, set = function(v) retryCount = v end }
    _G._GK_AI_CACHE = { reset = function() AI_CACHE = {}; AI_CACHE_SIZE = 0 end }
    _G._GK_VEH_CACHE = { reset = function() VEH_CACHE = {}; VEH_CACHE_TIME = 0 end }
    _G._GK_MAP_INIT_DONE = { set = function(v) MAP_INIT_DONE = v end }
    _G._GK_PBC_MATCH_TOKEN = { set = function(v) PBC_MATCH_TOKEN = v end }
    _G._GK_PBC_TICK_FAILURES = { set = function(v) PBC_TICK_FAILURES = v end }
    _G._GK_PBC_RUNNING = { set = function(v) PBC_RUNNING = v end }
    _G.InvalidatePawnCache = InvalidatePawnCache
    _G.RetryStart = RetryStart
end

-- S13C  MOD SKIN SYSTEM (Data, Logic, Attachments, Kill Counter & Avatars)
-- ============================================================================

do
    _G.VIP_Attachments = {
        [1101004236]={1010042307,1010042306,1010042308,1010042304,1010042300,1010042305,1010042299,1010042298,1010042297,1010042296,1010042295,1010042294,0,1010042314,1010042309,1010042316,1010042317,1010042318,1010042310,1010042315,1010042319,0},
        [1101001116]={1010011106,1010011107,1010011108,0,1010011109,1010011112,1010011105,1010011104,1010011103,0,1010011102,0,0,0,0,0,0,0,0,0,0,0},
        [1101001128]={1010011232,1010011233,1010011234,1010011228,1010011227,1010011229,1010011226,1010011225,1010011224,1010011223,1010011222,0,0,0,0,0,0,0,0,0,0,0},
        [1101001154]={1010011487,1010011488,1010011489,1010011493,1010011490,1010011494,1010011486,1010011485,1010011484,1010011483,1010011482,1010011497,0,0,0,0,0,0,0,0,1010011498,0},
        [1101001174]={1010011667,1010011668,1010011669,1010011673,1010011670,1010011674,1010011666,1010011665,1010011664,1010011663,1010011662,0,0,0,0,0,0,0,0,0,0,0},
        [1101001213]={1010012067,1010012068,1010012069,1010012072,1010012070,1010012073,1010012066,1010012065,1010012064,1010012063,1010012062,0,0,0,0,0,0,0,0,1010012074,0},
        [1101001231]={1010012267,1010012268,1010012269,1010012273,1010012272,1010012274,1010012266,1010012265,1010012264,1010012263,1010012262,1010012075,0,0,0,0,0,0,0,0,1010012275,0},
        [1101001242]={1010012357,1010012358,1010012359,1010012363,1010012362,1010012364,1010012356,1010012355,1010012354,1010012353,1010012352,1010012276,0,0,0,0,0,0,0,0,1010012365,0},
        [1101001249]={1010012437,1010012438,1010012439,1010012443,1010012442,1010012444,1010012436,1010012435,1010012434,1010012433,1010012432,1010012366,0,0,0,0,0,0,0,0,1010012445,0},
        [1101001256]={1010012588,1010012589,1010012590,1010012593,1010012592,1010012594,1010012587,1010012586,1010012585,1010012584,1010012583,1010012582,0,0,0,0,0,0,0,0,1010012595,0},
        [1101001265]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
        [1101001276]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
        [1101002029]={1010020249,1010020250,1010020255,1010020247,1010020246,1010020248,1010020240,1010020239,1010020238,1010020237,1010020236,1010020235,0,0,0,0,0,0,0,1010020257,1010020256,1010020258},
        [1101002056]={1010020519,0,0,1010020517,1010020516,1010020518,1010020500,1010020509,1010020508,1010020507,1010020506,1010020505,0,0,0,0,0,0,0,0,0,0},
        [1101002081]={1010020768,1010020769,1010020770,1010020766,1010020760,1010020767,1010020759,1010020758,1010020757,1010020756,1010020755,1010020776,0,0,0,0,0,0,0,1010020775,1010020777,1010020778},
        [1101003070]={1010030654,1010030653,1010030655,1010030649,1010030648,1010030650,1010030647,1010030646,1010030645,1010030644,1010030643,1010030642,0,1010030658,1010030656,1010030660,1010030662,1010030659,1010030657,0,1010030663,0},
        [1101003080]={1010030754,1010030753,1010030755,1010030749,1010030748,1010030750,1010030747,1010030746,1010030745,1010030744,1010030743,1010030742,0,1010030758,1010030756,1010030760,1010030762,1010030759,1010030757,0,1010030763,0},
        [1101003099]={1010030943,1010030944,1010030945,1010030939,1010030938,1010030942,1010030937,1010030936,1010030935,1010030934,1010030933,1010030932,0,1010030947,1010030946,1010030948,1010030949,1010030953,1010030952,0,1010030955,0},
        [1101003119]={1010031139,1010031140,1010031142,1010031138,1010031137,1010031146,1010031136,1010031135,1010031134,1010031133,1010031132,0,0,1010031144,1010031143,0,0,0,1010031145,0,0,0},
        [1101003146]={1010031229,1010031230,1010031237,1010031228,1010031227,1010031242,1010031226,1010031225,1010031224,1010031223,1010031222,0,0,1010031239,1010031238,0,0,0,1010031240,0,0,0},
        [1101003167]={1010031609,1010031610,1010031613,1010031608,1010031607,1010031617,1010031606,1010031605,1010031604,1010031603,1010031602,1010031618,0,1010031615,1010031614,1010031620,1010031622,1010031619,1010031616,0,1010031623,0},
        [1101003181]={1010031765,1010031764,1010031766,1010031759,1010031758,1010031763,1010031757,1010031756,1010031755,1010031754,1010031753,1010031752,0,1010031769,1010031767,1010031773,1010031774,1010031772,1010031768,0,1010031775,0},
        [1101003195]={1010031912,1010031911,1010031913,1010031908,1010031907,1010031909,1010031906,1010031905,1010031904,1010031903,1010031902,1010031901,0,1010031916,1010031914,1010031918,1010031919,1010031917,1010031915,0,1010031921,0},
        [1101003208]={1010032034,1010032033,1010032045,1010032029,1010032028,1010032032,1010032027,1010032026,1010032025,1010032024,1010032023,1010032022,0,1010032038,1010032036,1010032042,1010032043,1010032039,1010032037,0,1010032044,0},
        [1101004046]={1010040474,1010040475,1010040476,1010040472,1010040471,1010040473,1010040470,1010040469,1010040468,1010040467,1010040466,1010040481,0,1010040479,1010040477,1010040482,1010040483,1010040484,1010040478,1010040480,1010040485,0},
        [1101004062]={1010040578,1010040577,1010040579,1010040575,1010040570,1010040576,1010040569,1010040568,1010040567,1010040566,1010040565,1010040564,0,1010040585,1010040580,1010040587,1010040588,1010040589,1010040584,1010040586,1010040590,1010040594},
        [1101004098]={1010040924,1010040926,1010040925,0,1010040937,1010040938,1010040935,1010040934,1010040929,1010040928,1010040927,0,0,1010040939,1010040945,0,0,0,1010040944,1010040936,0,0},
        [1101004138]={1010041136,1010041137,1010041138,1010041134,1010041129,1010041135,1010041128,1010041127,1010041126,1010041125,1010041124,0,0,1010041145,1010041139,0,0,0,1010041144,1010041146,0,0},
        [1101004163]={1010041570,1010041574,1010041575,1010041568,1010041567,1010041569,1010041566,1010041565,1010041564,1010041560,1010041554,0,0,1010041578,1010041576,0,0,0,1010041577,1010041579,0,0},
        [1101004201]={1010041956,1010041957,1010041958,1010041950,1010041949,1010041955,1010041948,1010041947,1010041946,1010041945,1010041944,1010041967,0,1010041965,1010041959,0,0,0,1010041960,1010041966,0,0},
        [1101004209]={1010042038,1010042037,1010042039,1010042035,1010042034,1010042036,1010042029,1010042028,1010042027,1010042026,1010042025,1010042024,0,1010042046,1010042044,1010042048,1010042049,1010042054,1010042045,1010042047,1010042055,0},
        [1101004218]={1010042128,1010042127,1010042129,1010042125,1010042124,1010042126,1010042119,1010042118,1010042117,1010042116,1010042115,1010042114,0,1010042136,1010042134,1010042138,1010042139,1010042144,1010042135,1010042137,1010042145,0},
        [1101004226]={1010042238,1010042237,1010042239,1010042235,1010042234,1010042236,1010042233,1010042232,1010042231,1010042219,1010042218,1010042217,0,1010042243,1010042241,1010042245,1010042246,1010042247,1010042242,1010042244,1010042248,0},
        [1101004246]={1010042406,1010042407,1010042408,1010042404,1010042400,1010042405,1010042399,1010042398,1010042397,1010042396,1010042395,1010042394,0,1010042414,1010042409,1010042416,1010042417,1010042418,1010042410,1010042415,1010042419,1010042420},
        [1101005038]={0,0,1010050327,1010050329,1010050328,1010050330,1010050326,1010050325,1010050324,1010050323,1010050322,1010050334,0,0,0,0,0,0,0,0,0,0},
        [1101005052]={0,0,1010050467,1010050469,1010050468,1010050470,1010050466,1010050465,1010050464,1010050463,1010050462,1010050473,0,0,0,0,0,0,0,0,0,0},
        [1101005098]={0,0,1010050928,1010050930,1010050929,1010050932,1010050927,1010050926,1010050925,1010050924,1010050923,1010050922,0,0,0,0,0,0,0,0,0,0},
        [1101006062]={1010060573,1010060572,1010060574,1010060564,1010060563,1010060571,1010060562,1010060561,1010060554,1010060553,1010060552,1010060551,0,1010060583,1010060581,1010060591,1010060592,1010060584,1010060582,0,1010060593,0},
        [1101006075]={1010060702,1010060701,1010060703,1010060698,1010060697,1010060699,1010060696,1010060695,1010060694,1010060693,1010060692,1010060691,0,1010060706,1010060704,1010060708,1010060709,1010060707,1010060705,0,1010060711,0},
        [1101006085]={1010060796,1010060795,1010060797,1010060793,1010060789,1010060794,1010060788,1010060787,1010060786,1010060785,1010060784,1010060783,0,1010060800,1010060798,1010060804,1010060805,1010060803,1010060799,0,1010060806,0},
        [1101007046]={1010070410,1010070413,1010070414,1010070408,1010070407,1010070409,1010070406,1010070405,1010070404,1010070403,1010070402,1010070418,0,1010070417,1010070415,1010070420,1010070422,1010070419,1010070416,0,1010070423,0},
        [1101007062]={1010070579,1010070578,1010070581,1010070576,1010070575,1010070577,1010070574,1010070573,1010070572,1010070571,1010070569,1010070568,0,1010070584,1010070582,1010070585,1010070586,1010070587,1010070583,0,1010070588,0},
        [1101007071]={1010070663,1010070662,1010070664,1010070659,1010070658,1010070660,1010070657,1010070656,1010070655,1010070654,1010070653,1010070652,0,1010070667,1010070665,1010070668,1010070669,1010070670,1010070666,0,1010070672,0},
        [1101008051]={1010080463,1010080464,1010080465,1010080459,1010080458,1010080462,1010080457,1010080456,1010080455,1010080454,1010080453,1010080452,0,1010080467,1010080466,1010080468,1010080469,1010080473,1010080472,0,1010080475,0},
        [1101008061]={1010080563,1010080564,1010080565,1010080559,1010080558,1010080562,1010080557,1010080556,1010080555,1010080554,1010080553,0,0,1010080567,1010080566,0,0,0,1010080572,0,0,0},
        [1101008070]={1010080609,1010080612,1010080613,1010080608,1010080607,1010080617,1010080606,1010080605,1010080604,1010080603,1010080602,0,0,1010080615,1010080614,0,0,0,1010080616,0,0,0},
        [1101008081]={1010080740,1010080743,1010080745,1010080738,1010080737,1010080739,1010080736,1010080735,1010080734,1010080733,1010080732,1010080748,0,1010080747,1010080746,1010080750,1010080752,1010080749,1010080744,0,1010080753,0},
        [1101008104]={1010080980,1010080982,1010080984,1010080978,1010080977,1010080979,1010080976,1010080975,1010080974,1010080973,1010080972,1010080992,0,1010080986,1010080985,1010080989,1010080987,1010080993,1010080983,0,1010080988,0},
        [1101008116]={1010081110,1010081112,1010081114,1010081108,1010081107,1010081109,1010081106,1010081105,1010081104,1010081103,1010081102,0,0,1010081116,1010081115,0,0,0,1010081113,0,0,0},
        [1101008126]={1010081210,1010081225,1010081226,1010081208,1010081207,1010081209,1010081206,1010081205,1010081204,1010081203,1010081202,1010081218,0,1010081217,1010081216,1010081219,1010081220,1010081222,1010081214,1010081228,1010081227,1010081229},
        [1101008136]={1010081314,1010081315,1010081316,1010081312,1010081308,1010081313,1010081307,1010081306,1010081305,1010081304,1010081303,1010081302,0,1010081318,1010081317,1010081322,1010081323,1010081325,1010081324,0,1010081326,0},
        [1101008146]={1010081401,1010081402,1010081403,1010081398,1010081397,1010081399,1010081396,1010081395,1010081394,1010081393,1010081392,1010081391,0,1010081405,1010081404,1010081406,1010081407,1010081409,1010081408,0,1010081411,0},
        [1101008154]={1010081531,1010081532,1010081533,1010081528,1010081527,1010081529,1010081526,1010081525,1010081524,1010081523,1010081522,1010081521,0,1010081541,1010081534,1010081542,1010081543,1010081545,1010081544,0,1010081546,0},
        [1101008163]={1010081582,1010081583,1010081584,1010081579,1010081578,1010081580,1010081577,1010081576,1010081575,1010081574,1010081573,1010081572,0,1010081586,1010081585,1010081587,1010081588,1010081590,1010081589,0,1010081592,0},
        [1101012033]={1010120284,1010120285,1010120286,1010120280,1010120279,1010120283,1010120278,1010120277,1010120276,1010120275,1010120274,1010120273,0,0,0,0,0,0,0,0,1010120287,0},
        [1101100012]={1011000066,1011000067,1011000068,0,0,0,1011000058,1011000057,1011000056,1011000055,1011000054,1011000053,0,0,0,0,0,0,0,0,1011000073,0},
        [1101102007]={1011010025,1011010024,1011010026,1011010020,1011010019,1011010023,1011010018,1011010017,1011010016,1011010015,1011010014,1011010013,0,0,0,0,0,0,0,0,1011010027,0},
        [1101102017]={1011020027,1011020028,1011020029,1011020025,1011020024,1011020026,1011020019,1011020018,1011020017,1011020016,1011020015,1011020014,0,1011020036,1011020034,1011020038,1011020039,1011020044,1011020035,1011020037,1011020045,1011020047},
        [1101102025]={1011020127,1011020128,1011020129,1011020125,1011020124,1011020126,1011020119,1011020118,1011020117,1011020116,1011020115,1011020114,0,1011020136,1011020134,1011020138,1011020139,1011020144,1011020135,1011020137,1011020145,0},
        [1101102041]={1011020214,1011020215,1011020216,1011020212,1011020211,1011020213,1011020209,1011020208,1011020207,1011020206,1011020205,1011020204,0,1011020219,1011020217,1011020222,1011020223,1011020224,1011020218,1011020221,1011020225,1011020229},
        [1101102049]={1011020356,1011020357,1011020358,1011020354,1011020350,1011020355,1011020349,1011020348,1011020347,1011020346,1011020345,1011020344,0,1011020364,1011020359,1011020366,1011020367,1011020368,1011020360,1011020365,1011020369,1011020370},
        [1101101007]={1011020436,1011020437,1011020438,1011020434,1011020430,1011020435,1011020429,1011020428,1011020427,1011020426,1011020425,1011020424,0,1011020444,1011020439,1011020446,1011020447,1011020448,1011020440,1011020445,1011020449,1011020450},
        [1102001120]={1020011137,1020011138,1020011139,1020011135,1020011134,1020011136,1020011133,1020011132,0,0,0,0,0,0,0,0,0,0,0,1020011142,0,0},
        [1102001130]={1020011247,1020011248,1020011249,1020011245,1020011244,1020011246,1020011243,1020011242,0,0,0,0,0,0,0,0,0,0,0,1020011250,0,0},
        [1102002043]={1020020372,1020020374,1020020373,1020020383,1020020380,1020020384,1020020379,1020020378,1020020377,1020020376,1020020375,1020020388,0,1020020385,1020020387,0,0,0,1020020386,0,0,0},
        [1102002061]={1020020552,1020020554,1020020553,1020020563,1020020562,1020020564,1020020559,1020020558,1020020557,1020020556,1020020555,1020020578,0,1020020565,1020020567,1020020573,1020020574,1020020572,1020020566,0,1020020569,0},
        [1102002136]={1020021314,1020021313,1020021315,1020021309,1020021308,1020021312,1020021307,1020021306,1020021305,1020021304,1020021303,1020021302,0,1020021318,1020021316,1020021323,1020021324,1020021322,1020021317,0,1020021325,0},
        [1102002424]={1020024193,1020024192,1020024194,1020024189,1020024188,1020024190,1020024187,1020024186,1020024185,1020024184,1020024183,1020024182,0,1020024197,1020024195,1020024199,1020024200,1020024198,1020024196,0,1020024202,0},
        [1102003080]={1020030755,1020030756,1020030758,0,1020030749,1020030754,1020030748,1020030747,1020030746,1020030745,1020030744,1020030764,0,1020030760,0,1020030759,1020030757,0,0,1020030765,0,0},
        [1102003100]={1020030956,1020030957,1020030958,1020030954,1020030950,1020030955,1020030949,1020030948,1020030947,1020030946,1020030945,1020030944,0,1020030964,0,1020030960,1020030959,1020030965,0,1020030967,1020030966,1020030968},
        [1102005064]={1020050588,1020050589,1020050590,0,0,0,1020050587,1020050586,1020050585,1020050584,1020050583,1020050582,0,0,0,0,0,0,0,0,1020050592,0},
        [1103001101]={1030010954,1030010955,1030010956,0,0,0,0,0,0,0,1030010953,1030010952,1030010951,0,0,0,0,0,0,1030010957,0,1030010958},
        [1103001146]={1030011344,1030011345,1030011346,0,0,0,0,0,0,0,1030011343,1030011342,1030011341,0,0,0,0,0,0,1030011347,0,1030011348},
        [1103001154]={1030011484,1030011485,1030011486,0,0,0,0,0,0,0,1030011483,1030011482,1030011481,0,0,0,0,0,0,1030011487,0,1030011488},
        [1103001179]={1030011738,1030011739,1030011741,0,0,0,1030011737,1030011736,1030011735,1030011734,1030011733,1030011732,1030011731,0,0,0,0,0,0,1030011742,1030011743,1030011744},
        [1103001191]={1030011858,1030011859,1030011861,0,0,0,1030011857,1030011856,1030011855,1030011854,1030011853,1030011852,1030011851,0,0,0,0,0,0,1030011862,1030011863,1030011864},
        [1103001202]={1030011948,1030011949,1030011950,0,0,0,1030011947,1030011946,1030011945,1030011944,1030011943,1030011942,1030011941,0,0,0,0,0,0,1030011951,1030011952,1030011953},
        [1103002030]={1030020245,1030020246,1030020247,1030020252,1030020249,1030020253,1030020258,1030020257,1030020256,1030020255,1030020244,1030020243,1030020242,0,0,0,0,0,0,1030020248,0,0},
        [1103002059]={1030020544,1030020545,1030020546,1030020542,1030020539,1030020543,1030020538,1030020537,1030020536,1030020535,1030020534,1030020533,1030020532,0,0,0,0,0,0,1030020547,1030020548,0},
        [1103002087]={1030020824,1030020825,1030020826,0,0,0,1030020818,1030020817,1030020816,1030020815,1030020814,1030020813,1030020812,0,0,0,0,0,0,1030020827,1030020828,0},
        [1103002106]={1030021009,1030021010,1030021012,1030021015,1030021014,1030021016,1030021008,1030021007,1030021006,1030021005,1030021004,1030021003,1030021002,0,0,0,0,0,0,1030021013,1030021017,0},
        [1103002113]={1030021079,1030021080,1030021082,1030021085,1030021084,1030021086,1030021078,1030021077,1030021076,1030021075,1030021074,1030021073,1030021072,0,0,0,0,0,0,1030021083,1030021087,0},
        [1103003022]={1030030165,1030030166,1030030167,1030030172,1030030169,1030030173,0,0,0,0,1030030164,1030030163,1030030162,0,0,0,0,0,0,0,0,0},
        [1103003030]={1030030256,1030030257,1030030258,1030030254,1030030253,1030030255,1030030248,1030030247,1030030246,1030030245,1030030244,1030030243,1030030242,0,0,0,0,0,0,1030030259,1030030249,0},
        [1103003042]={1030030374,1030030375,1030030376,1030030372,1030030369,1030030373,0,0,0,0,1030030364,1030030363,1030030362,0,0,0,0,0,0,1030030377,0,0},
        [1103003051]={1030030458,1030030459,1030030460,1030030456,1030030455,1030030457,0,0,0,0,1030030454,1030030453,1030030452,0,0,0,0,0,0,1030030463,0,0},
        [1103003062]={1030030568,1030030569,1030030570,1030030566,1030030565,1030030567,0,0,0,0,1030030564,1030030563,1030030562,0,0,0,0,0,0,1030030572,0,0},
        [1103003079]={1030030744,1030030745,1030030746,1030030742,1030030740,1030030743,1030030738,1030030737,1030030736,1030030735,1030030734,1030030733,1030030732,0,0,0,0,0,0,1030030747,1030030739,0},
        [1103003087]={1030030825,1030030826,1030030827,1030030823,1030030824,1030030824,1030030818,1030030817,1030030816,1030030815,1030030814,1030030813,1030030812,0,0,0,0,0,0,1030030828,1030030819,0},
        [1103004037]={1030040315,1030040316,1030040317,1030040325,1030040324,1030040323,0,0,0,0,1030040314,1030040313,1030040312,1030040327,1030040326,0,0,0,1030040328,1030040329,0,0},
        [1103006030]={1030060245,1030060246,1030060247,0,1030060253,1030060252,0,0,0,0,1030060244,1030060243,1030060242,0,0,0,0,0,0,0,0,0},
        [1103007028]={1030070233,1030070234,1030070235,1030070226,1030070225,1030070227,1030070218,1030070217,1030070216,1030070215,1030070214,1030070213,1030070212,0,0,0,0,0,0,1030070236,1030070219,0},
        [1103012010]={0,0,0,0,0,0,1030120038,1030120037,1030120036,1030120035,1030120034,1030120033,1030120032,0,0,0,0,0,0,0,0,0},
        [1103012019]={0,0,0,0,0,0,1030120138,1030120137,1030120136,1030120135,1030120134,1030120133,1030120132,0,0,0,0,0,0,0,0,0},
        [1103012031]={0,0,0,0,0,0,1030120258,1030120257,1030120256,1030120255,1030120254,1030120253,1030120252,0,0,0,0,0,0,0,0,0},
        [1103012039]={0,0,0,0,0,0,1030120339,1030120338,1030120337,1030120336,1030120335,1030120334,1030120333,0,0,0,0,0,0,0,0,0},
        [1103102007]={1031020026,1031020027,1031020028,1031020024,1031020023,1031020025,1031020019,1031020018,1031020017,1031020016,1031020015,1031020014,1031020013,0,0,0,0,0,0,1031020029,0,0},
        [1105001034]={0,0,0,0,1050010287,1050010289,1050010286,1050010285,1050010284,1050010283,1050010282,0,0,0,0,0,0,0,0,1050010292,0,0},
        [1105001048]={0,0,0,1050010429,1050010428,1050010434,1050010427,1050010426,1050010425,1050010424,1050010423,0,0,0,0,0,0,0,0,1050010435,0,1050010436},
        [1105001069]={0,0,0,1050010639,1050010638,1050010640,1050010637,1050010636,1050010635,1050010634,1050010633,1050010645,0,0,0,0,0,0,0,1050010643,1050010646,1050010644},
        [1105002091]={0,0,0,0,0,0,1050020847,1050020846,1050020845,1050020844,1050020843,1050020842,0,0,0,0,0,0,0,0,0,1050020848},
        [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0}
    }

    _G.BaseAttachToIndex = {
        [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2, 
        [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4, 
        [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6, 
        [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13, 
        [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19, 
        [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22 
    }

    _G.VipAttachToIndex = {}
    for skinId, attachList in pairs(_G.VIP_Attachments) do
        for index, attachId in ipairs(attachList) do
            if attachId > 0 then
                _G.VipAttachToIndex[attachId] = index
            end
        end
    end

    _G.WeaponSkinMap = _G.WeaponSkinMap or {}
    _G.VehicleSkinMap = _G.VehicleSkinMap or {}
    _G.OutfitMap = _G.OutfitMap or {}
    _G.skinIdCache = _G.skinIdCache or {}
    _G.skinIdCache2 = _G.skinIdCache2 or {}

    _G.OutfitSkins = {
        Suit = {1405628,1407920,1407916,1407895,1405760,1407870,1407856,1407812,1407758,1407789,1407682,1407696,1407695,1407632,1407631,1407667,1407618,1407573,1407572,1407559,1407558,1407550,1407523,1407718,1407512,1407471,1407470,1406985,1407353,1407366,1407330,1407487,1410668,1407276,1407275,1407142,1407141,1407140,1406971,1406897,1406891,1407187,1405802,1405192,1405334,1400687,1405340,1405623,1405132,1405436,1405435,1405434,1405433,1405208,1407916,1407917,1407918,1407921,1407921,1407926,1407901,1407902,1407903,1407904,1407822,1407823,1407824,1407825,1407807,1407808,1407845,1407846,1407847,1407848,1407794,1411037,1407795,1411038,1407796,1411039},
        Pants = {1404002,1404050,1404425,1404495,1400650,1404522,1404441,1404152,1404196,1404134,1404137,1404164,1404191,1404466,1400052,404035,1404181,404084,1404516},
        Hair = {40605010,40605011,40605012,1410480,1410085,1410299,1402834,441400152,1400150,1402582,1410289,1402218,1402223,1402283,1400426},
        Bag = {
            {501001, 501002, 501003}, {1501001174, 1501002174, 1501003174}, {1501001220, 1501002220, 1501003220},
            {1501001051, 1501002051, 1501003051}, {1501001443, 1501002443, 1501003443}, {1501001265, 1501002265, 1501003265},
            {1501001321, 1501002321, 1501003321}, {1501001277, 1501002277, 1501003277}, {1501001550, 1501002550, 1501003550},
            {1501001592, 1501002592, 1501003592}, {1501001608, 1501002608, 1501003608}, {1501001024, 1501002024, 1501003024},
            {1501001019, 1501002019, 1501003019}, {1501001179, 1501002179, 1501003179}, {1501001194, 1501002194, 1501003194},
            {1501001346, 1501002346, 1501003346}
        },
        Helmet = {
            {502001, 502002, 502003}, {1502001014, 1502002014, 1502003014}, {1502001349, 1502002349, 1502003349},
            {1502001012, 1502002012, 1502003012}, {1502001009, 1502002009, 1502003009}, {1502001397, 1502002397, 1502003397},
            {1502001390, 1502002390, 1502003390}, {1502001381, 1502002381, 1502003381}, {1502001358, 1502002358, 1502003358},
            {1502001350, 1502002350, 1502003350}, {1502001342, 1502002342, 1502003342}
        },
        Pet = {50000,50001,50002,50003,50004,50005,50006,50021,50022,50038,50039,50040}
    }

    _G.skinIdMappings = {
        [101004]={101004, 1101004246,1101004226,1101004236,1101004062,1101004078,1101004086,1101004201,1101004218},
        [101001]={101001,1101001276,1101001089,1101001213,1101001172,1101001127,1101001230,1101001241},                    
        [101003]={101003,1101003227,1103003208,1101003195,1101003187,1101003098,1101003166,1101003218},                    
        [102002]={102002,1102002136,1102002043,1102002061,1102002424},                                          
        [101008]={101008,1101008146,1101008154,1101008079,1101008126,1101008104,1101008146,1101008061,1101008116},                    
        [101006]={101006,1101006085,1101006061,1101006074,1101006043,1101006032,1101006084},
        [102001]={102001, 1102001120}, -- UZI Bang Gia
        [101005]={101005, 1101005098}, -- Groza Godzilla Boc Lua
        [104003]={104003, 1104003037}, -- S12K Nguyen Tu
        [104004]={104004, 1104004035, 1104004041}, -- DBS Quai Thu & Sandsinger
        [101101]={101101, 1101101007}, --asm
        [101007]={101007, 1101007071,1101007062,1101007046,1101007078,1101007072},  -- QBZ
        [101012]={101012, 1101012033},  -- Honey Badger
        [101002]={101002, 1101002081,1101002056,1101002029,1101002149},  -- M16A4
        [101102]={101102, 1101102049,1101102025,1101102017,1101102007,1101102032},  -- ACE32

        [103001]={103001, 1103001202,1103001191,1103001179,1103001146,1103001101,1103001079,1103001202},  -- Kar98k
        [103002]={103002, 1103002113,1103002098,1103002087,1103002060,1103002059,1103002030},  -- M24
        [103003]={103003, 1103003087,1103003079,1103003069,1103003062,1103003055,1103003051,1103003042,1103003030,1103003022,1103003092},  -- AWM

    }

    local BuggySkins = { 1907058, 1907054, 1907059, 1907053, 1907063, 1907072, 1907040, 1907041, 1907027, 1907047, 1907021 }
    local MiradoSkins = { 1915021, 1915022, 1915008, 1915009, 1914011 }
    _G.VehicleSkins = { 
        [1961001] = { 1961151,1961152,1961153,1961147,1961148,1961149,1961144,1961145,1961137,1961138,1961139,1961066,1961067,1961065,1961062,1961063,1961064,1961054,1961055,1961056,1961057,1961051,1961052,1961053,1961048,1961049,1961050,1961044,1961045,1961046,1961047,1961041,1961042,1961043,1961038,1961039,1961040,1961033,1961034,1961035,1961029,1961030,1961031,1961032,1961007,1961010,1961012,1961013,1961014,1961015,1961140,1961141,1961142,1961143,1991023,1991024 }, -- Coupe RB
        [1903001] = { 1903228,1903220,1903221,1903223,1903218,1903219,1903213,1903212,1903202,1908094,1908095,1903193,1903192,1903191,19030790,19030791,19030800,19030801,1903074,1903075,1903076,1903071,1903072,1903073,1903216,1903217,1991001,1991002,1991003,1991004,1903088,1903089,1903090,1903023 }, -- Dacia
        [1908001] = { 1908108,1908109,19080951,19081080,1908084,1908085,1908075,1908077,1908078,1908070,1908069,1908066,1908086,1908088,1908089,1908018 }, -- UAZ
        [1907001] = BuggySkins,
        [1907002] = BuggySkins,
        [1915001] = MiradoSkins,
        [1915004] = MiradoSkins
    }
    _G.CustSlotType = { ClothesEquipemtSlot=5, BackpackEquipemtSlot=8, HelmetEquipemtSlot=9, ParachuteEquipemtSlot=11, GlideEquipemtSlot=15 }

    local function DownloadGameItem(id)
        local puffer_manager = package.loaded['client.slua.logic.download.puffer.puffer_manager'] or require('client.slua.logic.download.puffer.puffer_manager')
        local puffer_const = package.loaded['client.slua.logic.download.puffer_const'] or require('client.slua.logic.download.puffer_const')
        if puffer_manager and puffer_const and puffer_manager.GetState and puffer_const.ENUM_DownloadType and puffer_const.ENUM_DownloadState then
            if puffer_manager.GetState(puffer_const.ENUM_DownloadType.ODPTD, {id}) ~= puffer_const.ENUM_DownloadState.Done then
                pcall(puffer_manager.Download, puffer_const.ENUM_DownloadType.ODPTD, {id})
            end
        end
    end
    _G.download_item = DownloadGameItem

    _G.get_skin_id = function(weaponID)
        if not weaponID then return nil end
        local targetSkinId = _G.WeaponSkinMap and _G.WeaponSkinMap[weaponID]
        if targetSkinId and targetSkinId > 0 then
            if not _G.skinIdCache2[targetSkinId] then
                if _G.download_item then pcall(_G.download_item, targetSkinId) end
                _G.skinIdCache2[targetSkinId] = true
            end
            return targetSkinId
        end
        return weaponID
    end

    _G.equip_character_avatar = function(Character)
        if not Character or not Valid(Character) or not Character.AvatarComponent2 then return end
        local BackpackUtils = import("BackpackUtils")
        local NetAvatarData = Character.AvatarComponent2.NetAvatarData
        local SlotSyncData = NetAvatarData and NetAvatarData.SlotSyncData
        if not SlotSyncData or not Valid(SlotSyncData) or not BackpackUtils then return end

        if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end
        local om = _G.OutfitMap or {}

        -- [FIX] Detect new character or stale cache: check if SlotSyncData matches our expected outfit
        local needsFullApply = false
        if Character._LastAppliedOutfitHash then
            local currentOutfitHash = (om.Suit or 0) + (om.Pants or 0) * 3 + (om.Hair or 0) * 7 + (om.Parachute or 0) * 11
            if Character._LastAppliedOutfitHash ~= currentOutfitHash then
                needsFullApply = true
            else
                -- Verify actual slot data matches expected
                local numSlots = SlotSyncData:Num()
                for i = 0, numSlots - 1 do
                    local slotData = SlotSyncData:Get(i)
                    if slotData and slotData.SlotID then
                        local expectedItemId = 0
                        if slotData.SlotID == _G.CustSlotType.ClothesEquipemtSlot then expectedItemId = om.Suit or 0
                        elseif slotData.SlotID == 6 then expectedItemId = om.Pants or 0
                        elseif slotData.SlotID == 7 then expectedItemId = om.Hair or 0
                        elseif slotData.SlotID == _G.CustSlotType.BackpackEquipemtSlot then expectedItemId = om.Bag or 0
                        elseif slotData.SlotID == _G.CustSlotType.HelmetEquipemtSlot then expectedItemId = om.Helmet or 0
                        elseif slotData.SlotID == _G.CustSlotType.ParachuteEquipemtSlot then expectedItemId = om.Parachute or 0
                        end
                        if expectedItemId ~= 0 and slotData.ItemId ~= expectedItemId then
                            needsFullApply = true
                            break
                        end
                    end
                end
            end
        end

        -- If character is "new" (no cached hash or stale), force reapply
        if not Character._OutfitApplied or needsFullApply then
            Character._OutfitApplied = false
            Character._LastAppliedOutfitHash = nil
        end

        if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end
        local om = _G.OutfitMap or {}
        local isAnyModified = false

        local function EquipAvatar(ApplyDataIdx, mappedSkin, ApplyEquipSlot, isLevelDependent, levelFunc)
            if not mappedSkin or mappedSkin == 0 then return end
            local slotData = SlotSyncData:Get(ApplyDataIdx)
            if slotData and slotData.SlotID == ApplyEquipSlot then
                local applyItemId = mappedSkin
                if isLevelDependent and type(mappedSkin) == "table" then
                    local level = levelFunc and levelFunc(slotData.AdditionalItemID) or 1
                    if level < 1 then level = 1 end
                    if level > 3 then level = 3 end
                    applyItemId = mappedSkin[level] or mappedSkin[1]
                end

                if not applyItemId or applyItemId == 0 or slotData.ItemId == applyItemId then return end

                if not _G.skinIdCache[applyItemId] then
                    if _G.download_item then pcall(_G.download_item, applyItemId) end
                    _G.skinIdCache[applyItemId] = true
                end

                slotData.ItemId = applyItemId
                SlotSyncData:Set(ApplyDataIdx, slotData)
                isAnyModified = true
            end
        end

        local slotPresence = {}
        local numSlots = SlotSyncData:Num()
        for i = 0, numSlots - 1 do
            local slotData = SlotSyncData:Get(i)
            if slotData and slotData.SlotID then
                slotPresence[slotData.SlotID] = i
            end
        end

        if not slotPresence[_G.CustSlotType.GlideEquipemtSlot] then
            SlotSyncData:Add({ SlotID = _G.CustSlotType.GlideEquipemtSlot, ItemId = 0 })
            isAnyModified = true
        end

        if om.Suit and om.Suit ~= 0 and not slotPresence[_G.CustSlotType.ClothesEquipemtSlot] then
            SlotSyncData:Add({ SlotID = _G.CustSlotType.ClothesEquipemtSlot, ItemId = 0 })
            isAnyModified = true
        end

        for i = 0, SlotSyncData:Num() - 1 do
            EquipAvatar(i, om.Suit or 0, _G.CustSlotType.ClothesEquipemtSlot, false)
            EquipAvatar(i, om.Pants or 0, 6, false)
            EquipAvatar(i, om.Hair or 0, 7, false)
            EquipAvatar(i, om.Bag, _G.CustSlotType.BackpackEquipemtSlot, true, BackpackUtils.GetEquipmentBagLevel)
            EquipAvatar(i, om.Helmet, _G.CustSlotType.HelmetEquipemtSlot, true, BackpackUtils.GetEquipmentHelmetLevel)
            EquipAvatar(i, om.Parachute or 0, _G.CustSlotType.ParachuteEquipemtSlot, false)
        end

        if isAnyModified and Character.AvatarComponent2.OnRep_BodySlotStateChanged then
            pcall(function() Character.AvatarComponent2:OnRep_BodySlotStateChanged() end)
        end
        Character._OutfitApplied = true
    end

    _G.ApplyWeaponSkins = function(PlayerCharacter)
        pcall(function()
            if not Valid(PlayerCharacter) then return end
            local WeaponManager = PlayerCharacter:GetWeaponManager()
            if not Valid(WeaponManager) then return end

            if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end

            local function SkinSingleWeapon(Weapon)
                if not Valid(Weapon) or not Valid(Weapon.synData) then return end
                local WeaponID = Weapon:GetWeaponID()
                local SkinID = _G.get_skin_id(WeaponID) or WeaponID
                local isModified = false

                local SkinData = Weapon.synData:Get(7) 
                if SkinData and SkinData.defineID and SkinData.defineID.TypeSpecificID ~= SkinID then
                    SkinData.defineID.TypeSpecificID = SkinID
                    Weapon.synData:Set(7, SkinData)
                    if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(SkinID) end) end
                    if not _G.skinIdCache[SkinID] then 
                        if _G.download_item then _G.download_item(SkinID) end
                        _G.skinIdCache[SkinID] = true 
                    end
                    isModified = true
                end

                if SkinID and SkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[SkinID] then
                    for AttachIdx = 0, 5 do 
                        local attachData = Weapon.synData:Get(AttachIdx)
                        if attachData then
                            local defineIDRef = slua and slua.IndexReference and slua.IndexReference(attachData, "defineID")
                            if defineIDRef then
                                local attachmentId = defineIDRef.TypeSpecificID
                                if attachmentId and attachmentId > 0 then
                                    local mapIndex = _G.BaseAttachToIndex[attachmentId] or _G.VipAttachToIndex[attachmentId]
                                    if mapIndex and _G.VIP_Attachments[SkinID][mapIndex] and _G.VIP_Attachments[SkinID][mapIndex] > 0 then
                                        local targetAttachId = _G.VIP_Attachments[SkinID][mapIndex]
                                        if targetAttachId ~= attachmentId then
                                            attachData.defineID.TypeSpecificID = targetAttachId
                                            Weapon.synData:Set(AttachIdx, attachData)
                                            if not _G.skinIdCache2[targetAttachId] then 
                                                if _G.download_item then pcall(_G.download_item, targetAttachId) end
                                                _G.skinIdCache2[targetAttachId] = true 
                                            end
                                            isModified = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if isModified then
                    if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                    if Weapon.OnRep_synData then pcall(function() Weapon:OnRep_synData() end) end
                end
            end

            for slot = 1, 5 do
                local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
                SkinSingleWeapon(Weapon)
            end

            local curWeapon = PlayerCharacter.GetCurrentWeapon and PlayerCharacter:GetCurrentWeapon()
            if Valid(curWeapon) then
                SkinSingleWeapon(curWeapon)
            end
        end)
    end

    _G.ApplyVehicleSkins = function(PlayerCharacter)
        pcall(function()
            if not Valid(PlayerCharacter) then return end
            local Vehicle = PlayerCharacter:GetCurrentVehicle()
            if not Valid(Vehicle) then 
                _G.LastVehicleEntity = nil
                return 
            end

            if _G.LastVehicleEntity == Vehicle and _G.CurrentEquipVehicleID ~= nil then
                return
            end

            local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or (Vehicle.GetAvatarComponent and Vehicle:GetAvatarComponent())
            if not Valid(VehicleAvatar) then return end

            local defId = tostring((VehicleAvatar.GetDefaultAvatarID and VehicleAvatar:GetDefaultAvatarID()) or Vehicle.VehicleID or "")
            local currentId = tostring((Vehicle.GetAvatarId and Vehicle:GetAvatarId()) or "")
            local applySkinId = 0

            for baseMapId, targetSkin in pairs(_G.VehicleSkinMap) do
                if defId:find(tostring(baseMapId)) or currentId:find(tostring(baseMapId)) then 
                    applySkinId = targetSkin
                    break 
                end
            end

            if applySkinId and applySkinId > 0 then
                _G.skinIdCache = _G.skinIdCache or {}
                if not _G.skinIdCache[applySkinId] then 
                    if _G.download_item then pcall(_G.download_item, applySkinId) end
                    _G.skinIdCache[applySkinId] = true 
                end

                VehicleAvatar.curSwitchEffectId = 7303001
                if VehicleAvatar.ChangeItemAvatar then VehicleAvatar:ChangeItemAvatar(applySkinId, true) end

                _G.CurrentEquipVehicleID = applySkinId
                _G.LastVehicleEntity = Vehicle
            end
        end)
    end

    _G.HandlePetLogic = function()
        pcall(function()
            local petSkin = _G.OutfitMap and _G.OutfitMap.Pet
            if not petSkin or petSkin == 0 or petSkin == 50000 or petSkin == _G.LastAppliedPet then return end

            _G.skinIdCache = _G.skinIdCache or {}
            if not _G.skinIdCache[petSkin] then 
                if _G.download_item then pcall(_G.download_item, petSkin) end
                _G.skinIdCache[petSkin] = true 
            end

            local ModuleManager = package.loaded["client.module_framework.ModuleManager"] or require("client.module_framework.ModuleManager")
            if ModuleManager and ModuleManager.CommonModuleConfig then
                local logic_pet = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
                if logic_pet then
                    if logic_pet.SetCurPetID then logic_pet:SetCurPetID(petSkin) end
                    if logic_pet.EquipPet then logic_pet:EquipPet(petSkin) end
                end
            end
            _G.LastAppliedPet = petSkin
        end)
    end

    _G.ForceRefreshSkinMaps = function()
        pcall(function()
            if not _G.LexusState or not _G.LexusState.CustomTextData then return end
            local cData = _G.LexusState.CustomTextData

            if _G.OutfitSkins then
                if cData.SkinSuit and _G.OutfitSkins.Suit and _G.OutfitSkins.Suit[cData.SkinSuit] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[cData.SkinSuit] end
                if cData.SkinBag and _G.OutfitSkins.Bag and _G.OutfitSkins.Bag[cData.SkinBag] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[cData.SkinBag] end
                if cData.SkinHelmet and _G.OutfitSkins.Helmet and _G.OutfitSkins.Helmet[cData.SkinHelmet] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[cData.SkinHelmet] end
            end

            if _G.skinIdMappings then
                if cData.SkinM416 and _G.skinIdMappings[101004] and _G.skinIdMappings[101004][cData.SkinM416] then _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][cData.SkinM416] end
                if cData.SkinAKM and _G.skinIdMappings[101001] and _G.skinIdMappings[101001][cData.SkinAKM] then _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][cData.SkinAKM] end
                if cData.SkinSCAR and _G.skinIdMappings[101003] and _G.skinIdMappings[101003][cData.SkinSCAR] then _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][cData.SkinSCAR] end
                if cData.SkinM762 and _G.skinIdMappings[101008] and _G.skinIdMappings[101008][cData.SkinM762] then _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][cData.SkinM762] end
                if cData.SkinAUG and _G.skinIdMappings[101006] and _G.skinIdMappings[101006][cData.SkinAUG] then _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][cData.SkinAUG] end
                if cData.SkinUMP and _G.skinIdMappings[102002] and _G.skinIdMappings[102002][cData.SkinUMP] then _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][cData.SkinUMP] end
                if cData.SkinUZI and _G.skinIdMappings[102001] and _G.skinIdMappings[102001][cData.SkinUZI] then _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][cData.SkinUZI] end
                if cData.SkinGroza and _G.skinIdMappings[101005] and _G.skinIdMappings[101005][cData.SkinGroza] then _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][cData.SkinGroza] end
                if cData.SkinS12K and _G.skinIdMappings[104003] and _G.skinIdMappings[104003][cData.SkinS12K] then _G.WeaponSkinMap[104003] = _G.skinIdMappings[104003][cData.SkinS12K] end
                if cData.SkinDBS and _G.skinIdMappings[104004] and _G.skinIdMappings[104004][cData.SkinDBS] then _G.WeaponSkinMap[104004] = _G.skinIdMappings[104004][cData.SkinDBS] end
                if cData.SkinASM and _G.skinIdMappings[101101] and _G.skinIdMappings[101101][cData.SkinASM] then _G.WeaponSkinMap[101101] = _G.skinIdMappings[101101][cData.SkinASM] end
                if cData.SkinQBZ and _G.skinIdMappings[101007] and _G.skinIdMappings[101007][cData.SkinQBZ] then _G.WeaponSkinMap[101007] = _G.skinIdMappings[101007][cData.SkinQBZ] end
                if cData.SkinHoney and _G.skinIdMappings[101012] and _G.skinIdMappings[101012][cData.SkinHoney] then _G.WeaponSkinMap[101012] = _G.skinIdMappings[101012][cData.SkinHoney] end
                if cData.SkinM16A4 and _G.skinIdMappings[101002] and _G.skinIdMappings[101002][cData.SkinM16A4] then _G.WeaponSkinMap[101002] = _G.skinIdMappings[101002][cData.SkinM16A4] end
                if cData.SkinACE32 and _G.skinIdMappings[101102] and _G.skinIdMappings[101102][cData.SkinACE32] then _G.WeaponSkinMap[101102] = _G.skinIdMappings[101102][cData.SkinACE32] end
                if cData.SkinKar98k and _G.skinIdMappings[103001] and _G.skinIdMappings[103001][cData.SkinKar98k] then _G.WeaponSkinMap[103001] = _G.skinIdMappings[103001][cData.SkinKar98k] end
                if cData.SkinM24 and _G.skinIdMappings[103002] and _G.skinIdMappings[103002][cData.SkinM24] then _G.WeaponSkinMap[103002] = _G.skinIdMappings[103002][cData.SkinM24] end
                if cData.SkinAWM and _G.skinIdMappings[103003] and _G.skinIdMappings[103003][cData.SkinAWM] then _G.WeaponSkinMap[103003] = _G.skinIdMappings[103003][cData.SkinAWM] end
            end

            if _G.VehicleSkins then
                if cData.SkinDacia and _G.VehicleSkins[1903001] and _G.VehicleSkins[1903001][cData.SkinDacia] then _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][cData.SkinDacia] end
                if cData.SkinUAZ and _G.VehicleSkins[1908001] and _G.VehicleSkins[1908001][cData.SkinUAZ] then _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][cData.SkinUAZ] end
                if cData.SkinCoupe and _G.VehicleSkins[1961001] and _G.VehicleSkins[1961001][cData.SkinCoupe] then _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][cData.SkinCoupe] end
                if cData.SkinBuggy and _G.VehicleSkins[1907002] and _G.VehicleSkins[1907002][cData.SkinBuggy] then 
                    _G.VehicleSkinMap[1907001] = _G.VehicleSkins[1907002][cData.SkinBuggy]
                    _G.VehicleSkinMap[1907002] = _G.VehicleSkins[1907002][cData.SkinBuggy]
                end
                if cData.SkinMirado and _G.VehicleSkins[1915004] and _G.VehicleSkins[1915004][cData.SkinMirado] then 
                    _G.VehicleSkinMap[1915001] = _G.VehicleSkins[1915004][cData.SkinMirado]
                    _G.VehicleSkinMap[1915004] = _G.VehicleSkins[1915004][cData.SkinMirado]
                end
            end
        end)
    end

    local cached_GameplayStatics = nil
    local cached_PlayerTombBox = nil
    local cached_ActorClass = nil
    _G.NeedCheckDeadBoxTimer = 0

    _G.DeadBox_TemperRequest = function(PlayerController)
        if _G.NeedCheckDeadBoxTimer <= 0 or not Valid(PlayerController) then return end

        local curTime = os.clock()
        if _G.LastCheckDeadBoxTime and (curTime - _G.LastCheckDeadBoxTime) < 2.0 then return end
        _G.LastCheckDeadBoxTime = curTime
        _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1

        local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
        if not Valid(PlayerCharacter) then return end

        if not cached_GameplayStatics then
            cached_GameplayStatics = import("GameplayStatics")
            cached_ActorClass = import("Actor")
            cached_PlayerTombBox = import("PlayerTombBox")
        end

        if not _G.CachedActorArray and cached_ActorClass and slua and slua.Array then
            pcall(function() _G.CachedActorArray = slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass) end)
        end

        local UI_Util = package.loaded["client.common.ui_util"] or require("client.common.ui_util")
        local GameInstance = UI_Util and UI_Util.GetGameInstance and UI_Util.GetGameInstance()
        if not GameInstance or not cached_GameplayStatics or not _G.CachedActorArray then return end

        local deadBoxes = nil
        pcall(function() deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, _G.CachedActorArray) end)
        if not deadBoxes then return end

        for _, deadBoxActor in pairs(deadBoxes) do
            if Valid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
                local damageCauser = deadBoxActor.DamageCauser
                if damageCauser and damageCauser.PlayerKey == PlayerController.PlayerKey then
                    local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                    if Valid(DeadBoxAvatarComponent) then
                        local currentBoxSkinId = 0
                        if PlayerCharacter.CurrentVehicle and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
                            currentBoxSkinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
                        else
                            local currentWeapon = PlayerCharacter:GetCurrentWeapon()
                            if Valid(currentWeapon) and currentWeapon.synData then
                                local weaponSkinData = currentWeapon.synData:Get(7)
                                if weaponSkinData and weaponSkinData.defineID then
                                    currentBoxSkinId = weaponSkinData.defineID.TypeSpecificID
                                end
                            end
                        end

                        if currentBoxSkinId and currentBoxSkinId ~= 0 then
                            pcall(function()
                                if DeadBoxAvatarComponent.ResetItemAvatar then DeadBoxAvatarComponent:ResetItemAvatar() end
                                if DeadBoxAvatarComponent.PreChangeItemAvatar then DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId) end
                                if DeadBoxAvatarComponent.SyncChangeItemAvatar then DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId) end
                            end)
                        end
                        deadBoxActor.bIsTDSkinApplied = true
                    end
                end
            end
        end
    end

    _G.TDFTDeKillCounts = _G.TDFTDeKillCounts or {}
    local CACHED_LinearColor = import("LinearColor")
    local CACHED_GoldColor = CACHED_LinearColor and CACHED_LinearColor(1.0, 0.8, 0.0, 1.0) or nil
    local CACHED_UI_Manager = nil

    _G.ForceEnableKillCounterUI = function()
        pcall(function()
            local KillCounterUISubsystem = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"] or require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
            if KillCounterUISubsystem and KillCounterUISubsystem.__inner_impl and not _G.KCUISystemHacked2 then
                local kcImpl = KillCounterUISubsystem.__inner_impl
                kcImpl.CheckSupportKCUI = function() return true end
                kcImpl.CheckNeedMainKillCounterUI = function(self, PlayerWeapon, PlayerID)
                    if Valid(PlayerWeapon) then
                        local WeaponID = PlayerWeapon:GetWeaponID()
                        self:UpdateMainKillCounterUI(true, WeaponID, _G.get_skin_id(WeaponID) or WeaponID)
                    else self:UpdateMainKillCounterUI(false) end
                end
                local originalUpdateMainKillCounterUI = kcImpl.UpdateMainKillCounterUI
                kcImpl.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
                    if bShow then AvatarID = _G.get_skin_id(WeaponID) or AvatarID end
                    if originalUpdateMainKillCounterUI then originalUpdateMainKillCounterUI(self, bShow, WeaponID, AvatarID) end
                end
                _G.KCUISystemHacked2 = true
            end

            local ModuleManager = package.loaded["client.module_framework.ModuleManager"] or require("client.module_framework.ModuleManager")
            if ModuleManager and ModuleManager.CommonModuleConfig and not _G.KCLogicHacked2 then
                local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                if LogicKillCounter then
                    LogicKillCounter.CheckSupportKC = function() return true end
                    LogicKillCounter.CheckSupportKillCounterAvatar = function() return true end
                    LogicKillCounter.CheckHasWeaponKillCounter = function() return true end
                    LogicKillCounter.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
                    LogicKillCounter.GetEquipedKillCounterId = function() return 2100004 end
                    LogicKillCounter.GetMyEquipedKillCounterId = function() return 2100004 end
                    LogicKillCounter.GetOneWeaponKillCountInBattle = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                    LogicKillCounter.GetWeaponKillCountByUid = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                    _G.KCLogicHacked2 = true
                end
            end

            local killInfoPath = "GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"
            local KillInfo = package.loaded[killInfoPath] or require(killInfoPath)

            if KillInfo and KillInfo.__inner_impl and not _G.KillInfoCounterHacked then
                local originalFileItem = KillInfo.__inner_impl.FileItem
                KillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
                    pcall(function()
                        local gpd = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
                        local LocalPlayer = gpd and gpd.GetPlayerCharacter and gpd.GetPlayerCharacter()
                        if Valid(LocalPlayer) and DamageRecordData and DamageRecordData.Causer == LocalPlayer:GetPlayerNameSafety() then 
                            local currentWeapon = LocalPlayer:GetCurrentWeapon()
                            if Valid(currentWeapon) then
                                local weaponID = currentWeapon:GetWeaponID()
                                local skinID = _G.get_skin_id(weaponID)
                                if skinID then DamageRecordData.CauserWeaponAvatarID = skinID end
                                if _G.OutfitMap and _G.OutfitMap.Suit and _G.OutfitMap.Suit ~= 0 then DamageRecordData.CauserClothAvatarID = _G.OutfitMap.Suit end

                                if CACHED_GoldColor then
                                    DamageRecordData.IsUseColor, DamageRecordData.UseColor = true, CACHED_GoldColor
                                end

                                if DamageRecordData.ResultHealthStatus == 2 then
                                    _G.TDFTDeKillCounts[weaponID] = (_G.TDFTDeKillCounts[weaponID] or 0) + 1
                                    _G.NeedCheckDeadBoxTimer = 50 

                                    if not CACHED_UI_Manager then CACHED_UI_Manager = require("client.slua_ui_framework.manager") end
                                    local uiMainKillCounter = CACHED_UI_Manager and CACHED_UI_Manager.UI_Config_InGame and CACHED_UI_Manager.GetUI(CACHED_UI_Manager.UI_Config_InGame.MainKillCounter)

                                    if uiMainKillCounter and uiMainKillCounter.UpdateWeaponID then
                                        local mainAvatarID = skinID or (currentWeapon.GetWeaponMainAvatarID and currentWeapon:GetWeaponMainAvatarID())
                                        uiMainKillCounter:UpdateWeaponID(weaponID, mainAvatarID)
                                        if ModuleManager and ModuleManager.CommonModuleConfig then
                                            local kcModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                                            if kcModule and kcModule.GetEquipedKillCounterId then
                                                local kcItemID = kcModule:GetEquipedKillCounterId(0, mainAvatarID)
                                                if uiMainKillCounter.SetKillCounterItemShowWithNum then
                                                    uiMainKillCounter:SetKillCounterItemShowWithNum(kcItemID, _G.TDFTDeKillCounts[weaponID], mainAvatarID)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end)
                    if originalFileItem then return originalFileItem(self, DamageRecordData) end
                end
                _G.KillInfoCounterHacked = true
            end

            local SwitchWeaponSlotMode2 = package.loaded["GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2"] or require("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
            if SwitchWeaponSlotMode2 and SwitchWeaponSlotMode2.__inner_impl and not _G.SlotBaseHacked then
                SwitchWeaponSlotMode2.__inner_impl.CheckShowKCIcon = function(self)
                    if Valid(self.KillCounterImg) then 
                        self.KillCounterImg:SetVisibility(import("ESlateVisibility").SelfHitTestInvisible) 
                    end
                end
                _G.SlotBaseHacked = true
            end
        end)
    end

    _G.InitializeSkinModSystem = function()
        pcall(function()
            local LobbyAvatar = package.loaded["client.logic.avatar.LobbyAvatar"] or require("client.logic.avatar.LobbyAvatar")
            if LobbyAvatar and not _G.LobbySkinHooked then
                local originalPutonEquipment = LobbyAvatar.PutonEquipment
                LobbyAvatar.PutonEquipment = function(self, itemID, tAvatarCustom, tExtraData)
                    local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[itemID]
                    if attachIndex then
                        local holdingWeaponSkinID = self.GetCurHoldingWeaponSkinID and self:GetCurHoldingWeaponSkinID()
                        if holdingWeaponSkinID and holdingWeaponSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[holdingWeaponSkinID] then
                            local vipAttachID = _G.VIP_Attachments[holdingWeaponSkinID][attachIndex]
                            if vipAttachID and vipAttachID > 0 then
                                if self.HandleDownload then self:HandleDownload(vipAttachID, nil, nil, false) end
                                itemID = vipAttachID
                            end
                        end
                    end
                    if originalPutonEquipment then return originalPutonEquipment(self, itemID, tAvatarCustom, tExtraData) end
                end

                local originalCharEquipWeaponByResId = LobbyAvatar.CharEquipWeaponByResId
                LobbyAvatar.CharEquipWeaponByResId = function(self, resID, isUse, isAsync, SocketName)
                    local retValue = originalCharEquipWeaponByResId and originalCharEquipWeaponByResId(self, resID, isUse, isAsync, SocketName) or nil
                    if isUse and self.GetEquipments then
                        local equipments = self:GetEquipments()
                        if equipments then
                            for _, equip in ipairs(equipments) do
                                if equip and equip.itemID and _G.BaseAttachToIndex and _G.BaseAttachToIndex[equip.itemID] then
                                    self:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
                                end
                            end
                        end
                    end
                    return retValue
                end
                _G.LobbySkinHooked = true
            end
        end)

        pcall(function()
            local Common_Items_UIBP = package.loaded["client.slua.component.item.ItemChildren.Common_Items_UIBP"] or require("client.slua.component.item.ItemChildren.Common_Items_UIBP")
            if Common_Items_UIBP and not _G.IconBaloHacked then
                local originalInitView = Common_Items_UIBP.InitView
                Common_Items_UIBP.InitView = function(self, nItemId, nCount, nValidTime, tExtraData)
                    tExtraData = tExtraData or {}
                    local displayResId = nil

                    if _G.get_skin_id then
                        local skinID = _G.get_skin_id(nItemId)
                        if skinID and skinID ~= nItemId then displayResId = skinID end
                    end

                    local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[nItemId]
                    if not displayResId and attachIndex then
                        local gpd = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
                        local LocalPlayer = gpd and gpd.GetPlayerCharacter and gpd.GetPlayerCharacter()
                        if Valid(LocalPlayer) then
                            local currentWeapon = LocalPlayer:GetCurrentWeapon()
                            if Valid(currentWeapon) then
                                local weaponID = currentWeapon:GetWeaponID()
                                local finalSkinID = _G.get_skin_id(weaponID) or weaponID
                                if finalSkinID and finalSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[finalSkinID] then
                                    local vipAttachID = _G.VIP_Attachments[finalSkinID][attachIndex]
                                    if vipAttachID and vipAttachID > 0 then displayResId = vipAttachID end
                                end
                            end
                        end
                    end

                    if displayResId then
                        tExtraData.displayResId = displayResId
                        if not _G.skinIdCache2[displayResId] then
                            if _G.download_item then pcall(_G.download_item, displayResId) end
                            _G.skinIdCache2[displayResId] = true
                        end
                    end
                    if originalInitView then return originalInitView(self, nItemId, nCount, nValidTime, tExtraData) end
                end
                _G.IconBaloHacked = true
            end
        end)
    end

    _G.RestoreDefaultSkins = function(localPlayer)
        _G.OutfitMap = {}
        _G.WeaponSkinMap = {}
        _G.VehicleSkinMap = {}
        if not Valid(localPlayer) then return end
        pcall(function()
            local WeaponManager = localPlayer:GetWeaponManager()
            if Valid(WeaponManager) then
                for slot = 1, 3 do
                    local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
                    if Valid(Weapon) and Valid(Weapon.synData) then
                        local WeaponID = Weapon:GetWeaponID()
                        local SkinData = Weapon.synData:Get(7)
                        if SkinData and SkinData.defineID then
                            SkinData.defineID.TypeSpecificID = WeaponID
                            Weapon.synData:Set(7, SkinData)
                            if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(WeaponID) end) end
                            if isModified and Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                        end
                    end
                end
            end
            local Vehicle = localPlayer:GetCurrentVehicle()
            if Valid(Vehicle) then
                local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or (Vehicle.GetAvatarComponent and Vehicle:GetAvatarComponent())
                if Valid(VehicleAvatar) and type(VehicleAvatar.GetDefaultAvatarID) == "function" then
                    local defId = VehicleAvatar:GetDefaultAvatarID()
                    if VehicleAvatar.ChangeItemAvatar then VehicleAvatar:ChangeItemAvatar(defId, true) end
                end
            end
            if localPlayer.AvatarComponent2 and type(localPlayer.AvatarComponent2.OnRep_BodySlotStateChanged) == "function" then
                localPlayer.AvatarComponent2:OnRep_BodySlotStateChanged()
            end
        end)
    end


    -- ============================================================================

    _G.DownloadGameItem = DownloadGameItem
end

-- S14  GAME LIFECYCLE FUNCTIONS
-- ============================================================================

do
    local ShowExpiryDialog = _G.ShowExpiryDialog or function() end
    function BRPlayerCharacterBase:ctor() self._modTemp = self._modTemp or { tmpTbl = {} } end

    function BRPlayerCharacterBase:_PostConstruct()
      BRPlayerCharacterBase.__super._PostConstruct(self); self:InitAddSpecialMoveInfo(); self.bCanNearDeathGiveup = true
    end

    function BRPlayerCharacterBase:ReceiveBeginPlay()
      BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
      self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
      if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
        local CFDC = import("CheckFallingDistanceComponent")
        if slua.isValid(CFDC) and not slua.isValid(self:GetComponentByClass(CFDC)) then Game:AddComponent(CFDC, self, "CheckFallingDistanceComponent") end
      end
      if slua.isValid(self.STCharacterMovement) then self.STCharacterMovement.bPositiveBlowUp = true end
      if self.Role == ENetRole.ROLE_AutonomousProxy then
        self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
        self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
        self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", { AttrName = { "bCanSelfRescue" } }, self.CharacterAttrChangeEvent, self)
      end
      if Client then
        if bWriteLog and printf then pcall(printf, "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey) end
        pcall(GameplayData.AddCharacter, self.Object)
        self:AddControlEvent(self, "OnAttachedToVehicle", self.HandleOnAttachedToVehicle, self)
        self:AddControlEvent(self, "OnDetachedFromVehicle", self.HandleOnDetachedFromVehicle, self)
        if not _G.WH_TIMER_BR and _G.RetryStart then pcall(_G.RetryStart) end
        -- [FIX] Clear stale skin flags and reapply skins on spawn
        self._OutfitApplied = nil
        self._LastAppliedOutfitHash = nil
        if _G.equip_character_avatar then pcall(_G.equip_character_avatar, self) end
        if _G.ApplyWeaponSkins then pcall(_G.ApplyWeaponSkins, self) end
      else
        self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, { [1] = "FinishedState" }, self.HandleFinishedState, self)
      end
    end

    function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
      BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
      if self.Object ~= uPawn then return end
      if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then local uPC = self:GetPlayerControllerSafety(); if slua.isValid(uPC) then uPC:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "") end end
    end

    function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
      if PawnState == EPawnState.SwitchPP then local uPC = self:GetPlayerControllerSafety(); if slua.isValid(uPC) then uPC:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "") end end
    end

    function BRPlayerCharacterBase:HandleFinishedState()
      if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then local EDSQCDM = import("EDynamicSimpleQueryConfigDisableMask"); self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(EDSQCDM.Bit0, true) end
    end

    function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
      if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
        local GMT = CGameMode.GameModeType; local GMID = tonumber(CGameState.GameModeID)
        return (GMT == EGameModeType.ETypicalGameMode or GMT == EGameModeType.EFourInOneGameMode or GMT == EGameModeType.EHeavyWeaponGameMode) and not (MatchModeIds and MatchModeIds[GMID])
      end; return false
    end

    function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(Last, New)
      BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, Last, New)
      if not Client then local uPC = self:GetPlayerControllerSafety(); if slua.isValid(uPC) and uPC.CheckParachuteOpenFeature then if New == EParachuteState.PS_Opening then if uPC.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then uPC.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI() end elseif New == EParachuteState.PS_None then if uPC.CheckParachuteOpenFeature.RecoverParachuteOpenParam then uPC.CheckParachuteOpenFeature:RecoverParachuteOpenParam() end; if uPC.CheckParachuteOpenFeature.ClearTimerAndState then uPC.CheckParachuteOpenFeature:ClearTimerAndState() end end end end
    end

function BRPlayerCharacterBase:OnLanded()
        pcall(function()
          if type(_G.Notify) == "function" then
            _G.Notify("[] OnLanded - PlayerKey:" .. tostring(self.PlayerKey or "nil"))
          end
        end)
        if self.HandleOnLanded then self:HandleOnLanded(-1) end
        if not Client then local uPC = self:GetPlayerControllerSafety(); if slua.isValid(uPC) and uPC.CheckParachuteOpenFeature then if uPC.CheckParachuteOpenFeature.ClearTimerAndState then uPC.CheckParachuteOpenFeature:ClearTimerAndState() end; if uPC.CheckParachuteOpenFeature.ResetCheckShowUI then uPC.CheckParachuteOpenFeature:ResetCheckShowUI() end end end
        -- [FIX] Reapply skins on first landing after spawn/respawn
        if _G.equip_character_avatar then pcall(_G.equip_character_avatar, self) end
        if _G.ApplyWeaponSkins then pcall(_G.ApplyWeaponSkins, self) end
        if _G.ApplyVehicleSkins then pcall(_G.ApplyVehicleSkins, self) end
    end

    function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
      BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
      if Client then
        pcall(GameplayData.RemoveCharacter, self.Object)
        local pc = self:GetPlayerControllerSafety(); if Valid(pc) then ClearModTimers(pc) end; TimerManager:ClearAllForOwner(self)
        local isLocal = false; pcall(function() isLocal = self:IsLocallyControlled() == true end); if isLocal then CleanupESP(pc) end
      end
    end

    function BRPlayerCharacterBase:IsWarGameMode() local uGS = GameplayData:GetGameState(); if slua.isValid(uGS) and Game:IsClassOf(uGS, STExtraGameStateBase) then return uGS.GameModeType == EGameModeType.EWarGameMode end; return false end
    function BRPlayerCharacterBase:BPOnRecycled() 
        if Client then self:ResetMeshRelativeLocationAndRotation() end
        -- [FIX] Clear stale skin flags and reapply skins on recycle
        self._OutfitApplied = nil
        self._LastAppliedOutfitHash = nil
        if _G.equip_character_avatar then pcall(_G.equip_character_avatar, self) end
        if _G.ApplyWeaponSkins then pcall(_G.ApplyWeaponSkins, self) end
        if _G.ApplyVehicleSkins then pcall(_G.ApplyVehicleSkins, self) end
    end
    function BRPlayerCharacterBase:BPOnRespawned()
        if Client then self:ResetMeshRelativeLocationAndRotation() end
        -- [FIX] Clear stale skin flags and reapply skins on respawn
        self._OutfitApplied = nil
        self._LastAppliedOutfitHash = nil
        if _G.equip_character_avatar then pcall(_G.equip_character_avatar, self) end
        if _G.ApplyWeaponSkins then pcall(_G.ApplyWeaponSkins, self) end
        if _G.ApplyVehicleSkins then pcall(_G.ApplyVehicleSkins, self) end
    end
    function BRPlayerCharacterBase:ReceiveOnRecycle()
        if Client then pcall(self.ResetMeshRelativeLocationAndRotation, self); pcall(GameplayData.RemoveCharacter, self.Object) end
        -- [FIX] Clear stale skin flags and reapply skins on recycle
        self._OutfitApplied = nil
        self._LastAppliedOutfitHash = nil
        if _G.equip_character_avatar then pcall(_G.equip_character_avatar, self) end
        if _G.ApplyWeaponSkins then pcall(_G.ApplyWeaponSkins, self) end
        if _G.ApplyVehicleSkins then pcall(_G.ApplyVehicleSkins, self) end
    end
    function BRPlayerCharacterBase:ReceiveOnSpawn()
        if Client then pcall(self.ResetMeshRelativeLocationAndRotation, self); pcall(GameplayData.AddCharacter, self.Object) end
        local isLocal = false; pcall(function() isLocal = self:IsLocallyControlled() == true end)
        local pc = self:GetPlayerControllerSafety()
        -- [FIX] Clear stale skin flags and reapply skins on spawn
        self._OutfitApplied = nil
        self._LastAppliedOutfitHash = nil
        if _G.equip_character_avatar then pcall(_G.equip_character_avatar, self) end
        if _G.ApplyWeaponSkins then pcall(_G.ApplyWeaponSkins, self) end
        if _G.ApplyVehicleSkins then pcall(_G.ApplyVehicleSkins, self) end
    end

    function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
      if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
        local r = FRotator(0, -90, 0); local l = FVector(0, 0, 0)
        if self.Mesh.K2_SetRelativeRotation then self.Mesh:K2_SetRelativeRotation(r, false, nil, false) end; self:CacheInitialMeshOffset(l, r)
      end
    end

    function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
      if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then self.CharacterMovement:SetBase(nil, "", true) end
      if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI) end
    end

    function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord() end

    function BRPlayerCharacterBase:PreAttachedToVehicle()
      local IsDS = UKismetSystemLibrary.IsDedicatedServer(self); if not IsDS then return end
      local MPC = self:GetPlayerControllerSafety(); if not slua.isValid(MPC) then return end
      local CAC = self.CharacterAvatarComp2_BP; if not slua.isValid(CAC) then return end
      local CADU = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil"); local cid = CADU:ChangeVehicleSkinByClothes(MPC, CAC)
      local EVST = import("ESTExtraVehicleShapeType")
      if cid then local UAU = import("AvatarUtils"); if UAU.GetVehicleShapeBySkinID(cid) == EVST.VST_Horse then local uPS = self:GetPlayerStateSafety(); if slua.isValid(uPS) then uPS:AddGeneralCount(468, 1, false) end end end
    end

    function BRPlayerCharacterBase:ParachuteJump()
      local uPC = self:GetControllerSafety(); if slua.isValid(uPC) then if not self:GetEnsure() then if uPC:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPC:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false); uPC:ReInitParachuteItem(); uPC:ServerChangeStatePC(EStateType.State_ParachuteJump) end else EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object) end end
    end

    function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uChar, uNew, uOld)
      if uChar ~= self.Object then return end; local MC = self:GetMedievalCraneFromBase(uNew); if MC and MC.AddCharacter then MC:AddCharacter(self.Object) else MC = self:GetMedievalCraneFromBase(uOld); if MC and MC.RemoveCharacter then MC:RemoveCharacter(self.Object) end end
    end
    function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base) if not slua.isValid(Base) or not Base.GetOwner then return end; local L = Base:GetOwner(); if not slua.isValid(L) then return end; if not L.AddCharacter then return end; return L end
    function BRPlayerCharacterBase:CheckForbidFlaregun() local uPS = self:GetPlayerStateSafety(); if not slua.isValid(uPS) then return false end; if uPS.CanUseFlaregun == false and self:IsLocallyControlled() then local uPC = self:GetPlayerControllerSafety(); if slua.isValid(uPC) then uPC:DisplayGameTipWithMsgID(48532) end end; return not uPS.CanUseFlaregun end
    function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue() self:HandleNearDeathGiveupRescue() end
    function BRPlayerCharacterBase:HandleNearDeathGiveupRescue() local uNDC = self.NearDeatchComponent; if self:IsNearDeath() and slua.isValid(uNDC) and self.bCanNearDeathGiveup == true then local uPS = self:GetPlayerStateSafety(); if slua.isValid(uPS) then uPS:AddGeneralCount(1613, 1, false) end; uNDC:TriggerGotoDieExplictly(self.Object) end end
    function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId) if bWriteLog and log then pcall(log, "BRPlayerCharacterBase:RPC_Server_GmPlayAction. actionId: " .. tostring(actionId)) end; if USTExtraBlueprintFunctionLibrary.IsDevelopment() then self:MulticastRPC_GmPlayAction(actionId) end end
    function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
      if not Client then return end; local uPEC = self:GetPlayEmoteComponent(); if not slua.isValid(uPEC) then return end
      local LF = require("common.log_filter"); LF.SetLogTreeEnable(true); local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId); if not animCfg then return end
      local EHA = slua.loadObject(animCfg.Path); local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath")); local handle = EHA()
      uPEC:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, ""); local tb = FuncUtil.LuaArrayToTable(assetsArray); local au = require("common.asset_util"); au.GetAssetsArrayAsyncParallel(tb, function() uPEC:OnLoadEmoteAssetEnd(handle, actionId, 0) end)
    end
    function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(v) if slua.isValid(self.ParachuteComponent) then self.ParachuteComponent.bServerSyncShouldCheckPassWall = v end end
    function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState() self.Super:OnPlayerEnterCarryBoxState(); if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState() end end
    function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bII) self.Super:OnPlayerLeaveCarryBoxState(bII); if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bII) end end
    function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uIDB) if slua.isValid(uIDB) and Game:IsClassOf(uIDB, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:CarryDeadBox(uIDB) end end
    function BRPlayerCharacterBase:SetAreaID(AreaID) self:SetAttrValue("AreaID", AreaID, -1) end
    function BRPlayerCharacterBase:GetAreaID() return math.floor(self:GetAttrValue("AreaID") + 0.5) end
    function BRPlayerCharacterBase:CannotChangeIntoPetSpectator() return self.bCannotChangeIntoPetSpectator end
    function BRPlayerCharacterBase:DoModChangeToBT() if self:HasState(EPawnState.SpecialSuit) then self:TriggerEntrySkillWithID(4301101, true) end end
    function BRPlayerCharacterBase:SwitchCameraToParachuteOpening() self.Super:SwitchCameraToParachuteOpening(); if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then self.ParachuteFormation:OverlayFormationCameraParams() end end
    function BRPlayerCharacterBase:SwitchCameraToParachuteFalling() self.Super:SwitchCameraToParachuteFalling(); if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then self.ParachuteFormation:OverlayFormationCameraParams() end end
    function BRPlayerCharacterBase:SwitchCameraToNormal() self.Super:SwitchCameraToNormal(); if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then self.ParachuteFormation:OnLandingClearFormationCamera() end end
function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
        if self:HasState(EPawnState.AttachToOther) then local W = self:GetWeaponBySlot(Slot); if slua.isValid(W) then local WID = W:GetWeaponID(); local ATOC = GamePlayTools.GetCurrentConfig("AttachToOtherConfig"); if ATOC and ATOC.CheckIsWeaponInBlackList and ATOC.CheckIsWeaponInBlackList(WID) then local uPC = self:GetPlayerControllerSafety(); if Client and slua.isValid(uPC) and uPC.Role == ENetRole.ROLE_AutonomousProxy then uPC:DisplayGameTipWithMsgID(47306) end; return false end end end
        if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then local SSO = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing); if slua.isValid(SSO) then local nCS = SSO:GetCurMoveState(); if nCS == ESpiderSwingMoveState.Launching or nCS == ESpiderSwingMoveState.Swinging then return false end end end
        local result = self.Super:SwitchWeaponCheck(Slot, IgnoreState)
        -- [FIX] Reapply weapon skins after successful weapon switch
        if result and _G.ApplyWeaponSkins then pcall(_G.ApplyWeaponSkins, self) end
        return result
    end

    -- Vehicle attach/detach handlers
    function BRPlayerCharacterBase:HandleOnAttachedToVehicle(uVehicle)
        if not slua.isValid(uVehicle) then return end
        if self.Role == ENetRole.ROLE_SimulatedProxy then
          self:ClearAttachToVehicleTimer()
          self.nUpdatePlayerAttachToVehicleCount = 0

          local vehicleRef = uVehicle
          local timerName = "UpdatePlayerAttachToVehicle_" .. tostring(self)

          self.nUpdatePlayerAttachToVehicleTimer = TimerManager:Register(self, timerName, 5, true, "Movement", 
              function() 
                  -- Early exit if owner is destroyed
                  if not slua.isValid(self.Object) then 
                      if self.nUpdatePlayerAttachToVehicleTimer then
                          TimerManager:Clear(self.nUpdatePlayerAttachToVehicleTimer)
                          self.nUpdatePlayerAttachToVehicleTimer = nil
                      end
                      return
                  end

                  -- Early exit if vehicle is destroyed
                  if not slua.isValid(vehicleRef) then 
                      if self.nUpdatePlayerAttachToVehicleTimer then
                          TimerManager:Clear(self.nUpdatePlayerAttachToVehicleTimer)
                          self.nUpdatePlayerAttachToVehicleTimer = nil
                      end
                      return
                  end

                  -- Safe to call now
                  self:UpdatePlayerAttachToVehicle(vehicleRef)
              end)

          local vehicleRef2 = uVehicle
          local timerName2 = "FixMeshContainerOffsetIfNeeded_" .. tostring(self)

          self.nFixMeshContainerTimer = TimerManager:Register(self, timerName2, 3, true, "Movement", 
              function()
                  -- Early exit if owner is destroyed
                  if not slua.isValid(self.Object) then 
                      if self.nFixMeshContainerTimer then
                          TimerManager:Clear(self.nFixMeshContainerTimer)
                          self.nFixMeshContainerTimer = nil
                      end
                      return
                  end

                  -- Early exit if vehicle is destroyed
                  if not slua.isValid(vehicleRef2) then 
                      if self.nFixMeshContainerTimer then
                          TimerManager:Clear(self.nFixMeshContainerTimer)
                          self.nFixMeshContainerTimer = nil
                      end
                      return
                  end

                  -- Safe to call now
                  self:FixMeshContainerOffsetIfNeeded(vehicleRef2)
              end)
      end
      -- [FIX] Apply vehicle skins when entering vehicle
      if _G.ApplyVehicleSkins then pcall(_G.ApplyVehicleSkins, self) end
    end
    function BRPlayerCharacterBase:HandleOnDetachedFromVehicle(uLV)
        if not slua.isValid(uLV) then return end
        if self.Role == ENetRole.ROLE_SimulatedProxy then
            self:ClearAttachToVehicleTimer(); self.nUpdatePlayerAttachToVehicleCount = 0
            -- Ensure timers are cleared and nil'ed
            if self.nUpdatePlayerAttachToVehicleTimer then TimerManager:Clear(self.nUpdatePlayerAttachToVehicleTimer); self.nUpdatePlayerAttachToVehicleTimer = nil end
            if self.nFixMeshContainerTimer then TimerManager:Clear(self.nFixMeshContainerTimer); self.nFixMeshContainerTimer = nil end
        end
        -- [FIX] Reapply vehicle skins when exiting vehicle
        if _G.ApplyVehicleSkins then pcall(_G.ApplyVehicleSkins, self) end
    end
    function BRPlayerCharacterBase:UpdatePlayerAttachToVehicle(uV) if not slua.isValid(self.Object) or not slua.isValid(uV) then return end; if not slua.isValid(self.CapsuleComponent) or not slua.isValid(self.Mesh) or not slua.isValid(self.MeshContainer) then return end; if not slua.isValid(self:GetCurrentVehicle()) then return end; if Game:IsDriver(self.Object) then return end; if not self.nUpdatePlayerAttachToVehicleCount then self.nUpdatePlayerAttachToVehicleCount = 0 end; self.nUpdatePlayerAttachToVehicleCount = self.nUpdatePlayerAttachToVehicleCount + 1; if self.nUpdatePlayerAttachToVehicleCount >= 5 then self.nUpdatePlayerAttachToVehicleCount = 0 end end
    function BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded(uV) if not slua.isValid(self.Object) or not slua.isValid(uV) then return end; if not slua.isValid(self.MeshContainer) then return end; if not slua.isValid(self:GetCurrentVehicle()) then return end; if Game:IsDriver(self.Object) then return end; local tol = 1.0; local ez = -1 * self.StandHalfHeight; local cz = self.MeshContainer:GetRelativeTransform():GetLocation().Z; if tol <= math.abs(cz - ez) then self:SetMeshContainerOffsetZ(ez) end end
    function BRPlayerCharacterBase:ClearAttachToVehicleTimer() if self.nUpdatePlayerAttachToVehicleTimer then TimerManager:Clear(self.nUpdatePlayerAttachToVehicleTimer); self.nUpdatePlayerAttachToVehicleTimer = nil end; if self.nFixMeshContainerTimer then TimerManager:Clear(self.nFixMeshContainerTimer); self.nFixMeshContainerTimer = nil end end

    -- ============================================================================
    -- S15  MATCH FEATURES & MOD MENU
    -- ============================================================================
    local _ENV_LAST_WORLD = nil
    local function ApplyEnvironment()
        -- Keep the environment application lightweight: persistent settings are applied only when
        -- the world changes; grass state is applied only when its value changes.
        pcall(function()
            local currentWorld = slua.getWorld()
            local worldChanged = currentWorld ~= _ENV_LAST_WORLD
            if worldChanged then _ENV_LAST_WORLD = currentWorld; _ENV_ONCE_DONE = false end
            local gi = slua_GameFrontendHUD and slua_GameFrontendHUD:GetGameInstance()
            if gi then
                gi:ExecuteCMD("t.MaxFPS", "165")
                gi:ExecuteCMD("r.FrameRateLimit", "165")
                gi:ExecuteCMD("r.VSync", "0")
                if not _ENV_ONCE_DONE then
                    gi:ExecuteCMD("r.Touch.EnableVibration", "0")
                    gi:ExecuteCMD("r.GTSyncType", "2")
                    gi:ExecuteCMD("r.OneFrameThreadLag", "0")
                    gi:ExecuteCMD("r.Streaming.PoolSize", "512")
                    gi:ExecuteCMD("r.EnableLowFPSRender", "0")
                    gi:ExecuteCMD("r.LensFlareQuality", "0")
                    gi:ExecuteCMD("r.DepthOfFieldQuality", "0")
                    gi:ExecuteCMD("r.Shadow.CSM.TransitionScale", "0")
                    gi:ExecuteCMD("r.Tonemapper.Quality", "0")
                    _ENV_ONCE_DONE = true
                end
                local cleanup = _G.LexusConfig.VisualCleanupEnabled == true
                if _ENV_LAST_GRASS_STATE ~= cleanup or worldChanged then
                    if cleanup then
                        gi:ExecuteCMD("grass.DensityScale", "0")
                        gi:ExecuteCMD("grass.DiscardDataOnLoad", "1")
                    else
                        gi:ExecuteCMD("grass.DensityScale", "1")
                        gi:ExecuteCMD("grass.DiscardDataOnLoad", "0")
                    end
                    _ENV_LAST_GRASS_STATE = cleanup
                end
            end
        end)
        if _ENV_LAST_FOG_WORLD ~= _ENV_LAST_WORLD then
            _ENV_LAST_FOG_WORLD = _ENV_LAST_WORLD
            pcall(function()
                local KSL = import("KismetSystemLibrary")
                local w = slua.getWorld()
                if KSL and w then KSL.ExecuteConsoleCommand(w, "r.Fog 1") end
            end)
        end
    end

    local function MarkWHTimerBR()
        -- Set WH_TIMER_BR flag; no-op helper
        if _G.WH_TIMER_BR then return end
        _G.WH_TIMER_BR = true
    end

    local function StartMatchFeatures(pc, pawn)
        if type(ApplyEnvironment) == "function" then
            if not _G.LexusState.EnvironmentTimerId then
                pcall(ApplyEnvironment)
                _G.LexusState.EnvironmentTimerId = AddModTimer(pc, 30.0, true, ApplyEnvironment)
            else
                pcall(ApplyEnvironment)
            end
        end

        if _G._MOD_EXPIRED then 
            pcall(ShowExpiryDialog)
            AddModTimer(pc, 5.0, true, ShowExpiryDialog) 
        end

    -- Skin cache reset removed

        -- Always force-restart visuals on every new match
        _G.VisualsStarted = false
        _G.WH_TIMER_BR = nil
        if _G.StartVisuals then pcall(function() _G.StartVisuals(true) end) end
        pcall(function() if _G.SDW_Force165 then _G.SDW_Force165() end end)

        if not _G.WH_TIMER_BR then 
            pcall(_G.RetryStart or function() end)
        end
    end

    function _G.InitModMenuTab()
        if _G.ModMenuInitialized then return end; _G.ModMenuInitialized = true
        _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {
            iPadViewFOV = 110,
            SkinSuit = 1, SkinBag = 1, SkinHelmet = 1,
            SkinM416 = 1, SkinAKM = 1, SkinSCAR = 1, SkinM762 = 1, SkinAUG = 1, SkinUMP = 1,
            SkinUZI = 1, SkinGroza = 1, SkinS12K = 1, SkinDBS = 1, SkinASM = 1, SkinQBZ = 1,
            SkinHoney = 1, SkinM16A4 = 1, SkinACE32 = 1, SkinKar98k = 1, SkinM24 = 1, SkinAWM = 1,
            SkinDacia = 1, SkinUAZ = 1, SkinCoupe = 1, SkinBuggy = 1, SkinMirado = 1
        }
        local LocUtil = _G.LocUtil or package.loaded["client.common.LocUtil"]
        if not LocUtil then pcall(function() LocUtil = require("client.common.LocUtil") end) end
        local FakeTextMap = {
    [999000] = " PREMIUM",
    [999001] = "> VISUALS",
    [999002] = "> PERFORMANCE",
}
if LocUtil and not LocUtil._IsModMenuHooked then
    for _, fn in ipairs({"GetLocalizeResStr","GetText","GetTextByID","GetLocalText","GetLocalizeStr"}) do
        if LocUtil[fn] then
            local oldFunc = LocUtil[fn]
            local localOld = oldFunc
            LocUtil[fn] = function(id)
                if FakeTextMap[id] then return FakeTextMap[id] end
                if type(id) == "string" and not tonumber(id) then return id end
                if type(localOld) == "function" then return localOld(id) end
                return ""
            end
        end
    end
    LocUtil._IsModMenuHooked = true
end
local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")
local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")
-- D() triggers immediate force save on every setting change
local D = function()
    pcall(function()
        _G._ConfigDirty = true
        if _G.SaveModSettings then _G.SaveModSettings(true) end
    end)
    return true
end

-- > CATEGORIZED MENUS
local colNames = {"Red", "Cyan", "Yellow", "Green", "Purple", "White"}
local colVals = {0,1,2,3,4,5}

local StackWallhack = {
    { Key = "GK_Wallhack", UI = AliasMap.Switcher, Text = "Wallhack (New Engine Chams)", ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.WallhackEnabled end, SetFunc = function(c,v) SafeToggle("GK_Wallhack", function() _G.LexusConfig.WallhackEnabled = v; if not v then for _, data in pairs((_G.LexusState and _G.LexusState.EnemyMarks) or {}) do if data and data.enemy then UndoColorBodyNew(data.enemy, data) end end else StartVisuals() end end); return D() end },
    { Key = "GK_GlowIntensity", UI = AliasMap.Slider, Text = " + Glow Intensity (%10-%100)", ExpandHandle = "GK_Wallhack", MinValue = 10, MaxValue = 100, GetFunc = function() return _G.LexusConfig.GlowIntensity or 60 end, SetFunc = function(c,v) SafeToggle("GK_GlowIntensity", function() _G.LexusConfig.GlowIntensity = tonumber(v) or 60; LINEAR_COLOR_CACHE = {}; if _G.LexusState and _G.LexusState.EnemyMarks then for _, d in pairs(_G.LexusState.EnemyMarks) do d.LastColorNewHash = "" end end end); return D() end },
    { Key = "GK_C_EWH_V", UI = AliasMap.Switcher, Text = " + Enemy Visible Color", ExpandHandle = "GK_Wallhack", SwitcherText = colNames, SwitcherValue = colVals, GetFunc = function() return _G.LexusConfig.ColorEnemyWHVis or 0 end, SetFunc = function(c,v) _G.LexusConfig.ColorEnemyWHVis = v; LINEAR_COLOR_CACHE = {}; if _G.LexusState and _G.LexusState.EnemyMarks then for _, d in pairs(_G.LexusState.EnemyMarks) do d.LastColorNewHash = "" end end; return D() end },
    { Key = "GK_C_EWH_O", UI = AliasMap.Switcher, Text = " + Enemy Invisible Color", ExpandHandle = "GK_Wallhack", SwitcherText = colNames, SwitcherValue = colVals, GetFunc = function() return _G.LexusConfig.ColorEnemyWHOcc or 2 end, SetFunc = function(c,v) _G.LexusConfig.ColorEnemyWHOcc = v; LINEAR_COLOR_CACHE = {}; if _G.LexusState and _G.LexusState.EnemyMarks then for _, d in pairs(_G.LexusState.EnemyMarks) do d.LastColorNewHash = "" end end; return D() end },
    { Key = "GK_C_BWH_V", UI = AliasMap.Switcher, Text = " + Bot Visible Color", ExpandHandle = "GK_Wallhack", SwitcherText = colNames, SwitcherValue = colVals, GetFunc = function() return _G.LexusConfig.ColorBotWHVis or 1 end, SetFunc = function(c,v) _G.LexusConfig.ColorBotWHVis = v; LINEAR_COLOR_CACHE = {}; if _G.LexusState and _G.LexusState.EnemyMarks then for _, d in pairs(_G.LexusState.EnemyMarks) do d.LastColorNewHash = "" end end; return D() end },
    { Key = "GK_C_BWH_O", UI = AliasMap.Switcher, Text = " + Bot Invisible Color", ExpandHandle = "GK_Wallhack", SwitcherText = colNames, SwitcherValue = colVals, GetFunc = function() return _G.LexusConfig.ColorBotWHOcc or 3 end, SetFunc = function(c,v) _G.LexusConfig.ColorBotWHOcc = v; LINEAR_COLOR_CACHE = {}; if _G.LexusState and _G.LexusState.EnemyMarks then for _, d in pairs(_G.LexusState.EnemyMarks) do d.LastColorNewHash = "" end end; return D() end },
}

local StackESP = {
    { Key = "GK_HPBar", UI = AliasMap.Switcher, Text = "Combat Info ESP", GetFunc = function() return _G.LexusConfig.HealthBarESPEnabled end, SetFunc = function(c,v) _G.LexusConfig.HealthBarESPEnabled = v; return D() end },
    { Key = "GK_C_ETxt", UI = AliasMap.Switcher, Text = " + Enemy Text Color", SwitcherText = colNames, SwitcherValue = colVals, GetFunc = function() return _G.LexusConfig.ColorEnemyText or 0 end, SetFunc = function(c,v) _G.LexusConfig.ColorEnemyText = v; return D() end },
    { Key = "GK_C_BTxt", UI = AliasMap.Switcher, Text = " + Bot Text Color", SwitcherText = colNames, SwitcherValue = colVals, GetFunc = function() return _G.LexusConfig.ColorBotText or 1 end, SetFunc = function(c,v) _G.LexusConfig.ColorBotText = v; return D() end },
    { Key = "GK_TextSizeEnemy", UI = AliasMap.Slider, Text = " + Text Size (%0-%100)", MinValue = 0, MaxValue = 100, GetFunc = function() return _G.LexusConfig.TextSizeEnemyUI or 50 end, SetFunc = function(c,v) _G.LexusConfig.TextSizeEnemyUI = tonumber(v) or 50; return D() end },
    { Key = "GK_MapESP", UI = AliasMap.Switcher, Text = "Mini Map Tracking", GetFunc = function() return _G.LexusConfig.MapESPEnabled end, SetFunc = function(c,v) _G.LexusConfig.MapESPEnabled = v; return D() end },
    { Key = "GK_Snapline", UI = AliasMap.Switcher, Text = "ESP Snapline", GetFunc = function() return _G.LexusConfig.SnaplineESPEnabled end, SetFunc = function(c,v) _G.LexusConfig.SnaplineESPEnabled = v; if v then StartVisuals() else SnaplineESP.Clear() end; return D() end },
    { Key = "GK_BombESP", UI = AliasMap.Switcher, Text = "Bomb ESP", GetFunc = function() return _G.LexusConfig.BombESPEnabled end, SetFunc = function(c,v) _G.LexusConfig.BombESPEnabled = v; if v then StartVisuals() end; return D() end },

    { Key = "GK_Counter", UI = AliasMap.Switcher, Text = "Enemy Counter HUD", GetFunc = function() return _G.LexusConfig.EnemyCounterEnabled end, SetFunc = function(c,v) _G.LexusConfig.EnemyCounterEnabled = v; if not v then if GK_DestroyWidget then GK_DestroyWidget() end elseif _G.GK_WIDGET and SafeIsValid(_G.GK_WIDGET) then pcall(function() _G.GK_WIDGET:SetWidgetVisibility(import("ESlateVisibility").Collapsed) end) end; if v and not _G.VisualsStarted then pcall(StartVisuals) end; return D() end },
    { Key = "GK_BoxESP", UI = AliasMap.Switcher, Text = "Box ESP", GetFunc = function() return _G.LexusConfig.BoxESPEnabled end, SetFunc = function(c,v) _G.LexusConfig.BoxESPEnabled = v; if v then StartVisuals() end; return D() end },
}

local StackItem = {
    { Key = "Core_V1Aim", UI = AliasMap.TitleSwitcher, Text = "Aimbot ON/OFF", ExpandIndex = 0,
      GetFunc = function() return _G.LexusConfig.SDWAimbot == true or _G.LexusConfig.SDWAimbot == 1 or _G.LexusConfig.AimbotEnabled == true end,
      SetFunc = function(c,v)
        _G.LexusConfig.SDWAimbot = v
        _G.LexusConfig.AimbotEnabled = v
        return D()
      end },
    { Key = "Core_AimBone", UI = AliasMap.Slider, Text = "  └ Aim Bone (1 Chest  2 Stomach  3 Pelvis)", ExpandHandle = "Core_V1Aim",
      MinValue = 1, MaxValue = 3, GetFunc = function() return tonumber(_G.LexusConfig.SDWAimBone) or 3 end,
      SetFunc = function(c,v) local val = math.floor((tonumber(v) or 3) + 0.5); if val < 1 then val = 1 end; if val > 3 then val = 3 end; _G.LexusConfig.SDWAimBone = val; return true end },
    { Key = "Core_AimFOV", UI = AliasMap.Slider, Text = "  └ Aim FOV (recommended 8)", ExpandHandle = "Core_V1Aim",
      MinValue = 3, MaxValue = 25, GetFunc = function() return tonumber(_G.LexusConfig.SDWAimFOV) or 8 end,
      SetFunc = function(c,v) local val = math.floor((tonumber(v) or 8) + 0.5); if val < 3 then val = 3 end; if val > 25 then val = 25 end; _G.LexusConfig.SDWAimFOV = val; return true end },
    { Key = "Core_AimSpeed", UI = AliasMap.Slider, Text = "  └ Aim Speed (recommended 20)", ExpandHandle = "Core_V1Aim",
      MinValue = 5, MaxValue = 50, GetFunc = function() return tonumber(_G.LexusConfig.SDWAimSpeed) or 20 end,
      SetFunc = function(c,v) local val = math.floor((tonumber(v) or 20) + 0.5); if val < 5 then val = 5 end; if val > 50 then val = 50 end; _G.LexusConfig.SDWAimSpeed = val; return true end },
    { Key = "Core_AimDist", UI = AliasMap.Slider, Text = "  └ Max Distance (recommended 250 m)", ExpandHandle = "Core_V1Aim",
      MinValue = 50, MaxValue = 400, GetFunc = function() return tonumber(_G.LexusConfig.SDWAimMaxDist) or 250 end,
      SetFunc = function(c,v) local val = math.floor((tonumber(v) or 250) + 0.5); if val < 50 then val = 50 end; if val > 400 then val = 400 end; _G.LexusConfig.SDWAimMaxDist = val; return true end },
    { Key = "Core_AimTrigger", UI = AliasMap.Slider, Text = "  └ Trigger (1 Fire=default  2 Scope  3 Any)", ExpandHandle = "Core_V1Aim",
      MinValue = 1, MaxValue = 3,
      GetFunc = function()
        local t = _G.LexusConfig.SDWAimTrigger or "shoot"
        if t == "scope" then return 2 end
        if t == "any" then return 3 end
        return 1
      end,
      SetFunc = function(c,v)
        local val = math.floor((tonumber(v) or 1) + 0.5)
        if val == 2 then _G.LexusConfig.SDWAimTrigger = "scope"
        elseif val == 3 then _G.LexusConfig.SDWAimTrigger = "any"
        else _G.LexusConfig.SDWAimTrigger = "shoot" end
        return true
      end },
    { Key = "Core_AimVis", UI = AliasMap.Switcher, Text = "  └ Visible Only", ExpandHandle = "Core_V1Aim",
      GetFunc = function() return _G.LexusConfig.SDWAimVisibleOnly ~= false end,
      SetFunc = function(c,v) _G.LexusConfig.SDWAimVisibleOnly = v; return true end },
    { Key = "Core_AimBots", UI = AliasMap.Switcher, Text = "  └ Target Bots", ExpandHandle = "Core_V1Aim",
      GetFunc = function() return _G.LexusConfig.SDWAimTargetBots ~= false end,
      SetFunc = function(c,v) _G.LexusConfig.SDWAimTargetBots = v; return true end },
}

local StackVehicle = {
    { Key = "GK_VehESP", UI = AliasMap.Switcher, Text = "Vehicle ESP", ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.VehicleESPEnabled end, SetFunc = function(c,v) _G.LexusConfig.VehicleESPEnabled = v; return D() end },
    { Key = "GK_C_Veh", UI = AliasMap.Switcher, Text = " + Vehicle Color", ExpandHandle = "GK_VehESP", SwitcherText = colNames, SwitcherValue = colVals, GetFunc = function() return _G.LexusConfig.ColorVehicle or 5 end, SetFunc = function(c,v) _G.LexusConfig.ColorVehicle = v; return D() end },
    { Key = "GK_TextSizeVeh", UI = AliasMap.Slider, Text = " + Text Size (%0-%100)", ExpandHandle = "GK_VehESP", MinValue = 0, MaxValue = 100, GetFunc = function() return _G.LexusConfig.TextSizeVehUI or 50 end, SetFunc = function(c,v) _G.LexusConfig.TextSizeVehUI = tonumber(v) or 50; return D() end },
}
local uniqueVehs = {"Buggy", "Dacia", "UAZ", "Motorcycle", "Coupe RB", "Mirado", "Monster Truck", "Rony", "Scooter", "Snowmobile", "Tukshai", "Bike", "UTV", "Motor Glider", "PG-117 (Boat)", "Aquarail (Jet Ski)", "Hovercraft", "Horse", "Tank", "BRDM-2"}
for i=1, #uniqueVehs do
    local vName = uniqueVehs[i]
    local cfgKey = "VehESP_" .. string.gsub(vName, " ", "")
    table.insert(StackVehicle, { Key = "GK_"..cfgKey, UI = AliasMap.Switcher, Text = " + Show " .. vName, ExpandHandle = "GK_VehESP", GetFunc = function() return _G.LexusConfig[cfgKey] == nil and true or _G.LexusConfig[cfgKey] end, SetFunc = function(c,v) _G.LexusConfig[cfgKey] = v; return D() end })
end

local StackMisc = {
    { Key = "GK_iPadView", UI = AliasMap.Switcher, Text = "iPad View", GetFunc = function() return _G.LexusConfig.iPadViewEnabled end, SetFunc = function(c,v) _G.LexusConfig.iPadViewEnabled = v; pcall(function() if _G.ApplyiPadView then local ok,err = pcall(_G.ApplyiPadView); if not ok then LogError("ApplyiPadView", err) end end end); if v and _G.SDW_EnsureiPadHold then pcall(_G.SDW_EnsureiPadHold) end; return D() end },
    { Key = "GK_iPadFOV", UI = AliasMap.Slider, Text = " + iPad FOV (100-120)", MinValue = 1, MaxValue = 100, GetFunc = function() local v = _G.LexusConfig.iPadViewFOV or 110; return math.floor(((v-100)/20)*100) end, SetFunc = function(c,v) local val = tonumber(v) or 0; if val > 100 then val = 100 end; if val < 0 then val = 0 end; _G.LexusConfig.iPadViewFOV = 100 + (val/100)*20; pcall(function() if _G.ApplyiPadView then local ok,err = pcall(_G.ApplyiPadView); if not ok then LogError("ApplyiPadView", err) end end end); return D() end },
    { Key = "GK_NoGrass", UI = AliasMap.Switcher, Text = "No Grass / No Fog", GetFunc = function() return _G.LexusConfig.VisualCleanupEnabled end, SetFunc = function(c,v) _G.LexusConfig.VisualCleanupEnabled = v; pcall(function() if _G.ApplyEnvironment then local ok,err = pcall(_G.ApplyEnvironment); if not ok then LogError("ApplyEnvironment", err) end end end); return D() end },
    { Key = "GK_FakeHWID", UI = AliasMap.Switcher, Text = "Fake HWID (Device Ban Prevention)", GetFunc = function() return _G.LexusConfig.FakeHWID == nil and true or _G.LexusConfig.FakeHWID end, SetFunc = function(c,v) _G.LexusConfig.FakeHWID = v; return D() end },
    { Key = "GK_UnlockFPS165", UI = AliasMap.Switcher, Text = "Unlock 165 FPS", GetFunc = function() return _G.LexusConfig.UnlockFPS165 ~= false end, SetFunc = function(c,v) _G.LexusConfig.UnlockFPS165 = v; if v then if _G.SDW_Patch165 then pcall(_G.SDW_Patch165) end; if _G.SDW_Force165 then pcall(_G.SDW_Force165) end end; return D() end },

    -- Item ESP (moved from ITEM category)
    { Key = "GK_ItemESP", UI = AliasMap.Switcher, Text = "Item ESP", ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.ItemESPEnabled end, SetFunc = function(c,v) _G.LexusConfig.ItemESPEnabled=v; if v then StartVisuals() end; return D() end },
    { Key = "GK_C_Item", UI = AliasMap.Switcher, Text = " + Item Color", ExpandHandle = "GK_ItemESP", SwitcherText = colNames, SwitcherValue = colVals, GetFunc = function() return _G.LexusConfig.ColorItem or 2 end, SetFunc = function(c,v) _G.LexusConfig.ColorItem = v; return D() end },
    { Key = "GK_ItemDist", UI = AliasMap.Slider, Text = " + Distance (10-100 m)", ExpandHandle = "GK_ItemESP", MinValue=10, MaxValue=100, GetFunc=function() return tonumber(_G.LexusConfig.ItemESPMaxDistance) or 50 end, SetFunc=function(c,v) _G.LexusConfig.ItemESPMaxDistance=tonumber(v) or 50; return D() end },
    { Key = "GK_TextSizeItem", UI = AliasMap.Slider, Text = " + Text Size (%0-%100)", ExpandHandle = "GK_ItemESP", MinValue = 0, MaxValue = 100, GetFunc = function() return _G.LexusConfig.TextSizeItemUI or 50 end, SetFunc = function(c,v) _G.LexusConfig.TextSizeItemUI = tonumber(v) or 50; return D() end },

    -- Guns
    { Key = "GK_Item_M416", UI = AliasMap.Switcher, Text = " + M416", ExpandHandle="GK_ItemESP", GetFunc=function() return _G.LexusConfig.EspItem_M416 ~= false end, SetFunc=function(c,v) _G.LexusConfig.EspItem_M416=v; return D() end },
    { Key = "GK_Item_AKM", UI = AliasMap.Switcher, Text = " + AKM", ExpandHandle="GK_ItemESP", GetFunc=function() return _G.LexusConfig.EspItem_AKM ~= false end, SetFunc=function(c,v) _G.LexusConfig.EspItem_AKM=v; return D() end },
    { Key = "GK_Item_M762", UI = AliasMap.Switcher, Text = " + M762", ExpandHandle="GK_ItemESP", GetFunc=function() return _G.LexusConfig.EspItem_M762 ~= false end, SetFunc=function(c,v) _G.LexusConfig.EspItem_M762=v; return D() end },
    { Key = "GK_Item_SCARL", UI = AliasMap.Switcher, Text = " + SCAR-L", ExpandHandle="GK_ItemESP", GetFunc=function() return _G.LexusConfig.EspItem_SCARL ~= false end, SetFunc=function(c,v) _G.LexusConfig.EspItem_SCARL=v; return D() end },
    { Key = "GK_Item_UMP", UI = AliasMap.Switcher, Text = " + UMP45", ExpandHandle="GK_ItemESP", GetFunc=function() return _G.LexusConfig.EspItem_UMP ~= false end, SetFunc=function(c,v) _G.LexusConfig.EspItem_UMP=v; return D() end },
    { Key = "GK_Item_UZI", UI = AliasMap.Switcher, Text = " + UZI", ExpandHandle="GK_ItemESP", GetFunc=function() return _G.LexusConfig.EspItem_UZI ~= false end, SetFunc=function(c,v) _G.LexusConfig.EspItem_UZI=v; return D() end },
    { Key = "GK_Item_AWM", UI = AliasMap.Switcher, Text = " + AWM", ExpandHandle="GK_ItemESP", GetFunc=function() return _G.LexusConfig.EspItem_AWM ~= false end, SetFunc=function(c,v) _G.LexusConfig.EspItem_AWM=v; return D() end },
    { Key = "GK_Item_M24", UI = AliasMap.Switcher, Text = " + M24", ExpandHandle="GK_ItemESP", GetFunc=function() return _G.LexusConfig.EspItem_M24 ~= false end, SetFunc=function(c,v) _G.LexusConfig.EspItem_M24=v; return D() end },

    -- Scopes
    { Key = "GK_Item_Scope3x", UI = AliasMap.Switcher, Text = " + 3x Scope", ExpandHandle="GK_ItemESP", GetFunc=function() return _G.LexusConfig.EspItem_Scope3x ~= false end, SetFunc=function(c,v) _G.LexusConfig.EspItem_Scope3x=v; return D() end },
    { Key = "GK_Item_Scope4x", UI = AliasMap.Switcher, Text = " + 4x Scope", ExpandHandle="GK_ItemESP", GetFunc=function() return _G.LexusConfig.EspItem_Scope4x ~= false end, SetFunc=function(c,v) _G.LexusConfig.EspItem_Scope4x=v; return D() end },
    { Key = "GK_Item_Scope6x", UI = AliasMap.Switcher, Text = " + 6x Scope", ExpandHandle="GK_ItemESP", GetFunc=function() return _G.LexusConfig.EspItem_Scope6x ~= false end, SetFunc=function(c,v) _G.LexusConfig.EspItem_Scope6x=v; return D() end },
    { Key = "GK_Item_Scope8x", UI = AliasMap.Switcher, Text = " + 8x Scope", ExpandHandle="GK_ItemESP", GetFunc=function() return _G.LexusConfig.EspItem_Scope8x ~= false end, SetFunc=function(c,v) _G.LexusConfig.EspItem_Scope8x=v; return D() end },

    -- Grenades
    { Key = "GK_Item_Frag", UI = AliasMap.Switcher, Text = " + Frag Grenade", ExpandHandle="GK_ItemESP", GetFunc=function() return _G.LexusConfig.EspItem_Frag ~= false end, SetFunc=function(c,v) _G.LexusConfig.EspItem_Frag=v; return D() end },
    { Key = "GK_Item_Smoke", UI = AliasMap.Switcher, Text = " + Smoke Grenade", ExpandHandle="GK_ItemESP", GetFunc=function() return _G.LexusConfig.EspItem_Smoke ~= false end, SetFunc=function(c,v) _G.LexusConfig.EspItem_Smoke=v; return D() end },
    { Key = "GK_Item_Molotov", UI = AliasMap.Switcher, Text = " + Molotov", ExpandHandle="GK_ItemESP", GetFunc=function() return _G.LexusConfig.EspItem_Molotov ~= false end, SetFunc=function(c,v) _G.LexusConfig.EspItem_Molotov=v; return D() end },
}

local StackSkin = {
    { Key = "ModMenu_ModSkin", UI = AliasMap.TitleSwitcher, Text = "> Mod Skin System", ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.ModSkin end, SetFunc = function(c,v) _G.LexusConfig.ModSkin = v; _G.LexusConfig.SkinOptionOpen = v; if v and _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end; return D() end },

    -- Outfits
    { Key = "ModMenu_Skin_Suit", UI = AliasMap.Slider, Text = " + Outfit", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 80, GetFunc = function() return _G.LexusState.CustomTextData.SkinSuit or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinSuit = v; if _G.OutfitSkins and _G.OutfitSkins.Suit and _G.OutfitSkins.Suit[v] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[v] end; return D() end },
    { Key = "ModMenu_Skin_Bag", UI = AliasMap.Slider, Text = " + Backpack", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 16, GetFunc = function() return _G.LexusState.CustomTextData.SkinBag or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinBag = v; if _G.OutfitSkins and _G.OutfitSkins.Bag and _G.OutfitSkins.Bag[v] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[v] end; return D() end },
    { Key = "ModMenu_Skin_Helmet", UI = AliasMap.Slider, Text = " + Helmet", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 11, GetFunc = function() return _G.LexusState.CustomTextData.SkinHelmet or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinHelmet = v; if _G.OutfitSkins and _G.OutfitSkins.Helmet and _G.OutfitSkins.Helmet[v] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[v] end; return D() end },

    -- Weapons
    { Key = "ModMenu_Skin_M416", UI = AliasMap.Slider, Text = " + M416", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 9, GetFunc = function() return _G.LexusState.CustomTextData.SkinM416 or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinM416 = v; if _G.skinIdMappings and _G.skinIdMappings[101004] and _G.skinIdMappings[101004][v] then _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][v] end; return D() end },
    { Key = "ModMenu_Skin_AKM", UI = AliasMap.Slider, Text = " + AKM", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 8, GetFunc = function() return _G.LexusState.CustomTextData.SkinAKM or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinAKM = v; if _G.skinIdMappings and _G.skinIdMappings[101001] and _G.skinIdMappings[101001][v] then _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][v] end; return D() end },
    { Key = "ModMenu_Skin_SCAR", UI = AliasMap.Slider, Text = " + SCAR-L", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 8, GetFunc = function() return _G.LexusState.CustomTextData.SkinSCAR or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinSCAR = v; if _G.skinIdMappings and _G.skinIdMappings[101003] and _G.skinIdMappings[101003][v] then _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][v] end; return D() end },
    { Key = "ModMenu_Skin_M762", UI = AliasMap.Slider, Text = " + Beryl M762", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 9, GetFunc = function() return _G.LexusState.CustomTextData.SkinM762 or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinM762 = v; if _G.skinIdMappings and _G.skinIdMappings[101008] and _G.skinIdMappings[101008][v] then _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][v] end; return D() end },
    { Key = "ModMenu_Skin_AUG", UI = AliasMap.Slider, Text = " + AUG", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 7, GetFunc = function() return _G.LexusState.CustomTextData.SkinAUG or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinAUG = v; if _G.skinIdMappings and _G.skinIdMappings[101006] and _G.skinIdMappings[101006][v] then _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][v] end; return D() end },
    { Key = "ModMenu_Skin_UMP", UI = AliasMap.Slider, Text = " + UMP45", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 5, GetFunc = function() return _G.LexusState.CustomTextData.SkinUMP or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinUMP = v; if _G.skinIdMappings and _G.skinIdMappings[102002] and _G.skinIdMappings[102002][v] then _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][v] end; return D() end },
    { Key = "ModMenu_Skin_UZI", UI = AliasMap.Slider, Text = " + UZI", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 2, GetFunc = function() return _G.LexusState.CustomTextData.SkinUZI or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinUZI = v; if _G.skinIdMappings and _G.skinIdMappings[102001] and _G.skinIdMappings[102001][v] then _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][v] end; return D() end },
    { Key = "ModMenu_Skin_Groza", UI = AliasMap.Slider, Text = " + Groza", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 2, GetFunc = function() return _G.LexusState.CustomTextData.SkinGroza or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinGroza = v; if _G.skinIdMappings and _G.skinIdMappings[101005] and _G.skinIdMappings[101005][v] then _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][v] end; return D() end },
    { Key = "ModMenu_Skin_S12K", UI = AliasMap.Slider, Text = " + S12K", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 2, GetFunc = function() return _G.LexusState.CustomTextData.SkinS12K or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinS12K = v; if _G.skinIdMappings and _G.skinIdMappings[104003] and _G.skinIdMappings[104003][v] then _G.WeaponSkinMap[104003] = _G.skinIdMappings[104003][v] end; return D() end },
    { Key = "ModMenu_Skin_DBS", UI = AliasMap.Slider, Text = " + DBS", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 3, GetFunc = function() return _G.LexusState.CustomTextData.SkinDBS or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinDBS = v; if _G.skinIdMappings and _G.skinIdMappings[104004] and _G.skinIdMappings[104004][v] then _G.WeaponSkinMap[104004] = _G.skinIdMappings[104004][v] end; return D() end },
    { Key = "ModMenu_Skin_ASM", UI = AliasMap.Slider, Text = " + ASM", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 2, GetFunc = function() return _G.LexusState.CustomTextData.SkinASM or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinASM = v; if _G.skinIdMappings and _G.skinIdMappings[101101] and _G.skinIdMappings[101101][v] then _G.WeaponSkinMap[101101] = _G.skinIdMappings[101101][v] end; return D() end },
    { Key = "ModMenu_Skin_QBZ", UI = AliasMap.Slider, Text = " + QBZ", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 6, GetFunc = function() return _G.LexusState.CustomTextData.SkinQBZ or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinQBZ = v; if _G.skinIdMappings and _G.skinIdMappings[101007] and _G.skinIdMappings[101007][v] then _G.WeaponSkinMap[101007] = _G.skinIdMappings[101007][v] end; return D() end },
    { Key = "ModMenu_Skin_Honey", UI = AliasMap.Slider, Text = " + Honey Badger", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 2, GetFunc = function() return _G.LexusState.CustomTextData.SkinHoney or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinHoney = v; if _G.skinIdMappings and _G.skinIdMappings[101012] and _G.skinIdMappings[101012][v] then _G.WeaponSkinMap[101012] = _G.skinIdMappings[101012][v] end; return D() end },
    { Key = "ModMenu_Skin_M16A4", UI = AliasMap.Slider, Text = " + M16A4", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 5, GetFunc = function() return _G.LexusState.CustomTextData.SkinM16A4 or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinM16A4 = v; if _G.skinIdMappings and _G.skinIdMappings[101002] and _G.skinIdMappings[101002][v] then _G.WeaponSkinMap[101002] = _G.skinIdMappings[101002][v] end; return D() end },
    { Key = "ModMenu_Skin_ACE32", UI = AliasMap.Slider, Text = " + ACE32", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 6, GetFunc = function() return _G.LexusState.CustomTextData.SkinACE32 or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinACE32 = v; if _G.skinIdMappings and _G.skinIdMappings[101102] and _G.skinIdMappings[101102][v] then _G.WeaponSkinMap[101102] = _G.skinIdMappings[101102][v] end; return D() end },
    { Key = "ModMenu_Skin_Kar98k", UI = AliasMap.Slider, Text = " + Kar98k", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 8, GetFunc = function() return _G.LexusState.CustomTextData.SkinKar98k or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinKar98k = v; if _G.skinIdMappings and _G.skinIdMappings[103001] and _G.skinIdMappings[103001][v] then _G.WeaponSkinMap[103001] = _G.skinIdMappings[103001][v] end; return D() end },
    { Key = "ModMenu_Skin_M24", UI = AliasMap.Slider, Text = " + M24", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 7, GetFunc = function() return _G.LexusState.CustomTextData.SkinM24 or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinM24 = v; if _G.skinIdMappings and _G.skinIdMappings[103002] and _G.skinIdMappings[103002][v] then _G.WeaponSkinMap[103002] = _G.skinIdMappings[103002][v] end; return D() end },
    { Key = "ModMenu_Skin_AWM", UI = AliasMap.Slider, Text = " + AWM", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 11, GetFunc = function() return _G.LexusState.CustomTextData.SkinAWM or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinAWM = v; if _G.skinIdMappings and _G.skinIdMappings[103003] and _G.skinIdMappings[103003][v] then _G.WeaponSkinMap[103003] = _G.skinIdMappings[103003][v] end; return D() end },

    -- Vehicles
    { Key = "ModMenu_Skin_Dacia", UI = AliasMap.Slider, Text = " + Dacia", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 34, GetFunc = function() return _G.LexusState.CustomTextData.SkinDacia or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinDacia = v; if _G.VehicleSkins and _G.VehicleSkins[1903001] and _G.VehicleSkins[1903001][v] then _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][v] end; return D() end },
    { Key = "ModMenu_Skin_UAZ", UI = AliasMap.Slider, Text = " + UAZ", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 16, GetFunc = function() return _G.LexusState.CustomTextData.SkinUAZ or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinUAZ = v; if _G.VehicleSkins and _G.VehicleSkins[1908001] and _G.VehicleSkins[1908001][v] then _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][v] end; return D() end },
    { Key = "ModMenu_Skin_Coupe", UI = AliasMap.Slider, Text = " + Coupe RB", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 56, GetFunc = function() return _G.LexusState.CustomTextData.SkinCoupe or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinCoupe = v; if _G.VehicleSkins and _G.VehicleSkins[1961001] and _G.VehicleSkins[1961001][v] then _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][v] end; return D() end },
    { Key = "ModMenu_Skin_Buggy", UI = AliasMap.Slider, Text = " + Buggy", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 11, GetFunc = function() return _G.LexusState.CustomTextData.SkinBuggy or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinBuggy = v; if _G.VehicleSkins and _G.VehicleSkins[1907002] and _G.VehicleSkins[1907002][v] then _G.VehicleSkinMap[1907001] = _G.VehicleSkins[1907002][v]; _G.VehicleSkinMap[1907002] = _G.VehicleSkins[1907002][v] end; return D() end },
    { Key = "ModMenu_Skin_Mirado", UI = AliasMap.Slider, Text = " + Mirado", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 5, GetFunc = function() return _G.LexusState.CustomTextData.SkinMirado or 1 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.SkinMirado = v; if _G.VehicleSkins and _G.VehicleSkins[1915004] and _G.VehicleSkins[1915004][v] then _G.VehicleSkinMap[1915001] = _G.VehicleSkins[1915004][v]; _G.VehicleSkinMap[1915004] = _G.VehicleSkins[1915004][v] end; return D() end }
}

-- PAGE DEFINITION
if not SettingPageDefine.ModMenu then
    SettingPageDefine.ModMenu = {
        Key = "ModMenu",
        Text = 999000,
        UIKey = "Setting_Page_Privacy",
        Category = {
            { Key = "Cat_WH", Text = "> WALLHACK", Stack = StackWallhack },
            { Key = "Cat_ESP", Text = "> ESP INFO", Stack = StackESP },
            { Key = "Cat_Item", Text = "> AIMBOT", Stack = StackItem },
            { Key = "Cat_Veh", Text = "> VEHICLE ESP", Stack = StackVehicle },
            { Key = "Cat_Skin", Text = "> MOD SKIN", Stack = StackSkin },
            { Key = "Cat_Misc", Text = "> MISC SETTINGS", Stack = StackMisc }
        }
    }
            table.insert(SettingCatalog, SettingPageDefine.ModMenu)
        end
        -- UIMANAGER HOOK (injects mod menu tab into settings UI)
        local UIManager = _G.UIManager
        if UIManager and not UIManager._IsModMenuHooked then
            local old_ShowUI = UIManager.ShowUI
            UIManager.ShowUI = function(config, ...)
                local args = {...}
                local n = select('#', ...)
                if config and config.keyName and (string.find(string.lower(config.keyName), "setting_main") or string.find(string.lower(config.keyName), "setting")) then
                    local catalog = args[1]
                    if type(catalog) == "table" then
                        local hasModMenu = false
                        for _, page in ipairs(catalog) do
                            if type(page) == "table" and page.Key == "ModMenu" then
                                hasModMenu = true
                                break
                            end
                        end
                        if not hasModMenu then
                            table.insert(catalog, SettingPageDefine.ModMenu)
                        end
                    end
                end
                local table_unpack = table.unpack or unpack
                return old_ShowUI(config, table_unpack(args, 1, n))
            end
            UIManager._IsModMenuHooked = true
        end
    end

    -- ============================================================================

    _G.StartMatchFeatures = StartMatchFeatures
    _G.MarkWHTimerBR = MarkWHTimerBR
    -- [FIX SCOPE] Environment state reset accessor for CleanupMatchState
    _G._GK_ENV_RESET = function()
        _ENV_LAST_WORLD = nil
        _ENV_LAST_FOG_WORLD = nil
        _ENV_LAST_GRASS_STATE = nil
    end
end

-- S16  MAIN LOOP & FAST TICK
-- ============================================================================

do
    local GetMsgBox = _G.GetMsgBox or function() local ok, m = pcall(require, "client.slua.logic.common.logic_common_msg_box"); return ok and m or nil end
    local GetWebSDK = _G.GetWebSDK or function() local ok, w = pcall(require, "client.slua.logic.url.logic_webview_sdk"); return ok and w or nil end
    local FormatTimeRemaining = _G.FormatTimeRemaining or function(s) return tostring(s) end
    local ShowExpiryDialog = _G.ShowExpiryDialog or function() end
    local EXPIRE_DATE = _G.EXPIRE_DATE or "2027-09-28"

    local function CleanupMatchState(pc)
        -- Full local lifecycle reset. Keep security state untouched; only stop feature timers/caches.
        -- [FIX SCOPE] All S13-block locals are accessed via _G accessor closures
        if _G._GK_RETRY_GENERATION then _G._GK_RETRY_GENERATION.set(_G._GK_RETRY_GENERATION.get() + 1) end
        pcall(function() if _G.StopVisuals then _G.StopVisuals() end end)
        pcall(function() if pc and type(ClearModTimers) == "function" then ClearModTimers(pc) end end)
        pcall(function()
            if TimerManager and TimerManager.PurgeDeadTimers then TimerManager:PurgeDeadTimers() end
            if rawget(_G, "SnaplineESP") and SnaplineESP.ClearAllSnapLines then SnaplineESP.ClearAllSnapLines() end
            _FrameCache.frame = -1; _FrameCache.pawn = nil; _FrameCache.pos = nil; _FrameCache.hud = nil; _FrameCache.pc = nil; _FrameCache.team = 0
            if _G.LexusState then
                _G.LexusState.MatchStarted = false
                _G.LexusState.VisualsStarted = false
                _G.LexusState.WelcomeShown = false
                _G.TDSkinLoopStarted = false
                _G.LexusState.SkinWasApplied = false
                _G._LastAppliedOutfitHash = 0
                _G.LastVehicleEntity = nil
                _G.CurrentEquipVehicleID = nil
                _G.LastAppliedPet = nil
                _G.CachedActorArray = nil
                _G.LexusState.EnemyMarks = {}
            end
            _G.WH_TIMER_BR = nil
            _G.WALLHACK_NEEDS_CLEANUP = false
            _G.VisualTimerIds = nil
            -- [FIX 3] Ensure the global flag is reset on match exit
            _G.VisualsStarted = false
            _G._SDW_LastPawnKey = nil
            _G.WH_TIMER_BR = nil
            _G.VisualTimerIds = nil
            if _G.LexusState and _G.LexusState.EnvironmentTimerId then
                pcall(function() if pc and pc.RemoveGameTimer then pc:RemoveGameTimer(_G.LexusState.EnvironmentTimerId) end end)
                RemoveModTimerId(_G.LexusState.EnvironmentTimerId)
                _G.LexusState.EnvironmentTimerId = nil
            end
            -- [FIX SCOPE] Reset environment state via cross-scope accessor
            if _G._GK_ENV_RESET then _G._GK_ENV_RESET() end
            -- [FIX SCOPE] Reset retry/PBC state via cross-scope accessors
            if _G._GK_RETRY_TIMER_ACTIVE then _G._GK_RETRY_TIMER_ACTIVE.set(false) end
            -- [FIX 5] Reset retryCount so Match 2+ can initialize features successfully
            if _G._GK_retryCount then _G._GK_retryCount.set(0) end
            if _G.InvalidatePawnCache then _G.InvalidatePawnCache() end
            if _G._GK_AI_CACHE then _G._GK_AI_CACHE.reset() end
            _G.NAME_CACHE = {}; _G.NAME_LOOKUP_DONE = {}; _G.POS_CACHE = {}
            if _G._GK_VEH_CACHE then _G._GK_VEH_CACHE.reset() end
            if _G._GK_MAP_INIT_DONE then _G._GK_MAP_INIT_DONE.set(false) end
            if _G._GK_PBC_MATCH_TOKEN then _G._GK_PBC_MATCH_TOKEN.set(nil) end
            if _G._GK_PBC_TICK_FAILURES then _G._GK_PBC_TICK_FAILURES.set(0) end
            if _G._GK_PBC_RUNNING then _G._GK_PBC_RUNNING.set(false) end
            -- [FIX L4] Clear CachedActorArray to prevent stale UObject references across matches
            _G.CachedActorArray = nil
            -- [FIX L5] Clear LastAppliedPet so pet skin re-applies on new match
            _G.LastAppliedPet = nil
            -- [FIX FEEDBACK] Reset feedback state so screenshot loop restarts in next match
            _G._GK_FeedbackStarted = false
            if _G._GK_ResetFeedbackState then _G._GK_ResetFeedbackState() end
            if _G._GK_ResetMatchKills then _G._GK_ResetMatchKills() end
            -- [FIX] Reset skin mod hashes so they reapply on new match
            _G._LastAppliedOutfitHash = 0
            _G.LastAppliedPet = nil
            _G.LastVehicleEntity = nil
            _G.CurrentEquipVehicleID = nil
            -- [FIX] Full cache purge for all ESP systems
            LINEAR_COLOR_CACHE = {}
            if rawget(_G, "VEH_NAME_RESOLVE_CACHE") then _G.VEH_NAME_RESOLVE_CACHE = {} end
            if rawget(_G, "_ITEM_ACTORS_CACHE") then _G._ITEM_ACTORS_CACHE = nil end
            if rawget(_G, "_PAWN_CACHE") then _G._PAWN_CACHE = nil end
            if rawget(_G, "SnaplineESP") and SnaplineESP._WidgetPool then SnaplineESP._WidgetPool = {} end
            if rawget(_G, "AI_CACHE") then AI_CACHE = {} end
            if rawget(_G, "AI_CACHE_SIZE") then AI_CACHE_SIZE = 0 end
        end)
    end

    local function ShowSetupGuidanceDialog()
        pcall(function()
            local Msg = GetMsgBox()
            if not Msg or not Msg.Show then return end

            local onDismiss = function()
                pcall(function()
                    local sh = import("ScriptHelperClient")
                    if sh and sh.AddOnScreenDebugMessage then
                        sh.AddOnScreenDebugMessage("*  ACTIVE: Open Settings ->  to configure *", -1, 5.0, {0, 255, 255, 255}, {1.5, 1.5})
                    end
                end)
            end

            Msg.Show(1, "*  SETUP GUIDE *", table.concat({
                "HOW TO ACTIVATE FEATURES:",
                "",
                "1. Open in-game Settings (Gear Icon).",
                "2. Scroll down & select ' PREMIUM' tab.",
                "3. Enable Wallhack, ESP, Items, or Skins as needed.",
                "",
                "* All features are currently OFF by default for security.",
                "Tap [Continue Playing] below and enjoy!"
            }, "\n"), onDismiss, nil, "Continue Playing", "")
        end)
    end

    local function ShowWelcomePopup()
        pcall(function()
            local Msg = GetMsgBox(); if not Msg or not Msg.Show then return end
            local sh = import("ScriptHelperClient")
            local onClick = function() 
                pcall(function() GetWebSDK():OpenURL("https://t.me/") end)
                pcall(function()
                    local tt = require("common.time_ticker")
                    if tt and tt.AddTimerOnce then
                        tt.AddTimerOnce(0.5, ShowSetupGuidanceDialog)
                    else
                        ShowSetupGuidanceDialog()
                    end
                end)
            end
            if not _G.CheckExpiration() then
                local msgText = "Your Premium License has expired."
                if _G._TAMPER_DETECTED then
                    msgText = "System tampering detected! Date/Time manipulation is not allowed."
                elseif _G._NO_SERVER_TIME then
                    msgText = "No internet connection detected. Online verification failed."
                elseif _G._TIME_ROLLBACK_DETECTED then
                    msgText = "Time rollback detected. Please set correct date/time."
                end
                if sh and sh.AddOnScreenDebugMessage then sh.AddOnScreenDebugMessage("*  PREMIUM EXPIRED *\n" .. msgText, -1, 15.0, {255, 0, 0, 255}, {1.8, 1.8}) end
                Msg.Show(4, "*  PREMIUM EXPIRED *", table.concat({
                    msgText,
                    "Expired On: " .. EXPIRE_DATE,
                    "",
                    "Tap [Renew] to contact  on Telegram."
                }, "\n"), function() pcall(function() GetWebSDK():OpenURL("https://t.me/") end) end, nil, "Renew", "Cancel")
                return
            end
            local remaining = _G._MOD_REMAINING_SECONDS or 0
            local formatted = FormatTimeRemaining(remaining)

            if sh and sh.AddOnScreenDebugMessage then
                sh.AddOnScreenDebugMessage("*  PREMIUM INJECTED *", -1, 8.0, {255, 215, 0, 255}, {2.0, 2.0})
                sh.AddOnScreenDebugMessage("Time Remaining: " .. formatted, -1, 8.0, {0, 255, 255, 255}, {1.4, 1.4})
            end

            Msg.Show(1, "*  PREMIUM *", table.concat({
                "PREMIUM ACCESS GRANTED:",
                "* Engine Status : Active",
                "* Subscription  : Active",
                "* Time Remaining: " .. formatted,
                "",
                "STATUS: 100% Safe & Undetected. Enjoy!"
            }, "\n"), onClick, nil, "Join Telegram", "")
        end)
    end

    local function ShowWelcomeDialog()
        if _G.LexusState.WelcomeShown then return end
        _G.LexusState.WelcomeShown = true
        pcall(function()
            local Msg = GetMsgBox(); if not Msg or not Msg.Show then return end
            local sh = import("ScriptHelperClient")
            if sh and sh.AddOnScreenDebugMessage then sh.AddOnScreenDebugMessage("SECURING ENGINE...", -1, 2.0, {0, 255, 0, 255}, {1.5, 1.5}) end

            Msg.Show(1, "*  PREMIUM *", table.concat({
                "SECURITY STATUS:",
                "* Anti-Cheat  : Suppresed",
                "* Security Hooks : Modified",
                "* Client Integrity : Tampered",
                "",
                "STATUS: 100% Safe & Undetected. Enjoy!"
            }, "\n"), function()
                -- Show the second popup after they click OK
                pcall(function() require("common.time_ticker").AddTimerOnce(0.5, ShowWelcomePopup) end)
            end, nil, "Continue", "")
        end)
    end

    local _MAINLOOP_RUNNING = false
    local function MainLoop()
        if _MAINLOOP_RUNNING then return end
        _MAINLOOP_RUNNING = true
        local ok, err = pcall(function()
        if _G._MOD_EXPIRED then pcall(ShowExpiryDialog); return end
        if not _G.LexusState.CustomTextData then
            _G.LexusState.CustomTextData = {
                iPadViewFOV = 110,
                SkinSuit = 1, SkinBag = 1, SkinHelmet = 1,
                SkinM416 = 1, SkinAKM = 1, SkinSCAR = 1, SkinM762 = 1, SkinAUG = 1, SkinUMP = 1,
                SkinUZI = 1, SkinGroza = 1, SkinS12K = 1, SkinDBS = 1, SkinASM = 1, SkinQBZ = 1,
                SkinHoney = 1, SkinM16A4 = 1, SkinACE32 = 1, SkinKar98k = 1, SkinM24 = 1, SkinAWM = 1,
                SkinDacia = 1, SkinUAZ = 1, SkinCoupe = 1, SkinBuggy = 1, SkinMirado = 1
            }
        end
        -- [PERF OPT 3] Use cached require instead of pcall(require) every 3s
        local gpd = _cached_GameplayData
        if not gpd then local ok; ok, gpd = pcall(require, "GameLua.GameCore.Data.GameplayData"); if ok then _cached_GameplayData = gpd else return end end
        local pc = gpd.GetPlayerController(); local localPlayer = nil
        if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end
        if not Valid(localPlayer) then if _G.LexusState.MatchStarted then CleanupMatchState(pc) end; return end
        -- New match / new pawn detection
        local pawnKey = nil
        pcall(function() if localPlayer.GetUniqueID then pawnKey = tostring(localPlayer:GetUniqueID()) end end)
        if not pawnKey then pawnKey = tostring(localPlayer) end
        if not _G.LexusState.MatchStarted or (_G._SDW_LastPawnKey and _G._SDW_LastPawnKey ~= pawnKey) then
            _G.LexusState.MatchStarted = true
            _G._SDW_LastPawnKey = pawnKey
            pcall(_G.StartMatchFeatures, pc, localPlayer)
        end

        -- Heartbeat: force visuals if dead mid-match
        if _G.LexusState.MatchStarted and (not _G.VisualsStarted or not _G.VisualTimerIds or #_G.VisualTimerIds == 0) then
            pcall(function() if _G.StartVisuals then _G.StartVisuals(true) end end)
        end

        if not _G.LexusState.WelcomeShown then ShowWelcomePopup(); _G.LexusState.WelcomeShown = true end
        if not _G.ModMenuInitialized then _G.InitModMenuTab(); Notify(" PREMIUM active! Open Settings ->  to configure.") end
        if not _G._GK_FeedbackStarted then
            -- 10-min loop disabled; victory-only feedback (1.lua style)
            _G._GK_FeedbackStarted = true
        end
        pcall(function() if Valid(pc) then if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false end; if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false end end end)
        -- [FIX P4] Removed redundant outer pcall wrapper - ApplyiPadView already has internal pcall
        pcall(_G.ApplyiPadView or function() end)
        -- [FIX] iPad FOV hold (ported from eg.lua): re-apply every 0.25s so the
        -- FOV does not drop for 1-2s between MainLoop cycles.
        pcall(_G.SDW_EnsureiPadHold or function() end)

        -- ========================================================
        -- MOD SKIN EXECUTION (Continuous Enforcement & Dirty Checks)
        -- ========================================================
        if _G.LexusConfig and _G.LexusConfig.ModSkin then
            if not _G.TDSkinLoopStarted then
                if _G.InitializeSkinModSystem then _G.InitializeSkinModSystem() end
                if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end
                _G.TDSkinLoopStarted = true
            end

            _G.LexusState.SkinWasApplied = true
            local curTime = os.clock()

            if not _G.LastSkinUpdateTime or (curTime - _G.LastSkinUpdateTime) > 0.5 then
                _G.LastSkinUpdateTime = curTime

                pcall(function()
                    local isAlive = type(localPlayer.IsAlive) == "function" and localPlayer:IsAlive() or true
                    if isAlive then
                        if not _G.KillInfoCounterHacked and _G.ForceEnableKillCounterUI then _G.ForceEnableKillCounterUI() end
                        if _G.equip_character_avatar then _G.equip_character_avatar(localPlayer) end
                        if _G.ApplyWeaponSkins then _G.ApplyWeaponSkins(localPlayer) end
                        if _G.ApplyVehicleSkins then _G.ApplyVehicleSkins(localPlayer) end
                        if _G.HandlePetLogic then _G.HandlePetLogic() end -- Pet logic is lightweight
                        if _G.DeadBox_TemperRequest and Valid(pc) then _G.DeadBox_TemperRequest(pc) end
                    end
                end)
            end
        else
            -- Restore original skins when turned off
            if _G.LexusState and _G.LexusState.SkinWasApplied then
                if _G.RestoreDefaultSkins then _G.RestoreDefaultSkins(localPlayer) end
                _G.LexusState.SkinWasApplied = false
                _G._LastAppliedOutfitHash = 0
            end
            _G.TDSkinLoopStarted = false
        end
        -- HWID Spoofing
        pcall(function()
            local SL = import("KismetSystemLibrary")
            if SL and not _G.FakeHWID_Hooked then
                _G.Original_GetDeviceId = SL.GetDeviceId
                -- [FIX C4] Fixed HWID generation: added randomseed + fixed sub(pos,pos) to prevent empty strings
                if not _G._HWID_SEEDED then
                    pcall(function() math.randomseed(os.time() + math.floor(os.clock() * 1000)) end)
                    _G._HWID_SEEDED = true
                end
                SL.GetDeviceId = function(...) if _G.LexusConfig.FakeHWID then if not _G.FakeHWID_String then local chars = "0123456789abcdef"; local hwid = ""; for i = 1, 32 do local pos = math.random(1,16); hwid = hwid .. chars:sub(pos, pos) end; _G.FakeHWID_String = hwid end; return _G.FakeHWID_String end; if _G.Original_GetDeviceId then return _G.Original_GetDeviceId(...) end; return "UNKNOWN" end
                _G.FakeHWID_Hooked = true
            end
        end)
        end)
        _MAINLOOP_RUNNING = false
        if not ok then LogError("MainLoop", err) end
    end

    _G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1
    local myToken = _G.LexusState.LoopToken
    local function FastTick()
        if myToken ~= _G.LexusState.LoopToken then return end
        pcall(MainLoop)
        -- Periodic TimerManager cleanup (every ~30s)
        if TimerManager and TimerManager.PurgeDeadTimers then
            pcall(TimerManager.PurgeDeadTimers, TimerManager)
        end
        -- [PERF OPT 3] Use cached require for time_ticker
        local ticker = _cached_time_ticker
        if not ticker then local ok; ok, ticker = pcall(require, "common.time_ticker"); if ok then _cached_time_ticker = ticker end end
        if ticker and ticker.AddTimerOnce and not _G._MOD_EXPIRED and myToken == _G.LexusState.LoopToken then
            -- Keep the lightweight heartbeat alive, but back off in lobby/no-player state.
            local nextDelay = (_G.LexusState and _G.LexusState.MatchStarted) and 3.0 or 8.0  -- [OPT-P5d] Lobby 5s->8s
            ticker.AddTimerOnce(nextDelay, FastTick)
        end
    end
    FastTick()

    -- ========================================================================
    -- SHIVAM 2-STEP ORDERED INITIALIZATION:
    -- 1. INGAME PHONE STATS UI & WATERMARK CONSOLE
    -- 2. WELCOME DIALOG POPUP SEQUENCE
    -- ========================================================================
    local function ExecuteMasterSequence()
        -- STEP 1: Ingame Phone Stats UI & Watermark
        pcall(function()
            if _G.SetupConsole then _G.SetupConsole() end
            local sh = import("ScriptHelperClient")
            if sh and sh.AddOnScreenDebugMessage then
                sh.AddOnScreenDebugMessage("*  ENGINE & INGAME PHONE STATS ACTIVE *", -1, 4.0, {0, 255, 0, 255}, {1.5, 1.5})
            end
        end)

        -- STEP 3: Welcome Dialog Popup
        pcall(function()
            pcall(ShowWelcomeDialog)
            local tt = require("common.time_ticker")
            if tt and tt.AddTimerOnce then
                tt.AddTimerOnce(0.4, function()
                    if not _G.LexusState or not _G.LexusState.WelcomeShown then
                        pcall(ShowWelcomeDialog)
                    end
                end)
                tt.AddTimerOnce(1.2, function()
                    if not _G.LexusState or not _G.LexusState.WelcomeShown then
                        pcall(ShowWelcomeDialog)
                    end
                end)
            end
        end)
    end
    ExecuteMasterSequence()

    if _G._MOD_EXPIRED then pcall(function() require("common.time_ticker").AddTimerOnce(0.5, ShowExpiryDialog) end) end

    -- ============================================================================

    _G.CleanupMatchState = CleanupMatchState
    _G.ShowWelcomePopup = ShowWelcomePopup
    _G.ShowWelcomeDialog = ShowWelcomeDialog
    _G.ShowSetupGuidanceDialog = ShowSetupGuidanceDialog
    _G.MainLoop = MainLoop
    _G.FastTick = FastTick
end


-- SDW Aimbot from 1.lua (clean)
_G.LexusState = _G.LexusState or {}
-- Aimbot runs for whole session (all matches); do not bind to LoopToken
_G._SDW_AimAlive = true

if not _G.GetEnemyTargetsFromActors then
    _G.GetEnemyTargetsFromActors = function(maxDistCm)
        local list = {}
        pcall(function()
            local gpd = require("GameLua.GameCore.Data.GameplayData")
            local player = gpd and gpd.GetPlayerCharacter and gpd.GetPlayerCharacter()
            if not player or not slua.isValid(player) then return end
            local pawns = Game and Game.GetAllPlayerPawns and Game:GetAllPlayerPawns()
            if not pawns then return end
            local myTeam = player.TeamID or 0
            maxDistCm = maxDistCm or 25000
            for _, actor in pairs(pawns) do
                if actor and slua.isValid(actor) and actor ~= player then
                    local team = actor.TeamID
                    if team and team ~= myTeam then
                        local dist = 0
                        pcall(function() dist = player:GetDistanceTo(actor) end)
                        if dist and dist <= maxDistCm then
                            list[#list+1] = { actor = actor, distance = dist }
                        end
                    end
                end
            end
        end)
        return list
    end
end

_G.SDW_CleanAimbotTick = function()
    local C = _G.LexusConfig
    if not C then return end
    if not (C.SDWAimbot == true or C.SDWAimbot == 1 or C.AimbotEnabled == true or C.AimbotEnabled == 1) then return end

    local gpd = rawget(_G, "GameplayData")
    if not gpd then pcall(function() gpd = require("GameLua.GameCore.Data.GameplayData") end) end
    local pc, player = nil, nil
    if gpd then
        pcall(function()
            if gpd.GetPlayerController then pc = gpd.GetPlayerController() end
            if gpd.GetPlayerCharacter then player = gpd.GetPlayerCharacter() end
        end)
    end
    if not pc or not slua.isValid(pc) then return end
    if not player or not slua.isValid(player) then return end

    local firing = (player.bIsWeaponFiring == true or player.bIsFiring == true)
    local ads = (player.bIsGunADS == true)
    local trigger = C.SDWAimTrigger or "shoot"
    if trigger == "shoot" then
        if not firing then return end
    elseif trigger == "scope" then
        if not ads then return end
    else
        if not firing and not ads then return end
    end

    local KismetMath = import("KismetMathLibrary")
    if not KismetMath then return end

    local camLoc, curRot = nil, nil
    local cam = pc.PlayerCameraManager
    if cam and slua.isValid(cam) then
        if cam.CameraCache and cam.CameraCache.POV then camLoc = cam.CameraCache.POV.Location end
        if not camLoc and type(cam.GetCameraLocation) == "function" then
            pcall(function() camLoc = cam:GetCameraLocation() end)
        end
    end
    pcall(function() curRot = pc:GetControlRotation() end)
    if not camLoc or not curRot then return end

    local fovDeg = tonumber(C.SDWAimFOV) or 8
    local maxDistCm = (tonumber(C.SDWAimMaxDist) or 250) * 100
    local bi = tonumber(C.SDWAimBone) or 3
    if bi < 1 then bi = 1 elseif bi > 3 then bi = 3 end
    local boneName = (bi == 1 and "spine_03") or (bi == 2 and "spine_02") or "pelvis"
    local zOff = (bi == 1 and 40) or (bi == 2 and 20) or 5
    local visOnly = (C.SDWAimVisibleOnly ~= false)
    local targetBots = (C.SDWAimTargetBots ~= false)

    local enemies = nil
    if _G.GetEnemyTargetsFromActors then
        pcall(function() enemies = _G.GetEnemyTargetsFromActors(maxDistCm) end)
    end
    if not enemies or #enemies == 0 then return end

    local bestPoint, bestDist, bestAngle, bestEnemy = nil, nil, fovDeg, nil
    for i = 1, #enemies do
        local e = enemies[i]
        local actor = e and (e.actor or e)
        if actor and slua.isValid(actor) and actor ~= player then
            local bot = false
            if e.isBot ~= nil then bot = e.isBot
            else
                if actor.bIsAI == true or actor.IsAI == true then bot = true end
            end
            if targetBots or not bot then
                local dist = e.distance
                if not dist then pcall(function() dist = player:GetDistanceTo(actor) end) end
                if dist and dist <= maxDistCm then
                    local skip = false
                    if visOnly then
                        local ok = true
                        pcall(function()
                            if type(pc.LineOfSightTo) == "function" then ok = (pc:LineOfSightTo(actor) == true) end
                        end)
                        if not ok then skip = true end
                    end
                    if not skip then
                        local point = nil
                        local mesh = actor.Mesh
                        if mesh and slua.isValid(mesh) then
                            pcall(function()
                                if type(mesh.GetSocketLocation) == "function" then
                                    point = mesh:GetSocketLocation(boneName)
                                elseif type(mesh.GetBoneLocation) == "function" then
                                    point = mesh:GetBoneLocation(boneName)
                                end
                            end)
                        end
                        if not point or (point.X == 0 and point.Y == 0 and point.Z == 0) then
                            local base = nil
                            pcall(function()
                                if type(actor.K2_GetActorLocation) == "function" then base = actor:K2_GetActorLocation() end
                            end)
                            if base then point = { X = base.X, Y = base.Y, Z = base.Z + zOff } end
                        end
                        if point then
                            local tRot = nil
                            pcall(function() tRot = KismetMath.FindLookAtRotation(camLoc, point) end)
                            if tRot then
                                local dY = ((tRot.Yaw - curRot.Yaw + 180) % 360) - 180
                                local dP = ((tRot.Pitch - curRot.Pitch + 180) % 360) - 180
                                local ang = math.sqrt(dY * dY + dP * dP)
                                if ang <= bestAngle then
                                    bestAngle = ang
                                    bestPoint, bestDist, bestEnemy = point, dist, actor
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if not bestPoint then return end

    local aimX, aimY, aimZ = bestPoint.X, bestPoint.Y, bestPoint.Z
    if bestEnemy then
        pcall(function()
            local vel = nil
            if type(bestEnemy.GetVelocity) == "function" then vel = bestEnemy:GetVelocity() end
            if vel and (math.abs(vel.X or 0) > 30 or math.abs(vel.Y or 0) > 30) then
                local tt = bestDist / 85000
                aimX = aimX + (vel.X or 0) * tt
                aimY = aimY + (vel.Y or 0) * tt
                aimZ = aimZ + (vel.Z or 0) * tt
            end
        end)
    end
    local recoilSet = tonumber(C.SDWAimRecoil) or 1.1
    if recoilSet > 0 and firing then
        aimZ = aimZ - ((bestDist / 100.0) * recoilSet)
    end

    pcall(function()
        local tRot = KismetMath.FindLookAtRotation(camLoc, { X = aimX, Y = aimY, Z = aimZ })
        if not tRot then return end
        local dP = ((tRot.Pitch - curRot.Pitch + 180) % 360) - 180
        local dY = ((tRot.Yaw - curRot.Yaw + 180) % 360) - 180
        local spd = tonumber(C.SDWAimSpeed) or 20
        local factor = math.min(1.0, math.max(0.05, spd * 0.01))
        pc:SetControlRotation({ Pitch = curRot.Pitch + dP * factor, Yaw = curRot.Yaw + dY * factor, Roll = 0 }, "SDWAim")
    end)
end

local function SDW_AimTick()
    if _G._SDW_AimAlive == false then return end
    pcall(function()
        if _G.SDW_CleanAimbotTick then _G.SDW_CleanAimbotTick() end
    end)
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.02, SDW_AimTick)
    end
end
pcall(function() SDW_AimTick() end)

-- S17  CLASS DECLARATION & FEATURE REGISTRATION
-- ============================================================================
local ok_class, class = pcall(require, "class"); if not ok_class or type(class) ~= "function" then return end
local ok_char, CCharacterBase = pcall(require, "GameLua.GameCore.Framework.CharacterBase"); if not ok_char or type(CCharacterBase) ~= "table" then return end
local ok_create, CBRPlayerCharacterBase = pcall(function() return class(CCharacterBase, nil, BRPlayerCharacterBase) end); if not ok_create then return end
local ok_combine, combine_class = pcall(require, "combine_class"); if not ok_combine or type(combine_class) ~= "table" or type(combine_class.DeclareFeature) ~= "function" then return end
return combine_class.DeclareFeature(CBRPlayerCharacterBase, {
  { SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature" },
  { CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature" },
  { SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature" },
  { TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature" },
  { LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature" },
  { FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature" },
  { CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature" },
  { BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature" },
  { CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature" },
  { ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature" },
  { SpiderSenseFootprintFeature = "GameLua.Mod.Library.GamePlay.Feature.SpiderSenseFootprintFeature" },
  { GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature" }
}, "BRPlayerCharacterBase")


-- ============================================================================
-- END OF .LUA
-- ============================================================================

