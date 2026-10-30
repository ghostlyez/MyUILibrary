--[[
    ╔══════════════════════════════════════════════════════════════════════╗
    ║  Library.lua  v2  —  Roblox UI library (single file)                 ║
    ║  Loader → Key system → Window · Home · Dialogs · Themes · Configs    ║
    ║  Icons: Lucide (only the ones you use, cached on disk)               ║
    ╚══════════════════════════════════════════════════════════════════════╝

    Sections (search for the banner text):
      1 CORE            4 ICONS            7 DIALOGS            10 ELEMENTS
      2 UTIL            5 EFFECTS          8 LOADER / KEYS      11 HOME / SETTINGS
      3 THEMES          6 NOTIFICATIONS    9 LAYOUT / WINDOW    12 PUBLIC API
]]

----------------------------------------------------------------------------
-- 1. CORE
----------------------------------------------------------------------------
local Library = {
	Version = "2.0.0",
	Flags = {}, Elements = {}, Themes = {}, ThemeOrder = {}, Windows = {}, KeyServices = {},
}

local genv = (getgenv and getgenv()) or _G
if genv.__UILibraryInstance and genv.__UILibraryInstance ~= Library then
	pcall(function() genv.__UILibraryInstance:Unload() end)
end
genv.__UILibraryInstance = Library

local cloneref = cloneref or function(o) return o end
local function svc(name)
	local ok, s = pcall(function() return cloneref(game:GetService(name)) end)
	return ok and s or nil
end
local Players, RunService, UIS = svc("Players"), svc("RunService"), svc("UserInputService")
local TweenService, HttpService = svc("TweenService"), svc("HttpService")
local ContentProvider, CoreGui = svc("ContentProvider"), svc("CoreGui")
local MarketplaceService, Stats = svc("MarketplaceService"), svc("Stats")
local SoundService = svc("SoundService")
local LocalPlayer = Players.LocalPlayer

local loadstr = loadstring or load
local wait = task and task.wait or wait
local spawn = task and task.spawn or spawn
local delay = task and task.delay or delay

-- Layout metrics (compact on purpose). Everything below is in "design pixels".
Library.M = {
	Header = 38, Sidebar = 148, Row = 28, Button = 26, Field = 26, Tab = 28,
	Radius = 6, CardRadius = 8, WindowRadius = 10, Pad = 8,
}
local M = Library.M

-- Everything you may want to tweak lives here (or pass overrides in CreateWindow{ Config = {...} })
Library.Config = {
	Font = "rbxasset://fonts/families/GothamSSm.json",
	Animations = true,
	AnimSpeed = 1,                -- 1 = normal, 2 = twice as fast
	Shadows = "Contact",          -- "Contact" (crisp 2px) | "Soft" | "None"
	SoundsEnabled = true,
	SoundVolume = 1,
	Sounds = {},                  -- empty on purpose: add your own  Sounds = { Click = "rbxassetid://..." }
	-- Icon packs tried in order; each must return a table with GetAsset(name, size)
	IconSources = {
		"https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau",
		"https://raw.githubusercontent.com/deividcomsono/lucide-roblox-direct/refs/heads/main/source.lua",
	},
	IconResolution = 48,
	LoadTimeout = 6,
	PreloadTimeout = 1.2,
}

-- File system / http helpers (all safe on executors without them) -------------
local FS = {}
FS.canWrite = (writefile and readfile and isfile and isfolder and makefolder) and true or false
function FS.folder(path)
	if not FS.canWrite then return end
	pcall(function() if not isfolder(path) then makefolder(path) end end)
end
function FS.write(path, data)
	if not FS.canWrite then return false end
	return (pcall(writefile, path, data))
end
function FS.read(path)
	if not FS.canWrite then return nil end
	local ok, r = pcall(function() if isfile(path) then return readfile(path) end end)
	return ok and r or nil
end
function FS.list(folder)
	if not listfiles then return {} end
	local ok, r = pcall(listfiles, folder)
	return ok and r or {}
end
function FS.delete(path) if delfile then pcall(delfile, path) end end
Library.FS = FS

local function httpGet(url)
	local ok, res = pcall(function() return game:HttpGet(url) end)
	if ok and type(res) == "string" and #res > 0 then return res end
	local req = request or http_request or (syn and syn.request) or (http and http.request)
	if req then
		local ok2, r = pcall(req, { Url = url, Method = "GET" })
		if ok2 and r and r.Body and (r.StatusCode or 200) < 400 then return r.Body end
	end
	return nil
end
local function httpRequest(o)
	local req = request or http_request or (syn and syn.request) or (http and http.request)
	if not req then return nil end
	local ok, r = pcall(req, o)
	return ok and r or nil
end
local function jsonEncode(v) local ok, r = pcall(HttpService.JSONEncode, HttpService, v) return ok and r or nil end
local function jsonDecode(s) local ok, r = pcall(HttpService.JSONDecode, HttpService, s) return ok and r or nil end

-- Identity helpers
local function getHwid()
	local id
	pcall(function() if gethwid then id = gethwid() end end)
	if not id then pcall(function() id = svc("RbxAnalyticsService"):GetClientId() end) end
	return tostring(id or "unknown")
end
local function executorName()
	local n
	pcall(function() if identifyexecutor then n = (identifyexecutor()) end end)
	return n or "Unknown executor"
end

----------------------------------------------------------------------------
-- 2. UTIL
----------------------------------------------------------------------------
local Util = {}
Library.Util = Util

local Fonts = {}
local function getFont(weight)
	weight = weight or "Medium"
	if Fonts[weight] == nil then
		local ok, f = pcall(function() return Font.new(Library.Config.Font, Enum.FontWeight[weight], Enum.FontStyle.Normal) end)
		Fonts[weight] = ok and f or false
	end
	return Fonts[weight]
end
local function applyFont(inst, weight)
	local f = getFont(weight)
	if f then inst.FontFace = f else inst.Font = Enum.Font.GothamMedium end
end

local DEFAULTS = {
	Frame = { BorderSizePixel = 0 },
	CanvasGroup = { BorderSizePixel = 0 },
	TextLabel = { BackgroundTransparency = 1, BorderSizePixel = 0, TextColor3 = Color3.new(1, 1, 1), TextSize = 12 },
	TextButton = { BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = "", TextSize = 12 },
	TextBox = { BackgroundTransparency = 1, BorderSizePixel = 0, ClearTextOnFocus = false, TextSize = 12, Text = "" },
	ImageLabel = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	ImageButton = { BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false },
	ScrollingFrame = { BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, CanvasSize = UDim2.new() },
	UIListLayout = { SortOrder = Enum.SortOrder.LayoutOrder },
}
local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }

local function New(class, props, children)
	local inst = Instance.new(class)
	local d = DEFAULTS[class]
	if d then for k, v in pairs(d) do inst[k] = v end end
	local parent
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then parent = v
			elseif k ~= "Weight" then inst[k] = v end
		end
	end
	if TEXT_CLASSES[class] then applyFont(inst, props and props.Weight) end
	if children then for _, c in ipairs(children) do c.Parent = inst end end
	inst.Parent = parent
	return inst
end
Util.New = New

local function Corner(r, parent) return New("UICorner", { CornerRadius = (r == "full") and UDim.new(1, 0) or UDim.new(0, r), Parent = parent }) end
local function Padding(t, r, b, l, parent)
	return New("UIPadding", { PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b), PaddingLeft = UDim.new(0, l), Parent = parent })
end
local function List(parent, props)
	props = props or {}
	props.Parent = parent
	return New("UIListLayout", props)
end
Util.Corner, Util.Padding, Util.List = Corner, Padding, List

local Ease = {
	Smooth = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Fast   = TweenInfo.new(0.12, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
	Slow   = TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Soft   = TweenInfo.new(0.36, Enum.EasingStyle.Sine,  Enum.EasingDirection.InOut),
	Linear = TweenInfo.new(1, Enum.EasingStyle.Linear),
}
Util.Ease = Ease

local function tween(obj, props, info)
	if type(info) == "string" then info = Ease[info] end
	info = info or Ease.Smooth
	local cfg = Library.Config
	if cfg.Animations == false then
		for k, v in pairs(props) do pcall(function() obj[k] = v end) end
		return nil
	end
	if cfg.AnimSpeed ~= 1 and info ~= Ease.Linear then
		info = TweenInfo.new(info.Time / cfg.AnimSpeed, info.EasingStyle, info.EasingDirection, info.RepeatCount, info.Reverses, info.DelayTime)
	end
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end
Util.Tween = tween

local Maid = {}
Maid.__index = Maid
function Maid.new() return setmetatable({ items = {} }, Maid) end
function Maid:Add(x) table.insert(self.items, x) return x end
function Maid:Clean()
	for _, x in ipairs(self.items) do
		local t = typeof(x)
		if t == "RBXScriptConnection" then x:Disconnect()
		elseif t == "Instance" then x:Destroy()
		elseif type(x) == "function" then pcall(x)
		elseif type(x) == "table" and x.Destroy then pcall(x.Destroy, x) end
	end
	self.items = {}
end
Util.Maid = Maid
Library._maid = Maid.new()
local function connect(signal, fn) return Library._maid:Add(signal:Connect(fn)) end
Util.Connect = connect

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function round(v, inc)
	inc = inc or 1
	if inc == 0 then return v end
	local r = math.floor(v / inc + 0.5) * inc
	local decimals = 0
	local s = tostring(inc)
	local dot = s:find("%.")
	if dot then decimals = #s - dot end
	local m = 10 ^ decimals
	return math.floor(r * m + 0.5) / m
end
local function lerp(a, b, t) return a + (b - a) * t end
local function trim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
local function kp(t, v) return NumberSequenceKeypoint.new(t, v) end
local function safe(fn, ...)
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[Library] callback error: " .. tostring(err)) end
end
local function isTouch() return UIS.TouchEnabled and not UIS.KeyboardEnabled end
Util.Clamp, Util.Round, Util.Lerp, Util.Trim, Util.KP, Util.Safe, Util.IsTouch = clamp, round, lerp, trim, kp, safe, isTouch

-- Runs fn in its own thread and waits at most `seconds`. Returns finished, result.
function Util.Await(fn, seconds)
	local done, result = false, nil
	spawn(function()
		local ok, r = pcall(fn)
		if ok then result = r end
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < seconds do wait() end
	return done, result
end

-- Drag helper: mouse + touch. onMove(position, began)
function Util.Drag(hit, onMove, onEnd)
	hit.InputBegan:Connect(function(input)
		local ut = input.UserInputType
		if ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch then
			onMove(input.Position, true)
			local c1, c2
			c1 = UIS.InputChanged:Connect(function(i)
				if i == input or (ut == Enum.UserInputType.MouseButton1 and i.UserInputType == Enum.UserInputType.MouseMovement) then
					onMove(i.Position, false)
				end
			end)
			c2 = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					c1:Disconnect(); c2:Disconnect()
					if onEnd then onEnd() end
				end
			end)
		end
	end)
end

local function fmtTime(sec)
	sec = math.floor(sec)
	local h, m, s = math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60
	if h > 0 then return ("%d:%02d:%02d"):format(h, m, s) end
	return ("%02d:%02d"):format(m, s)
end
Util.FormatTime = fmtTime

-- Class tables (filled in later sections)
local Window, Tab, Section, Card = {}, {}, {}, {}
Library.Classes = { Window = Window, Tab = Tab, Section = Section, Card = Card }

-- Sounds: none by default. Define them yourself:  CreateWindow{ Sounds = { Click = "rbxassetid://123" } }
local Sound = { Cache = {} }
Library.Sound = Sound
function Sound.Play(name, speedMul, volMul)
	local cfg = Library.Config
	local def = cfg.SoundsEnabled and cfg.Sounds[name]
	if not def then return end
	if type(def) == "string" or type(def) == "number" then def = { Id = def } end
	local id = type(def.Id) == "number" and ("rbxassetid://" .. def.Id) or def.Id
	local s = Sound.Cache[name]
	if not s or not s.Parent then
		s = Instance.new("Sound")
		s.Name = "UI_" .. name
		s.Parent = Library.Gui or SoundService
		Sound.Cache[name] = s
	end
	if s.SoundId ~= id then s.SoundId = id end
	s.Volume = (def.Volume or 0.4) * (volMul or 1) * cfg.SoundVolume
	s.PlaybackSpeed = (def.Speed or 1) * (speedMul or 1)
	s.TimePosition = 0
	s:Play()
end

----------------------------------------------------------------------------
-- 3. THEMES  (16 dark + 1 light, each a full palette)
----------------------------------------------------------------------------
-- Tokens: Window Header Sidebar Content Card CardAlt Hover Track Knob Text SubText Muted
--         Accent AccentSoft AccentGlow OnAccent Rim Grid Danger Success Warning
local function mkTheme(o)
	local acc = o.accent
	local h, s0, v0 = Color3.toHSV(acc)
	h = o.hue or h
	local ns, b, light = o.sat or 0.3, o.base or 0.06, o.light == true
	local function t(v, sat) return Color3.fromHSV(h, clamp(sat == nil and ns or sat, 0, 1), clamp(v, 0, 1)) end
	local lum = 0.299 * acc.R + 0.587 * acc.G + 0.114 * acc.B
	local th = {
		Name = o.name, IsLight = light, Accent = acc,
		AccentSoft = Color3.fromHSV(h, math.min(1, s0 + 0.05), v0 * (light and 0.82 or 0.68)),
		AccentGlow = Color3.fromHSV(h, s0 * 0.55, math.min(1, v0 + 0.12)),
		OnAccent = lum > 0.6 and Color3.fromRGB(12, 13, 16) or Color3.new(1, 1, 1),
	}
	if light then
		th.Window, th.Header, th.Sidebar, th.Content = t(0.955, ns * 0.15), t(0.985, ns * 0.1), t(0.93, ns * 0.15), t(0.96, ns * 0.12)
		th.Card, th.CardAlt, th.Hover, th.Track = Color3.new(1, 1, 1), t(0.925, ns * 0.15), t(0.885, ns * 0.15), t(0.8, ns * 0.2)
		th.Text, th.SubText, th.Muted, th.Knob = t(0.09, 0.2), t(0.36, 0.15), t(0.56, 0.1), Color3.new(1, 1, 1)
		th.Rim, th.Grid = Color3.new(0, 0, 0), Color3.new(0, 0, 0)
		th.Danger, th.Success, th.Warning = Color3.fromRGB(220, 52, 80), Color3.fromRGB(22, 163, 100), Color3.fromRGB(217, 140, 20)
	else
		th.Window, th.Header, th.Sidebar, th.Content = t(b), t(b + 0.022), t(b + 0.01), t(b + 0.016)
		th.Card, th.CardAlt, th.Hover, th.Track = t(b + 0.058, ns * 0.9), t(b + 0.098, ns * 0.85), t(b + 0.14, ns * 0.8), t(b + 0.19, ns * 0.8)
		th.Text, th.SubText, th.Muted, th.Knob = t(0.96, 0.04), t(0.7, ns * 0.35), t(0.47, ns * 0.4), t(0.97, 0.04)
		th.Rim, th.Grid = Color3.new(1, 1, 1), Color3.new(1, 1, 1)
		th.Danger, th.Success, th.Warning = Color3.fromRGB(242, 82, 108), Color3.fromRGB(70, 222, 148), Color3.fromRGB(250, 188, 68)
	end
	return th
end

local Theme = { Current = nil, Name = nil, Bound = setmetatable({}, { __mode = "k" }), Listeners = {}, Gradients = setmetatable({}, { __mode = "k" }) }
Library.Theme = Theme

local function resolve(tok)
	local ty = type(tok)
	if ty == "string" then return Theme.Current[tok] or Color3.new(1, 0, 1) end
	if ty == "function" then return tok(Theme.Current) end
	return tok
end
Theme.Resolve = resolve

function Theme.Register(name, spec)
	local t
	if typeof(spec) == "Color3" then
		t = mkTheme({ name = name, accent = spec })
	elseif type(spec) == "table" then
		t = spec.Accent and mkTheme({ name = name, accent = spec.Accent, sat = spec.NeutralSaturation, base = spec.Base, light = spec.Light, hue = spec.Hue })
			or mkTheme({ name = name, accent = Color3.fromRGB(226, 226, 232), sat = 0, base = 0.1 })
		for k, v in pairs(spec) do if typeof(v) == "Color3" then t[k] = v end end
	end
	if not t then return end
	t.Name = name
	if not Library.Themes[name] then table.insert(Library.ThemeOrder, name) end
	Library.Themes[name] = t
end

-- 16 dark themes + 1 light theme. Graphite is the default (neutral gray with black gradients).
for _, d in ipairs({
	{ "Graphite", Color3.fromRGB(226, 226, 232), 0, 0.105 },
	{ "Obsidian", Color3.fromRGB(240, 240, 245), 0, 0.04 },
	{ "Purple",   Color3.fromRGB(150, 94, 255), 0.36, 0.058 },
	{ "Violet",   Color3.fromRGB(124, 112, 255), 0.4, 0.062 },
	{ "Cyan",     Color3.fromRGB(34, 211, 238), 0.34, 0.058 },
	{ "Ocean",    Color3.fromRGB(74, 138, 255), 0.36, 0.06 },
	{ "Midnight", Color3.fromRGB(96, 165, 250), 0.52, 0.045 },
	{ "Emerald",  Color3.fromRGB(52, 211, 153), 0.34, 0.056 },
	{ "Forest",   Color3.fromRGB(110, 214, 120), 0.4, 0.052 },
	{ "Crimson",  Color3.fromRGB(242, 72, 96), 0.36, 0.058 },
	{ "Rose",     Color3.fromRGB(244, 114, 182), 0.3, 0.062 },
	{ "Sunset",   Color3.fromRGB(251, 121, 60), 0.36, 0.058 },
	{ "Amber",    Color3.fromRGB(251, 176, 64), 0.34, 0.058 },
	{ "Mocha",    Color3.fromRGB(214, 160, 110), 0.3, 0.07, 0.07 },
	{ "Slate",    Color3.fromRGB(148, 163, 184), 0.22, 0.09, 0.6 },
	{ "Mono",     Color3.fromRGB(255, 255, 255), 0, 0.02 },
}) do
	table.insert(Library.ThemeOrder, d[1])
	Library.Themes[d[1]] = mkTheme({ name = d[1], accent = d[2], sat = d[3], base = d[4], hue = d[5] })
end
do
	Library.Themes.Light = mkTheme({ name = "Light", accent = Color3.fromRGB(37, 99, 235), sat = 0.12, light = true })
	table.insert(Library.ThemeOrder, "Light")
end
Theme.Current, Theme.Name = Library.Themes.Graphite, "Graphite"

-- Bind properties to theme tokens: Theme.Bind(frame, { BackgroundColor3 = "Card" })
-- A token can be a name, a Color3, or a function(theme) -> Color3.
function Theme.Bind(inst, props)
	local b = Theme.Bound[inst]
	if not b then b = {}; Theme.Bound[inst] = b end
	for k, tok in pairs(props) do
		b[k] = tok
		inst[k] = resolve(tok)
	end
	return inst
end

-- "Gray with black gradients": a black shade child that fades in toward the bottom of a surface.
-- It is a plain Frame (never a gradient on a CanvasGroup, which would tint the content too) and re-tunes on theme change.
local function shadeSeq(strength)
	local s = Theme.Current.IsLight and strength * 0.22 or strength
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 1 - s) })
end
function Theme.Gradient(frame, strength, rotation)
	local cr = frame:FindFirstChildOfClass("UICorner")
	local shade = New("Frame", { Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 0, Parent = frame })
	if cr then New("UICorner", { CornerRadius = cr.CornerRadius, Parent = shade }) end
	local g = New("UIGradient", { Rotation = rotation or 90, Transparency = shadeSeq(strength), Parent = shade })
	Theme.Gradients[g] = strength
	return g
end

function Theme.Set(name, instant)
	local t = Library.Themes[name]
	if not t then return false end
	Theme.Current, Theme.Name = t, name
	for inst, b in pairs(Theme.Bound) do
		if inst.Parent then
			local goal = {}
			for prop, tok in pairs(b) do goal[prop] = resolve(tok) end
			if instant then
				for prop, val in pairs(goal) do inst[prop] = val end
			else
				tween(inst, goal, Ease.Slow)
			end
		end
	end
	for g, strength in pairs(Theme.Gradients) do
		if g.Parent then g.Transparency = shadeSeq(strength) end
	end
	for _, fn in ipairs(Theme.Listeners) do pcall(fn, t, name) end
	return true
end

function Theme.OnChange(fn) table.insert(Theme.Listeners, fn) end

----------------------------------------------------------------------------
-- 4. ICONS  (Lucide — only the icons your UI actually uses are loaded, then cached on disk)
----------------------------------------------------------------------------
local Icons = {
	Provider = nil, Size = nil, Cache = {}, Custom = {}, Seen = {}, SeenList = {}, Queue = {}, Warmed = {},
	Bound = setmetatable({}, { __mode = "k" }), Loading = false, Dirty = false, Path = nil, AutoProvider = false,
}
Library.Icons = Icons

local function iconKey(name) return (tostring(name):gsub("^lucide[%-/:]", "")):lower() end

function Icons.LoadCache(path)
	Icons.Path = path
	local raw = FS.read(path)
	local data = raw and jsonDecode(raw)
	if type(data) == "table" and data.res == Library.Config.IconResolution and type(data.icons) == "table" then
		for name, e in pairs(data.icons) do
			if type(e) == "table" and type(e.u) == "string" and e.u:find("^rbxassetid://") then
				Icons.Cache[name] = { Url = e.u, Rect = e.rw and Vector2.new(e.rw, e.rh) or nil, Offset = e.ox and Vector2.new(e.ox, e.oy) or nil }
			end
		end
	end
end

function Icons.SaveCache()
	if not Icons.Path or not Icons.Dirty then return end
	Icons.Dirty = false
	local out = {}
	for name, d in pairs(Icons.Cache) do
		if d and d.Url:find("^rbxassetid://") then
			out[name] = { u = d.Url, rw = d.Rect and d.Rect.X, rh = d.Rect and d.Rect.Y, ox = d.Offset and d.Offset.X, oy = d.Offset and d.Offset.Y }
		end
	end
	local json = jsonEncode({ res = Library.Config.IconResolution, icons = out })
	if json then FS.write(Icons.Path, json) end
end

function Icons.LoadProvider(report)
	local sources = Library.Config.IconSources
	local timeout = Library.Config.LoadTimeout
	for i, url in ipairs(sources) do
		report((i - 1) / #sources, "Fetching icon pack", ("%d / %d"):format(i, #sources))
		local done, src = Util.Await(function() return httpGet(url) end, timeout)
		local fn = done and src and loadstr and loadstr(src)
		if fn then
			local fin, mod = Util.Await(function()
				local ok, m = pcall(fn)
				return ok and m or nil
			end, timeout)
			if fin and type(mod) == "table" and type(mod.GetAsset) == "function" then
				for _, size in ipairs({ Library.Config.IconResolution, 48, 256, false }) do
					local ok2, test = pcall(mod.GetAsset, "house", size or nil)
					if ok2 and type(test) == "table" and test.Url then
						Icons.Provider, Icons.Size = mod, size or nil
						report(1, "Icon pack ready", "")
						return true
					end
				end
			end
		end
	end
	report(1, "Icon pack unavailable", "")
	return false
end

-- Fetches the icon pack in the background the first time an unknown icon is requested after launch
function Icons.EnsureProvider()
	if Icons.Provider or Icons.Loading or Icons.Failed then return end
	Icons.Loading = true
	spawn(function()
		local ok = Icons.LoadProvider(function() end)
		Icons.Loading = false
		if not ok then Icons.Failed, Icons.Queue = true, {} return end
		for key in pairs(Icons.Queue) do Icons.Queue[key] = nil; Icons.Resolve(key) end
		Icons.SaveCache()
		Icons.Refresh()
	end)
end

-- Accepts a lucide name ("house", "lucide-house"), an asset id, a "rbxassetid://" string or a table
function Icons.Resolve(name)
	local ty = type(name)
	if ty == "number" then return { Url = "rbxassetid://" .. name } end
	if ty == "table" then return name end
	if ty ~= "string" or name == "" then return nil end
	if name:find("://", 1, true) then return { Url = name } end
	local key = iconKey(name)
	if Icons.Custom[key] then return Icons.Custom[key] end
	if not Icons.Seen[key] then Icons.Seen[key] = true; table.insert(Icons.SeenList, key) end
	local cached = Icons.Cache[key]
	if cached ~= nil then return cached or nil end
	if not Icons.Provider then
		Icons.Queue[key] = true
		if Icons.AutoProvider and not Icons.Failed then Icons.EnsureProvider() end
		return nil
	end
	local data
	local ok, r = pcall(Icons.Provider.GetAsset, key, Icons.Size)
	if ok and type(r) == "table" and r.Url then
		data = { Url = r.Url, Rect = r.ImageRectSize, Offset = r.ImageRectOffset }
		Icons.Dirty = true
	end
	Icons.Cache[key] = data or false
	return data
end

function Icons.Apply(img, name)
	local d = Icons.Resolve(name)
	if d then
		img.Image = d.Url
		img.ImageRectSize = d.Rect or Vector2.new(0, 0)
		img.ImageRectOffset = d.Offset or Vector2.new(0, 0)
	else
		img.Image = ""
	end
	return d ~= nil
end

-- Re-applies icons created before their data existed (pack still loading)
function Icons.Refresh()
	for img, name in pairs(Icons.Bound) do
		if img.Parent then Icons.Apply(img, name) end
	end
end

-- Create a themed icon: Icons.New("house", 16, "Text", parent, { Position = ... })
function Icons.New(name, size, token, parent, props)
	props = props or {}
	props.Size = props.Size or UDim2.fromOffset(size, size)
	props.Parent = parent
	props.ScaleType = Enum.ScaleType.Fit
	local img = New("ImageLabel", props)
	Icons.Apply(img, name)
	Icons.Bound[img] = name
	Theme.Bind(img, { ImageColor3 = token or "Text" })
	return img
end
function Icons.Set(img, name) Icons.Bound[img] = name; Icons.Apply(img, name) end

-- Register your own icon (any rbxassetid) so it works everywhere a name does
function Icons.Register(name, assetId, rectSize, rectOffset)
	Icons.Custom[name:lower()] = {
		Url = type(assetId) == "number" and ("rbxassetid://" .. assetId) or assetId,
		Rect = rectSize, Offset = rectOffset,
	}
end

-- Loader step: resolves exactly the icons the UI uses (+ extras), fetching the pack only if some are not cached.
-- report(fraction, status, detail)
function Icons.Prepare(report, extra)
	local names, set = {}, {}
	for _, k in ipairs(Icons.SeenList) do if not set[k] then set[k] = true; table.insert(names, k) end end
	for _, n in ipairs(extra or {}) do
		local k = iconKey(n)
		if not set[k] and not Icons.Custom[k] then set[k] = true; table.insert(names, k) end
	end
	local n = #names
	local missing = 0
	for _, k in ipairs(names) do if Icons.Cache[k] == nil then missing = missing + 1 end end
	local base = 0
	if missing > 0 and not Icons.Provider then
		if not Icons.LoadProvider(function(f, s, d) report(f * 0.55, s, d) end) then Icons.Failed = true end
		base = 0.55
	end
	for i, k in ipairs(names) do
		Icons.Resolve(k)
		report(base + (0.35 * i / n) * (1 - base), "Loading icons", ("%d / %d"):format(i, n))
		if i % 4 == 0 then wait() end
	end
	local urls, seen = {}, {}
	for _, k in ipairs(names) do
		local d = Icons.Cache[k]
		if d and d.Url and not seen[d.Url] and not Icons.Warmed[d.Url] then seen[d.Url] = true; table.insert(urls, d.Url) end
	end
	if #urls > 0 and ContentProvider then
		report(0.92, "Rendering icons", "")
		local holders = {}
		for _, url in ipairs(urls) do
			table.insert(holders, New("ImageLabel", { Image = url, Size = UDim2.fromOffset(1, 1), ImageTransparency = 0.99 }))
			Icons.Warmed[url] = true
		end
		Util.Await(function() ContentProvider:PreloadAsync(holders) end, Library.Config.PreloadTimeout)
		for _, h in ipairs(holders) do h:Destroy() end
	end
	Icons.AutoProvider = true
	Icons.SaveCache()
	Icons.Refresh()
	report(1, "Loading icons", ("%d / %d"):format(n, n))
	return n
end

----------------------------------------------------------------------------
-- 5. EFFECTS & COMPONENTS
----------------------------------------------------------------------------
local Effects = {}
Library.Effects = Effects

-- Per-layer opacities so stacked translucent layers add up to a smooth falloff (1 = innermost)
local function layerAlphas(n, peak, power)
	local out, cum = {}, 0
	for i = n, 1, -1 do
		local rho = (i - 0.5) / n
		local target = peak * (1 - rho) ^ power
		local a = 1 - (1 - target) / (1 - cum)
		a = math.max(0, math.min(0.98, a))
		out[i] = a
		cum = 1 - (1 - cum) * (1 - a)
	end
	return out
end

-- Shadows are always black and small. Config.Shadows: "Contact" (crisp 2px, default) | "Soft" | "None"
-- Group = true returns a CanvasGroup you can fade with GroupTransparency.
function Effects.Shadow(parent, o)
	o = o or {}
	local mode = Library.Config.Shadows
	local soft = mode == "Soft"
	local spread = o.Spread or (soft and 10 or 2)
	local n = (mode == "None") and 0 or (soft and (o.Layers or 7) or 2)
	local alphas = layerAlphas(math.max(n, 1), o.Strength or (soft and 0.5 or 0.36), soft and 2 or 1.2)
	local box = New(o.Group and "CanvasGroup" or "Frame", {
		Name = "Shadow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, o.OffsetY or (soft and 4 or 2)),
		Size = UDim2.new(1, spread * 2, 1, spread * 2), BackgroundTransparency = 1, ZIndex = o.ZIndex or 0, Parent = parent,
	})
	if o.Group and o.Hidden then box.GroupTransparency = 1 end
	for i = 1, n do
		local e = spread * i / n
		local layer = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -spread * 2 + e * 2, 1, -spread * 2 + e * 2),
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1 - alphas[i], Parent = box,
		})
		Corner((o.Radius or M.Radius) + e, layer)
	end
	return box
end

-- 1px border that fades along a gradient, built from two nested frames (no UIStroke).
-- Returns outer, inner, rim. Put your content in `inner`.
local RIM_OFFSET = { [0] = 0, [1] = 0.3, [2] = 0.62 }
function Effects.Bordered(parent, o)
	o = o or {}
	local r, t = o.Radius or M.Radius, o.Border or 1
	local outer = New("Frame", {
		Name = o.Name or "Rim", Size = o.Size or UDim2.fromScale(1, 1), Position = o.Position, AnchorPoint = o.AnchorPoint,
		LayoutOrder = o.LayoutOrder or 0, ZIndex = o.ZIndex or 1, BackgroundColor3 = Color3.new(1, 1, 1), Parent = parent,
	})
	Corner(r, outer)
	local top = o.Top or 0.86
	local grad = New("UIGradient", {
		Rotation = o.Rotation or 90, Parent = outer,
		Transparency = NumberSequence.new({ kp(0, top), kp(0.5, math.min(1, top + 0.1)), kp(1, 1) }),
	})
	local inner = New(o.Class or "Frame", {
		Name = "Body", Size = UDim2.new(1, -t * 2, 1, -t * 2), Position = UDim2.fromOffset(t, t), ZIndex = 1, Parent = outer,
	})
	Corner(math.max(0, r - t), inner)
	if o.Fill then Theme.Bind(inner, { BackgroundColor3 = o.Fill }) end
	local rim = { Outer = outer, Grad = grad }
	Theme.Bind(outer, { BackgroundColor3 = function(th) return rim._color or th.Rim end })
	-- level: 0 rest · 1 hover · 2 active/focus   (color optional; nil = theme rim colour)
	function rim:Set(level, color)
		rim._color = color
		tween(grad, { Offset = Vector2.new(0, RIM_OFFSET[level] or 0) }, Ease.Smooth)
		tween(outer, { BackgroundColor3 = color or resolve("Rim") }, Ease.Smooth)
	end
	function rim:Flash(color)
		rim._color = color
		outer.BackgroundColor3 = color
		grad.Offset = Vector2.new(0, 0.9)
		tween(grad, { Offset = Vector2.new(0, 0) }, Ease.Slow)
		delay(0.6, function() if outer.Parent then rim:Set(0) end end)
	end
	return outer, inner, rim
end

-- Hover colour shift + rim brighten + press shade. Works on any GuiObject (press needs a GuiButton).
function Effects.Interact(body, o)
	o = o or {}
	local cr = body:FindFirstChildOfClass("UICorner")
	local press = New("Frame", {
		Name = "Press", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1, ZIndex = o.ZIndex or 4, Parent = body,
	})
	if cr then New("UICorner", { CornerRadius = cr.CornerRadius, Parent = press }) end
	body.MouseEnter:Connect(function()
		Sound.Play("Hover")
		if o.Hover then tween(body, { BackgroundColor3 = resolve(o.Hover) }, Ease.Fast) end
		if o.Rim then o.Rim:Set(1, o.RimColor) end
	end)
	body.MouseLeave:Connect(function()
		if o.Base then tween(body, { BackgroundColor3 = resolve(o.Base) }, Ease.Smooth) end
		if o.Rim then o.Rim:Set(0) end
		tween(press, { BackgroundTransparency = 1 }, Ease.Fast)
	end)
	if body:IsA("GuiButton") then
		body.MouseButton1Down:Connect(function()
			tween(press, { BackgroundTransparency = 0.9 }, Ease.Fast)
			if o.Rim then o.Rim:Set(2, o.RimColor) end
		end)
		body.MouseButton1Up:Connect(function()
			tween(press, { BackgroundTransparency = 1 }, Ease.Smooth)
			if o.Rim then o.Rim:Set(1, o.RimColor) end
		end)
	end
	return press
end

-- Brand mark: your logo image, a Lucide icon, or (default) a monogram of the name
function Effects.BrandMark(parent, cfg, o)
	local size = o.Size or 24
	local outer, body = Effects.Bordered(parent, {
		Radius = math.floor(size * 0.3), Fill = "Accent", Top = 0.6, Size = UDim2.fromOffset(size, size),
		Position = o.Position, AnchorPoint = o.AnchorPoint, ZIndex = o.ZIndex or 2, Name = "BrandMark",
	})
	if cfg.Logo then
		New("ImageLabel", { Image = tostring(cfg.Logo):find("://") and cfg.Logo or ("rbxassetid://" .. cfg.Logo), Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit, Parent = body })
	elseif cfg.Icon then
		Icons.New(cfg.Icon, math.floor(size * 0.58), "OnAccent", body, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	else
		local t = New("TextLabel", { Text = tostring(cfg.Name or "L"):sub(1, 1):upper(), TextSize = math.floor(size * 0.52), Weight = "Bold", Size = UDim2.fromScale(1, 1), Parent = body })
		Theme.Bind(t, { TextColor3 = "OnAccent" })
	end
	return outer
end

-- Hairline that fades out at both ends
function Effects.Hairline(parent, props)
	props.BackgroundTransparency = props.BackgroundTransparency or 0.9
	props.Parent = parent
	local vertical = props.Vertical
	props.Vertical = nil
	local l = New("Frame", props)
	Theme.Bind(l, { BackgroundColor3 = "Rim" })
	New("UIGradient", { Transparency = NumberSequence.new({ kp(0, 1), kp(0.5, 0), kp(1, 1) }), Rotation = vertical and 90 or 0, Parent = l })
	return l
end

----------------------------------------------------------------------------
-- Background: static dot field or grid that fades out from the top centre (no cursor effects)
----------------------------------------------------------------------------
function Effects.Background(parent, size, style)
	local self = { Style = style or "Dots", Size = size }
	local root = New("Frame", {
		Name = "Background", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		ClipsDescendants = true, ZIndex = 0, Parent = parent,
	})
	local layer = New("Frame", { Name = "Layer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0, Parent = root })
	local function smooth(x) x = clamp(x, 0, 1); return x * x * (3 - 2 * x) end

	function self:Build(newStyle, newSize)
		self.Style = newStyle or self.Style
		self.Size = newSize or self.Size
		layer:ClearAllChildren()
		local W, H = self.Size.X, self.Size.Y
		local gc = resolve("Grid")
		if self.Style == "Dots" then
			local cell = 20
			local cols, rows = math.ceil(W / cell), math.ceil(H / cell)
			for r = 0, rows do
				for c = 0, cols do
					local nx, ny = (c / cols - 0.5) * 2, r / rows
					local d = math.sqrt(nx * nx * 0.55 + ny * ny * 1.15)
					local tr = lerp(0.9, 0.995, smooth(d ^ 1.2))
					if tr < 0.99 then
						local f = New("Frame", {
							Size = UDim2.fromOffset(2, 2), Position = UDim2.fromOffset(c * cell + 9, r * cell + 9),
							BackgroundColor3 = gc, BackgroundTransparency = tr, ZIndex = 0, Parent = layer,
						})
						Corner("full", f)
						f:SetAttribute("Bg", true)
					end
				end
			end
		elseif self.Style == "Grid" then
			local cell = 28
			for c = 0, math.ceil(W / cell) do
				local x = c * cell + 8
				local tr = lerp(0.945, 0.99, smooth(math.abs(x - W / 2) / (W / 2)))
				local l = New("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromOffset(x, 0), BackgroundColor3 = gc, BackgroundTransparency = tr, ZIndex = 0, Parent = layer })
				New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 0), kp(0.5, 0.55), kp(1, 1) }), Parent = l })
			end
			for r = 0, math.ceil(H / cell) do
				local y = r * cell + 8
				local tr = lerp(0.945, 0.99, smooth(y / H))
				local l = New("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, y), BackgroundColor3 = gc, BackgroundTransparency = tr, ZIndex = 0, Parent = layer })
				New("UIGradient", { Transparency = NumberSequence.new({ kp(0, 1), kp(0.5, 0), kp(1, 1) }), Parent = l })
			end
		end
	end

	Theme.OnChange(function()
		if not root.Parent then return end
		local gc = resolve("Grid")
		for _, f in ipairs(layer:GetChildren()) do f.BackgroundColor3 = gc end
	end)
	function self:SetEnabled() end
	function self:Destroy() root:Destroy() end
	self.Root = root
	self:Build()
	return self
end

----------------------------------------------------------------------------
-- Tooltip (one shared instance, follows the cursor)
----------------------------------------------------------------------------
local Tooltip = { Token = 0 }
local function tipFrame()
	if Tooltip.Frame and Tooltip.Frame.Parent then return Tooltip.Frame end
	local f = New("Frame", { Name = "Tooltip", AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), Visible = false, ZIndex = 90, Parent = Library.Gui })
	Corner(6, f)
	Theme.Bind(f, { BackgroundColor3 = "CardAlt" })
	Padding(5, 8, 5, 8, f)
	Tooltip.Scale = New("UIScale", { Parent = f })
	Tooltip.Label = New("TextLabel", { Text = "", TextSize = 11, AutomaticSize = Enum.AutomaticSize.XY, TextWrapped = false, Size = UDim2.fromOffset(0, 0), Parent = f })
	Theme.Bind(Tooltip.Label, { TextColor3 = "Text" })
	Tooltip.Frame = f
	connect(RunService.Heartbeat, function()
		if not f.Visible then return end
		local m = UIS:GetMouseLocation()
		local vp = Library.Gui.AbsoluteSize
		local x = clamp(m.X + 12, 4, vp.X - f.AbsoluteSize.X - 4)
		local y = clamp(m.Y + 16, 4, vp.Y - f.AbsoluteSize.Y - 4)
		f.Position = UDim2.fromOffset(x, y)
	end)
	return f
end

function Effects.Tooltip(obj, text)
	local state = { Text = text }
	obj.MouseEnter:Connect(function()
		if not state.Text or state.Text == "" then return end
		Tooltip.Token = Tooltip.Token + 1
		local my = Tooltip.Token
		delay(0.45, function()
			if Tooltip.Token ~= my or not obj.Parent then return end
			local f = tipFrame()
			Tooltip.Label.Text = state.Text
			Tooltip.Scale.Scale = Library.UIScale or 1
			f.Visible = true
		end)
	end)
	local function hide()
		Tooltip.Token = Tooltip.Token + 1
		if Tooltip.Frame then Tooltip.Frame.Visible = false end
	end
	obj.MouseLeave:Connect(hide)
	if obj:IsA("GuiButton") then obj.MouseButton1Down:Connect(hide) end
	return state
end

----------------------------------------------------------------------------
-- Components shared by loader, key system, dialogs and elements
----------------------------------------------------------------------------
local Components = {}
Library.Components = Components

local function onAccent(t) return t.OnAccent end
local BUTTON_STYLES = {
	Primary = { Base = "Accent", Hover = function(t) return t.Accent:Lerp(t.AccentGlow, 0.35) end, Text = onAccent, RimTop = 0.6, Shadow = true },
	Secondary = { Base = "CardAlt", Hover = "Hover", Text = "Text", RimTop = 0.88, Shadow = true },
	Danger = { Base = "Danger", Hover = function(t) return t.Danger:Lerp(Color3.new(1, 1, 1), 0.14) end, Text = Color3.new(1, 1, 1), RimTop = 0.6, Shadow = true },
	Success = { Base = "Success", Hover = function(t) return t.Success:Lerp(Color3.new(1, 1, 1), 0.14) end, Text = Color3.fromRGB(8, 20, 14), RimTop = 0.6, Shadow = true },
	Ghost = { Base = "Card", Hover = "CardAlt", Text = "SubText", RimTop = 0.94 },
}
Components.ButtonStyles = BUTTON_STYLES

-- o: Text, Icon, RightIcon, Style (Primary|Secondary|Danger|Success|Ghost), Align ("Center"|"Left"), Height, Size, Position, Callback
function Components.Button(parent, o)
	o = o or {}
	local st = BUTTON_STYLES[o.Style or "Secondary"] or BUTTON_STYLES.Secondary
	local H = o.Height or M.Button
	local holder = New("Frame", {
		Name = o.Name or "Button", BackgroundTransparency = 1, Size = o.Size or UDim2.new(1, 0, 0, H),
		Position = o.Position, AnchorPoint = o.AnchorPoint, LayoutOrder = o.LayoutOrder or 0, Parent = parent,
	})
	if st.Shadow then Effects.Shadow(holder, { Radius = M.Radius, Strength = 0.3, Spread = 2, OffsetY = 1 }) end
	local _, body, rim = Effects.Bordered(holder, { Class = "TextButton", Radius = M.Radius, Fill = st.Base, Top = st.RimTop })

	local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = body })
	local left = o.Align == "Left"
	List(row, {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = left and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6),
	})
	if left then Padding(0, 8, 0, 9, row) end
	local icon
	if o.Icon then icon = Icons.New(o.Icon, o.IconSize or 13, st.Text, row, { ZIndex = 3, LayoutOrder = 1 }) end
	local label = New("TextLabel", {
		Text = o.Text or "Button", TextSize = o.TextSize or 12, Weight = "SemiBold", AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14), ZIndex = 3, LayoutOrder = 2, Parent = row,
	})
	Theme.Bind(label, { TextColor3 = st.Text })
	if o.Text == "" then label.Visible = false end
	if o.RightIcon then
		local ri = Icons.New(o.RightIcon, 12, "Muted", body, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0), ZIndex = 3 })
	end
	Effects.Interact(body, { Base = st.Base, Hover = st.Hover, Rim = rim })

	local obj = { Holder = holder, Body = body, Label = label, Icon = icon, Rim = rim, Enabled = true, Callback = o.Callback }
	body.MouseButton1Click:Connect(function()
		if not obj.Enabled then return end
		Sound.Play("Click")
		safe(obj.Callback)
	end)
	function obj:SetText(t) label.Text = t end
	function obj:SetCallback(fn) obj.Callback = fn end
	function obj:SetIcon(n) if icon then Icons.Set(icon, n) end end
	function obj:SetEnabled(b)
		obj.Enabled = b
		tween(label, { TextTransparency = b and 0 or 0.55 }, Ease.Fast)
		if icon then tween(icon, { ImageTransparency = b and 0 or 0.55 }, Ease.Fast) end
	end
	function obj:Destroy() holder:Destroy() end
	return obj
end

-- Text field with focus rim. o: Placeholder, Text, Icon, Numeric, Live, OnChange, Callback(text, enterPressed), Align, Multiline
function Components.Field(parent, o)
	o = o or {}
	local wrap, holder, rim = Effects.Bordered(parent, {
		Name = "Field", Radius = M.Radius, Fill = o.Token or "CardAlt", Top = 0.9, Size = o.Size or UDim2.new(1, 0, 0, M.Field),
		Position = o.Position, AnchorPoint = o.AnchorPoint, LayoutOrder = o.LayoutOrder or 0,
	})
	local left = 9
	local icon
	if o.Icon then
		icon = Icons.New(o.Icon, 13, "Muted", holder, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0) })
		left = 28
	end
	local box = New("TextBox", {
		Size = UDim2.new(1, -(left + 8), 1, o.Multiline and -8 or 0), Position = UDim2.fromOffset(left, o.Multiline and 4 or 0),
		PlaceholderText = o.Placeholder or "", Text = o.Text or "", TextSize = o.TextSize or 12,
		TextXAlignment = o.Align or Enum.TextXAlignment.Left, ClipsDescendants = true, Parent = holder,
		MultiLine = o.Multiline or false, TextWrapped = o.Multiline or false,
		TextYAlignment = o.Multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
	})
	Theme.Bind(box, { TextColor3 = "Text", PlaceholderColor3 = "Muted" })

	local obj = { Frame = wrap, Box = box, Rim = rim }
	holder.MouseEnter:Connect(function() if not box:IsFocused() then rim:Set(1) end end)
	holder.MouseLeave:Connect(function() if not box:IsFocused() then rim:Set(0) end end)
	box.Focused:Connect(function()
		rim:Set(2, resolve("Accent"))
		if icon then tween(icon, { ImageColor3 = resolve("Accent") }, Ease.Fast) end
	end)
	box.FocusLost:Connect(function(enter)
		rim:Set(0)
		if icon then tween(icon, { ImageColor3 = resolve("Muted") }, Ease.Smooth) end
		if o.Numeric then box.Text = (box.Text:gsub("[^%d%.%-]", "")) end
		safe(o.Callback, box.Text, enter)
	end)
	if o.Live or o.Numeric then
		box:GetPropertyChangedSignal("Text"):Connect(function()
			if o.Numeric then
				local f = box.Text:gsub("[^%d%.%-]", "")
				if f ~= box.Text then box.Text = f end
			end
			if o.Live then safe(o.OnChange, box.Text) end
		end)
	end
	function obj.Set(t) box.Text = tostring(t) end
	function obj.Get() return box.Text end
	function obj.Flash(tok) rim:Flash(resolve(tok)) end
	return obj
end

-- Small pill label: Components.Badge(parent, "NEW", "Accent")
function Components.Badge(parent, text, token, props)
	props = props or {}
	props.Text, props.TextSize, props.Weight = tostring(text), 9.5, "SemiBold"
	props.AutomaticSize, props.Size, props.Parent = Enum.AutomaticSize.X, UDim2.fromOffset(0, 15), parent
	local b = New("TextLabel", props)
	Padding(0, 6, 0, 6, b)
	Corner("full", b)
	b.BackgroundTransparency = 0.86
	Theme.Bind(b, { BackgroundColor3 = token or "Accent", TextColor3 = token or "Accent" })
	return b
end

----------------------------------------------------------------------------
-- 6. NOTIFICATIONS
----------------------------------------------------------------------------
local Notify = { Items = {}, Counter = 0 }
Library._notify = Notify
local N_ICON = { Info = "info", Success = "circle-check", Warning = "triangle-alert", Error = "circle-alert" }
local N_TOKEN = { Info = "Accent", Success = "Success", Warning = "Warning", Error = "Danger" }

function Notify.Init(gui)
	local holder = New("Frame", {
		Name = "Notifications", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(264, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 80, Parent = gui,
	})
	List(holder, { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right })
	Notify.Scale = New("UIScale", { Parent = holder })
	Notify.Holder = holder
end

-- Library:Notify{ Title, Content, Type = "Info|Success|Warning|Error", Duration, Icon }
function Notify.Push(o)
	if not Notify.Holder then return end
	if type(o) == "string" then o = { Content = o } end
	local typ = N_ICON[o.Type] and o.Type or "Info"
	local tok = N_TOKEN[typ]
	Notify.Counter = Notify.Counter + 1

	local wrap = New("Frame", {
		Name = "Notification", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = Notify.Counter, Parent = Notify.Holder,
	})
	local shadow = Effects.Shadow(wrap, { Radius = 8, Group = true, Hidden = true })
	local card = New("CanvasGroup", {
		Name = "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(34, 0), GroupTransparency = 1, Parent = wrap,
	})
	Corner(8, card)
	Theme.Bind(card, { BackgroundColor3 = "Card" })
	local content = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
	Padding(10, 12, 12, 14, content)
	Icons.New(o.Icon or N_ICON[typ], 16, tok, content, { Position = UDim2.fromOffset(0, 1) })
	local texts = New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, Parent = content,
	})
	List(texts, { Padding = UDim.new(0, 1) })
	local title = New("TextLabel", {
		Text = o.Title or typ, TextSize = 12.5, Weight = "SemiBold", TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, Parent = texts,
	})
	Theme.Bind(title, { TextColor3 = "Text" })
	if o.Content and o.Content ~= "" then
		local body = New("TextLabel", {
			Text = o.Content, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2, Parent = texts,
		})
		Theme.Bind(body, { TextColor3 = "SubText" })
	end
	local bar = New("Frame", { Size = UDim2.new(0, 2, 1, 0), Parent = card })
	Theme.Bind(bar, { BackgroundColor3 = tok })
	local prog = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 0.6, Parent = card })
	Theme.Bind(prog, { BackgroundColor3 = tok })
	local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = card })

	local entry = { Wrap = wrap }
	local dead = false
	function entry.Dismiss()
		if dead then return end
		dead = true
		for i, v in ipairs(Notify.Items) do if v == entry then table.remove(Notify.Items, i) break end end
		tween(card, { GroupTransparency = 1, Position = UDim2.fromOffset(34, 0) }, Ease.Smooth)
		tween(shadow, { GroupTransparency = 1 }, Ease.Smooth)
		delay(0.22, function()
			if not wrap.Parent then return end
			local h = wrap.AbsoluteSize.Y / math.max(Notify.Scale.Scale, 0.01)
			wrap.AutomaticSize = Enum.AutomaticSize.None
			wrap.Size = UDim2.new(1, 0, 0, h)
			tween(wrap, { Size = UDim2.new(1, 0, 0, 0) }, Ease.Smooth)
			delay(0.28, function() wrap:Destroy() end)
		end)
	end
	hit.MouseButton1Click:Connect(entry.Dismiss)
	table.insert(Notify.Items, entry)
	if #Notify.Items > 5 then Notify.Items[1].Dismiss() end

	tween(card, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Ease.Smooth)
	tween(shadow, { GroupTransparency = 0 }, Ease.Smooth)
	local dur = o.Duration or 4
	tween(prog, { Size = UDim2.new(0, 0, 0, 2) }, TweenInfo.new(dur, Enum.EasingStyle.Linear))
	delay(dur, entry.Dismiss)
	Sound.Play("Notify")
	return entry
end

----------------------------------------------------------------------------
-- 7. DIALOGS & POPUPS
----------------------------------------------------------------------------
local Dialogs = {}
Library.Dialogs = Dialogs
local D_TOKEN = { Info = "Accent", Success = "Success", Warning = "Warning", Danger = "Danger", Error = "Danger" }
local D_ICON = { Info = "info", Success = "circle-check", Warning = "triangle-alert", Danger = "triangle-alert", Error = "circle-alert" }

-- Modal dialog on top of `host` (a window's Main frame, or the ScreenGui).
-- o: Title, Content, Type ("Info"|"Success"|"Warning"|"Danger"), Icon, Width, Dismissable,
--    Input = { Placeholder, Default, Multiline }, OnClose,
--    Buttons = { { Title, Variant = "Primary|Secondary|Danger|Success|Ghost", Callback = function(inputText) return false to keep open end, Close = true } }
function Dialogs.Open(host, o)
	o = o or {}
	local hostIsGui = host == Library.Gui
	local hs = hostIsGui and 1 or (Library.UIScale or 1)
	local layer = New("Frame", {
		Name = "Dialog", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1, ZIndex = 100, Active = true, Parent = host,
	})
	local dismiss = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = layer })
	local width = math.min(o.Width or 300, host.AbsoluteSize.X / hs - 24)
	local shell = New("Frame", {
		Name = "Shell", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 10), Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 2, Parent = layer,
	})
	local scale = New("UIScale", { Scale = 0.96, Parent = shell })
	local shadow = Effects.Shadow(shell, { Radius = 10, Group = true, Hidden = true, Spread = 3, Strength = 0.5 })
	local card = New("CanvasGroup", {
		Name = "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, GroupTransparency = 1, Parent = shell,
	})
	Corner(10, card)
	Theme.Bind(card, { BackgroundColor3 = "Card" })
	Padding(14, 14, 12, 14, card)
	List(card, { Padding = UDim.new(0, 8) })

	local typ = o.Type or "Info"
	local head = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = card })
	List(head, { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8) })
	if o.Icon ~= false then
		local badge = New("Frame", { Size = UDim2.fromOffset(26, 26), LayoutOrder = 1, Parent = head })
		Corner(7, badge)
		badge.BackgroundTransparency = 0.86
		Theme.Bind(badge, { BackgroundColor3 = D_TOKEN[typ] or "Accent" })
		Icons.New(o.Icon or D_ICON[typ] or "info", 14, D_TOKEN[typ] or "Accent", badge, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	end
	local title = New("TextLabel", {
		Text = o.Title or "Notice", TextSize = 14, Weight = "Bold", TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -34, 0, 22), LayoutOrder = 2, Parent = head,
	})
	Theme.Bind(title, { TextColor3 = "Text" })
	local bodyLabel
	if o.Content and o.Content ~= "" then
		bodyLabel = New("TextLabel", {
			Text = o.Content, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = card,
		})
		Theme.Bind(bodyLabel, { TextColor3 = "SubText" })
	end
	local input
	if o.Input then
		input = Components.Field(card, {
			Placeholder = o.Input.Placeholder, Text = o.Input.Default, Multiline = o.Input.Multiline, LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, o.Input.Multiline and 64 or M.Field + 2),
		})
	end

	local obj = { Layer = layer, Card = card, Input = input }
	local closed, escConn = false, nil
	function obj:Close()
		if closed then return end
		closed = true
		if escConn then escConn:Disconnect() end
		tween(layer, { BackgroundTransparency = 1 }, Ease.Smooth)
		tween(card, { GroupTransparency = 1 }, Ease.Fast)
		tween(shadow, { GroupTransparency = 1 }, Ease.Fast)
		tween(scale, { Scale = 0.97 }, Ease.Smooth)
		tween(shell, { Position = UDim2.new(0.5, 0, 0.5, 6) }, Ease.Smooth)
		delay(0.3, function() layer:Destroy() end)
		safe(o.OnClose)
	end
	function obj:SetContent(t) if bodyLabel then bodyLabel.Text = t end end

	local buttons = o.Buttons or { { Title = "OK", Variant = "Primary" } }
	local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, M.Button + 4), LayoutOrder = 5, Parent = card })
	List(row, { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 6) })
	for i, b in ipairs(buttons) do
		local w = math.max(64, #tostring(b.Title) * 7 + 30)
		Components.Button(row, {
			Text = b.Title, Icon = b.Icon, Style = b.Variant or (i == #buttons and "Primary" or "Secondary"), LayoutOrder = i,
			Size = UDim2.fromOffset(w, M.Button),
			Callback = function()
				local keep = false
				if b.Callback then
					local ok, r = pcall(b.Callback, input and input.Get() or nil)
					if not ok then warn("[Library] dialog callback error: " .. tostring(r)) end
					keep = ok and r == false
				end
				if b.Close ~= false and not keep then obj:Close() end
			end,
		})
	end

	if o.Dismissable ~= false then
		dismiss.MouseButton1Click:Connect(function() obj:Close() end)
		escConn = UIS.InputBegan:Connect(function(i, gp)
			if not gp and i.KeyCode == Enum.KeyCode.Escape then obj:Close() end
		end)
	end

	tween(layer, { BackgroundTransparency = 0.5 }, Ease.Smooth)
	tween(card, { GroupTransparency = 0 }, Ease.Smooth)
	tween(shadow, { GroupTransparency = 0 }, Ease.Smooth)
	tween(scale, { Scale = 1 }, Ease.Smooth)
	tween(shell, { Position = UDim2.new(0.5, 0, 0.5, 0) }, Ease.Smooth)
	if input then delay(0.25, function() pcall(function() input.Box:CaptureFocus() end) end) end
	return obj
end

----------------------------------------------------------------------------
-- 8. LOADER & KEY SYSTEM
----------------------------------------------------------------------------
-- One shared dim layer behind the loader / key screen / blocked screen, so it never flickers between them
local Backdrop = { count = 0, token = 0 }
local function backdropAcquire(gui)
	Backdrop.count, Backdrop.token = Backdrop.count + 1, Backdrop.token + 1
	if not Backdrop.frame or not Backdrop.frame.Parent then
		Backdrop.frame = New("Frame", {
			Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1, ZIndex = 5, Active = true, Parent = gui,
		})
	end
	tween(Backdrop.frame, { BackgroundTransparency = 0.5 }, Ease.Smooth)
end
local function backdropRelease()
	Backdrop.count = Backdrop.count - 1
	local tok = Backdrop.token
	delay(0.2, function()
		local f = Backdrop.frame
		if Backdrop.count <= 0 and Backdrop.token == tok and f and f.Parent then
			tween(f, { BackgroundTransparency = 1 }, Ease.Smooth)
			delay(0.4, function()
				if Backdrop.count <= 0 and Backdrop.token == tok and Backdrop.frame == f then f:Destroy(); Backdrop.frame = nil end
			end)
		end
	end)
end
function Library._ResetBackdrop() Backdrop.count, Backdrop.frame = 0, nil end

-- Centered card used by the loader, key system and blocked screen. Scales down on small screens, never up.
local function makePanel(gui, w, h, z)
	backdropAcquire(gui)
	local holder = New("Frame", {
		Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, ZIndex = z, Parent = gui,
	})
	local scale = New("UIScale", { Parent = holder })
	local shadow = Effects.Shadow(holder, { Radius = 14, Group = true, Hidden = true, Spread = 3, Strength = 0.5 })
	local fade = New("CanvasGroup", { Name = "Fade", Size = UDim2.fromScale(1, 1), GroupTransparency = 1, ZIndex = 1, Parent = holder })
	local _, card = Effects.Bordered(fade, { Radius = 14, Fill = "Window", Top = 0.86 })
	Theme.Gradient(card, 0.28)
	local content = New("Frame", { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = card })

	local function fit()
		local vp = gui.AbsoluteSize
		scale.Scale = math.min(1, (vp.X - 24) / w, (vp.Y - 24) / h)
	end
	fit()
	local fitConn = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	local panel = { Holder = holder, Content = content }
	function panel.Show()
		tween(fade, { GroupTransparency = 0 }, Ease.Smooth)
		tween(shadow, { GroupTransparency = 0 }, Ease.Smooth)
		tween(holder, { Position = UDim2.new(0.5, 0, 0.5, 0) }, Ease.Smooth)
	end
	function panel.Hide()
		tween(fade, { GroupTransparency = 1 }, Ease.Fast)
		tween(shadow, { GroupTransparency = 1 }, Ease.Fast)
		tween(holder, { Position = UDim2.new(0.5, 0, 0.5, -8) }, Ease.Smooth)
		backdropRelease()
	end
	function panel.Destroy()
		fitConn:Disconnect()
		holder:Destroy()
	end
	return panel
end
Library.MakePanel = makePanel

local function panelHeader(c, cfg, rightText)
	Effects.BrandMark(c, cfg, { Size = 24, Position = UDim2.fromOffset(18, 15) })
	local nm = New("TextLabel", {
		Text = tostring(cfg.Name or "Loading"):upper(), TextSize = 12, Weight = "Bold", TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(50, 15), Size = UDim2.new(1, -150, 0, 24), Parent = c,
	})
	Theme.Bind(nm, { TextColor3 = "Text" })
	if rightText then
		local r = New("TextLabel", { Text = rightText, TextSize = 10.5, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -98, 0, 15), Size = UDim2.fromOffset(80, 24), Parent = c })
		Theme.Bind(r, { TextColor3 = "Muted" })
	end
	Effects.Hairline(c, { Position = UDim2.fromOffset(18, 52), Size = UDim2.new(1, -36, 0, 1), BackgroundTransparency = 0.9 })
end

------------------------------------------------------------ loader UI
local LoaderUI = {}
function LoaderUI.new(gui, cfg)
	local lc = type(cfg.Loader) == "table" and cfg.Loader or {}
	local panel = makePanel(gui, 360, 232, 10)
	local c = panel.Content
	panelHeader(c, cfg, "v" .. tostring(cfg.Version or Library.Version))

	local stage = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 66), Size = UDim2.fromOffset(88, 88), BackgroundTransparency = 1, Parent = c })
	local stageScale = New("UIScale", { Parent = stage })
	local rings = {}
	local function addRing(diam, thick, speed, band, tok, trackAlpha)
		local function circle()
			local f = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(diam, diam), BackgroundTransparency = 1, Parent = stage })
			Corner("full", f)
			return f
		end
		local track = New("UIStroke", { Thickness = thick, Transparency = trackAlpha, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = circle() })
		Theme.Bind(track, { Color = tok })
		local arc = New("UIStroke", { Thickness = thick, Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = circle() })
		Theme.Bind(arc, { Color = tok })
		local g = New("UIGradient", {
			Transparency = NumberSequence.new({ kp(0, 1), kp(0.5 - band, 1), kp(0.5, 0), kp(0.5 + band, 1), kp(1, 1) }), Parent = arc,
		})
		table.insert(rings, { G = g, S = arc, T = track, Speed = speed })
	end
	addRing(88, 1.5, 70, 0.3, "Muted", 0.8)
	addRing(66, 2, -150, 0.24, "Accent", 0.82)
	addRing(44, 1.5, 230, 0.34, "SubText", 0.85)
	local pct = New("TextLabel", { Text = "0", TextSize = 14, Weight = "Bold", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 20), Parent = stage })
	Theme.Bind(pct, { TextColor3 = "Text" })

	local status = New("TextLabel", {
		Text = lc.Tagline or "Starting", TextSize = 11.5, Weight = "Medium", TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(22, 166), Size = UDim2.new(1, -130, 0, 16), Parent = c,
	})
	Theme.Bind(status, { TextColor3 = "SubText" })
	local detail = New("TextLabel", {
		Text = "", TextSize = 10.5, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, 166), Size = UDim2.fromOffset(100, 16), Parent = c,
	})
	Theme.Bind(detail, { TextColor3 = "Muted" })
	local track = New("Frame", { Position = UDim2.fromOffset(22, 192), Size = UDim2.new(1, -44, 0, 3), Parent = c })
	Corner("full", track)
	Theme.Bind(track, { BackgroundColor3 = "CardAlt" })
	local fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), Parent = track })
	Corner("full", fill)
	Theme.Bind(fill, { BackgroundColor3 = "Accent" })

	local self = { target = 0, shown = 0, changed = os.clock() }
	local t0 = os.clock()
	local conn = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock() - t0
		for _, r in ipairs(rings) do r.G.Rotation = (t * r.Speed) % 360 end
		local goal = self.target
		if goal < 1 then goal = math.min(0.97, goal + math.min(0.05, (os.clock() - self.changed) * 0.06)) end
		self.shown = self.shown + (goal - self.shown) * (1 - math.exp(-dt * 20))
		if goal - self.shown < 0.0005 then self.shown = goal end
		fill.Size = UDim2.new(self.shown, 0, 1, 0)
		pct.Text = tostring(math.floor(self.shown * 100 + 0.5))
		local step = math.floor(self.shown * 10)
		if step > (self.lastTick or 0) then self.lastTick = step; Sound.Play("Tick", 0.8 + self.shown * 0.8) end
	end)
	panel.Show()
	Sound.Play("Open")

	function self:SetProgress(p) if p > self.target then self.target = math.min(1, p); self.changed = os.clock() end end
	function self:SetStatus(s, d)
		status.Text = tostring(s)
		detail.Text = d and tostring(d) or ""
	end
	function self:Finish()
		self.target = 1
		local minTime = lc.MinTime or 0.1
		while self.shown < 0.97 or (os.clock() - t0) < minTime do wait() end
		pct.Text = "100"
		status.Text = lc.DoneText or "Ready"
		detail.Text = ""
		Sound.Play("Success")
		for _, r in ipairs(rings) do tween(r.S, { Transparency = 1 }, Ease.Fast); tween(r.T, { Transparency = 1 }, Ease.Fast) end
		tween(stageScale, { Scale = 1.08 }, Ease.Smooth)
		wait(0.05)
		panel.Hide()
		delay(0.35, function() conn:Disconnect(); panel.Destroy() end)
	end
	function self:Destroy() conn:Disconnect(); panel.Destroy() end
	return self
end

-- Runs stages of { Name, Weight, Run = function(report) } through the loader UI.
-- Tasks inside one stage run in parallel; stages run one after another. report(fraction, status, detail)
function Library._RunLoader(cfg, stages, silent)
	local ui
	if silent then
		ui = { SetProgress = function() end, SetStatus = function() end, Finish = function() end }
	else
		local custom = type(cfg.Loader) == "table" and cfg.Loader.Custom
		if type(custom) == "function" then
			local ok, r = pcall(custom, { Library = Library, Gui = Library.Gui, Config = cfg })
			if ok and type(r) == "table" then ui = r end
		end
		ui = ui or LoaderUI.new(Library.Gui, cfg)
	end
	local total = 0
	for _, stage in ipairs(stages) do for _, t in ipairs(stage) do total = total + (t.Weight or 1) end end
	local fracs = {}
	local function overall()
		local s = 0
		for t, f in pairs(fracs) do s = s + (t.Weight or 1) * f end
		return s / math.max(total, 1)
	end
	for _, stage in ipairs(stages) do
		local pending = #stage
		for _, t in ipairs(stage) do
			fracs[t] = 0
			spawn(function()
				local ok, err = pcall(t.Run, function(frac, status, detail)
					if frac then fracs[t] = clamp(frac, 0, 1) end
					ui:SetProgress(overall())
					if status then ui:SetStatus(status, detail) end
				end)
				if not ok then warn("[Library] loader task '" .. tostring(t.Name) .. "' failed: " .. tostring(err)) end
				fracs[t] = 1
				ui:SetProgress(overall())
				pending = pending - 1
			end)
		end
		while pending > 0 do wait() end
	end
	ui:Finish()
end

------------------------------------------------------------ key system logic
local KeySystem = { Cache = {}, Services = {} }
Library.KeySystem = KeySystem

function KeySystem.Fetch(url)
	if KeySystem.Cache[url] then return KeySystem.Cache[url], true end
	local body = httpGet(url)
	if not body then return {}, false end
	local list = {}
	for line in body:gmatch("[^\r\n]+") do
		line = trim(line)
		if line ~= "" and not line:find("^#") and not line:find("^%-%-") then table.insert(list, line) end
	end
	KeySystem.Cache[url] = list
	return list, true
end

function KeySystem.Prefetch(ks)
	for _, k in ipairs({ "KeyUrl", "WhitelistUrl", "BlacklistUrl" }) do
		if ks[k] then KeySystem.Fetch(ks[k]) end
	end
end

local function identifiers()
	local ids = {}
	local function add(v) if v ~= nil and tostring(v) ~= "" then ids[tostring(v):lower()] = true end end
	add(LocalPlayer.UserId); add(LocalPlayer.Name); add(LocalPlayer.DisplayName); add(getHwid())
	return ids
end

local function mergedList(static, url)
	local out = {}
	for _, e in ipairs(static or {}) do table.insert(out, e) end
	if url then for _, e in ipairs((KeySystem.Fetch(url))) do table.insert(out, e) end end
	return out
end

local function listMatch(ids, list)
	for _, e in ipairs(list) do
		local id, reason = e, nil
		if type(e) == "table" then id, reason = e.Id or e.Name or e[1], e.Reason end
		if type(id) == "string" and id:find("|", 1, true) then
			local a, b = id:match("^(.-)%s*|%s*(.*)$")
			id, reason = a, reason or b
		end
		if id ~= nil and ids[tostring(id):lower()] then return true, reason end
	end
	return false
end

-- Returns "blocked" | "pass" | "needkey", reason
function KeySystem.Check(ks)
	local ids = identifiers()
	local hit, reason = listMatch(ids, mergedList(ks.Blacklist, ks.BlacklistUrl))
	if hit then return "blocked", reason or "Your account has been blacklisted." end
	local hasWL = (ks.Whitelist and #ks.Whitelist > 0) or ks.WhitelistUrl
	if hasWL then
		if listMatch(ids, mergedList(ks.Whitelist, ks.WhitelistUrl)) then return "pass" end
		local hasKeys = (ks.Keys and #ks.Keys > 0) or ks.KeyUrl or ks.Validate or ks.Service
		if ks.WhitelistOnly or not hasKeys then return "blocked", "You are not on the whitelist." end
	end
	return "needkey"
end

-- Key services ------------------------------------------------------------------
-- A service is { Validate = function(ks, key) -> ok, message, GetLink = function(ks) -> url|nil }.
-- Built-ins: luarmor, platoboost, pandadevelopment, http.  Add your own with Library:RegisterKeyService(name, impl).
local function enc(s) return HttpService:UrlEncode(tostring(s)) end
local function fillTemplate(s, key)
	s = tostring(s)
	s = s:gsub("{key}", function() return enc(key) end)
	s = s:gsub("{hwid}", function() return enc(getHwid()) end)
	s = s:gsub("{userid}", function() return tostring(LocalPlayer.UserId) end)
	s = s:gsub("{username}", function() return enc(LocalPlayer.Name) end)
	return s
end

KeySystem.Services.luarmor = {
	Validate = function(ks, key)
		local api = KeySystem._luarmor
		if not api then
			local src = httpGet("https://sdkapi-public.luarmor.net/library.lua")
			local fn = src and loadstr and loadstr(src)
			if fn then api = fn() end
			KeySystem._luarmor = api
		end
		if not api then return false, "Couldn't reach Luarmor." end
		api.script_id = ks.ScriptId
		local status = api.check_key(key)
		local code = status and status.code
		if code == "KEY_VALID" then
			genv.script_key = key
			return true, "Key accepted."
		end
		local msgs = {
			KEY_HWID_LOCKED = "This key is locked to another device.", KEY_INCORRECT = "That key isn't valid.",
			KEY_EXPIRED = "This key has expired.", KEY_BANNED = "This key has been banned.",
			KEY_BLACKLISTED = "This key is blacklisted.", KEY_INVALID = "That key isn't valid.",
			SCRIPT_ID_INCORRECT = "Script id is incorrect (check ScriptId).", SCRIPT_ID_INVALID = "Script id is invalid (check ScriptId).",
		}
		return false, msgs[code] or (status and status.message) or "Key check failed."
	end,
}

local PB_HOST = "https://api.platoboost.net"
KeySystem.Services.platoboost = {
	GetLink = function(ks)
		local r = httpRequest({
			Url = PB_HOST .. "/public/start", Method = "POST", Headers = { ["Content-Type"] = "application/json" },
			Body = jsonEncode({ service = ks.ServiceId, identifier = getHwid() }),
		})
		local d = r and r.Body and jsonDecode(r.Body)
		return d and d.success and d.data and d.data.url or nil
	end,
	Validate = function(ks, key)
		local r = httpRequest({
			Url = PB_HOST .. "/public/redeem/" .. tostring(ks.ServiceId), Method = "POST", Headers = { ["Content-Type"] = "application/json" },
			Body = jsonEncode({ identifier = getHwid(), key = key }),
		})
		local d = r and r.Body and jsonDecode(r.Body)
		if d and d.success and d.data and d.data.valid then return true, "Key accepted." end
		local body = httpGet(PB_HOST .. "/public/whitelist/" .. tostring(ks.ServiceId) .. "?identifier=" .. enc(getHwid()) .. "&key=" .. enc(key))
		d = body and jsonDecode(body)
		if d and d.success and d.data and d.data.valid then return true, "Key accepted." end
		if not r and not body then return false, "Couldn't reach Platoboost." end
		return false, "That key isn't valid."
	end,
}

KeySystem.Services.pandadevelopment = {
	GetLink = function(ks) return "https://pandadevelopment.net/getkey?service=" .. enc(ks.ServiceId) .. "&hwid=" .. enc(getHwid()) end,
	Validate = function(ks, key)
		local body = httpGet("https://pandadevelopment.net/v2_validation?key=" .. enc(key) .. "&service=" .. enc(ks.ServiceId) .. "&hwid=" .. enc(getHwid()))
		if not body then return false, "Couldn't reach Panda Development." end
		local d = jsonDecode(body)
		if d and (d.V2_Authentication == "success" or d.success == true) then return true, "Key accepted." end
		return false, "That key isn't valid."
	end,
}

-- Generic JSON/HTTP service for your own server:  Service = "Http", Url = "https://x/check?key={key}&hwid={hwid}"
-- Optional: Method, Body, Headers, Check = function(body, json) -> ok, message
KeySystem.Services.http = {
	Validate = function(ks, key)
		local body
		if tostring(ks.Method or "GET"):upper() == "POST" then
			local r = httpRequest({ Url = fillTemplate(ks.Url, key), Method = "POST", Headers = ks.Headers or { ["Content-Type"] = "application/json" }, Body = fillTemplate(ks.Body or "{}", key) })
			body = r and r.Body
		else
			body = httpGet(fillTemplate(ks.Url, key))
		end
		if not body then return false, "Couldn't reach the key server." end
		local json = jsonDecode(body)
		if type(ks.Check) == "function" then
			local ok, a, b = pcall(ks.Check, body, json)
			if ok and a then return true, b or "Key accepted." end
			return false, (ok and b) or "That key isn't valid."
		end
		if (json and (json.valid == true or json.success == true or json.status == "valid")) or body:lower():match("^%s*valid") or body:lower():match("^%s*true") then
			return true, "Key accepted."
		end
		return false, "That key isn't valid."
	end,
}

function KeySystem.Validate(ks, key)
	key = trim(key or "")
	if key == "" then return false, "Enter your key first." end
	if type(ks.Validate) == "function" then
		local ok, a, b = pcall(ks.Validate, key)
		if not ok then return false, "Validation error." end
		if a then return true, b or "Key accepted." end
		return false, b or "That key isn't valid."
	end
	if ks.Service then
		local impl = KeySystem.Services[tostring(ks.Service):lower()]
		if not impl then return false, "Unknown key service '" .. tostring(ks.Service) .. "'." end
		local ok, a, b = pcall(impl.Validate, ks, key)
		if not ok then warn("[Library] key service error: " .. tostring(a)); return false, "Key service error." end
		return a and true or false, b or (a and "Key accepted." or "That key isn't valid.")
	end
	local function eq(a, b)
		if ks.CaseSensitive == false then return tostring(a):lower() == tostring(b):lower() end
		return tostring(a) == tostring(b)
	end
	for _, k in ipairs(ks.Keys or {}) do if eq(k, key) then return true, "Key accepted." end end
	if ks.KeyUrl then
		local list, ok = KeySystem.Fetch(ks.KeyUrl)
		if not ok then return false, "Couldn't reach the key server." end
		for _, k in ipairs(list) do if eq(k, key) then return true, "Key accepted." end end
	end
	return false, "That key isn't valid."
end

-- Resolves the "get key" link: explicit GetKeyLink, else the service's own link
function KeySystem.GetLink(ks)
	if ks.GetKeyLink then return ks.GetKeyLink end
	local impl = ks.Service and KeySystem.Services[tostring(ks.Service):lower()]
	if impl and impl.GetLink then
		local ok, url = pcall(impl.GetLink, ks)
		if ok then return url end
	end
end

------------------------------------------------------------ key system UI
local function iconButton(parent, iconName, pos, onClick, size)
	size = size or 24
	local b = New("TextButton", { Size = UDim2.fromOffset(size, size), Position = pos, ZIndex = 5, Parent = parent })
	Corner(6, b)
	Theme.Bind(b, { BackgroundColor3 = "CardAlt" })
	b.BackgroundTransparency = 1
	local ic = Icons.New(iconName, 13, "SubText", b, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0 }, Ease.Fast); tween(ic, { ImageColor3 = resolve("Text") }, Ease.Fast) end)
	b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 1 }, Ease.Smooth); tween(ic, { ImageColor3 = resolve("SubText") }, Ease.Smooth) end)
	b.MouseButton1Click:Connect(function() Sound.Play("Click"); safe(onClick) end)
	return b, ic
end
Library._IconButton = iconButton

local KeyUI = {}
local SERVICE_LABEL = { luarmor = "Luarmor", platoboost = "Platoboost", pandadevelopment = "Panda Development", http = "Custom server" }

function KeyUI.Show(ks, cfg)
	local panel = makePanel(Library.Gui, 380, 306, 12)
	local c = panel.Content
	local result, reason, finished = false, nil, false
	panelHeader(c, cfg)
	iconButton(c, "x", UDim2.new(1, -42, 0, 15), function() reason, finished = "closed", true end)

	local title = New("TextLabel", {
		Text = ks.Title or "Verify access", TextSize = 16, Weight = "Bold", TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(22, 66), Size = UDim2.new(1, -44, 0, 22), Parent = c,
	})
	Theme.Bind(title, { TextColor3 = "Text" })
	local sub = New("TextLabel", {
		Text = ks.Subtitle or "Paste your key below to unlock the interface.", TextSize = 11.5, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(22, 90), Size = UDim2.new(1, -44, 0, 28), Parent = c,
	})
	Theme.Bind(sub, { TextColor3 = "SubText" })

	local field = Components.Field(c, {
		Icon = "key-round", Placeholder = ks.Placeholder or "Enter your key…", Position = UDim2.fromOffset(22, 124),
		Size = UDim2.new(1, -44, 0, 32), Callback = function(_, enter) if enter then KeyUI._attempt() end end,
	})
	local statusIcon = Icons.New("info", 12, "Muted", c, { Position = UDim2.fromOffset(24, 166) })
	local statusLabel = New("TextLabel", {
		Text = "Waiting for key", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(42, 164), Size = UDim2.new(1, -66, 0, 16), Parent = c,
	})
	Theme.Bind(statusLabel, { TextColor3 = "Muted" })
	local function setStatus(text, tok, iconName)
		statusLabel.Text = text
		Theme.Bind(statusLabel, { TextColor3 = tok })
		Theme.Bind(statusIcon, { ImageColor3 = tok })
		Icons.Set(statusIcon, iconName)
	end

	local verify = Components.Button(c, {
		Text = ks.VerifyText or "Verify key", Icon = "shield-check", Style = "Primary", Height = 30,
		Position = UDim2.fromOffset(22, 188), Size = UDim2.new(1, -44, 0, 30),
	})

	local links = ks.Links or {}
	if #links == 0 then
		local hasLink = ks.GetKeyLink or (ks.Service and KeySystem.Services[tostring(ks.Service):lower()] and KeySystem.Services[tostring(ks.Service):lower()].GetLink)
		if hasLink then table.insert(links, { Name = "Get key", Icon = "key-round", Get = true }) end
		if ks.DiscordLink then table.insert(links, { Name = "Discord", Url = ks.DiscordLink, Icon = "external-link" }) end
	end
	if #links > 0 then
		local row = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 226), Size = UDim2.new(1, -44, 0, M.Button), Parent = c })
		List(row, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) })
		for i, l in ipairs(links) do
			Components.Button(row, {
				Text = l.Name or "Link", Icon = l.Icon or "external-link", Style = "Secondary", LayoutOrder = i,
				Size = UDim2.new(1 / #links, -(8 * (#links - 1)) / #links, 1, 0),
				Callback = function()
					spawn(function()
						local url = l.Get and KeySystem.GetLink(ks) or l.Url
						if not url then Library:Notify({ Title = "No link", Content = "Couldn't get a key link right now.", Type = "Warning" }) return end
						if setclipboard then pcall(setclipboard, url) end
						Library:Notify({ Title = l.Name or "Link", Content = "Link copied to your clipboard.", Type = "Success", Duration = 3 })
					end)
				end,
			})
		end
	end

	Effects.Hairline(c, { Position = UDim2.new(0, 22, 1, -34), Size = UDim2.new(1, -44, 0, 1), BackgroundTransparency = 0.92 })
	local hwid = getHwid()
	local foot = New("TextLabel", {
		Text = ("HWID  %s…%s"):format(hwid:sub(1, 6), hwid:sub(-4)), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 22, 1, -28), Size = UDim2.new(0.5, 0, 0, 18), Parent = c,
	})
	Theme.Bind(foot, { TextColor3 = "Muted" })
	local svcName = ks.Service and (SERVICE_LABEL[tostring(ks.Service):lower()] or tostring(ks.Service)) or "Signed in as @" .. LocalPlayer.Name
	local foot2 = New("TextLabel", {
		Text = svcName, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 1, -28), Size = UDim2.new(0.5, 0, 0, 18), Parent = c,
	})
	Theme.Bind(foot2, { TextColor3 = "Muted" })

	local spinning = false
	local spin = RunService.Heartbeat:Connect(function(dt)
		if spinning then statusIcon.Rotation = (statusIcon.Rotation + dt * 360) % 360 else statusIcon.Rotation = 0 end
	end)

	local busy, attempts = false, 0
	local maxAttempts = ks.MaxAttempts or 6
	function KeyUI._attempt()
		if busy or finished then return end
		busy = true
		verify:SetEnabled(false)
		setStatus("Checking key…", "SubText", "loader-circle")
		spinning = true
		local ok, msg = KeySystem.Validate(ks, field.Get())
		spinning = false
		if ok then
			Sound.Play("Success")
			field.Flash("Success")
			setStatus(msg, "Success", "circle-check")
			if ks.SaveKey ~= false and Library.Folder then FS.write(Library.Folder .. "/key.txt", trim(field.Get())) end
			wait(0.5)
			result, finished = true, true
		else
			attempts = attempts + 1
			Sound.Play("Error")
			field.Flash("Danger")
			local left = maxAttempts - attempts
			setStatus(msg .. (left > 0 and ("  ·  " .. left .. " left") or ""), "Danger", "circle-alert")
			if left <= 0 then wait(0.6); reason, finished = "Too many failed attempts.", true end
			verify:SetEnabled(true)
		end
		busy = false
	end
	verify:SetCallback(KeyUI._attempt)

	panel.Show()
	Sound.Play("Open")
	while not finished do wait() end
	spin:Disconnect()
	panel.Hide()
	delay(0.4, panel.Destroy)
	return result, reason
end

function KeyUI.Blocked(message, ks, cfg)
	local panel = makePanel(Library.Gui, 340, 214, 12)
	local c = panel.Content
	local done = false
	local badge = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.fromOffset(40, 40), Parent = c })
	Corner("full", badge)
	badge.BackgroundTransparency = 0.84
	Theme.Bind(badge, { BackgroundColor3 = "Danger" })
	Icons.New("ban", 20, "Danger", badge, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local t = New("TextLabel", { Text = "Access denied", TextSize = 16, Weight = "Bold", Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 22), Parent = c })
	Theme.Bind(t, { TextColor3 = "Text" })
	local m = New("TextLabel", {
		Text = message or "You can't use this script.", TextSize = 11.5, TextWrapped = true,
		Position = UDim2.fromOffset(30, 100), Size = UDim2.new(1, -60, 0, 34), TextYAlignment = Enum.TextYAlignment.Top, Parent = c,
	})
	Theme.Bind(m, { TextColor3 = "SubText" })
	Components.Button(c, { Text = "Close", Style = "Secondary", Height = 30, Position = UDim2.fromOffset(30, 156), Size = UDim2.new(1, -60, 0, 30), Callback = function() done = true end })
	panel.Show()
	Sound.Play("Error")
	if ks and ks.BlacklistAction == "Kick" then
		delay(2.2, function() pcall(function() LocalPlayer:Kick(message or "Blacklisted") end) end)
	end
	while not done do wait() end
	panel.Hide()
	delay(0.4, panel.Destroy)
end

-- Returns true when the user may continue to the GUI
function Library._RunKeySystem(cfg)
	local ks = cfg.KeySystem
	if not ks or ks.Enabled == false then return true end
	if type(ks.Custom) == "function" then
		local ok, res = pcall(ks.Custom, {
			Library = Library, Gui = Library.Gui, Config = cfg,
			Check = function() return KeySystem.Check(ks) end,
			Validate = function(k) return KeySystem.Validate(ks, k) end,
			Panel = function(w, h) return makePanel(Library.Gui, w, h, 12) end,
		})
		return ok and res == true
	end
	local state, reason = KeySystem.Check(ks)
	if state == "blocked" then KeyUI.Blocked(reason, ks, cfg) return false end
	if state == "pass" then return true end
	if ks.SaveKey ~= false and Library.Folder then
		local saved = FS.read(Library.Folder .. "/key.txt")
		if saved and (KeySystem.Validate(ks, saved)) then return true end
	end
	local ok, why = KeyUI.Show(ks, cfg)
	if not ok and why and why ~= "closed" then KeyUI.Blocked(why, ks, cfg) end
	return ok
end

----------------------------------------------------------------------------
-- 9. LAYOUT  (Tab → Section → Card → elements)
----------------------------------------------------------------------------
Window.__index, Card.__index = Window, Card

-- Section and Tab forward every Add* call to a default card, so `tab:AddToggle{...}` works directly.
Section.__index = function(self, k)
	local own = rawget(Section, k)
	if own ~= nil then return own end
	if type(k) == "string" and k:sub(1, 3) == "Add" and type(Card[k]) == "function" then
		return function(sec, ...) return Card[k](sec:_DefaultCard(), ...) end
	end
end
Tab.__index = function(self, k)
	local own = rawget(Tab, k)
	if own ~= nil then return own end
	if type(k) == "string" and k:sub(1, 3) == "Add" and (Card[k] or k == "AddCard") then
		return function(tab, ...)
			local sec = tab:_DefaultSection()
			if k == "AddCard" then return sec:AddCard(...) end
			return Card[k](sec:_DefaultCard(), ...)
		end
	end
end

function Tab:_DefaultSection()
	if not self._defSection then self._defSection = self:CreateSection({}) end
	return self._defSection
end

-- CreateSection{ Title, Subtitle, Collapsible, Open }
function Tab:CreateSection(o)
	if type(o) == "string" then o = { Title = o } end
	o = o or {}
	self._order = self._order + 1
	local sec = setmetatable({ Tab = self, _n = 0, _cards = {}, Open = o.Open ~= false }, Section)
	local frame = New("Frame", {
		Name = "Section", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		LayoutOrder = self._order, Parent = self.Scroll,
	})
	List(frame, { Padding = UDim.new(0, 7) })
	sec.Frame = frame
	table.insert(self._sections, sec)

	if o.Title then
		local head = New("TextButton", { Name = "Header", Size = UDim2.new(1, 0, 0, o.Subtitle and 32 or 20), LayoutOrder = 0, Parent = frame })
		local t = New("TextLabel", {
			Text = o.Title, TextSize = 14, Weight = "Bold", TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -20, 0, 18), Parent = head,
		})
		Theme.Bind(t, { TextColor3 = "Text" })
		sec.TitleLabel = t
		if o.Subtitle then
			local s = New("TextLabel", {
				Text = o.Subtitle, TextSize = 10.5, TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, -20, 0, 14), Parent = head,
			})
			Theme.Bind(s, { TextColor3 = "Muted" })
		end
		if o.Collapsible then
			sec.Chevron = Icons.New("chevron-down", 13, "Muted", head, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 3) })
			head.MouseButton1Click:Connect(function() sec:SetOpen(not sec.Open) end)
			head.MouseEnter:Connect(function() tween(sec.Chevron, { ImageColor3 = resolve("Text") }, Ease.Fast) end)
			head.MouseLeave:Connect(function() tween(sec.Chevron, { ImageColor3 = resolve("Muted") }, Ease.Smooth) end)
		end
	end
	sec.Body = New("Frame", { Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ClipsDescendants = false, LayoutOrder = 1, Parent = frame })
	sec.BodyList = List(sec.Body, { Padding = UDim.new(0, 8) })
	if o.Collapsible and not sec.Open then sec:SetOpen(false, true) end
	return sec
end

-- Collapse / expand the cards of a section with a height animation
function Section:SetOpen(open, instant)
	if open == self.Open and not instant then return end
	self.Open = open
	local body = self.Body
	if self.Chevron then tween(self.Chevron, { Rotation = open and 0 or -90 }, Ease.Smooth) end
	local scale = Library.UIScale or 1
	if instant then
		body.Visible = open
		return
	end
	if open then
		body.Visible = true
		body.AutomaticSize = Enum.AutomaticSize.None
		body.ClipsDescendants = true
		body.Size = UDim2.new(1, 0, 0, 0)
		local h = self.BodyList.AbsoluteContentSize.Y / scale
		tween(body, { Size = UDim2.new(1, 0, 0, h) }, Ease.Smooth)
		delay(0.26, function()
			if self.Open then body.AutomaticSize = Enum.AutomaticSize.Y; body.Size = UDim2.new(1, 0, 0, 0); body.ClipsDescendants = false end
		end)
	else
		local h = body.AbsoluteSize.Y / scale
		body.AutomaticSize = Enum.AutomaticSize.None
		body.ClipsDescendants = true
		body.Size = UDim2.new(1, 0, 0, h)
		tween(body, { Size = UDim2.new(1, 0, 0, 0) }, Ease.Smooth)
		delay(0.26, function() if not self.Open then body.Visible = false end end)
	end
end

local function newBand(sec)
	sec._n = sec._n + 1
	local f = New("Frame", {
		Name = "Band", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		LayoutOrder = sec._n, Parent = sec.Body,
	})
	List(f, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Top })
	local cols = {}
	for i = 1, 2 do
		cols[i] = New("Frame", {
			Name = "Col" .. i, Size = i == 1 and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -4, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = i, Visible = i == 1, Parent = f,
		})
		List(cols[i])
	end
	local band = { Frame = f, Cols = cols, Cards = {} }
	-- both cards of a row always share the taller height, so rows are filled edge to edge
	function band.Sync()
		local a, b = band.Cards[1], band.Cards[2]
		if not (a and b) then return end
		local s = Library.UIScale or 1
		local h = math.floor(math.max(a.List.AbsoluteContentSize.Y, b.List.AbsoluteContentSize.Y) / s + 6 + 0.5)
		a.Frame.Size, b.Frame.Size = UDim2.new(1, 0, 0, h), UDim2.new(1, 0, 0, h)
	end
	return band
end

function Section:_DefaultCard()
	if not self._defCard then self._defCard = self:AddCard({ Wide = true }) end
	return self._defCard
end

-- AddCard{ Title?, Wide? } — cards pair up two per row and fill the full width; a lone card takes the whole row.
function Section:AddCard(o)
	o = o or {}
	local band, second
	if o.Wide then
		band = newBand(self)
		self._pending = nil
	elseif self._pending then
		band, second = self._pending, true
		self._pending = nil
	else
		band = newBand(self)
		self._pending = band
	end
	local col = band.Cols[second and 2 or 1]
	if second then
		col.Visible = true
		band.Cols[1].Size = UDim2.new(0.5, -4, 0, 0)
	end
	local card = setmetatable({ Section = self, Band = band, _count = 0, _order = 0, _rows = {} }, Card)
	local frame = New("Frame", { Name = "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = col })
	Corner(M.CardRadius, frame)
	Theme.Bind(frame, { BackgroundColor3 = "Card" })
	Padding(3, 10, 3, 10, frame)
	card.List = List(frame)
	card.Frame = frame
	table.insert(band.Cards, card)
	table.insert(self._cards, card)
	card.List:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(band.Sync)
	if o.Title then
		card._order = card._order + 1
		local t = New("TextLabel", {
			Text = tostring(o.Title):upper(), TextSize = 9.5, Weight = "SemiBold", TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 22), LayoutOrder = card._order, Parent = frame,
		})
		Theme.Bind(t, { TextColor3 = "Muted" })
	end
	return card
end

---------------------------------------------------------------- card plumbing
function Card:_Divider()
	self._order = self._order + 1
	local d = Effects.Hairline(self.Frame, { Name = "Divider", Size = UDim2.new(1, 0, 0, 1), LayoutOrder = self._order, BackgroundTransparency = 0.93 })
	return d
end

-- mode: "labels" (auto height, padded inner frame for label text) | "fixed" | "auto". Returns row, inner.
function Card:_Row(h, mode, noDivider)
	local div
	if self._count > 0 and not noDivider then div = self:_Divider() end
	self._count = self._count + 1
	self._order = self._order + 1
	mode = mode or "labels"
	local row = New("Frame", {
		Name = "Row", Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = self._order,
		AutomaticSize = (mode == "fixed") and Enum.AutomaticSize.None or Enum.AutomaticSize.Y, Parent = self.Frame,
	})
	local inner
	if mode == "labels" then
		local pad = math.max(0, math.floor((h - 16) / 2))
		inner = New("Frame", { Name = "Inner", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = row })
		Padding(pad, 0, pad, 0, inner)
	end
	local item = { Row = row, Div = div, Text = "" }
	row:SetAttribute("Searchable", true)
	table.insert(self._rows, item)
	self._lastItem = item
	return row, inner
end

-- Registers searchable text for the row created last (used by the header search box)
function Card:_Index(text) if self._lastItem then self._lastItem.Text = tostring(text or ""):lower() end end

function Card:_Labels(row, name, desc, rightPad)
	local box = New("Frame", {
		Name = "Labels", BackgroundTransparency = 1, Size = UDim2.new(1, -(rightPad or 0), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, Parent = row,
	})
	List(box, { Padding = UDim.new(0, 1) })
	local t = New("TextLabel", {
		Text = tostring(name or ""), TextSize = 12.5, Weight = "Medium", TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, Parent = box,
	})
	Theme.Bind(t, { TextColor3 = "Text" })
	local d
	if desc and desc ~= "" then
		d = New("TextLabel", {
			Text = tostring(desc), TextSize = 10.5, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = box,
		})
		Theme.Bind(d, { TextColor3 = "Muted" })
	end
	self:_Index((name or "") .. " " .. (desc or ""))
	return t, d
end

-- Registers an element's value so it is saved by configs and readable via Library.Flags
function Card:_Register(o, kind, get, set)
	if not o.Flag then return end
	Library.Elements[o.Flag] = { Type = kind, Get = get, Set = set, Ignore = o.IgnoreConfig }
	Library.Flags[o.Flag] = get()
end

----------------------------------------------------------------------------
-- 9b. WINDOW  (shell, header, sidebar, tabs, resize, fullscreen, minimize dock, search, close confirmation)
----------------------------------------------------------------------------
local iconButton = Library._IconButton

function Window.new(cfg)
	local self = setmetatable({
		Tabs = {}, Config = cfg, State = "Hidden", UserScale = 1, _items = {}, _scale = 1, _closeCbs = {}, _destroyCbs = {},
		_readyCbs = {}, _prelaunch = {}, Ready = false, Fullscreen = false, _topbar = 0,
	}, Window)
	local W, H = cfg.Size.X, cfg.Size.Y
	self.NomW, self.NomH, self.W, self.H = W, H, W, H
	self.MinW = cfg.MinSize and cfg.MinSize.X or 440
	self.MinH = cfg.MinSize and cfg.MinSize.Y or 300
	local SW, HH = cfg.SidebarWidth or M.Sidebar, M.Header
	self.SW, self.HH = SW, HH
	local gui = Library.Gui

	-- mover (positioned/dragged, screen pixels) > holder (UIScale) > fade > rim > main
	local mover = New("Frame", {
		Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Visible = false, ZIndex = 10, Parent = gui,
	})
	local holder = New("Frame", {
		Name = "Scaler", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Parent = mover,
	})
	local uiScale = New("UIScale", { Parent = holder })
	local shadow = Effects.Shadow(holder, { Radius = M.WindowRadius, Group = true, Hidden = true, Spread = 3, Strength = 0.5 })
	local fade = New("CanvasGroup", { Name = "Fade", Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Parent = holder })
	local _, main = Effects.Bordered(fade, { Class = "CanvasGroup", Radius = M.WindowRadius, Fill = "Window", Top = 0.82 })
	self.Mover, self.Holder, self.UIScale, self.Shadow, self.Fade, self.Main = mover, holder, uiScale, shadow, fade, main

	---------------------------------------------------------------- header
	local header = New("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, HH), Active = true, ZIndex = 3, Parent = main })
	Theme.Bind(header, { BackgroundColor3 = "Header" })
	self.HeaderFrame = header
	Effects.Hairline(header, { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.9, ZIndex = 4 })
	Effects.BrandMark(header, cfg, { Size = 22, Position = UDim2.fromOffset(10, 8), ZIndex = 4 })

	local titleRow = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -230, 1, 0), ZIndex = 4, Parent = header })
	List(titleRow, { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6) })
	local title = New("TextLabel", {
		Text = cfg.TitleCase == "Normal" and tostring(cfg.Name) or tostring(cfg.Name):upper(), TextSize = 12.5, Weight = "Bold",
		TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), ZIndex = 5, LayoutOrder = 1, Parent = titleRow,
	})
	Theme.Bind(title, { TextColor3 = "Text" })
	self.TitleLabel = title
	self.TagRow = New("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), ZIndex = 5, LayoutOrder = 2, Parent = titleRow })
	List(self.TagRow, { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4) })
	if cfg.Subtitle then self:Tag({ Title = tostring(cfg.Subtitle), Color = "Muted" }) end

	local controls = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 5, Parent = header,
	})
	List(controls, { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 2) })
	self.Controls = controls
	local function ctl(icon, order, cb, tip)
		local b = iconButton(controls, icon, UDim2.new(), cb, 24)
		b.LayoutOrder = order
		if tip then Effects.Tooltip(b, tip) end
		return b
	end
	self._ctl = ctl

	-- search (collapsed to an icon until focused)
	if cfg.Search ~= false then
		local holderS = New("Frame", { Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = 1, Parent = controls })
		local sf = Components.Field(holderS, {
			Icon = "search", Placeholder = "Search…", Size = UDim2.fromOffset(150, 24), Live = true, OnChange = function(t) self:_Search(t) end,
		})
		local catcher = New("TextButton", { Size = UDim2.fromOffset(24, 24), ZIndex = 10, Parent = holderS })
		catcher.MouseButton1Click:Connect(function() sf.Box:CaptureFocus() end)
		sf.Box.Focused:Connect(function()
			catcher.Visible = false
			tween(holderS, { Size = UDim2.fromOffset(150, 24) }, Ease.Smooth)
		end)
		sf.Box.FocusLost:Connect(function()
			if sf.Box.Text == "" then
				catcher.Visible = true
				tween(holderS, { Size = UDim2.fromOffset(24, 24) }, Ease.Smooth)
			end
		end)
		self.SearchField = sf
	end
	self.BtnMin = ctl("minus", 100, function() self:Minimize() end, "Minimize")
	self.BtnFull = ctl("scan", 101, function() self:ToggleFullscreen() end, "Fullscreen")
	self.BtnClose = ctl("x", 102, function() self:Close() end, "Close")

	---------------------------------------------------------------- sidebar
	local sidebar = New("Frame", { Name = "Sidebar", Position = UDim2.fromOffset(0, HH), Size = UDim2.new(0, SW, 1, -HH), Parent = main })
	Theme.Bind(sidebar, { BackgroundColor3 = "Sidebar" })
	Effects.Hairline(sidebar, { Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundTransparency = 0.92, Vertical = true, ZIndex = 4 })
	self.Sidebar = sidebar
	Theme.Gradient(sidebar, 0.3)
	local tabScroll = New("ScrollingFrame", {
		Name = "Tabs", Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -58), ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = sidebar,
	})
	self.TabScroll = tabScroll
	local pill, pillBody = Effects.Bordered(tabScroll, { Name = "Pill", Size = UDim2.new(1, 0, 0, M.Tab), Radius = M.Radius, Fill = "CardAlt", Top = 0.88, ZIndex = 1 })
	pill.Visible = false
	local bar = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(2, 12), ZIndex = 2, Parent = pillBody })
	Corner("full", bar)
	Theme.Bind(bar, { BackgroundColor3 = "Accent" })
	self.Pill = pill

	-- user chip
	local ucfg = cfg.User or {}
	local user = New("TextButton", { Position = UDim2.new(0, 6, 1, -46), Size = UDim2.new(1, -12, 0, 40), ZIndex = 2, Parent = sidebar })
	Corner(8, user)
	Theme.Bind(user, { BackgroundColor3 = "Card" })
	user.BackgroundTransparency = 0
	local avatar = New("ImageLabel", {
		Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(26, 26), ZIndex = 3, Parent = user,
		Image = ucfg.Anonymous and "" or ("rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100"):format(LocalPlayer.UserId),
	})
	Corner("full", avatar)
	avatar.BackgroundTransparency = 0
	Theme.Bind(avatar, { BackgroundColor3 = "CardAlt" })
	local uname = New("TextLabel", {
		Text = ucfg.Anonymous and "Anonymous" or (ucfg.Name or LocalPlayer.DisplayName), TextSize = 11.5, Weight = "SemiBold", TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(39, 6), Size = UDim2.new(1, -46, 0, 14), ZIndex = 3, Parent = user,
	})
	Theme.Bind(uname, { TextColor3 = "Text" })
	local utag = New("TextLabel", {
		Text = ucfg.Anonymous and "Hidden" or (ucfg.Tag or ("@" .. LocalPlayer.Name)), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(39, 20), Size = UDim2.new(1, -46, 0, 13), ZIndex = 3, Parent = user,
	})
	Theme.Bind(utag, { TextColor3 = "Muted" })
	if ucfg.Callback then user.MouseButton1Click:Connect(function() Sound.Play("Click"); safe(ucfg.Callback) end) end
	self.UserChip = user

	---------------------------------------------------------------- content
	local content = New("Frame", { Name = "Content", Position = UDim2.fromOffset(SW, HH), Size = UDim2.new(1, -SW, 1, -HH), Parent = main })
	Theme.Bind(content, { BackgroundColor3 = "Content" })
	self.ContentFrame = content
	Theme.Gradient(content, 0.38)
	self.Background = Effects.Background(content, Vector2.new(W - SW, H - HH), cfg.Background or "Dots")
	self.Pages = New("Frame", { Name = "Pages", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = content })

	---------------------------------------------------------------- resize grip
	local grip = New("TextButton", { Name = "Grip", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(16, 16), ZIndex = 40, Parent = main })
	for i = 0, 2 do
		for j = 0, 2 - i do
			local d = New("Frame", { Size = UDim2.fromOffset(2, 2), Position = UDim2.fromOffset(11 - i * 4, 11 - j * 4), ZIndex = 41, BackgroundTransparency = 0.5, Parent = grip })
			Corner("full", d)
			Theme.Bind(d, { BackgroundColor3 = "Muted" })
		end
	end
	grip.Visible = cfg.Resizable ~= false
	self.Grip = grip
	local rs
	Util.Drag(grip, function(pos, began)
		if began then rs = { x = pos.X, y = pos.Y, w = self.W, h = self.H } return end
		if not rs or self.Fullscreen then return end
		local s, vp = self._scale, gui.AbsoluteSize
		local w = clamp(rs.w + (pos.X - rs.x) / s, self.MinW, math.max(self.MinW, (vp.X - 12) / s))
		local h = clamp(rs.h + (pos.Y - rs.y) / s, self.MinH, math.max(self.MinH, (vp.Y - 12) / s))
		self:_SetSize(w, h, false)
		self:_Clamp()
	end, function()
		self.Background:Build(nil, Vector2.new(self.W - self.SW, self.H - self.HH))
		safe(self.OnResize, self.W, self.H)
	end)

	---------------------------------------------------------------- dragging (kept fully on screen)
	local dragging, dragStart, startOff
	header.InputBegan:Connect(function(input)
		local ut = input.UserInputType
		if (ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch) and not self.Fullscreen then
			dragging, dragStart, startOff = input, input.Position, mover.Position
			input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = nil end end)
		end
	end)
	connect(UIS.InputChanged, function(input)
		if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local d = input.Position - dragStart
			mover.Position = UDim2.new(0.5, startOff.X.Offset + d.X, 0.5, startOff.Y.Offset + d.Y)
			self:_Clamp()
		end
	end)

	---------------------------------------------------------------- toggle key + fit
	self.ToggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
	connect(UIS.InputBegan, function(input, gp)
		if not gp and self.ToggleKey and input.KeyCode == self.ToggleKey and self.Ready then self:Toggle() end
	end)
	connect(gui:GetPropertyChangedSignal("AbsoluteSize"), function() self:_Fit() end)
	self:_Fit(true)
	local nf = function() if Notify.Scale then Notify.Scale.Scale = clamp(gui.AbsoluteSize.X / 300, 0.7, 1) end end
	nf()
	connect(gui:GetPropertyChangedSignal("AbsoluteSize"), nf)
	return self
end

---------------------------------------------------------------- size, scale, position
function Window:_Fit(instant)
	local vp = Library.Gui.AbsoluteSize
	if self.Fullscreen then
		local s0 = self._scale
		self.W, self.H = (vp.X - 12) / s0, (vp.Y - 44) / s0
	end
	local base = math.min(1, (vp.X - 20) / self.NomW, (vp.Y - 20) / self.NomH)
	local fit = math.min((vp.X - 8) / self.W, (vp.Y - 8) / self.H)
	local s = math.max(0.3, math.min(base * self.UserScale, fit))
	self._scale, Library.UIScale = s, s
	self.Holder.Size = UDim2.fromOffset(self.W, self.H)
	self.Mover.Size = UDim2.fromOffset(self.W * s, self.H * s)
	if instant or self.State ~= "Open" then self.UIScale.Scale = s else tween(self.UIScale, { Scale = s }, Ease.Smooth) end
	self:_Clamp()
end

function Window:SetScale(v) self.UserScale = clamp(v, 0.6, 1.5); self:_Fit() end

function Window:_SetSize(w, h, animate)
	w, h = math.floor(w + 0.5), math.floor(h + 0.5)
	self.W, self.H = w, h
	local s = self._scale
	if animate then
		tween(self.Holder, { Size = UDim2.fromOffset(w, h) }, Ease.Smooth)
		tween(self.Mover, { Size = UDim2.fromOffset(w * s, h * s) }, Ease.Smooth)
		delay(0.28, function()
			self.Background:Build(nil, Vector2.new(w - self.SW, h - self.HH))
			self:_Clamp()
		end)
	else
		self.Holder.Size, self.Mover.Size = UDim2.fromOffset(w, h), UDim2.fromOffset(w * s, h * s)
	end
end
function Window:SetSize(v) self.NomW, self.NomH = v.X, v.Y; self:_SetSize(v.X, v.Y, true); self:_Fit() end

-- keeps the window fully inside the screen (below the Roblox top bar), also while resizing / rotating
function Window:_Clamp()
	local vp = Library.Gui.AbsoluteSize
	local w, h = self.Mover.Size.X.Offset, self.Mover.Size.Y.Offset
	local mx = math.max(0, vp.X / 2 - w / 2 - 4)
	local up = math.max(0, vp.Y / 2 - h / 2 - 38)
	local down = math.max(0, vp.Y / 2 - h / 2 - 4)
	local p = self.Mover.Position
	self.Mover.Position = UDim2.new(0.5, clamp(p.X.Offset, -mx, mx), 0.5, clamp(p.Y.Offset, -up, down))
end

function Window:ToggleFullscreen()
	local vp = Library.Gui.AbsoluteSize
	if not self.Fullscreen then
		self._restore = { w = self.W, h = self.H, pos = self.Mover.Position }
		self.Fullscreen = true
		self.Grip.Visible = false
		local s = self._scale
		self:_SetSize((vp.X - 12) / s, (vp.Y - 44) / s, true)
		tween(self.Mover, { Position = UDim2.new(0.5, 0, 0.5, 16) }, Ease.Smooth)
	else
		local r = self._restore
		self.Fullscreen = false
		self.Grip.Visible = self.Config.Resizable ~= false
		self:_SetSize(r.w, r.h, true)
		tween(self.Mover, { Position = r.pos }, Ease.Smooth)
	end
	safe(self.OnFullscreen, self.Fullscreen)
end

---------------------------------------------------------------- state: Open / Minimized / Hidden
function Window:SetState(state)
	if state == self.State or self._dead then return end
	self.State = state
	local s = self._scale
	if state == "Open" then
		self.Mover.Visible = true
		self.UIScale.Scale = s * 0.97
		tween(self.UIScale, { Scale = s }, Ease.Smooth)
		tween(self.Fade, { GroupTransparency = 0 }, Ease.Smooth)
		tween(self.Shadow, { GroupTransparency = 0 }, Ease.Smooth)
		self:_DockShow(false)
		Sound.Play("Open")
	else
		Sound.Play("Close")
		tween(self.UIScale, { Scale = s * (state == "Minimized" and 0.9 or 0.97) }, Ease.Smooth)
		tween(self.Fade, { GroupTransparency = 1 }, Ease.Smooth)
		tween(self.Shadow, { GroupTransparency = 1 }, Ease.Smooth)
		delay(0.26, function() if self.State ~= "Open" and self.Mover.Parent then self.Mover.Visible = false end end)
		self:_DockShow(state == "Minimized")
	end
end
function Window:Open() self:SetState("Open") end
function Window:Minimize() self:SetState("Minimized") end
function Window:Restore() self:SetState("Open") end
function Window:Hide() self:SetState("Hidden") end
function Window:Toggle()
	if self.State == "Open" then self:SetState(Util.IsTouch() and "Minimized" or "Hidden") else self:SetState("Open") end
end
function Window:SetToggleKey(key) self.ToggleKey = key end
function Window:IsOpen() return self.State == "Open" end

---------------------------------------------------------------- minimize dock (pill)
function Window:_BuildDock()
	if self.Dock then return self.Dock end
	local cfg, gui = self.Config, Library.Gui
	local dc = type(cfg.Dock) == "table" and cfg.Dock or {}
	local name = dc.Title or tostring(cfg.Name)
	local width = 38 + #name * 7 + 92
	local holder = New("Frame", {
		Name = "Dock", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(width, 32),
		BackgroundTransparency = 1, Visible = false, ZIndex = 30, Parent = gui,
	})
	local scale = New("UIScale", { Parent = holder })
	local shadow = Effects.Shadow(holder, { Radius = 16, Group = true, Hidden = true, Spread = 3 })
	local fade = New("CanvasGroup", { Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Parent = holder })
	local _, body, rim = Effects.Bordered(fade, { Class = "TextButton", Radius = 16, Fill = "Card", Top = 0.78 })
	Effects.BrandMark(body, { Name = cfg.Name, Icon = dc.Icon or cfg.Icon, Logo = cfg.Logo }, { Size = 20, Position = UDim2.fromOffset(6, 5), ZIndex = 3 })
	local nm = New("TextLabel", {
		Text = name, TextSize = 12, Weight = "SemiBold", TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -120, 1, 0), ZIndex = 3, Parent = body,
	})
	Theme.Bind(nm, { TextColor3 = "Text" })
	local fps = New("TextLabel", {
		Text = "", TextSize = 10.5, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -30, 0, 0), Size = UDim2.fromOffset(60, 30), ZIndex = 3, Parent = body,
	})
	Theme.Bind(fps, { TextColor3 = "Muted" })
	Icons.New("maximize-2", 12, "SubText", body, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), ZIndex = 3 })
	Effects.Interact(body, { Base = "Card", Hover = "CardAlt", Rim = rim, ZIndex = 6 })

	local dock = { Holder = holder, Fade = fade, Shadow = shadow, Scale = scale, FPS = fps, Moved = false }
	local down, origin, startPos
	body.InputBegan:Connect(function(input)
		local ut = input.UserInputType
		if ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch then
			down, origin, startPos, dock.Moved = input, input.Position, holder.Position, false
			input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then down = nil end end)
		end
	end)
	connect(UIS.InputChanged, function(input)
		if down and (input == down or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local d = input.Position - origin
			if d.Magnitude > 5 then dock.Moved = true end
			if dock.Moved then
				local vp = gui.AbsoluteSize
				local x = clamp(startPos.X.Offset + d.X, -(vp.X / 2) + width / 2 + 4, vp.X / 2 - width / 2 - 4)
				local y = clamp(startPos.Y.Offset + d.Y, 40, vp.Y - 40)
				holder.Position = UDim2.new(0.5, x, 0, y)
			end
		end
	end)
	body.MouseButton1Click:Connect(function()
		if dock.Moved then return end
		Sound.Play("Click")
		self:SetState("Open")
	end)
	-- live FPS while visible
	local acc, frames = 0, 0
	connect(RunService.Heartbeat, function(dt)
		if not holder.Visible then return end
		acc, frames = acc + dt, frames + 1
		if acc >= 0.5 then fps.Text = ("%d FPS"):format(math.floor(frames / acc + 0.5)); acc, frames = 0, 0 end
	end)
	self.Dock = dock
	return dock
end

function Window:_DockShow(show)
	if not show and not self.Dock then return end
	local d = self:_BuildDock()
	local vp = Library.Gui.AbsoluteSize
	d.Scale.Scale = math.min(1, (vp.X - 16) / d.Holder.Size.X.Offset)
	if show then
		d.Holder.Visible = true
		d.Fade.GroupTransparency = 1
		local p = d.Holder.Position
		d.Holder.Position = UDim2.new(p.X.Scale, p.X.Offset, 0, p.Y.Offset - 14)
		tween(d.Holder, { Position = p }, Ease.Smooth)
		tween(d.Fade, { GroupTransparency = 0 }, Ease.Smooth)
		tween(d.Shadow, { GroupTransparency = 0 }, Ease.Smooth)
	else
		tween(d.Fade, { GroupTransparency = 1 }, Ease.Fast)
		tween(d.Shadow, { GroupTransparency = 1 }, Ease.Fast)
		delay(0.2, function() if self.State ~= "Minimized" then d.Holder.Visible = false end end)
	end
end

-- Window:EditDock{ Title, Icon } — rebuilds the minimized pill with new text/icon
function Window:EditDock(o)
	self.Config.Dock = o
	if self.Dock then self.Dock.Holder:Destroy(); self.Dock = nil end
	if self.State == "Minimized" then self:_DockShow(true) end
end

---------------------------------------------------------------- close / destroy
function Window:OnClose(fn) table.insert(self._closeCbs, fn) end       -- return false to cancel
function Window:OnDestroy(fn) table.insert(self._destroyCbs, fn) end

function Window:Close()
	if self._closing or self._dead then return end
	for _, cb in ipairs(self._closeCbs) do
		local ok, r = pcall(cb)
		if ok and r == false then return end
	end
	if self.Config.ConfirmClose == false then return self:Destroy() end
	self._closing = true
	self:SetState("Open")
	self:Dialog({
		Title = "Close interface?", Type = "Warning",
		Content = "The interface will be unloaded. Configs you saved stay on disk.",
		OnClose = function() self._closing = false end,
		Buttons = { { Title = "Cancel" }, { Title = "Close", Variant = "Danger", Callback = function() self:Destroy() end } },
	})
end

function Window:Destroy()
	if self._dead then return end
	for _, cb in ipairs(self._destroyCbs) do safe(cb) end
	self:SetState("Hidden")
	self._dead = true
	if self.Dock then self.Dock.Holder:Destroy() end
	for i, w in ipairs(Library.Windows) do if w == self then table.remove(Library.Windows, i) break end end
	delay(0.35, function() if self.Mover then self.Mover:Destroy() end end)
	if #Library.Windows == 0 then delay(0.5, function() Library:Unload() end) end
end

---------------------------------------------------------------- dialogs
function Window:Dialog(o) return Dialogs.Open(self.Main, o) end
-- Confirm{ Title, Content, Confirm, Cancel, Danger } -> callback(true) when confirmed
function Window:Confirm(o, cb)
	return self:Dialog({
		Title = o.Title, Content = o.Content, Type = o.Type or "Warning",
		Buttons = {
			{ Title = o.Cancel or "Cancel", Variant = "Secondary" },
			{ Title = o.Confirm or "Confirm", Variant = o.Danger and "Danger" or "Primary", Callback = function() safe(cb, true) end },
		},
	})
end
-- Prompt{ Title, Content, Placeholder, Default, Confirm } -> callback(text)
function Window:Prompt(o, cb)
	return self:Dialog({
		Title = o.Title, Content = o.Content, Type = "Info", Input = { Placeholder = o.Placeholder, Default = o.Default, Multiline = o.Multiline },
		Buttons = { { Title = "Cancel", Variant = "Secondary" }, { Title = o.Confirm or "OK", Variant = "Primary", Callback = function(text) safe(cb, text) end } },
	})
end

---------------------------------------------------------------- tags, topbar buttons, look
-- Window:Tag{ Title, Color = "Accent"|"Success"|"Warning"|"Danger"|"Muted"|Color3 }
function Window:Tag(o)
	local b = Components.Badge(self.TagRow, o.Title or "", o.Color or "Accent", { ZIndex = 5 })
	local obj = { Frame = b }
	function obj:SetText(t) b.Text = tostring(t) end
	function obj:Destroy() b:Destroy() end
	return obj
end

-- Window:CreateTopbarButton{ Icon, Callback, Tooltip }
function Window:CreateTopbarButton(o)
	self._topbar = self._topbar + 1
	return self._ctl(o.Icon or "star", 10 + self._topbar, o.Callback, o.Tooltip)
end

function Window:SetTheme(name) return Theme.Set(name) end
function Window:SetAccent(color)
	Theme.Register("Custom", { Accent = color, NeutralSaturation = Theme.Current.IsLight and 0.12 or 0.3, Light = Theme.Current.IsLight })
	Theme.Set("Custom")
end
function Window:SetBackground(style) self.Background:Build(style) end

-- 0 = solid, up to ~0.6 = see-through panels
function Window:SetTransparency(t)
	t = clamp(t, 0, 0.7)
	for _, f in ipairs({ self.Main, self.HeaderFrame, self.Sidebar, self.ContentFrame }) do tween(f, { BackgroundTransparency = t }, Ease.Smooth) end
end

function Window:SetBackgroundImage(id, transparency)
	if not self.BgImage then
		self.BgImage = New("ImageLabel", { Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop, ZIndex = 1, Parent = self.ContentFrame })
	end
	self.BgImage.Image = id and (tostring(id):find("://") and id or ("rbxassetid://" .. id)) or ""
	self.BgImage.ImageTransparency = transparency or 0.75
end

function Window:Notify(o) return Notify.Push(o) end

-- Runs fn once the loader and key system are done (immediately if they already are)
function Window:OnReady(fn)
	if self.Ready then safe(fn) else table.insert(self._readyCbs, fn) end
end
-- Yields until ready; returns false if access was denied / closed
function Window:WaitReady()
	while not self.Ready and not self._dead and not self._denied do wait() end
	return self.Ready
end

---------------------------------------------------------------- tabs
function Window:_Relayout(animate)
	local y = 2
	for _, it in ipairs(self._items) do
		local show = it.Show ~= false
		it.Frame.Visible = show
		if show then
			local pos = UDim2.fromOffset(it.X or 0, y)
			if animate then tween(it.Frame, { Position = pos }, Ease.Smooth) else it.Frame.Position = pos end
			it.Y = y
			if it.Tab then it.Tab._y = y end
			y = y + it.H + 2
		end
	end
	self.TabScroll.CanvasSize = UDim2.fromOffset(0, y)
	local cur = self.Current
	if cur then
		self.Pill.Visible = cur.Item.Show ~= false
		local pos = UDim2.fromOffset(cur.Item.X or 0, cur.Item.Y or 2)
		if animate then tween(self.Pill, { Position = pos }, Ease.Smooth) else self.Pill.Position = pos end
	end
end

function Window:CreateTabLabel(text)
	local lbl = New("TextLabel", {
		Text = tostring(text):upper(), TextSize = 9.5, Weight = "SemiBold", TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -10, 0, 16), ZIndex = 2, Parent = self.TabScroll,
	})
	Theme.Bind(lbl, { TextColor3 = "Muted" })
	table.insert(self._items, { Kind = "label", Frame = lbl, H = 18, X = 8 })
	self:_Relayout()
	return lbl
end

function Window:CreateTabDivider()
	local d = Effects.Hairline(self.TabScroll, { Size = UDim2.new(1, -8, 0, 1), BackgroundTransparency = 0.9, ZIndex = 2 })
	table.insert(self._items, { Kind = "divider", Frame = d, H = 6, X = 4 })
	self:_Relayout()
end

-- CreateTabGroup{ Title, Icon, Open } -> group:CreateTab{...}
function Window:CreateTabGroup(o)
	o = o or {}
	local g = { Window = self, Open = o.Open ~= false, Tabs = {} }
	local btn = New("TextButton", { Name = "Group", Size = UDim2.new(1, 0, 0, M.Tab), ZIndex = 2, Parent = self.TabScroll })
	local x = 10
	if o.Icon then Icons.New(o.Icon, 13, "Muted", btn, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 3 }); x = 30 end
	local lbl = New("TextLabel", { Text = o.Title or "Group", TextSize = 11, Weight = "SemiBold", TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x - 24, 1, 0), ZIndex = 3, Parent = btn })
	Theme.Bind(lbl, { TextColor3 = "SubText" })
	local chev = Icons.New("chevron-down", 12, "Muted", btn, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), ZIndex = 3, Rotation = g.Open and 0 or -90 })
	local item = { Kind = "group", Frame = btn, H = M.Tab, Group = g }
	table.insert(self._items, item)
	function g:SetOpen(b)
		g.Open = b
		tween(chev, { Rotation = b and 0 or -90 }, Ease.Smooth)
		for _, it in ipairs(self.Window._items) do if it.Group == g and it.Kind == "tab" then it.Show = b end end
		self.Window:_Relayout(true)
	end
	function g:CreateTab(o2) return self.Window:CreateTab(o2, g) end
	btn.MouseButton1Click:Connect(function() Sound.Play("Click"); g:SetOpen(not g.Open) end)
	self:_Relayout()
	return g
end

-- CreateTab{ Name, Icon, Description, Locked, LockedTitle, Badge }
function Window:CreateTab(o, group)
	if type(o) == "string" then o = { Name = o } end
	o = o or {}
	local tab = setmetatable({
		Window = self, Name = o.Name or "Tab", IconName = o.Icon, Description = o.Description, Selected = false, Locked = o.Locked, LockedTitle = o.LockedTitle,
		_order = 0, _sections = {}, _search = {}, Group = group,
	}, Tab)
	local btn = New("TextButton", { Name = tab.Name, Size = UDim2.new(1, -(group and 8 or 0), 0, M.Tab), ZIndex = 2, Parent = self.TabScroll })
	local x = 11
	if o.Icon then
		tab.Icon = Icons.New(o.Icon, 14, "SubText", btn, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 3 })
		Theme.Bind(tab.Icon, { ImageColor3 = function(t) return tab.Selected and t.Accent or t.SubText end })
		x = 31
	end
	tab.Label = New("TextLabel", {
		Text = tab.Name, TextSize = 12, Weight = "Medium", TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x - 8, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = btn,
	})
	Theme.Bind(tab.Label, { TextColor3 = function(t) return tab.Selected and t.Text or t.SubText end })
	tab.Button = btn
	if o.Badge then
		local b = Components.Badge(btn, o.Badge, o.BadgeColor or "Accent", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), ZIndex = 3 })
	end
	tab.LockIcon = Icons.New("lock", 11, "Muted", btn, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0), ZIndex = 3, Visible = tab.Locked == true })

	local item = { Kind = "tab", Frame = btn, H = M.Tab, X = group and 8 or 0, Group = group, Tab = tab, Show = not group or group.Open }
	tab.Item = item
	table.insert(self._items, item)
	if group then table.insert(group.Tabs, tab) end

	btn.MouseEnter:Connect(function()
		if not tab.Selected then tween(tab.Label, { TextColor3 = resolve("Text") }, Ease.Fast) end
	end)
	btn.MouseLeave:Connect(function()
		if not tab.Selected then tween(tab.Label, { TextColor3 = resolve("SubText") }, Ease.Smooth) end
	end)
	btn.MouseButton1Click:Connect(function()
		if tab.Locked then
			Library:Notify({ Title = tab.LockedTitle or "Locked", Content = tab.Name .. " isn't available right now.", Type = "Warning" })
			return
		end
		self:SelectTab(tab)
	end)

	tab.Page = New("CanvasGroup", { Name = tab.Name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, Parent = self.Pages })
	tab.Scroll = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarImageTransparency = 0.5, ScrollBarThickness = 3, Parent = tab.Page,
	})
	Theme.Bind(tab.Scroll, { ScrollBarImageColor3 = "Muted" })
	Padding(10, 12, 14, 10, tab.Scroll)
	List(tab.Scroll, { Padding = UDim.new(0, 12) })
	tab.NoResults = New("TextLabel", { Text = "No matching options", TextSize = 12, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 5, Parent = tab.Page })
	Theme.Bind(tab.NoResults, { TextColor3 = "Muted" })

	table.insert(self.Tabs, tab)
	self:_Relayout()
	if #self.Tabs == 1 and not tab.Locked then self:SelectTab(tab, true) end
	return tab
end

function Tab:SetLocked(b, title) self.Locked, self.LockedTitle = b, title or self.LockedTitle; self.LockIcon.Visible = b end

function Window:GetTab(name) for _, t in ipairs(self.Tabs) do if t.Name == name then return t end end end

function Window:SelectTab(tab, instant)
	if type(tab) == "string" then tab = self:GetTab(tab) end
	if type(tab) ~= "table" or self.Current == tab then return end
	local prev = self.Current
	self.Current = tab
	if not instant then Sound.Play("Click") end
	if prev then
		prev.Selected = false
		tween(prev.Label, { TextColor3 = resolve("SubText") }, Ease.Smooth)
		if prev.Icon then tween(prev.Icon, { ImageColor3 = resolve("SubText") }, Ease.Smooth) end
		tween(prev.Page, { GroupTransparency = 1 }, Ease.Fast)
		delay(0.14, function() if self.Current ~= prev then prev.Page.Visible = false end end)
	end
	tab.Selected = true
	tween(tab.Label, { TextColor3 = resolve("Text") }, Ease.Smooth)
	if tab.Icon then tween(tab.Icon, { ImageColor3 = resolve("Accent") }, Ease.Smooth) end
	tab.Page.Visible = true
	local pos = UDim2.fromOffset(tab.Item.X or 0, tab.Item.Y or 2)
	if instant then
		tab.Page.GroupTransparency = 0
		self.Pill.Position, self.Pill.Visible = pos, true
	else
		tab.Page.Position = UDim2.fromOffset(0, 8)
		tween(tab.Page, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Ease.Smooth)
		tween(self.Pill, { Position = pos }, Ease.Smooth)
		self.Pill.Visible = true
	end
	if self.SearchField and self.SearchField.Box.Text ~= "" then self:_Search(self.SearchField.Box.Text) end
	safe(self.OnTabChanged, tab)
end

---------------------------------------------------------------- search
function Window:_Search(q)
	q = tostring(q or ""):lower()
	local function scan(tab)
		local any = false
		for _, sec in ipairs(tab._sections) do
			local secAny = false
			for _, card in ipairs(sec._cards) do
				local cardAny = false
				for _, it in ipairs(card._rows) do
					local match = q == "" or it.Text:find(q, 1, true) ~= nil
					it.Row.Visible = match
					if it.Div then it.Div.Visible = q == "" end
					cardAny = cardAny or match
				end
				card.Frame.Visible = q == "" or cardAny
				secAny = secAny or cardAny
			end
			sec.Frame.Visible = q == "" or secAny
			any = any or secAny
		end
		return any
	end
	local tab = self.Current
	if not tab then return end
	local any = scan(tab)
	if q ~= "" and not any then
		for _, other in ipairs(self.Tabs) do
			if other ~= tab and not other.Locked then
				local hit = false
				for _, sec in ipairs(other._sections) do
					for _, card in ipairs(sec._cards) do
						for _, it in ipairs(card._rows) do if it.Text:find(q, 1, true) then hit = true end end
					end
				end
				if hit then self:SelectTab(other) return end
			end
		end
	end
	tab.NoResults.Visible = q ~= "" and not any
end

----------------------------------------------------------------------------
-- 10. ELEMENTS   (methods of Card; Section/Tab forward to a default card)
----------------------------------------------------------------------------
local WHITE = Color3.new(1, 1, 1)

local function elementLabel(parent, text, size, token, props)
	props = props or {}
	props.Text, props.TextSize, props.Weight = tostring(text or ""), size or 12.5, props.Weight or "Medium"
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.Parent = parent
	local l = New("TextLabel", props)
	Theme.Bind(l, { TextColor3 = token or "Text" })
	return l
end

-- common behaviour for every element object: visibility, destroy, tooltip, lock overlay
local function finish(obj, row, o)
	o = o or {}
	obj.Frame = row
	function obj:SetVisible(v) row.Visible = v end
	function obj:Destroy() row:Destroy() end
	local tip
	if o.Tooltip then tip = Effects.Tooltip(row, o.Tooltip) end
	function obj:SetTooltip(t) if tip then tip.Text = t else tip = Effects.Tooltip(row, t) end end
	local overlay
	function obj:Lock(msg)
		if overlay then return end
		local dim = New("Frame", { Name = "LockDim", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.45, ZIndex = 28, Parent = row })
		Theme.Bind(dim, { BackgroundColor3 = "Card" })
		local hit = New("TextButton", { Name = "LockHit", Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = row })
		local ic = Icons.New("lock", 11, "Muted", row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), ZIndex = 31 })
		hit.MouseButton1Click:Connect(function() Library:Notify({ Title = "Locked", Content = msg or "This option isn't available.", Type = "Warning" }) end)
		overlay = { dim, hit, ic }
	end
	function obj:Unlock()
		if overlay then for _, i in ipairs(overlay) do i:Destroy() end overlay = nil end
	end
	if o.Locked then obj:Lock(o.LockedTitle) end
	return obj
end

---------------------------------------------------------------- Label / Paragraph / Spacer / Custom
function Card:AddLabel(o)
	if type(o) == "string" then o = { Text = o } end
	o = o or {}
	local row, inner = self:_Row(26)
	local l = elementLabel(inner, o.Text or o.Name or "", 11.5, o.Color or "SubText", {
		Weight = "Regular", TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextYAlignment = Enum.TextYAlignment.Top,
	})
	self:_Index(o.Text or o.Name)
	local obj = { Type = "Label" }
	function obj:SetText(t) l.Text = tostring(t) end
	return finish(obj, row, o)
end

function Card:AddParagraph(o)
	o = o or {}
	local row, inner = self:_Row(34)
	local t, d = self:_Labels(inner, o.Title or o.Name or "", o.Content or o.Description)
	local obj = { Type = "Paragraph" }
	function obj:SetTitle(x) t.Text = x end
	function obj:SetContent(x) if d then d.Text = x end end
	return finish(obj, row, o)
end

function Card:AddSpacer(h) local row = self:_Row(h or 6, "fixed", true) return { Frame = row } end

-- Build anything yourself: card:AddCustom(function(row, card) ... end, height)
function Card:AddCustom(builder, height)
	local row = self:_Row(height or 30, "fixed")
	safe(builder, row, self)
	return { Type = "Custom", Frame = row }
end

---------------------------------------------------------------- Button (or a row of buttons)
function Card:AddButton(o)
	if type(o) == "string" then o = { Name = o } end
	o = o or {}
	local row, obj
	if o.Buttons then
		row = self:_Row(32, "fixed")
		local list = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 24), Parent = row })
		List(list, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) })
		local n, names = #o.Buttons, {}
		obj = { Type = "ButtonGroup", Buttons = {} }
		for i, b in ipairs(o.Buttons) do
			table.insert(names, b.Name or b.Text or "")
			obj.Buttons[i] = Components.Button(list, {
				Text = b.Name or b.Text, Icon = b.Icon, Style = b.Style, Height = 24, LayoutOrder = i,
				Size = UDim2.new(1 / n, -(6 * (n - 1)) / n, 1, 0), Callback = b.Callback,
			})
		end
		self:_Index(table.concat(names, " "))
	elseif o.Description and o.Description ~= "" then
		local inner
		row, inner = self:_Row(36)
		self:_Labels(inner, o.Name or "Button", o.Description, (o.ButtonWidth or 64) + 8)
		obj = Components.Button(row, {
			Text = o.ButtonText or "Run", Icon = o.Icon, Style = o.Style or "Secondary", AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(o.ButtonWidth or 64, 22), Callback = o.Callback,
		})
	else
		row = self:_Row(30, "fixed")
		obj = Components.Button(row, {
			Text = o.Name or o.Text or "Button", Icon = o.Icon, Style = o.Style or "Secondary", Align = o.Align,
			RightIcon = o.RightIcon, Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, 24), Callback = o.Callback,
		})
		self:_Index(o.Name or o.Text)
	end
	obj.Type = obj.Type or "Button"
	return finish(obj, row, o)
end

---------------------------------------------------------------- Toggle (switch or checkbox)
function Card:AddToggle(o)
	o = o or {}
	local row, inner = self:_Row(M.Row)
	local isBox = o.Type == "Checkbox"
	local nameLbl = self:_Labels(inner, o.Name or "Toggle", o.Description, isBox and 26 or 42)
	local state = o.Default == true
	local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = row })
	local obj = { Type = "Toggle", Value = state }
	local visual

	if isBox then
		local boxOuter, box, rim = Effects.Bordered(row, {
			Name = "Box", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(16, 16), Radius = 5, Top = 0.78, ZIndex = 3,
		})
		Theme.Bind(box, { BackgroundColor3 = function(t) return state and t.Accent or t.CardAlt end })
		local tick = Icons.New("check", 11, "OnAccent", box, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ImageTransparency = state and 0 or 1 })
		function visual()
			tween(box, { BackgroundColor3 = state and resolve("Accent") or resolve("CardAlt") }, Ease.Smooth)
			tween(tick, { ImageTransparency = state and 0 or 1 }, Ease.Smooth)
			rim:Set(state and 1 or 0, state and resolve("AccentGlow") or nil)
		end
		hit.MouseEnter:Connect(function() rim:Set(state and 2 or 1, state and resolve("AccentGlow") or nil) end)
		hit.MouseLeave:Connect(function() rim:Set(state and 1 or 0, state and resolve("AccentGlow") or nil) end)
	else
		local _, track, rim = Effects.Bordered(row, {
			Name = "Track", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(32, 18), Radius = 9, Top = 0.72, ZIndex = 3,
		})
		Theme.Bind(track, { BackgroundColor3 = function(t) return state and t.Accent or t.Track end })
		local knob = New("Frame", { Name = "Knob", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, state and 16 or 2, 0.5, 0), Size = UDim2.fromOffset(12, 12), ZIndex = 4, Parent = track })
		Corner("full", knob)
		Theme.Bind(knob, { BackgroundColor3 = function(t) return state and t.OnAccent or t.Knob end })
		local pressed = false
		local function knobGoal()
			local w = pressed and 16 or 12
			return UDim2.new(0, state and (30 - w - 2) or 2, 0.5, 0), UDim2.fromOffset(w, 12)
		end
		function visual()
			local p, s = knobGoal()
			tween(track, { BackgroundColor3 = state and resolve("Accent") or resolve("Track") }, Ease.Smooth)
			tween(knob, { Position = p, Size = s, BackgroundColor3 = state and resolve("OnAccent") or resolve("Knob") }, Ease.Smooth)
			rim:Set(state and 1 or 0, state and resolve("AccentGlow") or nil)
		end
		hit.MouseButton1Down:Connect(function()
			pressed = true
			local p, s = knobGoal()
			tween(knob, { Position = p, Size = s }, Ease.Fast)
		end)
		local function release() if pressed then pressed = false; local p, s = knobGoal(); tween(knob, { Position = p, Size = s }, Ease.Smooth) end end
		hit.MouseButton1Up:Connect(release)
		hit.MouseEnter:Connect(function() rim:Set(state and 2 or 1, state and resolve("AccentGlow") or nil) end)
		hit.MouseLeave:Connect(function() release(); rim:Set(state and 1 or 0, state and resolve("AccentGlow") or nil) end)
	end

	local function apply(v, silent)
		state = v and true or false
		obj.Value = state
		visual()
		if o.Flag then Library.Flags[o.Flag] = state end
		if not silent then Sound.Play("Toggle", state and 1.1 or 0.9); safe(o.Callback, state) end
	end
	function obj:Set(v, silent) if (v and true or false) ~= state then apply(v, silent) elseif not silent then safe(o.Callback, state) end end
	function obj:Get() return state end
	function obj:SetLabel(t) nameLbl.Text = t end
	hit.MouseButton1Click:Connect(function() apply(not state) end)
	self:_Register(o, "Toggle", function() return state end, function(v) obj:Set(v) end)
	return finish(obj, row, o)
end

---------------------------------------------------------------- Slider
function Card:AddSlider(o)
	o = o or {}
	local min, max, inc = o.Min or 0, o.Max or 100, o.Increment or 1
	local value = clamp(o.Default or min, min, max)
	local row = self:_Row(38, "fixed")
	elementLabel(row, o.Name or "Slider", 12.5, "Text", { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, -64, 0, 16) })
	local valLbl = elementLabel(row, "", 11.5, "SubText", {
		Weight = "SemiBold", TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(64, 16),
	})
	self:_Index(o.Name)
	local track = New("Frame", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 4), Parent = row })
	Corner("full", track)
	Theme.Bind(track, { BackgroundColor3 = "Track" })
	local fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), Parent = track })
	Corner("full", fill)
	Theme.Bind(fill, { BackgroundColor3 = "Accent" })
	local knobHolder = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 3, Parent = track })
	Effects.Shadow(knobHolder, { Radius = 5, Spread = 2, OffsetY = 1, Strength = 0.4 })
	local knob = New("Frame", { Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = knobHolder })
	Corner("full", knob)
	Theme.Bind(knob, { BackgroundColor3 = "Knob" })
	local hit = New("TextButton", { Position = UDim2.fromOffset(-6, 18), Size = UDim2.new(1, 12, 0, 20), ZIndex = 5, Parent = row })

	local obj = { Type = "Slider" }
	local function visual(instant)
		local ratio = (max == min) and 0 or (value - min) / (max - min)
		if instant then
			fill.Size, knobHolder.Position = UDim2.new(ratio, 0, 1, 0), UDim2.new(ratio, 0, 0.5, 0)
		else
			tween(fill, { Size = UDim2.new(ratio, 0, 1, 0) }, Ease.Fast)
			tween(knobHolder, { Position = UDim2.new(ratio, 0, 0.5, 0) }, Ease.Fast)
		end
		valLbl.Text = ("%g"):format(round(value, inc)) .. (o.Suffix or "")
	end
	local function set(v, silent, instant)
		v = clamp(round(v, inc), min, max)
		if v == value and not instant then return end
		value = v
		obj.Value = v
		visual(instant)
		if o.Flag then Library.Flags[o.Flag] = v end
		if not silent then Sound.Play("Slide", 0.9 + 0.4 * ((v - min) / math.max(max - min, 1e-9))); safe(o.Callback, v) end
	end
	local function grow(big) tween(knobHolder, { Size = big and UDim2.fromOffset(13, 13) or UDim2.fromOffset(10, 10) }, Ease.Fast) end
	Util.Drag(hit, function(pos)
		set(min + clamp((pos.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1) * (max - min))
	end, function() grow(false) end)
	hit.MouseButton1Down:Connect(function() grow(true) end)
	hit.MouseEnter:Connect(function() grow(true) end)
	hit.MouseLeave:Connect(function() grow(false) end)
	value = clamp(round(value, inc), min, max)
	obj.Value = value
	visual(true)
	if o.Flag then Library.Flags[o.Flag] = value end
	function obj:Set(v, silent) set(v, silent) end
	function obj:Get() return value end
	self:_Register(o, "Slider", function() return value end, function(v) if type(v) == "number" then set(v) end end)
	return finish(obj, row, o)
end

---------------------------------------------------------------- Input (single or multi line)
function Card:AddInput(o)
	o = o or {}
	local fieldH = o.Multiline and 64 or 24
	local row = self:_Row(26 + fieldH, "fixed")
	elementLabel(row, o.Name or "Input", 12.5, "Text", { Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 16) })
	self:_Index(o.Name)
	local value = tostring(o.Default or "")
	local field = Components.Field(row, {
		Placeholder = o.Placeholder or "Type here…", Text = value, Numeric = o.Numeric, Multiline = o.Multiline,
		Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, fieldH), Live = o.Live,
		OnChange = function(t) value = t; if o.Flag then Library.Flags[o.Flag] = t end; safe(o.OnChange, t) end,
		Callback = function(text, enter)
			value = text
			if o.Flag then Library.Flags[o.Flag] = text end
			if enter or not o.EnterOnly then safe(o.Callback, text) end
		end,
	})
	local obj = { Type = "Input", Value = value }
	function obj:Set(t, silent)
		value = tostring(t); field.Set(value)
		if o.Flag then Library.Flags[o.Flag] = value end
		if not silent then safe(o.Callback, value) end
	end
	function obj:Get() return value end
	if o.Flag then Library.Flags[o.Flag] = value end
	self:_Register(o, "Input", function() return value end, function(v) obj:Set(v) end)
	return finish(obj, row, o)
end

---------------------------------------------------------------- Number (stepper)
function Card:AddNumber(o)
	o = o or {}
	local min, max, inc = o.Min or -math.huge, o.Max or math.huge, o.Increment or 1
	local value = clamp(o.Default or 0, min, max)
	local row = self:_Row(50, "fixed")
	elementLabel(row, o.Name or "Number", 12.5, "Text", { Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 16) })
	self:_Index(o.Name)
	local field
	local obj = { Type = "Number" }
	local function set(v, silent)
		v = clamp(round(tonumber(v) or value, inc), min, max)
		value = v
		obj.Value = v
		field.Set(("%g"):format(v))
		if o.Flag then Library.Flags[o.Flag] = v end
		if not silent then safe(o.Callback, v) end
	end
	field = Components.Field(row, {
		Numeric = true, Text = ("%g"):format(value), Align = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(28, 24), Size = UDim2.new(1, -56, 0, 24), Callback = function(t) set(t) end,
	})
	local function stepper(iconName, dir, pos)
		local b = Components.Button(row, { Icon = iconName, Text = "", Style = "Secondary", Position = pos, Size = UDim2.fromOffset(24, 24), Height = 24 })
		local token, down = 0, false
		b.Body.MouseButton1Down:Connect(function()
			token = token + 1
			local my = token
			down = true
			set(value + dir * inc)
			delay(0.4, function() while down and token == my do set(value + dir * inc); wait(0.06) end end)
		end)
		local function up() down = false end
		b.Body.MouseButton1Up:Connect(up)
		b.Body.MouseLeave:Connect(up)
		b.Callback = nil
	end
	stepper("minus", -1, UDim2.fromOffset(0, 24))
	stepper("plus", 1, UDim2.new(1, -24, 0, 24))
	function obj:Set(v, silent) set(v, silent) end
	function obj:Get() return value end
	obj.Value = value
	if o.Flag then Library.Flags[o.Flag] = value end
	self:_Register(o, "Number", function() return value end, function(v) set(v) end)
	return finish(obj, row, o)
end

---------------------------------------------------------------- expandable header (dropdown / colour picker)
local function expandable(card, name, headH)
	local row = card:_Row(headH, "auto")
	List(row)
	local head = New("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, headH), BackgroundTransparency = 1, LayoutOrder = 1, Parent = row })
	elementLabel(head, name, 12.5, "Text", { Size = UDim2.new(0.5, 0, 1, 0) })
	card:_Index(name)
	local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = head })
	local drop = New("Frame", { Name = "Drop", Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = 2, Parent = row })
	local box = New("Frame", { Name = "Box", Size = UDim2.new(1, 0, 1, -5), Parent = drop })
	Corner(6, box)
	Theme.Bind(box, { BackgroundColor3 = "CardAlt" })
	return row, head, hit, drop, box
end

---------------------------------------------------------------- Dropdown (single / multi / searchable)
function Card:AddDropdown(o)
	o = o or {}
	local multi = o.Multi == true
	local options = o.Options or {}
	local value, set = nil, {}
	local row, head, hit, drop, box = expandable(self, o.Name or "Dropdown", M.Row)
	local searchable = o.Search == true or (o.Search == nil and #options > 8)

	local valLbl = elementLabel(head, "", 11.5, "SubText", {
		TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -17, 0.5, 0), Size = UDim2.new(0.5, 0, 0, 16),
	})
	local chev = Icons.New("chevron-down", 12, "Muted", head, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0) })

	local topPad = searchable and 30 or 4
	local scroll = New("ScrollingFrame", {
		Position = UDim2.fromOffset(0, topPad), Size = UDim2.new(1, 0, 1, -topPad), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2, ScrollBarImageTransparency = 0.5, Parent = box,
	})
	Theme.Bind(scroll, { ScrollBarImageColor3 = "Muted" })
	Padding(0, 4, 4, 4, scroll)
	List(scroll, { Padding = UDim.new(0, 1) })

	local obj = { Type = "Dropdown" }
	local buttons = {}
	local open = false
	local function isSel(n) if multi then return set[n] == true end return value == n end
	local function list() local t = {} for _, n in ipairs(options) do if set[n] then table.insert(t, n) end end return t end
	local function current() if multi then return list() end return value end
	local function summary()
		if multi then local l = list() return #l > 0 and table.concat(l, ", ") or "None" end
		return value ~= nil and tostring(value) or "Select…"
	end
	local function render()
		valLbl.Text = summary()
		for n, b in pairs(buttons) do
			local sel = isSel(n)
			tween(b.Label, { TextColor3 = sel and resolve("Text") or resolve("SubText") }, Ease.Smooth)
			tween(b.Check, { ImageTransparency = sel and 0 or 1 }, Ease.Smooth)
		end
		if o.Flag then Library.Flags[o.Flag] = current() end
	end
	local function targetH() return math.min(#options, 6) * 23 + (searchable and 34 or 8) + 5 end
	local function setOpen(v)
		open = v
		tween(drop, { Size = UDim2.new(1, 0, 0, v and targetH() or 0) }, Ease.Smooth)
		tween(chev, { Rotation = v and 180 or 0 }, Ease.Smooth)
	end
	local function choose(n, silent)
		if multi then set[n] = not set[n] or nil else value = n end
		render()
		if not silent then Sound.Play("Click"); safe(o.Callback, current()) end
		if not multi and o.CloseOnSelect ~= false then setOpen(false) end
	end
	local function build()
		for _, b in pairs(buttons) do b.Btn:Destroy() end
		buttons = {}
		for i, n in ipairs(options) do
			local b = New("TextButton", { Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i, Parent = scroll })
			Corner(5, b)
			Theme.Bind(b, { BackgroundColor3 = "Hover" })
			b.BackgroundTransparency = 1
			local lbl = elementLabel(b, n, 12, "SubText", { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -28, 1, 0) })
			Theme.Bind(lbl, { TextColor3 = function(t) return isSel(n) and t.Text or t.SubText end })
			local chk = Icons.New("check", 12, "Accent", b, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0), ImageTransparency = isSel(n) and 0 or 1 })
			b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0.4 }, Ease.Fast) end)
			b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 1 }, Ease.Smooth) end)
			b.MouseButton1Click:Connect(function() choose(n) end)
			buttons[n] = { Btn = b, Label = lbl, Check = chk }
		end
		if open then drop.Size = UDim2.new(1, 0, 0, targetH()) end
	end
	if searchable then
		local sf = Components.Field(box, {
			Icon = "search", Placeholder = "Search…", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 22), Token = "Card", Live = true,
			OnChange = function(t)
				t = t:lower()
				for n, b in pairs(buttons) do b.Btn.Visible = t == "" or tostring(n):lower():find(t, 1, true) ~= nil end
			end,
		})
	end
	hit.MouseButton1Click:Connect(function() Sound.Play("Click"); setOpen(not open) end)
	hit.MouseEnter:Connect(function() tween(chev, { ImageColor3 = resolve("Text") }, Ease.Fast) end)
	hit.MouseLeave:Connect(function() tween(chev, { ImageColor3 = resolve("Muted") }, Ease.Smooth) end)

	function obj:Set(v, silent)
		if multi then
			set = {}
			if type(v) == "table" then for _, n in ipairs(v) do set[n] = true end elseif v ~= nil then set[v] = true end
		else value = v end
		render()
		if not silent then safe(o.Callback, current()) end
	end
	function obj:Get() return current() end
	function obj:Refresh(newOptions, keep)
		options = newOptions or {}
		if not keep then value, set = nil, {} end
		build(); render()
	end
	function obj:Open(v) setOpen(v ~= false) end
	build()
	local def = o.Default
	if multi then if type(def) == "table" then for _, n in ipairs(def) do set[n] = true end end else value = def end
	render()
	self:_Register(o, "Dropdown", current, function(v) obj:Set(v) end)
	return finish(obj, row, o)
end

---------------------------------------------------------------- Keybind
local KEY_LABELS = {
	LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl", LeftAlt = "LAlt", RightAlt = "RAlt",
	Return = "Enter", Backspace = "Bksp", Escape = "Esc", MouseButton2 = "MB2", MouseButton3 = "MB3", Unknown = "None",
	CapsLock = "Caps", Delete = "Del", Insert = "Ins", PageUp = "PgUp", PageDown = "PgDn",
}
local function keyLabel(name) return KEY_LABELS[name] or name end

function Card:AddKeybind(o)
	o = o or {}
	local row, inner = self:_Row(M.Row)
	self:_Labels(inner, o.Name or "Keybind", o.Description, 64)
	local keyName = "None"
	local def = o.Default
	if typeof(def) == "EnumItem" then keyName = def.Name elseif type(def) == "string" then keyName = def end
	local mode = o.Mode or "Press"
	local listening, held = false, false

	local btnOuter, btn, rim = Effects.Bordered(row, {
		Class = "TextButton", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(46, 20),
		Radius = 6, Fill = "CardAlt", Top = 0.86, ZIndex = 3,
	})
	applyFont(btn, "SemiBold")
	btn.TextSize = 11
	Theme.Bind(btn, { TextColor3 = "SubText" })
	Effects.Interact(btn, { Base = "CardAlt", Hover = "Hover", Rim = rim, ZIndex = 4 })

	local obj = { Type = "Keybind" }
	local function render()
		btn.Text = listening and "…" or keyLabel(keyName)
		btnOuter.Size = UDim2.fromOffset(math.max(42, #btn.Text * 6.6 + 20), 20)
	end
	local function matches(input)
		if keyName == "None" then return false end
		if input.KeyCode ~= Enum.KeyCode.Unknown then return input.KeyCode.Name == keyName end
		return input.UserInputType.Name == keyName
	end
	local function setKey(n, silent)
		keyName = n
		obj.Value = n
		if o.Flag then Library.Flags[o.Flag] = n end
		render()
		if not silent then safe(o.ChangedCallback, n) end
	end
	btn.MouseButton1Click:Connect(function()
		if listening then return end
		Sound.Play("Click")
		listening = true
		render()
		Theme.Bind(btn, { TextColor3 = "Accent" })
		local c
		c = UIS.InputBegan:Connect(function(input)
			local ut = input.UserInputType
			local pick
			if ut == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then pick = keyName
				elseif input.KeyCode == Enum.KeyCode.Backspace then pick = "None"
				else pick = input.KeyCode.Name end
			elseif ut == Enum.UserInputType.MouseButton2 or ut == Enum.UserInputType.MouseButton3 then pick = ut.Name end
			if pick then
				c:Disconnect()
				setKey(pick)
				Theme.Bind(btn, { TextColor3 = "SubText" })
				wait(0.12)
				listening = false
				render()
			end
		end)
	end)
	local c1 = UIS.InputBegan:Connect(function(input, gp)
		if listening or gp or not matches(input) then return end
		if mode == "Hold" then held = true; safe(o.Callback, true)
		elseif mode == "Toggle" then held = not held; safe(o.Callback, held)
		else safe(o.Callback) end
	end)
	local c2 = UIS.InputEnded:Connect(function(input)
		if mode == "Hold" and held and matches(input) then held = false; safe(o.Callback, false) end
	end)
	Library._maid:Add(c1); Library._maid:Add(c2)
	function obj:Set(v, silent)
		if typeof(v) == "EnumItem" then v = v.Name end
		setKey(tostring(v or "None"), silent)
	end
	function obj:Get() return keyName end
	setKey(keyName, true)
	self:_Register(o, "Keybind", function() return keyName end, function(v) obj:Set(v) end)
	finish(obj, row, o)
	function obj:Destroy() c1:Disconnect(); c2:Disconnect(); row:Destroy() end
	return obj
end

---------------------------------------------------------------- Color picker
function Card:AddColorPicker(o)
	o = o or {}
	local color = o.Default or Color3.fromRGB(150, 94, 255)
	local h, s, v = Color3.toHSV(color)
	local row, head, hit, drop, box = expandable(self, o.Name or "Color", M.Row)
	local open = false
	local _, swatch = Effects.Bordered(head, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(32, 18), Radius = 5, Top = 0.6 })
	swatch.BackgroundColor3 = color

	Padding(7, 7, 7, 7, box)
	local sv = New("Frame", { Size = UDim2.new(1, -22, 0, 84), BackgroundColor3 = Color3.fromHSV(h, 1, 1), Parent = box })
	Corner(5, sv)
	local white = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = sv })
	Corner(5, white)
	New("UIGradient", { Transparency = NumberSequence.new({ kp(0, 0), kp(1, 1) }), Parent = white })
	local black = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = sv })
	Corner(5, black)
	New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 1), kp(1, 0) }), Parent = black })
	local cursor = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = WHITE, ZIndex = 5, Parent = sv })
	Corner("full", cursor)
	Effects.Shadow(cursor, { Radius = 5, Spread = 2, OffsetY = 1, Strength = 0.5 })
	local dot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = color, ZIndex = 6, Parent = cursor })
	Corner("full", dot)

	local hue = New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 12, 0, 84), BackgroundColor3 = WHITE, Parent = box })
	Corner(5, hue)
	local seq = {}
	for i = 0, 6 do table.insert(seq, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 == 1 and 0.999 or i / 6, 1, 1))) end
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(seq), Parent = hue })
	local hueMark = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, h, 0), Size = UDim2.new(1, 4, 0, 3), BackgroundColor3 = WHITE, ZIndex = 5, Parent = hue })
	Corner("full", hueMark)
	Effects.Shadow(hueMark, { Radius = 2, Spread = 2, OffsetY = 1, Strength = 0.5 })

	local hexField
	local obj = { Type = "ColorPicker" }
	local function hex(c) return ("#%02X%02X%02X"):format(math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
	local function refresh(silent, fromHex)
		color = Color3.fromHSV(h, s, v)
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		cursor.Position = UDim2.fromScale(s, 1 - v)
		dot.BackgroundColor3 = color
		hueMark.Position = UDim2.new(0.5, 0, h, 0)
		swatch.BackgroundColor3 = color
		if not fromHex and hexField and not hexField.Box:IsFocused() then hexField.Set(hex(color)) end
		obj.Value = color
		if o.Flag then Library.Flags[o.Flag] = color end
		if not silent then safe(o.Callback, color) end
	end
	local svHit = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = sv })
	Util.Drag(svHit, function(pos)
		s = clamp((pos.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
		v = 1 - clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
		refresh()
	end)
	local hueHit = New("TextButton", { Size = UDim2.new(1, 8, 1, 0), Position = UDim2.fromOffset(-4, 0), ZIndex = 7, Parent = hue })
	Util.Drag(hueHit, function(pos)
		h = clamp((pos.Y - hue.AbsolutePosition.Y) / math.max(hue.AbsoluteSize.Y, 1), 0, 0.999)
		refresh()
	end)
	hexField = Components.Field(box, {
		Placeholder = "#RRGGBB", Text = hex(color), Align = Enum.TextXAlignment.Center, TextSize = 11.5,
		Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 0, 22), Token = "Card",
		Callback = function(text)
			local t = text:gsub("#", "")
			if #t == 6 and t:match("^%x+$") then
				h, s, v = Color3.toHSV(Color3.fromRGB(tonumber(t:sub(1, 2), 16), tonumber(t:sub(3, 4), 16), tonumber(t:sub(5, 6), 16)))
				refresh(false, true)
			else hexField.Set(hex(color)) end
		end,
	})
	local function setOpen(b) open = b; tween(drop, { Size = UDim2.new(1, 0, 0, b and 136 or 0) }, Ease.Smooth) end
	hit.MouseButton1Click:Connect(function() Sound.Play("Click"); setOpen(not open) end)
	function obj:Set(c, silent)
		if type(c) == "table" and typeof(c) ~= "Color3" then c = Color3.new(c.R or c.r or 0, c.G or c.g or 0, c.B or c.b or 0) end
		if typeof(c) ~= "Color3" then return end
		h, s, v = Color3.toHSV(c)
		refresh(silent)
	end
	function obj:Get() return color end
	refresh(true)
	self:_Register(o, "ColorPicker", function() return color end, function(c) obj:Set(c) end)
	return finish(obj, row, o)
end

---------------------------------------------------------------- Code block (with copy), Progress, Stat, Image
function Card:AddCode(o)
	o = o or {}
	local row = self:_Row(60, "auto")
	List(row, { Padding = UDim.new(0, 4) })
	Padding(4, 0, 4, 0, row)
	if o.Title then
		elementLabel(row, o.Title, 12, "Text", { Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1 })
		self:_Index(o.Title)
	end
	local _, box = Effects.Bordered(row, { Radius = 6, Fill = "CardAlt", Top = 0.9, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2 })
	box.Parent.AutomaticSize = Enum.AutomaticSize.Y
	box.Size = UDim2.new(1, -2, 0, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.Position = UDim2.fromOffset(1, 1)
	local txt = New("TextLabel", {
		Text = o.Code or "", TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -34, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = box,
	})
	txt.Font = Enum.Font.Code
	Padding(7, 0, 7, 8, txt)
	Theme.Bind(txt, { TextColor3 = "SubText" })
	local copy = iconButton(box, "copy", UDim2.new(1, -26, 0, 4), function()
		if setclipboard then pcall(setclipboard, txt.Text) end
		Library:Notify({ Title = "Copied", Content = "Code copied to your clipboard.", Type = "Success", Duration = 2 })
	end, 22)
	local obj = { Type = "Code" }
	function obj:SetCode(t) txt.Text = tostring(t) end
	return finish(obj, row, o)
end

function Card:AddProgress(o)
	o = o or {}
	local row = self:_Row(32, "fixed")
	elementLabel(row, o.Name or "Progress", 12.5, "Text", { Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, -60, 0, 16) })
	self:_Index(o.Name)
	local val = elementLabel(row, "", 11.5, "SubText", { Weight = "SemiBold", TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 3), Size = UDim2.fromOffset(60, 16) })
	local track = New("Frame", { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 5), Parent = row })
	Corner("full", track)
	Theme.Bind(track, { BackgroundColor3 = "Track" })
	local fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), Parent = track })
	Corner("full", fill)
	Theme.Bind(fill, { BackgroundColor3 = o.Color or "Accent" })
	local obj = { Type = "Progress", Value = 0 }
	function obj:Set(p, text)
		p = clamp(p, 0, 1)
		obj.Value = p
		tween(fill, { Size = UDim2.new(p, 0, 1, 0) }, Ease.Smooth)
		val.Text = text or (math.floor(p * 100 + 0.5) .. "%")
	end
	obj:Set(o.Default or 0)
	return finish(obj, row, o)
end

function Card:AddStat(o)
	o = o or {}
	local row, inner = self:_Row(M.Row - 2)
	local t = self:_Labels(inner, o.Name or "Stat", o.Description, 90)
	local val = elementLabel(row, tostring(o.Value or "–"), 12, o.Color or "Accent", {
		Weight = "SemiBold", TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 88, 0, 16),
	})
	local obj = { Type = "Stat" }
	function obj:Set(v) val.Text = tostring(v) end
	return finish(obj, row, o)
end

function Card:AddImage(o)
	o = o or {}
	local row = self:_Row((o.Height or 80) + 6, "fixed")
	local img = New("ImageLabel", {
		Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, o.Height or 80), ScaleType = o.Fit and Enum.ScaleType.Fit or Enum.ScaleType.Crop,
		Image = o.Image and (tostring(o.Image):find("://") and o.Image or ("rbxassetid://" .. o.Image)) or "", Parent = row,
	})
	Corner(6, img)
	local obj = { Type = "Image" }
	function obj:Set(id) img.Image = tostring(id):find("://") and id or ("rbxassetid://" .. id) end
	return finish(obj, row, o)
end

-- Theme swatch grid: one small square per registered theme
function Card:AddThemeGrid(o)
	o = o or {}
	local names = {}
	for _, n in ipairs(Library.ThemeOrder) do table.insert(names, n) end
	local rows = math.ceil(#names / 6)
	local row = self:_Row(rows * 44 + 8, "fixed")
	self:_Index("theme themes appearance")
	local grid = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 1, -8), Parent = row })
	New("UIGridLayout", { CellSize = UDim2.new(1 / 6, -5, 0, 38), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local sw = {}
	local function mark()
		for n, s in pairs(sw) do s.rim:Set(n == Theme.Name and 2 or 0, n == Theme.Name and Library.Themes[n].Accent or nil) end
	end
	for i, n in ipairs(names) do
		local th = Library.Themes[n]
		local outer, body, rim = Effects.Bordered(grid, { Class = "TextButton", Radius = 7, Top = 0.82, LayoutOrder = i })
		body.BackgroundColor3 = th.Window
		local dot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.42, 0), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = th.Accent, Parent = body })
		Corner("full", dot)
		local bar = New("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(0.6, 0, 0, 3), BackgroundColor3 = th.Card, Parent = body })
		Corner("full", bar)
		Effects.Tooltip(body, n)
		body.MouseButton1Click:Connect(function() Sound.Play("Click"); Theme.Set(n); mark(); safe(o.Callback, n) end)
		sw[n] = { rim = rim }
	end
	mark()
	Theme.OnChange(function() if row.Parent then mark() end end)
	return finish({ Type = "ThemeGrid" }, row, o)
end

----------------------------------------------------------------------------
-- 11. HOME TAB  (welcome, live stats, game detection, quick access, discord, changelog)
----------------------------------------------------------------------------
local function pingMs()
	local ms
	pcall(function() ms = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
	if not ms then pcall(function() ms = LocalPlayer:GetNetworkPing() * 2000 end) end
	return ms and math.floor(ms + 0.5) or nil
end

-- Home tab: build it FIRST so it is the first sidebar entry.
-- CreateHomeTab{ Name, Icon, Welcome, Games = { [placeId] = "Name" | { Name, Supported } }, Features = {...},
--                Discord = { Invite, Name }, Links = { { Name, Url, Icon } }, Changelog = { { Version, Date, Items = {...} } },
--                Stats = true, QuickAccess = true }
function Window:CreateHomeTab(o)
	o = o or {}
	local win = self
	local tab = self:CreateTab({ Name = o.Name or "Home", Icon = o.Icon or "house", Description = "Overview and quick access" })
	local t0 = os.clock()

	-- welcome
	local welcome = tab:CreateSection({})
	local wc = welcome:AddCard({ Wide = true })
	wc:AddCustom(function(row)
		local avatar = New("ImageLabel", {
			Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(46, 46), Parent = row,
			Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(LocalPlayer.UserId),
		})
		Corner("full", avatar)
		avatar.BackgroundTransparency = 0
		Theme.Bind(avatar, { BackgroundColor3 = "CardAlt" })
		local hello = New("TextLabel", {
			Text = (o.Welcome or "Welcome back") .. ", " .. LocalPlayer.DisplayName, TextSize = 15, Weight = "Bold", TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(58, 10), Size = UDim2.new(1, -150, 0, 20), Parent = row,
		})
		Theme.Bind(hello, { TextColor3 = "Text" })
		local sub = New("TextLabel", {
			Text = ("@%s  ·  account age %d days  ·  %s"):format(LocalPlayer.Name, LocalPlayer.AccountAge or 0, executorName()), TextSize = 10.5,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(58, 32), Size = UDim2.new(1, -150, 0, 16), Parent = row,
		})
		Theme.Bind(sub, { TextColor3 = "Muted" })
		local ver = win.Config.Version or o.Version
		if ver then
			local b = Components.Badge(row, "v" .. tostring(ver), "Accent", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 12) })
		end
		local status = Components.Badge(row, "Online", "Success", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 32) })
	end, 64)

	-- live stats
	if o.Stats ~= false then
		local live = tab:CreateSection({ Title = "Live", Subtitle = "Updated twice a second" })
		local lc = live:AddCard({ Wide = true })
		local defs = {
			{ "fps", "FPS" }, { "ping", "Ping" }, { "players", "Players" },
			{ "session", "Running time" }, { "server", "Server time" }, { "memory", "Memory" },
		}
		local row = lc:_Row(2 * 46 + 4, "fixed", true)
		local grid = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 1, -4), Parent = row })
		New("UIGridLayout", { CellSize = UDim2.new(1 / 3, -5, 0, 40), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		local vals = {}
		for i, d in ipairs(defs) do
			local tile = New("Frame", { LayoutOrder = i, Parent = grid })
			Corner(7, tile)
			Theme.Bind(tile, { BackgroundColor3 = "CardAlt" })
			local v = New("TextLabel", { Text = "–", TextSize = 14, Weight = "Bold", TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(9, 4), Size = UDim2.new(1, -12, 0, 18), Parent = tile })
			Theme.Bind(v, { TextColor3 = "Text" })
			local l = New("TextLabel", { Text = d[2], TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(9, 22), Size = UDim2.new(1, -12, 0, 14), Parent = tile })
			Theme.Bind(l, { TextColor3 = "Muted" })
			vals[d[1]] = v
		end
		local acc, frames = 0, 0
		connect(RunService.Heartbeat, function(dt)
			acc, frames = acc + dt, frames + 1
			if acc < 0.5 then return end
			local fps = frames / acc
			acc, frames = 0, 0
			if win.State ~= "Open" or win.Current ~= tab then return end
			vals.fps.Text = tostring(math.floor(fps + 0.5))
			Theme.Bind(vals.fps, { TextColor3 = fps >= 50 and "Success" or (fps >= 28 and "Warning" or "Danger") })
			local ms = pingMs()
			vals.ping.Text = ms and (ms .. " ms") or "–"
			Theme.Bind(vals.ping, { TextColor3 = (not ms) and "Text" or (ms <= 90 and "Success" or (ms <= 180 and "Warning" or "Danger")) })
			vals.players.Text = ("%d / %d"):format(#Players:GetPlayers(), Players.MaxPlayers)
			vals.session.Text = fmtTime(os.clock() - t0)
			vals.server.Text = fmtTime(workspace.DistributedGameTime)
			local mem = 0
			pcall(function() mem = Stats:GetTotalMemoryUsageMb() end)
			vals.memory.Text = math.floor(mem + 0.5) .. " MB"
		end)
	end

	-- game detection + quick access side by side
	local info = tab:CreateSection({ Title = "Overview" })
	local gc = info:AddCard({ Title = "Game" })
	local placeId = game.PlaceId
	local known = o.Games and (o.Games[placeId] or o.Games[tostring(placeId)])
	local gName = type(known) == "table" and known.Name or known
	local supported = type(known) == "table" and known.Supported ~= false or known ~= nil
	local gameStat = gc:AddStat({ Name = "Detected", Value = gName or "Detecting…", Color = "Text" })
	spawn(function()
		if gName or not MarketplaceService then return end
		local ok, pinfo = pcall(function() return MarketplaceService:GetProductInfo(placeId) end)
		if ok and pinfo and pinfo.Name then gameStat:Set(pinfo.Name) else gameStat:Set("Unknown") end
	end)
	gc:AddStat({ Name = "Support", Value = supported and "Supported" or "Universal mode", Color = supported and "Success" or "Warning" })
	gc:AddStat({ Name = "Place ID", Value = tostring(placeId), Color = "SubText" })
	gc:AddButton({
		Buttons = {
			{ Name = "Copy Job ID", Icon = "copy", Callback = function()
				if setclipboard then pcall(setclipboard, tostring(game.JobId)) end
				Library:Notify({ Title = "Copied", Content = "Server Job ID copied.", Type = "Success", Duration = 2 })
			end },
			{ Name = "Rejoin", Icon = "refresh-cw", Callback = function()
				win:Confirm({ Title = "Rejoin this server?", Content = "You will be teleported back into the same server.", Confirm = "Rejoin" }, function()
					pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
				end)
			end },
		},
	})

	if o.QuickAccess ~= false then
		local qa = info:AddCard({ Title = "Quick access" })
		-- filled at launch, when every tab exists
		table.insert(self._prelaunch, function()
			local count = 0
			for _, t in ipairs(win.Tabs) do
				if t ~= tab then
					count = count + 1
					local btn = qa:AddButton({
						Name = t.Name, Icon = t.IconName, Align = "Left", RightIcon = "chevron-right", Style = "Ghost",
						Tooltip = t.Description, Callback = function() if not t.Locked then win:SelectTab(t) end end,
					})
				end
			end
			if count == 0 then qa:AddLabel("Create more tabs to see shortcuts here.") end
		end)
	end

	-- features
	if o.Features and #o.Features > 0 then
		local fs = tab:CreateSection({ Title = "What it has", Subtitle = "Everything included in this script" })
		local fc = fs:AddCard({ Wide = true })
		for _, f in ipairs(o.Features) do
			if type(f) == "string" then fc:AddParagraph({ Title = f }) else fc:AddParagraph({ Title = f.Name or f.Title, Content = f.Description }) end
		end
	end

	-- discord / links
	if o.Discord or (o.Links and #o.Links > 0) then
		local cs = tab:CreateSection({ Title = "Community" })
		local cc = cs:AddCard({ Wide = true })
		if o.Discord then
			local d = o.Discord
			local code = tostring(d.Invite or d.Url or ""):match("discord%.gg/([%w%-]+)") or tostring(d.Invite or ""):match("([%w%-]+)$")
			local url = tostring(d.Invite or ""):find("^http") and d.Invite or ("https://discord.gg/" .. tostring(d.Invite))
			cc:AddButton({
				Name = d.Name or "Discord server", Description = d.Description or url, ButtonText = "Join", Style = "Primary", Icon = "log-in",
				Callback = function()
					spawn(function()
						local ok = false
						local r = httpRequest({
							Url = "http://127.0.0.1:6463/rpc?v=1", Method = "POST",
							Headers = { ["Content-Type"] = "application/json", Origin = "https://discord.com" },
							Body = jsonEncode({ cmd = "INVITE_BROWSER", args = { code = code }, nonce = HttpService:GenerateGUID(false) }),
						})
						if r and (r.StatusCode or 0) < 300 then ok = true end
						if not ok and setclipboard then pcall(setclipboard, url) end
						Library:Notify({
							Title = ok and "Discord" or "Invite copied", Type = ok and "Success" or "Info", Duration = 3,
							Content = ok and "Opening the invite in your Discord app." or "Paste the invite link in your browser to join.",
						})
					end)
				end,
			})
		end
		for _, l in ipairs(o.Links or {}) do
			cc:AddButton({
				Name = l.Name, Description = l.Description or l.Url, ButtonText = "Copy", Icon = l.Icon or "external-link",
				Callback = function()
					if setclipboard then pcall(setclipboard, l.Url) end
					Library:Notify({ Title = "Copied", Content = l.Name .. " link copied.", Type = "Success", Duration = 2 })
				end,
			})
		end
	end

	-- changelog
	if o.Changelog and #o.Changelog > 0 then
		local ch = tab:CreateSection({ Title = "What's new", Collapsible = true, Open = true })
		local cc = ch:AddCard({ Wide = true })
		for _, e in ipairs(o.Changelog) do
			cc:AddParagraph({
				Title = ("%s%s"):format(e.Version and ("v" .. e.Version) or "Update", e.Date and ("  ·  " .. e.Date) or ""),
				Content = type(e.Items) == "table" and ("• " .. table.concat(e.Items, "\n• ")) or tostring(e.Items or ""),
			})
		end
	end
	return tab
end

----------------------------------------------------------------------------
-- Watermark: small draggable HUD pill (name · FPS · ping · clock)
----------------------------------------------------------------------------
function Library:Watermark(o)
	o = o or {}
	if not Library.Gui then return end
	local holder = New("Frame", { Name = "Watermark", Position = UDim2.fromOffset(12, 44), Size = UDim2.fromOffset(40, 24), BackgroundTransparency = 1, ZIndex = 60, Parent = Library.Gui })
	local scale = New("UIScale", { Parent = holder })
	Effects.Shadow(holder, { Radius = 7, Spread = 2 })
	local _, body, rim = Effects.Bordered(holder, { Class = "TextButton", Radius = 7, Fill = "Card", Top = 0.8 })
	local label = New("TextLabel", { Text = "", TextSize = 11, Weight = "Medium", Size = UDim2.fromScale(1, 1), Parent = body })
	Theme.Bind(label, { TextColor3 = "Text" })
	local show = o.Show or { FPS = true, Ping = true, Time = true }
	local acc, frames = 0, 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		acc, frames = acc + dt, frames + 1
		if acc < 0.5 then return end
		local parts = { o.Text or (Library.Windows[1] and Library.Windows[1].Config.Name) or "Library" }
		if show.FPS then table.insert(parts, ("%d fps"):format(math.floor(frames / acc + 0.5))) end
		if show.Ping then local ms = pingMs() if ms then table.insert(parts, ms .. " ms") end end
		if show.Time then table.insert(parts, os.date("%H:%M")) end
		label.Text = table.concat(parts, "  |  ")
		holder.Size = UDim2.fromOffset(#label.Text * 6.2 + 22, 24)
		acc, frames = 0, 0
	end)
	Library._maid:Add(conn)
	local down, origin, startPos
	body.InputBegan:Connect(function(input)
		local ut = input.UserInputType
		if ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch then
			down, origin, startPos = input, input.Position, holder.Position
			input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then down = nil end end)
		end
	end)
	connect(UIS.InputChanged, function(input)
		if down and (input == down or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local d = input.Position - origin
			holder.Position = UDim2.fromOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
		end
	end)
	local obj = {}
	function obj:SetVisible(v) holder.Visible = v end
	function obj:SetText(t) o.Text = t end
	function obj:Destroy() conn:Disconnect(); holder:Destroy() end
	return obj
end

----------------------------------------------------------------------------
-- 11b. CONFIGS & SETTINGS TAB
----------------------------------------------------------------------------
local function encodeValue(v)
	if typeof(v) == "Color3" then return { __c = { v.R, v.G, v.B } } end
	return v
end
local function decodeValue(v)
	if type(v) == "table" and v.__c then return Color3.new(v.__c[1], v.__c[2], v.__c[3]) end
	return v
end
local function cleanName(n) return (tostring(n):gsub("[^%w_%-%s]", ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function cfgPath(name) return (Library.Folder or "Library") .. "/configs/" .. cleanName(name) .. ".json" end

function Library:SaveConfig(name)
	name = cleanName(name or "")
	if name == "" or not FS.canWrite then return false end
	local data = {}
	for flag, el in pairs(Library.Elements) do
		if not el.Ignore then data[flag] = encodeValue(el.Get()) end
	end
	local json = jsonEncode(data)
	return json ~= nil and FS.write(cfgPath(name), json)
end

function Library:LoadConfig(name)
	local raw = FS.read(cfgPath(name or ""))
	local data = raw and jsonDecode(raw)
	if type(data) ~= "table" then return false end
	for flag, val in pairs(data) do
		local el = Library.Elements[flag]
		if el and not el.Ignore then
			local ok, err = pcall(el.Set, decodeValue(val))
			if not ok then warn("[Library] config '" .. flag .. "': " .. tostring(err)) end
		end
	end
	return true
end

function Library:ListConfigs()
	local out = {}
	for _, path in ipairs(FS.list((Library.Folder or "Library") .. "/configs")) do
		local n = tostring(path):gsub("\\", "/"):match("([^/]+)%.json$")
		if n then table.insert(out, n) end
	end
	table.sort(out)
	return out
end
function Library:DeleteConfig(name) FS.delete(cfgPath(name)) end
function Library:SetAutoload(name)
	if not Library.Folder then return end
	if name and name ~= "" then FS.write(Library.Folder .. "/autoload.txt", cleanName(name)) else FS.delete(Library.Folder .. "/autoload.txt") end
end
function Library:GetAutoload()
	local n = Library.Folder and FS.read(Library.Folder .. "/autoload.txt")
	return n and trim(n) ~= "" and trim(n) or nil
end
function Library:LoadAutoload()
	local n = Library:GetAutoload()
	if n and Library:LoadConfig(n) then
		Library:Notify({ Title = "Config loaded", Content = "Auto-loaded “" .. n .. "”.", Type = "Success", Duration = 3 })
		return true
	end
	return false
end

-- Settings tab: themes, accent, background, transparency, scale, menu key, interface, configs, about
function Window:CreateSettingsTab(o)
	o = o or {}
	local win = self
	local cfg = self.Config
	local tab = self:CreateTab({ Name = o.Name or "Settings", Icon = o.Icon or "settings", Description = "Appearance, interface and configs" })

	local ap = tab:CreateSection({ Title = "Appearance", Subtitle = (#Library.ThemeOrder) .. " themes · background · transparency" })
	ap:AddCard({ Wide = true, Title = "Theme" }):AddThemeGrid({})
	local c1 = ap:AddCard({ Title = "Colour" })
	c1:AddColorPicker({ Name = "Custom accent", Default = Theme.Current.Accent, Callback = function(c) win:SetAccent(c) end })
	c1:AddDropdown({ Name = "Background", Options = { "Dots", "Grid", "None" }, Default = cfg.Background or "Dots", Callback = function(v) win:SetBackground(v) end })
	local c2 = ap:AddCard({ Title = "Window" })
	c2:AddSlider({ Name = "Transparency", Min = 0, Max = 60, Default = 0, Suffix = "%", Callback = function(v) win:SetTransparency(v / 100) end })
	c2:AddSlider({ Name = "UI scale", Min = 60, Max = 150, Default = 100, Suffix = "%", Callback = function(v) win:SetScale(v / 100) end })
	c2:AddKeybind({
		Name = "Menu key", Default = self.ToggleKey,
		ChangedCallback = function(k)
			local ok, kc = pcall(function() return Enum.KeyCode[k] end)
			if ok and kc then win:SetToggleKey(kc) end
		end,
	})

	local ix = tab:CreateSection({ Title = "Interface" })
	local c3 = ix:AddCard()
	c3:AddToggle({ Name = "Animations", Default = Library.Config.Animations ~= false, Callback = function(v) Library.Config.Animations = v end })
	c3:AddSlider({ Name = "Animation speed", Min = 50, Max = 200, Default = Library.Config.AnimSpeed * 100, Suffix = "%", Callback = function(v) Library.Config.AnimSpeed = v / 100 end })
	local c4 = ix:AddCard()
	c4:AddToggle({ Name = "Confirm before closing", Default = cfg.ConfirmClose ~= false, Callback = function(v) cfg.ConfirmClose = v end })
	c4:AddButton({ Name = "Toggle fullscreen", Icon = "scan", Callback = function() win:ToggleFullscreen() end })
	if next(Library.Config.Sounds) then
		c4:AddToggle({ Name = "UI sounds", Default = Library.Config.SoundsEnabled, Callback = function(v) Library.Config.SoundsEnabled = v end })
	end

	local cs = tab:CreateSection({ Title = "Configuration", Subtitle = "Save and restore every setting" })
	local cc = cs:AddCard({ Wide = true })
	local selected
	local nameBox = cc:AddInput({ Name = "Config name", Placeholder = "my-config" })
	local dd
	local function needFS()
		if FS.canWrite then return false end
		Library:Notify({ Title = "Not supported", Content = "Your executor has no file access, so configs can't be saved.", Type = "Warning" })
		return true
	end
	local function reload() if dd then dd:Refresh(Library:ListConfigs()) end end
	cc:AddButton({
		Name = "Save config", Icon = "save", Style = "Primary",
		Callback = function()
			if needFS() then return end
			local n = cleanName(nameBox:Get())
			if n == "" then Library:Notify({ Title = "Name needed", Content = "Type a config name first.", Type = "Warning" }) return end
			if Library:SaveConfig(n) then Library:Notify({ Title = "Saved", Content = "“" .. n .. "” written to disk.", Type = "Success" }); reload()
			else Library:Notify({ Title = "Failed", Content = "Could not write the config.", Type = "Error" }) end
		end,
	})
	dd = cc:AddDropdown({ Name = "Saved configs", Options = Library:ListConfigs(), Callback = function(v) selected = v end })
	cc:AddButton({
		Buttons = {
			{ Name = "Load", Icon = "folder-open", Callback = function()
				if needFS() or not selected then return end
				if Library:LoadConfig(selected) then Library:Notify({ Title = "Loaded", Content = "“" .. selected .. "” applied.", Type = "Success" })
				else Library:Notify({ Title = "Failed", Content = "Config could not be read.", Type = "Error" }) end
			end },
			{ Name = "Delete", Icon = "trash-2", Style = "Danger", Callback = function()
				if needFS() or not selected then return end
				local name = selected
				win:Confirm({ Title = "Delete config?", Content = "“" .. name .. "” will be removed from disk.", Confirm = "Delete", Danger = true }, function()
					Library:DeleteConfig(name); selected = nil; reload()
					Library:Notify({ Title = "Deleted", Content = "Config removed.", Type = "Info" })
				end)
			end },
		},
	})
	cc:AddToggle({
		Name = "Auto-load selected", Description = "Applies it every time the script starts.",
		Callback = function(v) if selected then Library:SetAutoload(v and selected or nil) end end,
	})

	local ab = tab:CreateSection({ Title = "About" })
	local ac = ab:AddCard({ Wide = true })
	ac:AddStat({ Name = "Library", Value = "v" .. Library.Version })
	ac:AddStat({ Name = "Executor", Value = executorName(), Color = "SubText" })
	ac:AddButton({
		Buttons = {
			{ Name = "Copy HWID", Icon = "copy", Callback = function()
				if setclipboard then pcall(setclipboard, getHwid()) end
				Library:Notify({ Title = "Copied", Content = "Hardware id copied.", Type = "Success", Duration = 2 })
			end },
			{ Name = "Unload UI", Icon = "x", Style = "Danger", Callback = function() win:Close() end },
		},
	})
	return tab
end

----------------------------------------------------------------------------
-- 12. PUBLIC API
----------------------------------------------------------------------------
local function createGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = HttpService:GenerateGUID(false):sub(1, 14)
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000
	pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
	local parent
	pcall(function() if gethui then parent = gethui() end end)
	if parent then gui.Parent = parent
	else
		local ok = pcall(function() gui.Parent = CoreGui end)
		if not ok or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
	end
	return gui
end

local function deepMerge(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then deepMerge(dst[k], v) else dst[k] = v end
	end
end

-- Loader stages: exactly the icons the UI uses (+ cfg.Icons) → optional access lists → your own tasks
local function loaderStages(cfg)
	local stage1 = {
		{ Name = "Loading icons", Weight = 4, Run = function(report) Icons.Prepare(report, cfg.Icons) end },
	}
	local ks = cfg.KeySystem
	if ks and ks.Enabled ~= false and (ks.KeyUrl or ks.WhitelistUrl or ks.BlacklistUrl) then
		table.insert(stage1, { Name = "Checking access lists", Weight = 1, Run = function(report)
			report(0.1, "Checking access lists", "")
			KeySystem.Prefetch(ks)
			report(1, "Checking access lists", "")
		end })
	end
	if next(Library.Config.Sounds) and ContentProvider then
		table.insert(stage1, { Name = "Loading audio", Weight = 1, Run = function(report)
			local items = {}
			for _, def in pairs(Library.Config.Sounds) do
				local snd = Instance.new("Sound")
				local id = type(def) == "table" and def.Id or def
				snd.SoundId = type(id) == "number" and ("rbxassetid://" .. id) or tostring(id)
				table.insert(items, snd)
			end
			report(0.3, "Loading audio", "")
			Util.Await(function() ContentProvider:PreloadAsync(items) end, Library.Config.PreloadTimeout)
			for _, it in ipairs(items) do it:Destroy() end
			report(1, "Loading audio", "")
		end })
	end
	local stages = { stage1 }
	if type(cfg.Loader) == "table" and cfg.Loader.Tasks then
		for _, t in ipairs(cfg.Loader.Tasks) do table.insert(stages, { t }) end
	end
	return stages
end

-- Window:Launch() runs: loader → key system → show window. Called automatically after your script builds the UI.
function Window:Launch()
	if self._launched then return self:WaitReady() end
	self._launched = true
	local cfg = self.Config
	if cfg.LoaderTheme and Library.Themes[cfg.LoaderTheme] then Theme.Set(cfg.LoaderTheme, true) end
	for _, f in ipairs(self._prelaunch) do safe(f) end
	Library._RunLoader(cfg, loaderStages(cfg), cfg.Loader == false)
	if cfg.LoaderTheme then Theme.Set(cfg.Theme, true) end
	if not Library._RunKeySystem(cfg) then
		self._denied = true
		Library:Unload()
		return false
	end
	self.Ready = true
	self:SetState("Open")
	for _, cb in ipairs(self._readyCbs) do safe(cb) end
	if cfg.AutoLoadConfig ~= false then Library:LoadAutoload() end
	return true
end

--[[ CreateWindow(config) returns the Window immediately. Build your tabs, then the loader and key system run
   automatically (or call Window:Launch() yourself). Use Window:OnReady(fn) / Window:WaitReady() for code that
   must only run once access is granted.

   Name, Version, Subtitle, Icon | Logo, Size, Theme, LoaderTheme, Background, ToggleKey, Resizable, MinSize,
   SidebarWidth, ConfirmClose, Search, User, Dock, ConfigFolder, Icons = {...}, Sounds = {...}, Config = {...},
   Loader = false | { Tagline, DoneText, MinTime, Tasks, Custom }, KeySystem = false | { ... }
]]
function Library:CreateWindow(cfg)
	cfg = cfg or {}
	cfg.Name = cfg.Name or "Library"
	local sz = cfg.Size
	if typeof(sz) == "UDim2" then sz = Vector2.new(sz.X.Offset, sz.Y.Offset) end
	if type(sz) == "table" then sz = Vector2.new(sz[1], sz[2]) end
	cfg.Size = sz or Vector2.new(605, 420)
	cfg.Theme = Library.Themes[cfg.Theme or ""] and cfg.Theme or "Graphite"
	if cfg.Config then deepMerge(Library.Config, cfg.Config) end
	if cfg.Sounds then
		for k, v in pairs(cfg.Sounds) do Library.Config.Sounds[k] = v end
	end
	if cfg.IconSources then Library.Config.IconSources = cfg.IconSources end

	Library.Folder = tostring(cfg.ConfigFolder or cfg.Name):gsub("[^%w_%-]", "_")
	FS.folder(Library.Folder)
	FS.folder(Library.Folder .. "/configs")
	Icons.LoadCache(Library.Folder .. "/icons.json")

	if not Library.Gui then
		Library.Gui = createGui()
		Notify.Init(Library.Gui)
	end
	Theme.Set(cfg.Theme, true)

	local win = Window.new(cfg)
	win.ConfigManager = {
		Save = function(_, n) return Library:SaveConfig(n) end, Load = function(_, n) return Library:LoadConfig(n) end,
		Delete = function(_, n) return Library:DeleteConfig(n) end, List = function() return Library:ListConfigs() end,
		SetAutoload = function(_, n) return Library:SetAutoload(n) end,
	}
	table.insert(Library.Windows, win)
	if cfg.AutoLaunch ~= false then
		task.defer(function()
			if not win._launched and not win._dead then win:Launch() end
		end)
	end
	return win
end

function Library:Notify(o) return Notify.Push(o) end
function Library:SetTheme(name) return Theme.Set(name) end

-- Standalone popup (not tied to a window): same options as Window:Dialog
function Library:Popup(o)
	if not Library.Gui then
		Library.Gui = createGui()
		Notify.Init(Library.Gui)
	end
	return Dialogs.Open(Library.Gui, o)
end

-- RegisterTheme("Sunset2", Color3.fromRGB(255,120,60))  or  RegisterTheme("X", { Accent = ..., Base = 0.06, NeutralSaturation = 0.3, Light = false, Card = Color3... })
function Library:RegisterTheme(name, spec) Theme.Register(name, spec) end

-- RegisterElement("Name", function(card, opts, Library) ... end) -> card:AddName{...}
function Library:RegisterElement(name, builder)
	Card["Add" .. name] = function(card, o) return builder(card, o or {}, Library) end
end

-- RegisterKeyService("myservice", { Validate = function(ks, key) return ok, message end, GetLink = function(ks) return url end })
function Library:RegisterKeyService(name, impl) KeySystem.Services[tostring(name):lower()] = impl end

function Library:PreloadIcons(list) Icons.Prepare(function() end, list) end

function Library:Unload()
	for _, w in ipairs({ table.unpack(Library.Windows) }) do pcall(function() w.Mover:Destroy() end) end
	Library.Windows = {}
	Library._maid:Clean()
	if Library.Gui then Library.Gui:Destroy() Library.Gui = nil end
	Notify.Holder, Notify.Items = nil, {}
	Tooltip.Frame = nil
	Sound.Cache = {}
	Library._ResetBackdrop()
	Theme.Listeners = {}
	Library.Flags, Library.Elements = {}, {}
	if genv.__UILibraryInstance == Library then genv.__UILibraryInstance = nil end
end

Library.New, Library.Tween, Library.Ease = New, tween, Ease
Library.Corner, Library.Padding, Library.List = Corner, Padding, List
Library.HWID, Library.Executor = getHwid, executorName

return Library
