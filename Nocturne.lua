--[[
    ╔══════════════════════════════════════════════════════════════════════╗
    ║  Library.lua  —  modular Roblox UI library (single file)            ║
    ║  Loader  →  Key system  →  Window   ·   all pieces replaceable      ║
    ║  Icons: Lucide (fetched from GitHub + cached)  ·  See README.md     ║
    ╚══════════════════════════════════════════════════════════════════════╝

    Sections in this file (search for the banner text):
      1. CORE & ENVIRONMENT      5. EFFECTS & COMPONENTS    9. WINDOW
      2. UTIL                    6. NOTIFICATIONS          10. ELEMENTS
      3. THEMES                  7. LOADER                 11. SETTINGS / CONFIG
      4. SOUND & ICONS           8. KEY SYSTEM             12. PUBLIC API
]]

----------------------------------------------------------------------------
-- 1. CORE & ENVIRONMENT
----------------------------------------------------------------------------
local Library = {
	Version = "1.0.0",
	Flags = {},          -- Library.Flags[flag] = current value
	Elements = {},       -- Library.Elements[flag] = { Get, Set, Type }
	Themes = {},         -- registered themes
	Windows = {},
	_custom = {},        -- custom elements registered through RegisterElement
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

local Players = svc("Players")
local RunService = svc("RunService")
local UIS = svc("UserInputService")
local TweenService = svc("TweenService")
local HttpService = svc("HttpService")
local SoundService = svc("SoundService")
local ContentProvider = svc("ContentProvider")
local CoreGui = svc("CoreGui")
local LocalPlayer = Players.LocalPlayer

local loadstr = loadstring or load
local wait = task and task.wait or wait
local spawn = task and task.spawn or spawn
local delay = task and task.delay or delay

-- Everything you may want to tweak lives here (or pass overrides in CreateWindow)
Library.Config = {
	Font = "rbxasset://fonts/families/GothamSSm.json",
	ShadowImage = "rbxassetid://6014261993",
	Animations = true,
	AnimSpeed = 1,                 -- 1 = normal, 2 = twice as fast
	SoundsEnabled = true,
	SoundVolume = 1,               -- master multiplier
	-- Icon providers are tried in order; each must return a table with :GetAsset(name, size)
	IconSources = {
		"https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau",
		"https://raw.githubusercontent.com/deividcomsono/lucide-roblox-direct/refs/heads/main/source.lua",
	},
	IconResolution = 256,
	-- Each slot: { Id, Volume, Speed }. Replace any Id with your own rbxassetid.
	Sounds = {
		Click   = { Id = "rbxasset://sounds/clickfast.wav",          Volume = 0.35, Speed = 1.00 },
		Hover   = { Id = "rbxasset://sounds/snap.mp3",               Volume = 0.05, Speed = 1.70 },
		Toggle  = { Id = "rbxasset://sounds/switch.mp3",             Volume = 0.30, Speed = 1.00 },
		Open    = { Id = "rbxasset://sounds/snap.mp3",               Volume = 0.25, Speed = 0.80 },
		Close   = { Id = "rbxasset://sounds/snap.mp3",               Volume = 0.25, Speed = 0.65 },
		Tick    = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.22, Speed = 1.00 },
		Success = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.40, Speed = 1.45 },
		Error   = { Id = "rbxasset://sounds/button.wav",             Volume = 0.35, Speed = 0.60 },
		Notify  = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.30, Speed = 1.00 },
		Slide   = { Id = "rbxasset://sounds/clickfast.wav",          Volume = 0.05, Speed = 1.60 },
	},
}

-- File-system / http helpers (all safe on executors without them) -----------
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

local function jsonEncode(v) local ok, r = pcall(HttpService.JSONEncode, HttpService, v) return ok and r or nil end
local function jsonDecode(s) local ok, r = pcall(HttpService.JSONDecode, HttpService, s) return ok and r or nil end

----------------------------------------------------------------------------
-- 2. UTIL
----------------------------------------------------------------------------
local Util = {}
Library.Util = Util

local Fonts = {}
local function getFont(weight)
	weight = weight or "Medium"
	if Fonts[weight] == nil then
		local ok, f = pcall(function()
			return Font.new(Library.Config.Font, Enum.FontWeight[weight], Enum.FontStyle.Normal)
		end)
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
	TextLabel = { BackgroundTransparency = 1, BorderSizePixel = 0, TextColor3 = Color3.new(1, 1, 1), TextSize = 13 },
	TextButton = { BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = "", TextSize = 13 },
	TextBox = { BackgroundTransparency = 1, BorderSizePixel = 0, ClearTextOnFocus = false, TextSize = 13, Text = "" },
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
	Smooth = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Fast   = TweenInfo.new(0.14, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
	Slow   = TweenInfo.new(0.50, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Soft   = TweenInfo.new(0.40, Enum.EasingStyle.Sine,  Enum.EasingDirection.InOut),
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

-- Simple connection / instance bag
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
	-- strip float noise
	local decimals = 0
	local s = tostring(inc)
	local dot = s:find("%.")
	if dot then decimals = #s - dot end
	local m = 10 ^ decimals
	return math.floor(r * m + 0.5) / m
end
local function lerp(a, b, t) return a + (b - a) * t end
Util.Clamp, Util.Round, Util.Lerp = clamp, round, lerp

local function isTouch() return UIS.TouchEnabled and not UIS.KeyboardEnabled end
Util.IsTouch = isTouch

local function trim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end

-- Drag helper: works for mouse and touch. onMove(position: Vector3, began: boolean)
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

local function kp(t, v) return NumberSequenceKeypoint.new(t, v) end
Util.KP = kp

----------------------------------------------------------------------------
-- 3. THEMES
----------------------------------------------------------------------------
-- Every theme is derived from one accent colour, so adding your own is a one-liner:
--   Library:RegisterTheme("Sunset", Color3.fromRGB(255, 120, 60))
local function makeTheme(accent, neutralSat)
	local h, s, v = Color3.toHSV(accent)
	neutralSat = neutralSat or 0.36
	local function tint(val, sat) return Color3.fromHSV(h, sat or neutralSat, val) end
	local lum = 0.299 * accent.R + 0.587 * accent.G + 0.114 * accent.B
	return {
		Window = tint(0.055), Header = tint(0.078), Sidebar = tint(0.066), Content = tint(0.072),
		Card = tint(0.118, neutralSat * 0.92), CardAlt = tint(0.158, neutralSat * 0.86), Hover = tint(0.205, neutralSat * 0.8),
		Text = tint(0.97, 0.05), SubText = tint(0.72, neutralSat * 0.4), Muted = tint(0.50, neutralSat * 0.5),
		Accent = accent,
		AccentSoft = Color3.fromHSV(h, math.min(1, s + 0.06), v * 0.70),
		AccentGlow = Color3.fromHSV(h, s * 0.55, math.min(1, v + 0.12)),
		OnAccent = lum > 0.62 and Color3.fromRGB(10, 12, 16) or Color3.new(1, 1, 1),
		Track = tint(0.25, neutralSat * 0.8), Knob = tint(0.96, 0.05),
		Divider = Color3.new(1, 1, 1), Grid = Color3.fromHSV(h, s * 0.55, 1),
		Danger = Color3.fromRGB(242, 82, 108), Success = Color3.fromRGB(70, 222, 148), Warning = Color3.fromRGB(250, 188, 68),
	}
end

Library.Themes.Purple  = makeTheme(Color3.fromRGB(150, 94, 255))
Library.Themes.Cyan    = makeTheme(Color3.fromRGB(34, 211, 238))
Library.Themes.Crimson = makeTheme(Color3.fromRGB(242, 72, 96))
Library.Themes.Emerald = makeTheme(Color3.fromRGB(52, 211, 153))
Library.Themes.Amber   = makeTheme(Color3.fromRGB(251, 176, 64))
Library.Themes.Ocean   = makeTheme(Color3.fromRGB(74, 138, 255))
Library.Themes.Rose    = makeTheme(Color3.fromRGB(244, 114, 182))
Library.Themes.Mono    = makeTheme(Color3.fromRGB(232, 232, 238), 0.03)

local Theme = { Current = Library.Themes.Purple, Name = "Purple", Bound = setmetatable({}, { __mode = "k" }), Listeners = {} }
Library.Theme = Theme

local function resolve(tok)
	local ty = type(tok)
	if ty == "string" then return Theme.Current[tok] or Color3.new(1, 0, 1) end
	if ty == "function" then return tok(Theme.Current) end
	return tok
end
Theme.Resolve = resolve

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
	for _, fn in ipairs(Theme.Listeners) do pcall(fn, t, name) end
	return true
end

function Theme.OnChange(fn) table.insert(Theme.Listeners, fn) end

----------------------------------------------------------------------------
-- 4. SOUND & ICONS
----------------------------------------------------------------------------
local Sound = { Cache = {} }
Library.Sound = Sound

function Sound.Play(name, speedMul, volMul)
	local cfg = Library.Config
	if not cfg.SoundsEnabled then return end
	local def = cfg.Sounds[name]
	if not def then return end
	if type(def) == "string" then def = { Id = def, Volume = 0.4, Speed = 1 } end
	local s = Sound.Cache[name]
	if not s or not s.Parent then
		s = Instance.new("Sound")
		s.Name = "UI_" .. name
		s.Parent = Library.Gui or SoundService
		Sound.Cache[name] = s
	end
	if s.SoundId ~= def.Id then s.SoundId = def.Id end
	s.Volume = (def.Volume or 0.4) * (volMul or 1) * cfg.SoundVolume
	s.PlaybackSpeed = (def.Speed or 1) * (speedMul or 1)
	s.TimePosition = 0
	s:Play()
end

local Icons = { Provider = nil, Cache = {}, Custom = {}, Urls = {} }
Library.Icons = Icons

-- Every icon the library itself uses (pre-fetched by the loader)
Icons.Needed = {
	"house", "settings", "sword", "shield", "shield-check", "eye", "eye-off", "chevron-down", "chevron-right",
	"check", "x", "minus", "plus", "lock", "key-round", "user", "users", "ban", "circle-alert", "info",
	"triangle-alert", "circle-check", "bell", "palette", "keyboard", "sliders-horizontal", "mouse-pointer-click",
	"search", "clipboard-copy", "save", "folder-open", "refresh-cw", "moon", "sun", "volume-2", "sparkles",
	"zap", "crosshair", "ghost", "log-in", "loader-circle", "external-link", "copy", "layers", "gamepad-2",
	"flame", "star", "trash-2", "monitor", "rotate-ccw", "paintbrush", "type", "hash", "download", "upload",
}

function Icons.LoadProvider(report)
	for i, url in ipairs(Library.Config.IconSources) do
		report((i - 1) / #Library.Config.IconSources, "Fetching icon pack " .. i .. "/" .. #Library.Config.IconSources)
		local src = httpGet(url)
		local fn = src and loadstr and loadstr(src)
		if fn then
			local ok, mod = pcall(fn)
			if ok and type(mod) == "table" and type(mod.GetAsset) == "function" then
				local ok2, test = pcall(mod.GetAsset, "house", Library.Config.IconResolution)
				if ok2 and type(test) == "table" and test.Url then
					Icons.Provider = mod
					report(1, "Icon pack ready")
					return true
				end
			end
		end
	end
	report(1, "Icon pack unavailable")
	return false
end

-- Accepts a lucide name ("house", "lucide-house"), an asset id, a "rbxassetid://" string or a table
function Icons.Resolve(name)
	local ty = type(name)
	if ty == "number" then return { Url = "rbxassetid://" .. name } end
	if ty == "table" then return name end
	if ty ~= "string" or name == "" then return nil end
	if name:find("://", 1, true) then return { Url = name } end
	local key = (name:gsub("^lucide[%-/:]", "")):lower()
	if Icons.Custom[key] then return Icons.Custom[key] end
	local cached = Icons.Cache[key]
	if cached ~= nil then return cached or nil end
	local data
	if Icons.Provider then
		local ok, r = pcall(Icons.Provider.GetAsset, key, Library.Config.IconResolution)
		if ok and type(r) == "table" and r.Url then
			data = { Url = r.Url, Rect = r.ImageRectSize, Offset = r.ImageRectOffset }
		end
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

-- Create a themed icon: Icons.New("house", 16, "Text", parent, { Position = ... })
function Icons.New(name, size, token, parent, props)
	props = props or {}
	props.Size = props.Size or UDim2.fromOffset(size, size)
	props.Parent = parent
	props.ScaleType = Enum.ScaleType.Fit
	local img = New("ImageLabel", props)
	Icons.Apply(img, name)
	Theme.Bind(img, { ImageColor3 = token or "Text" })
	return img
end

-- Register your own icon (any rbxassetid) so it works everywhere a name does
function Icons.Register(name, assetId, rectSize, rectOffset)
	Icons.Custom[name:lower()] = {
		Url = type(assetId) == "number" and ("rbxassetid://" .. assetId) or assetId,
		Rect = rectSize, Offset = rectOffset,
	}
end

function Icons.Preload(names, report)
	local seen, n = {}, #names
	for i, nm in ipairs(names) do
		local d = Icons.Resolve(nm)
		if d and d.Url then seen[d.Url] = true end
		if i % 6 == 0 or i == n then
			report(i / n, ("Loading icons  %d / %d"):format(i, n))
			wait()
		end
	end
	-- warm the sprite sheets so nothing pops in later
	local holders = {}
	for url in pairs(seen) do
		table.insert(holders, New("ImageLabel", { Image = url, Size = UDim2.fromOffset(1, 1), ImageTransparency = 0.99 }))
	end
	if ContentProvider and #holders > 0 then pcall(function() ContentProvider:PreloadAsync(holders) end) end
	for _, h in ipairs(holders) do h:Destroy() end
end

----------------------------------------------------------------------------
-- 5. EFFECTS & COMPONENTS
----------------------------------------------------------------------------
local function safe(fn, ...)
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[Library] callback error: " .. tostring(err)) end
end
Util.Safe = safe

local Effects = {}
Library.Effects = Effects

-- Soft 9-slice shadow. Parent it to a *holder* that also contains the element
-- (a child would be drawn on top of its parent, so shadows live next to the body).
function Effects.Shadow(parent, o)
	o = o or {}
	local spread = o.Spread or 14
	return New("ImageLabel", {
		Name = "Shadow", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, o.OffsetY or 3),
		Size = UDim2.new(1, spread * 2, 1, spread * 2),
		Image = Library.Config.ShadowImage, ImageColor3 = o.Color or Color3.new(0, 0, 0),
		ImageTransparency = o.Transparency or 0.6,
		ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450),
		SliceScale = spread / 49, ZIndex = o.ZIndex or 0, Parent = parent,
	})
end

-- Stroke that fades out along its gradient (never a hard outline)
function Effects.FadeStroke(parent, o)
	o = o or {}
	local stroke = New("UIStroke", {
		Thickness = o.Thickness or 1, Color = o.Color or Color3.new(1, 1, 1), Transparency = o.Transparency or 0.82,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
	})
	local grad = New("UIGradient", {
		Rotation = o.Rotation or 90,
		Transparency = NumberSequence.new({ kp(0, 0), kp(0.55, 0.7), kp(1, 1) }),
		Parent = stroke,
	})
	if o.Token then Theme.Bind(stroke, { Color = o.Token }) end
	return stroke, grad
end

-- Vertical sheen: gradient colours multiply the base, so the bottom darkens slightly
function Effects.Gloss(frame, strength)
	strength = strength or 0.16
	return New("UIGradient", {
		Rotation = 90, Parent = frame,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1 - strength, 1 - strength, 1 - strength)),
	})
end

-- 1px highlight on the upper edge, fading out to both sides
function Effects.TopLight(frame, transparency)
	local l = New("Frame", {
		Name = "TopLight", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = transparency or 0.82,
		Size = UDim2.new(1, -20, 0, 1), Position = UDim2.new(0, 10, 0, 1), ZIndex = 3, Parent = frame,
	})
	New("UIGradient", { Transparency = NumberSequence.new({ kp(0, 1), kp(0.5, 0), kp(1, 1) }), Parent = l })
	return l
end

-- Hover sheen sweep + press shade + colour shift. Works on any GuiObject (press needs a GuiButton).
function Effects.Interact(body, o)
	o = o or {}
	local z = o.ZIndex or 4
	local cr = body:FindFirstChildOfClass("UICorner")
	local function overlay(name, color)
		local f = New("Frame", {
			Name = name, Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = 1,
			ZIndex = z, Parent = body,
		})
		if cr then New("UICorner", { CornerRadius = cr.CornerRadius, Parent = f }) end
		return f
	end
	local sheen = overlay("Sheen", Color3.new(1, 1, 1))
	sheen.BackgroundTransparency = 0
	local sg = New("UIGradient", {
		Rotation = 18, Offset = Vector2.new(-1.2, 0), Parent = sheen,
		Transparency = NumberSequence.new({ kp(0, 1), kp(0.40, 1), kp(0.5, 0.9), kp(0.60, 1), kp(1, 1) }),
	})
	local press = overlay("Press", Color3.new(0, 0, 0))
	local sweep = TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	body.MouseEnter:Connect(function()
		Sound.Play("Hover")
		if o.Hover then tween(body, { BackgroundColor3 = resolve(o.Hover) }, Ease.Fast) end
		if o.Stroke then tween(o.Stroke, { Transparency = o.StrokeHover or 0.3 }, Ease.Smooth) end
		sg.Offset = Vector2.new(-1.2, 0)
		tween(sg, { Offset = Vector2.new(1.2, 0) }, sweep)
	end)
	body.MouseLeave:Connect(function()
		if o.Base then tween(body, { BackgroundColor3 = resolve(o.Base) }, Ease.Smooth) end
		if o.Stroke then tween(o.Stroke, { Transparency = o.StrokeBase or 0.82 }, Ease.Smooth) end
		tween(press, { BackgroundTransparency = 1 }, Ease.Fast)
	end)
	if body:IsA("GuiButton") then
		body.MouseButton1Down:Connect(function() tween(press, { BackgroundTransparency = 0.88 }, Ease.Fast) end)
		body.MouseButton1Up:Connect(function() tween(press, { BackgroundTransparency = 1 }, Ease.Smooth) end)
	end
	return { Sheen = sheen, Press = press }
end

----------------------------------------------------------------------------
-- Background: dot field / grid + a soft glow that follows the cursor
----------------------------------------------------------------------------
function Effects.Background(parent, size, style)
	local self = { Style = style or "Dots", Size = size, Dots = {}, Active = {}, Enabled = true }
	local root = New("Frame", {
		Name = "Background", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		ClipsDescendants = true, ZIndex = 0, Parent = parent,
	})
	local glow = New("ImageLabel", {
		Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(size.X * 0.75, size.Y * 0.2),
		Size = UDim2.fromOffset(300, 300), Image = Library.Config.ShadowImage, ImageTransparency = 0.91,
		ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450), SliceScale = 2.4, ZIndex = 0, Parent = root,
	})
	Theme.Bind(glow, { ImageColor3 = "Accent" })
	local layer = New("Frame", { Name = "Layer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0, Parent = root })

	function self:Build(newStyle, newSize)
		self.Style = newStyle or self.Style
		self.Size = newSize or self.Size
		layer:ClearAllChildren()
		self.Dots, self.Active = {}, {}
		glow.Visible = self.Style ~= "None"
		local W, H = self.Size.X, self.Size.Y
		local gc = resolve("Grid")
		if self.Style == "Dots" then
			local cell = 22
			local cols, rows = math.ceil(W / cell) + 1, math.ceil(H / cell) + 1
			for r = 0, rows - 1 do
				for c = 0, cols - 1 do
					local base = 0.90 + 0.085 * (r / rows) + 0.04 * math.abs(c / cols - 0.5) * 2
					local x, y = c * cell + 6, r * cell + 6
					local f = New("Frame", {
						Size = UDim2.fromOffset(2, 2), Position = UDim2.fromOffset(x, y),
						BackgroundColor3 = gc, BackgroundTransparency = base, ZIndex = 0, Parent = layer,
					})
					Corner("full", f)
					table.insert(self.Dots, { F = f, X = x + 1, Y = y + 1, Base = base, I = 0, T = 0 })
				end
			end
		elseif self.Style == "Grid" then
			local cell = 30
			for c = 0, math.ceil(W / cell) do
				local l = New("Frame", {
					Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromOffset(c * cell + 8, 0),
					BackgroundColor3 = gc, BackgroundTransparency = 0.955, ZIndex = 0, Parent = layer,
				})
				New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 0), kp(1, 1) }), Parent = l })
			end
			for r = 0, math.ceil(H / cell) do
				local l = New("Frame", {
					Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, r * cell + 8),
					BackgroundColor3 = gc, BackgroundTransparency = 0.955, ZIndex = 0, Parent = layer,
				})
				New("UIGradient", { Transparency = NumberSequence.new({ kp(0, 0.9), kp(0.5, 0), kp(1, 0.9) }), Parent = l })
			end
		end
	end

	local conn = RunService.Heartbeat:Connect(function(dt)
		if not self.Enabled or root.AbsoluteSize.X < 1 then return end
		local sc = root.AbsoluteSize.X / self.Size.X
		local m = UIS:GetMouseLocation()
		local lx, ly = (m.X - root.AbsolutePosition.X) / sc, (m.Y - root.AbsolutePosition.Y) / sc
		local inside = lx > -40 and ly > -40 and lx < self.Size.X + 40 and ly < self.Size.Y + 40
		local k = math.min(1, dt * 3.2)
		local tx = inside and lx or self.Size.X * 0.75
		local ty = inside and ly or self.Size.Y * 0.2
		glow.Position = UDim2.fromOffset(lerp(glow.Position.X.Offset, tx, k), lerp(glow.Position.Y.Offset, ty, k))
		if self.Style ~= "Dots" then return end
		local R = 100
		local gc, accent = resolve("Grid"), resolve("Accent")
		for d in pairs(self.Active) do d.T = 0 end
		if inside then
			for _, d in ipairs(self.Dots) do
				local dx, dy = d.X - lx, d.Y - ly
				local dist2 = dx * dx + dy * dy
				if dist2 < R * R then
					local t = 1 - math.sqrt(dist2) / R
					d.T = t * t * (3 - 2 * t)
					self.Active[d] = true
				end
			end
		end
		local step = math.min(1, dt * 10)
		for d in pairs(self.Active) do
			d.I = d.I + (d.T - d.I) * step
			if d.I < 0.015 and d.T == 0 then
				d.I = 0
				d.F.BackgroundTransparency, d.F.BackgroundColor3 = d.Base, gc
				self.Active[d] = nil
			else
				d.F.BackgroundTransparency = lerp(d.Base, 0.3, d.I)
				d.F.BackgroundColor3 = gc:Lerp(accent, d.I)
			end
		end
	end)
	Library._maid:Add(conn)

	Theme.OnChange(function()
		if not root.Parent then return end
		local gc = resolve("Grid")
		for _, d in ipairs(self.Dots) do if not self.Active[d] then d.F.BackgroundColor3 = gc end end
	end)

	function self:SetEnabled(b) self.Enabled = b end
	function self:Destroy() conn:Disconnect(); root:Destroy() end
	self.Root = root
	self:Build()
	return self
end

----------------------------------------------------------------------------
-- Components shared by loader, key system and elements
----------------------------------------------------------------------------
local Components = {}
Library.Components = Components

local function onAccent(t) return t.OnAccent end
local BUTTON_STYLES = {
	Primary = {
		Base = "Accent", Hover = function(t) return t.Accent:Lerp(t.AccentGlow, 0.32) end,
		Text = onAccent, Gloss = 0.2, Shadow = true, StrokeT = 0.55,
	},
	Secondary = { Base = "CardAlt", Hover = "Hover", Text = "Text", Gloss = 0.12, Shadow = true, StrokeT = 0.84 },
	Danger = {
		Base = "Danger", Hover = function(t) return t.Danger:Lerp(Color3.new(1, 1, 1), 0.18) end,
		Text = Color3.new(1, 1, 1), Gloss = 0.2, Shadow = true, StrokeT = 0.55,
	},
	Ghost = { Base = "Card", Hover = "CardAlt", Text = "SubText", StrokeT = 0.9 },
}

function Components.Button(parent, o)
	o = o or {}
	local st = BUTTON_STYLES[o.Style or "Secondary"] or BUTTON_STYLES.Secondary
	local holder = New("Frame", {
		Name = o.Name or "Button", BackgroundTransparency = 1, Size = o.Size or UDim2.new(1, 0, 0, 34),
		Position = o.Position, AnchorPoint = o.AnchorPoint, LayoutOrder = o.LayoutOrder or 0, Parent = parent,
	})
	if st.Shadow then Effects.Shadow(holder, { Spread = 10, OffsetY = 3, Transparency = 0.5 }) end
	local body = New("TextButton", { Name = "Body", Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = holder })
	Corner(8, body)
	Theme.Bind(body, { BackgroundColor3 = st.Base })
	if st.Gloss then Effects.Gloss(body, st.Gloss) end
	local stroke = Effects.FadeStroke(body, { Transparency = st.StrokeT })
	if st.Gloss then Effects.TopLight(body, 0.8) end

	local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = body })
	List(row, {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6),
	})
	local icon
	if o.Icon then icon = Icons.New(o.Icon, o.IconSize or 15, st.Text, row, { ZIndex = 3, LayoutOrder = 1 }) end
	local label = New("TextLabel", {
		Text = o.Text or "Button", TextSize = o.TextSize or 13, Weight = "SemiBold", AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 16), ZIndex = 3, LayoutOrder = 2, Parent = row,
	})
	Theme.Bind(label, { TextColor3 = st.Text })
	if o.Text == "" then label.Visible = false end
	Effects.Interact(body, { Base = st.Base, Hover = st.Hover, Stroke = stroke, StrokeBase = st.StrokeT, StrokeHover = 0.25 })

	local obj = { Holder = holder, Body = body, Label = label, Icon = icon, Enabled = true, Callback = o.Callback }
	body.MouseButton1Click:Connect(function()
		if not obj.Enabled then return end
		Sound.Play("Click")
		safe(obj.Callback)
	end)
	function obj:SetText(t) label.Text = t end
	function obj:SetCallback(fn) obj.Callback = fn end
	function obj:SetIcon(n) if icon then Icons.Apply(icon, n) end end
	function obj:SetEnabled(b)
		obj.Enabled = b
		tween(label, { TextTransparency = b and 0 or 0.55 }, Ease.Fast)
		if icon then tween(icon, { ImageTransparency = b and 0 or 0.55 }, Ease.Fast) end
	end
	function obj:Destroy() holder:Destroy() end
	return obj
end

-- Text field with focus glow; used for key entry, Input and Number elements
function Components.Field(parent, o)
	o = o or {}
	local holder = New("Frame", {
		Name = "Field", Size = o.Size or UDim2.new(1, 0, 0, 34), Position = o.Position,
		AnchorPoint = o.AnchorPoint, LayoutOrder = o.LayoutOrder or 0, Parent = parent,
	})
	Corner(8, holder)
	Theme.Bind(holder, { BackgroundColor3 = o.Token or "CardAlt" })
	local stroke = Effects.FadeStroke(holder, { Transparency = 0.86 })
	local left = 10
	local icon
	if o.Icon then
		icon = Icons.New(o.Icon, 15, "Muted", holder, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0) })
		left = 32
	end
	local box = New("TextBox", {
		Size = UDim2.new(1, -(left + 10), 1, 0), Position = UDim2.fromOffset(left, 0),
		PlaceholderText = o.Placeholder or "", Text = o.Text or "", TextSize = o.TextSize or 13,
		TextXAlignment = o.Align or Enum.TextXAlignment.Left, Parent = holder,
	})
	Theme.Bind(box, { TextColor3 = "Text", PlaceholderColor3 = "Muted" })

	local obj = { Frame = holder, Box = box, Stroke = stroke }
	box.Focused:Connect(function()
		stroke.Color = resolve("Accent")
		tween(stroke, { Transparency = 0.1 }, Ease.Fast)
		if icon then tween(icon, { ImageColor3 = resolve("Accent") }, Ease.Fast) end
	end)
	box.FocusLost:Connect(function(enter)
		tween(stroke, { Transparency = 0.86 }, Ease.Smooth)
		stroke.Color = Color3.new(1, 1, 1)
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
	function obj.Flash(tok)
		stroke.Color = resolve(tok)
		stroke.Transparency = 0.05
		tween(stroke, { Transparency = 0.86 }, Ease.Slow)
		delay(0.5, function() if stroke.Parent then stroke.Color = Color3.new(1, 1, 1) end end)
	end
	return obj
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
		Name = "Notifications", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -18),
		Size = UDim2.fromOffset(290, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 50, Parent = gui,
	})
	List(holder, { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right })
	Notify.Scale = New("UIScale", { Parent = holder })
	Notify.Holder = holder
end

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
	local shadow = Effects.Shadow(wrap, { Spread = 16, OffsetY = 4, Transparency = 1 })
	local card = New("CanvasGroup", {
		Name = "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(46, 0), GroupTransparency = 1, Parent = wrap,
	})
	Corner(10, card)
	Theme.Bind(card, { BackgroundColor3 = "Card" })

	local content = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
	Padding(12, 14, 15, 16, content)
	Icons.New(o.Icon or N_ICON[typ], 18, tok, content, { Position = UDim2.fromOffset(0, 0) })
	local texts = New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -28, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, Parent = content,
	})
	List(texts, { Padding = UDim.new(0, 2) })
	local title = New("TextLabel", {
		Text = o.Title or typ, TextSize = 13.5, Weight = "SemiBold", TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = texts,
	})
	Theme.Bind(title, { TextColor3 = "Text" })
	if o.Content and o.Content ~= "" then
		local body = New("TextLabel", {
			Text = o.Content, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2, Parent = texts,
		})
		Theme.Bind(body, { TextColor3 = "SubText" })
	end

	local bar = New("Frame", { Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, Parent = card })
	Theme.Bind(bar, { BackgroundColor3 = tok })
	New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 0), kp(1, 0.85) }), Parent = bar })
	local prog = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 0.35, Parent = card })
	Theme.Bind(prog, { BackgroundColor3 = tok })
	local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = card })

	local entry = { Wrap = wrap }
	local dead = false
	function entry.Dismiss()
		if dead then return end
		dead = true
		for i, v in ipairs(Notify.Items) do if v == entry then table.remove(Notify.Items, i) break end end
		tween(card, { GroupTransparency = 1, Position = UDim2.fromOffset(46, 0) }, Ease.Smooth)
		tween(shadow, { ImageTransparency = 1 }, Ease.Smooth)
		delay(0.24, function()
			if not wrap.Parent then return end
			local h = wrap.AbsoluteSize.Y / math.max(Notify.Scale.Scale, 0.01)
			wrap.AutomaticSize = Enum.AutomaticSize.None
			wrap.Size = UDim2.new(1, 0, 0, h)
			tween(wrap, { Size = UDim2.new(1, 0, 0, 0) }, Ease.Smooth)
			delay(0.3, function() wrap:Destroy() end)
		end)
	end
	hit.MouseButton1Click:Connect(entry.Dismiss)

	table.insert(Notify.Items, entry)
	if #Notify.Items > 5 then Notify.Items[1].Dismiss() end

	tween(card, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Ease.Smooth)
	tween(shadow, { ImageTransparency = 0.55 }, Ease.Smooth)
	local dur = o.Duration or 4.5
	tween(prog, { Size = UDim2.new(0, 0, 0, 2) }, TweenInfo.new(dur, Enum.EasingStyle.Linear))
	delay(dur, entry.Dismiss)
	Sound.Play("Notify", typ == "Error" and 0.7 or (typ == "Success" and 1.3 or 1))
	return entry
end

----------------------------------------------------------------------------
-- 7. LOADER  (rings + sounds, driven by real loading work)
----------------------------------------------------------------------------
-- A centered card used by the loader, the key system and the "blocked" screen.
local function makePanel(gui, w, h, z)
	local backdrop = New("Frame", {
		Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1, ZIndex = z, Parent = gui,
	})
	local holder = New("Frame", {
		Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 14),
		Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, ZIndex = z + 1, Parent = backdrop,
	})
	local scale = New("UIScale", { Parent = holder })
	local shadow = Effects.Shadow(holder, { Spread = 30, OffsetY = 10, Transparency = 1 })
	local card = New("CanvasGroup", { Name = "Card", Size = UDim2.fromScale(1, 1), GroupTransparency = 1, ZIndex = 1, Parent = holder })
	Corner(16, card)
	Theme.Bind(card, { BackgroundColor3 = "Window" })
	local bg = Effects.Background(card, Vector2.new(w, h), "Dots")
	local content = New("Frame", { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = card })

	local function fit()
		local vp = gui.AbsoluteSize
		scale.Scale = math.min(1, (vp.X - 24) / w, (vp.Y - 24) / h)
	end
	fit()
	local fitConn = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	local panel = { Backdrop = backdrop, Holder = holder, Card = card, Content = content, Background = bg }
	function panel.Show()
		tween(backdrop, { BackgroundTransparency = 0.42 }, Ease.Slow)
		tween(card, { GroupTransparency = 0 }, Ease.Slow)
		tween(shadow, { ImageTransparency = 0.35 }, Ease.Slow)
		tween(holder, { Position = UDim2.new(0.5, 0, 0.5, 0) }, Ease.Slow)
	end
	function panel.Hide()
		tween(backdrop, { BackgroundTransparency = 1 }, Ease.Smooth)
		tween(card, { GroupTransparency = 1 }, Ease.Smooth)
		tween(shadow, { ImageTransparency = 1 }, Ease.Smooth)
		tween(holder, { Position = UDim2.new(0.5, 0, 0.5, -12) }, Ease.Smooth)
	end
	function panel.Destroy()
		fitConn:Disconnect()
		bg:Destroy()
		backdrop:Destroy()
	end
	return panel
end

local function brandChip(parent, cfg, pos)
	local chip = New("Frame", { Size = UDim2.fromOffset(26, 26), Position = pos, Parent = parent })
	Corner(8, chip)
	Theme.Bind(chip, { BackgroundColor3 = "Accent" })
	Effects.Gloss(chip, 0.3)
	Effects.FadeStroke(chip, { Transparency = 0.55 })
	Icons.New(cfg.Icon or "ghost", 15, "OnAccent", chip, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	return chip
end

local LoaderUI = {}
function LoaderUI.new(gui, cfg)
	local lc = type(cfg.Loader) == "table" and cfg.Loader or {}
	local panel = makePanel(gui, 340, 292, 10)
	local c = panel.Content

	brandChip(c, cfg, UDim2.fromOffset(18, 16))
	local name = New("TextLabel", {
		Text = tostring(cfg.Name or "Loading"):upper(), TextSize = 13, Weight = "Bold", TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(52, 17), Size = UDim2.new(1, -140, 0, 24), Parent = c,
	})
	Theme.Bind(name, { TextColor3 = "Text" })
	local ver = New("TextLabel", {
		Text = "v" .. tostring(cfg.Version or Library.Version), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -86, 0, 17), Size = UDim2.fromOffset(68, 24), Parent = c,
	})
	Theme.Bind(ver, { TextColor3 = "Muted" })

	-- ring stage
	local stage = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(124, 124),
		BackgroundTransparency = 1, Parent = c,
	})
	local stageScale = New("UIScale", { Parent = stage })
	local blob = New("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(150, 150),
		Image = Library.Config.ShadowImage, ImageTransparency = 0.8, ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450), SliceScale = 1.4, Parent = stage,
	})
	Theme.Bind(blob, { ImageColor3 = "Accent" })

	local rings = {}
	local function addRing(diam, thick, speed, band, tok, trackAlpha)
		local function circle()
			local f = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(diam, diam), BackgroundTransparency = 1, Parent = stage,
			})
			Corner("full", f)
			return f
		end
		local trackStroke = New("UIStroke", { Thickness = thick, Transparency = trackAlpha, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = circle() })
		Theme.Bind(trackStroke, { Color = tok })
		local arcStroke = New("UIStroke", { Thickness = thick, Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = circle() })
		Theme.Bind(arcStroke, { Color = tok })
		local g = New("UIGradient", {
			Transparency = NumberSequence.new({ kp(0, 1), kp(0.5 - band, 1), kp(0.5, 0), kp(0.5 + band, 1), kp(1, 1) }),
			Parent = arcStroke,
		})
		table.insert(rings, { G = g, S = arcStroke, T = trackStroke, Speed = speed })
	end
	addRing(124, 2, 70, 0.30, "AccentSoft", 0.9)
	addRing(96, 3, -140, 0.22, "Accent", 0.88)
	addRing(68, 2, 210, 0.34, "AccentGlow", 0.9)

	local pct = New("TextLabel", {
		Text = "0%", TextSize = 20, Weight = "Bold", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(70, 28), Parent = stage,
	})
	Theme.Bind(pct, { TextColor3 = "Text" })
	local check = Icons.New("check", 34, "Accent", stage, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ImageTransparency = 1,
	})

	local status = New("TextLabel", {
		Text = lc.Tagline or "Preparing", TextSize = 12.5, Position = UDim2.fromOffset(18, 200), Size = UDim2.new(1, -36, 0, 18), Parent = c,
	})
	Theme.Bind(status, { TextColor3 = "SubText" })

	local track = New("Frame", { Position = UDim2.fromOffset(28, 236), Size = UDim2.new(1, -56, 0, 4), Parent = c })
	Corner("full", track)
	Theme.Bind(track, { BackgroundColor3 = "CardAlt" })
	local fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), Parent = track })
	Corner("full", fill)
	Theme.Bind(fill, { BackgroundColor3 = "Accent" })
	New("UIGradient", { Transparency = NumberSequence.new({ kp(0, 0.65), kp(1, 0) }), Parent = fill })
	local tip = New("TextLabel", {
		Text = lc.Footer or "Fetching everything up front so the UI never waits on assets later",
		TextSize = 10.5, TextWrapped = true, Position = UDim2.fromOffset(28, 250), Size = UDim2.new(1, -56, 0, 28), Parent = c,
	})
	Theme.Bind(tip, { TextColor3 = "Muted" })

	local self = { target = 0, shown = 0, lastTick = 0 }
	local t0 = os.clock()
	local conn = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock() - t0
		for _, r in ipairs(rings) do r.G.Rotation = (t * r.Speed) % 360 end
		blob.ImageTransparency = 0.78 + 0.07 * math.sin(t * 2)
		local d = self.target - self.shown
		if d > 0 then self.shown = math.min(self.target, self.shown + math.max(d * math.min(1, dt * 4), dt * 0.05)) end
		fill.Size = UDim2.new(self.shown, 0, 1, 0)
		pct.Text = math.floor(self.shown * 100 + 0.5) .. "%"
		local step = math.floor(self.shown * 25)
		if step > self.lastTick then
			self.lastTick = step
			Sound.Play("Tick", 0.75 + self.shown * 0.9)
		end
	end)

	panel.Show()
	Sound.Play("Open")

	function self:SetProgress(p) self.target = math.max(self.target, clamp(p, 0, 1)) end
	function self:SetStatus(s)
		status.Text = tostring(s)
		status.TextTransparency = 0.65
		tween(status, { TextTransparency = 0 }, Ease.Fast)
	end
	function self:Finish()
		self.target = 1
		local minTime = lc.MinTime or 2.2
		while self.shown < 0.999 or (os.clock() - t0) < minTime do wait() end
		pct.Text = "100%"
		status.Text = lc.DoneText or "Ready"
		Sound.Play("Success")
		for _, r in ipairs(rings) do
			tween(r.S, { Transparency = 1 }, Ease.Slow)
			tween(r.T, { Transparency = 1 }, Ease.Slow)
		end
		tween(stageScale, { Scale = 1.18 }, Ease.Slow)
		tween(pct, { TextTransparency = 1 }, Ease.Smooth)
		tween(check, { ImageTransparency = 0 }, Ease.Slow)
		wait(0.65)
		panel.Hide()
		wait(0.45)
		conn:Disconnect()
		panel.Destroy()
	end
	function self:Destroy() conn:Disconnect(); panel.Destroy() end
	return self
end

-- Runs a list of { Name, Weight, Run = function(report) } through the loader UI
function Library._RunLoader(cfg, tasks, silent)
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
	for _, t in ipairs(tasks) do total = total + (t.Weight or 1) end
	local done = 0
	for _, t in ipairs(tasks) do
		local w = t.Weight or 1
		ui:SetStatus(t.Name)
		local ok, err = pcall(t.Run, function(frac, status)
			ui:SetProgress((done + w * clamp(frac or 0, 0, 1)) / total)
			if status then ui:SetStatus(status) end
		end)
		if not ok then warn("[Library] loader task '" .. tostring(t.Name) .. "' failed: " .. tostring(err)) end
		done = done + w
		ui:SetProgress(done / total)
	end
	ui:Finish()
end

----------------------------------------------------------------------------
-- 8. KEY SYSTEM  (keys · whitelist · blacklist · custom validators)
----------------------------------------------------------------------------
local KeySystem = { Cache = {} }
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
	add(LocalPlayer.UserId); add(LocalPlayer.Name); add(LocalPlayer.DisplayName)
	pcall(function() if gethwid then add(gethwid()) end end)
	pcall(function() add(svc("RbxAnalyticsService"):GetClientId()) end)
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
		local hasKeys = (ks.Keys and #ks.Keys > 0) or ks.KeyUrl or ks.Validate
		if ks.WhitelistOnly or not hasKeys then return "blocked", "You are not on the whitelist." end
	end
	return "needkey"
end

function KeySystem.Validate(ks, key)
	key = trim(key or "")
	if key == "" then return false, "Enter your key first." end
	if type(ks.Validate) == "function" then
		local ok, a, b = pcall(ks.Validate, key)
		if not ok then return false, "Validation error." end
		if a then return true, b or "Key accepted." end
		return false, b or "That key isn't valid."
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

local function smallIconButton(parent, iconName, pos, onClick)
	local b = New("TextButton", { Size = UDim2.fromOffset(26, 26), Position = pos, Parent = parent })
	Corner(8, b)
	Theme.Bind(b, { BackgroundColor3 = "CardAlt" })
	b.BackgroundTransparency = 1
	local ic = Icons.New(iconName, 14, "SubText", b, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0 }, Ease.Fast); tween(ic, { ImageColor3 = resolve("Text") }, Ease.Fast) end)
	b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 1 }, Ease.Smooth); tween(ic, { ImageColor3 = resolve("SubText") }, Ease.Smooth) end)
	b.MouseButton1Click:Connect(function() Sound.Play("Click"); safe(onClick) end)
	return b
end

local KeyUI = {}

function KeyUI.Show(ks, cfg)
	local panel = makePanel(Library.Gui, 360, 340, 12)
	local c = panel.Content
	local result, reason, finished = false, nil, false

	brandChip(c, cfg, UDim2.fromOffset(20, 18))
	local nm = New("TextLabel", {
		Text = tostring(cfg.Name or "Access"):upper(), TextSize = 12.5, Weight = "Bold", TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(54, 18), Size = UDim2.new(1, -110, 0, 26), Parent = c,
	})
	Theme.Bind(nm, { TextColor3 = "Text" })
	smallIconButton(c, "x", UDim2.new(1, -46, 0, 18), function() reason, finished = "closed", true end)

	local title = New("TextLabel", {
		Text = ks.Title or "Verify access", TextSize = 20, Weight = "Bold", TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(22, 64), Size = UDim2.new(1, -44, 0, 26), Parent = c,
	})
	Theme.Bind(title, { TextColor3 = "Text" })
	local sub = New("TextLabel", {
		Text = ks.Subtitle or "Paste your key below to unlock the interface.", TextSize = 12.5, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(22, 92), Size = UDim2.new(1, -44, 0, 34), Parent = c,
	})
	Theme.Bind(sub, { TextColor3 = "SubText" })

	local field = Components.Field(c, {
		Icon = "key-round", Placeholder = ks.Placeholder or "Enter your key…", Position = UDim2.fromOffset(22, 134),
		Size = UDim2.new(1, -44, 0, 40), Callback = function(_, enter) if enter then KeyUI._attempt() end end,
	})

	local statusIcon = Icons.New("info", 14, "Muted", c, { Position = UDim2.fromOffset(24, 186) })
	local statusLabel = New("TextLabel", {
		Text = "Waiting for key", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(46, 184), Size = UDim2.new(1, -70, 0, 18), Parent = c,
	})
	Theme.Bind(statusLabel, { TextColor3 = "Muted" })
	local function setStatus(text, tok, iconName)
		statusLabel.Text = text
		Theme.Bind(statusLabel, { TextColor3 = tok })
		Theme.Bind(statusIcon, { ImageColor3 = tok })
		Icons.Apply(statusIcon, iconName)
		statusLabel.TextTransparency = 0.6
		tween(statusLabel, { TextTransparency = 0 }, Ease.Fast)
	end

	local verify = Components.Button(c, {
		Text = ks.VerifyText or "Verify key", Icon = "shield-check", Style = "Primary",
		Position = UDim2.fromOffset(22, 214), Size = UDim2.new(1, -44, 0, 40),
	})

	-- link buttons (Get key / Discord / ...)
	local links = ks.Links or {}
	if #links == 0 then
		if ks.GetKeyLink then table.insert(links, { Name = "Get key", Url = ks.GetKeyLink, Icon = "key-round" }) end
		if ks.DiscordLink then table.insert(links, { Name = "Discord", Url = ks.DiscordLink, Icon = "external-link" }) end
	end
	if #links > 0 then
		local row = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 266), Size = UDim2.new(1, -44, 0, 34), Parent = c })
		List(row, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) })
		for i, l in ipairs(links) do
			Components.Button(row, {
				Text = l.Name or "Link", Icon = l.Icon or "external-link", Style = "Secondary", LayoutOrder = i,
				Size = UDim2.new(1 / #links, -(8 * (#links - 1)) / #links, 1, 0),
				Callback = function()
					if setclipboard and l.Url then pcall(setclipboard, l.Url) end
					Library:Notify({ Title = l.Name or "Link", Content = "Link copied to your clipboard.", Type = "Success", Duration = 3 })
				end,
			})
		end
	end

	local foot = New("TextLabel", {
		Text = "Signed in as @" .. LocalPlayer.Name, TextSize = 10.5, Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 16), Parent = c,
	})
	Theme.Bind(foot, { TextColor3 = "Muted" })

	-- spinner for the "checking" state
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
			wait(0.8)
			result, finished = true, true
		else
			attempts = attempts + 1
			Sound.Play("Error")
			field.Flash("Danger")
			local left = maxAttempts - attempts
			setStatus(msg .. (left > 0 and ("  ·  " .. left .. " left") or ""), "Danger", "circle-alert")
			if left <= 0 then
				wait(0.7)
				reason, finished = "Too many failed attempts.", true
			end
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
	wait(0.45)
	panel.Destroy()
	return result, reason
end

function KeyUI.Blocked(message, ks, cfg)
	local panel = makePanel(Library.Gui, 340, 250, 12)
	local c = panel.Content
	local done = false
	local badge = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 28), Size = UDim2.fromOffset(52, 52), Parent = c })
	Corner("full", badge)
	Theme.Bind(badge, { BackgroundColor3 = "Danger" })
	Effects.Gloss(badge, 0.25)
	Effects.FadeStroke(badge, { Transparency = 0.5 })
	Icons.New("ban", 26, Color3.new(1, 1, 1), badge, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local t = New("TextLabel", { Text = "Access denied", TextSize = 18, Weight = "Bold", Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 0, 24), Parent = c })
	Theme.Bind(t, { TextColor3 = "Text" })
	local m = New("TextLabel", {
		Text = message or "You can't use this script.", TextSize = 12.5, TextWrapped = true,
		Position = UDim2.fromOffset(28, 122), Size = UDim2.new(1, -56, 0, 40), TextYAlignment = Enum.TextYAlignment.Top, Parent = c,
	})
	Theme.Bind(m, { TextColor3 = "SubText" })
	Components.Button(c, {
		Text = "Close", Style = "Secondary", Position = UDim2.fromOffset(28, 184), Size = UDim2.new(1, -56, 0, 38),
		Callback = function() done = true end,
	})
	panel.Show()
	Sound.Play("Error")
	if ks and ks.BlacklistAction == "Kick" then
		delay(2.2, function() pcall(function() LocalPlayer:Kick(message or "Blacklisted") end) end)
	end
	while not done do wait() end
	panel.Hide()
	wait(0.45)
	panel.Destroy()
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
	if state == "blocked" then
		KeyUI.Blocked(reason, ks, cfg)
		return false
	elseif state == "pass" then
		return true
	end
	if ks.SaveKey ~= false and Library.Folder then
		local saved = FS.read(Library.Folder .. "/key.txt")
		if saved and (KeySystem.Validate(ks, saved)) then return true end
	end
	local ok, why = KeyUI.Show(ks, cfg)
	if not ok and why and why ~= "closed" then KeyUI.Blocked(why, ks, cfg) end
	return ok
end

-- exposed so custom loaders / key screens can reuse the same look
Library.MakePanel = makePanel

----------------------------------------------------------------------------
-- 9. WINDOW
----------------------------------------------------------------------------
local Window, Tab, Section, Card = {}, {}, {}, {}
Window.__index, Tab.__index, Card.__index = Window, Tab, Card
Library.Classes = { Window = Window, Tab = Tab, Section = Section, Card = Card }

-- Section and Tab forward every Add* call to a default card, so
-- `tab:AddToggle{...}` works without creating sections by hand.
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

local function fadeLine(parent, props)
	local vertical = props.Vertical
	props.Vertical = nil
	props.BackgroundColor3 = Color3.new(1, 1, 1)
	props.BackgroundTransparency = props.BackgroundTransparency or 0.93
	props.Parent = parent
	local l = New("Frame", props)
	New("UIGradient", { Transparency = NumberSequence.new({ kp(0, 1), kp(0.5, 0), kp(1, 1) }), Rotation = vertical and 90 or 0, Parent = l })
	return l
end

function Window.new(cfg)
	local self = setmetatable({ Tabs = {}, Config = cfg, Visible = false, UserScale = 1, _tabY = 4, _scale = 1 }, Window)
	local W, H = cfg.Size.X, cfg.Size.Y
	local SW, HH = cfg.SidebarWidth or 150, 46
	self.W, self.H, self.SW, self.HH = W, H, SW, HH
	local gui = Library.Gui

	-- mover (positioned/dragged) > holder (UIScale) so drag offsets stay in screen pixels
	local mover = New("Frame", {
		Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Visible = false, Parent = gui,
	})
	local holder = New("Frame", {
		Name = "Scaler", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Parent = mover,
	})
	local uiScale = New("UIScale", { Parent = holder })
	local shadow = Effects.Shadow(holder, { Spread = 36, OffsetY = 14, Transparency = 1 })
	local main = New("CanvasGroup", { Name = "Main", Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Parent = holder })
	Corner(14, main)
	Theme.Bind(main, { BackgroundColor3 = "Window" })
	self.Mover, self.Holder, self.UIScale, self.Main, self.Shadow = mover, holder, uiScale, main, shadow

	---------------------------------------------------------------- header
	local header = New("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, HH), Active = true, ZIndex = 3, Parent = main })
	Theme.Bind(header, { BackgroundColor3 = "Header" })
	fadeLine(header, { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.9, ZIndex = 4 })

	local chip = New("Frame", { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(14, 9), ZIndex = 4, Parent = header })
	Corner(9, chip)
	Theme.Bind(chip, { BackgroundColor3 = "Accent" })
	Effects.Gloss(chip, 0.32)
	Effects.FadeStroke(chip, { Transparency = 0.5 })
	Icons.New(cfg.Icon or "ghost", 16, "OnAccent", chip, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5 })

	local titleRow = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -160, 1, 0), ZIndex = 4, Parent = header })
	List(titleRow, { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8) })
	local title = New("TextLabel", {
		Text = tostring(cfg.Name):upper(), TextSize = 16, Weight = "Bold", TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), ZIndex = 5, LayoutOrder = 1, Parent = titleRow,
	})
	Theme.Bind(title, { TextColor3 = "Text" })
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.62, 0.62, 0.66)), Parent = title })
	if cfg.Subtitle ~= false then
		local pill = New("TextLabel", {
			Text = tostring(cfg.Subtitle or ("v" .. Library.Version)), TextSize = 10.5, Weight = "SemiBold",
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), ZIndex = 5, LayoutOrder = 2, Parent = titleRow,
		})
		Padding(0, 7, 0, 7, pill)
		Corner("full", pill)
		pill.BackgroundTransparency = 0
		Theme.Bind(pill, { BackgroundColor3 = "CardAlt", TextColor3 = "SubText" })
	end

	local btnClose = smallIconButton(header, "x", UDim2.new(1, -40, 0, 10), function() self:Destroy() end)
	local btnMin = smallIconButton(header, "minus", UDim2.new(1, -70, 0, 10), function() self:SetVisible(false) end)
	btnClose.ZIndex, btnMin.ZIndex = 5, 5

	---------------------------------------------------------------- sidebar
	local sidebar = New("Frame", { Name = "Sidebar", Position = UDim2.fromOffset(0, HH), Size = UDim2.new(0, SW, 1, -HH), Parent = main })
	Theme.Bind(sidebar, { BackgroundColor3 = "Sidebar" })
	fadeLine(sidebar, { Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundTransparency = 0.92, Vertical = true, ZIndex = 4 })

	local tabScroll = New("ScrollingFrame", {
		Name = "Tabs", Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -76), ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = sidebar,
	})
	self.TabScroll = tabScroll
	local pill = New("Frame", { Name = "Pill", Size = UDim2.new(1, 0, 0, 36), Visible = false, ZIndex = 1, Parent = tabScroll })
	Corner(9, pill)
	Theme.Bind(pill, { BackgroundColor3 = "CardAlt" })
	Effects.FadeStroke(pill, { Transparency = 0.86, Rotation = 0 })
	local pillBar = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(3, 16), ZIndex = 2, Parent = pill })
	Corner("full", pillBar)
	Theme.Bind(pillBar, { BackgroundColor3 = "Accent" })
	self.Pill = pill

	-- user chip
	local user = New("Frame", { Position = UDim2.new(0, 8, 1, -58), Size = UDim2.new(1, -16, 0, 50), ZIndex = 2, Parent = sidebar })
	Corner(10, user)
	Theme.Bind(user, { BackgroundColor3 = "Card" })
	local avatar = New("ImageLabel", {
		Position = UDim2.fromOffset(9, 9), Size = UDim2.fromOffset(32, 32), ZIndex = 3, Parent = user,
		Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100"):format(LocalPlayer.UserId),
	})
	Corner("full", avatar)
	Theme.Bind(avatar, { BackgroundColor3 = "CardAlt" })
	avatar.BackgroundTransparency = 0
	local uname = New("TextLabel", {
		Text = cfg.UserName or LocalPlayer.DisplayName, TextSize = 12, Weight = "SemiBold", TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(48, 9), Size = UDim2.new(1, -56, 0, 16), ZIndex = 3, Parent = user,
	})
	Theme.Bind(uname, { TextColor3 = "Text" })
	local utag = New("TextLabel", {
		Text = cfg.UserTag or ("@" .. LocalPlayer.Name), TextSize = 10.5, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(48, 25), Size = UDim2.new(1, -56, 0, 14), ZIndex = 3, Parent = user,
	})
	Theme.Bind(utag, { TextColor3 = "Muted" })

	---------------------------------------------------------------- content
	local content = New("Frame", { Name = "Content", Position = UDim2.fromOffset(SW, HH), Size = UDim2.new(1, -SW, 1, -HH), Parent = main })
	Theme.Bind(content, { BackgroundColor3 = "Content" })
	self.Content = content
	self.Background = Effects.Background(content, Vector2.new(W - SW, H - HH), cfg.Background or "Dots")
	self.Background:SetEnabled(false)
	self.Pages = New("Frame", { Name = "Pages", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = content })

	---------------------------------------------------------------- dragging
	local dragging, dragStart, startOff
	header.InputBegan:Connect(function(input)
		local ut = input.UserInputType
		if ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch then
			dragging, dragStart, startOff = input, input.Position, mover.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = nil end
			end)
		end
	end)
	connect(UIS.InputChanged, function(input)
		if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local d = input.Position - dragStart
			local vp = gui.AbsoluteSize
			local x = clamp(startOff.X.Offset + d.X, -(vp.X / 2) + 90, vp.X / 2 - 90)
			local y = clamp(startOff.Y.Offset + d.Y, -(vp.Y / 2) + 30, vp.Y / 2 - 40)
			mover.Position = UDim2.new(0.5, x, 0.5, y)
		end
	end)

	---------------------------------------------------------------- toggle key + floating button
	self.ToggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
	connect(UIS.InputBegan, function(input, gp)
		if not gp and self.ToggleKey and input.KeyCode == self.ToggleKey then self:Toggle() end
	end)
	if cfg.FloatingButton ~= false and (cfg.FloatingButton or UIS.TouchEnabled) then self:_BuildFloatingButton() end

	---------------------------------------------------------------- responsive scale
	connect(gui:GetPropertyChangedSignal("AbsoluteSize"), function() self:_Fit() end)
	self:_Fit(true)
	Window._InitNotifyScale()
	return self
end

function Window._InitNotifyScale()
	local gui = Library.Gui
	if not Notify.Scale then return end
	local function f() Notify.Scale.Scale = clamp(gui.AbsoluteSize.X / 330, 0.65, 1) end
	f()
	connect(gui:GetPropertyChangedSignal("AbsoluteSize"), f)
end

function Window:_Fit(instant)
	local vp = Library.Gui.AbsoluteSize
	local fit = math.min((vp.X - 20) / self.W, (vp.Y - 20) / self.H)
	local s = math.max(0.3, math.min(math.min(1, fit) * self.UserScale, fit))
	self._scale = s
	self.Mover.Size = UDim2.fromOffset(self.W * s, self.H * s)
	if instant or not self.Visible then self.UIScale.Scale = s else tween(self.UIScale, { Scale = s }, Ease.Smooth) end
end

function Window:SetScale(v) self.UserScale = clamp(v, 0.6, 1.5); self:_Fit() end

function Window:SetSize(v)
	self.W, self.H = v.X, v.Y
	self.Holder.Size = UDim2.fromOffset(v.X, v.Y)
	self.Background:Build(nil, Vector2.new(v.X - self.SW, v.Y - self.HH))
	self:_Fit(true)
end

function Window:SetVisible(v)
	if v == self.Visible then return end
	self.Visible = v
	local s = self._scale
	if v then
		self.Mover.Visible = true
		self.UIScale.Scale = s * 0.95
		tween(self.UIScale, { Scale = s }, Ease.Smooth)
		tween(self.Main, { GroupTransparency = 0 }, Ease.Smooth)
		tween(self.Shadow, { ImageTransparency = 0.35 }, Ease.Smooth)
		self.Background:SetEnabled(true)
		Sound.Play("Open")
	else
		Sound.Play("Close")
		tween(self.UIScale, { Scale = s * 0.96 }, Ease.Smooth)
		tween(self.Main, { GroupTransparency = 1 }, Ease.Smooth)
		tween(self.Shadow, { ImageTransparency = 1 }, Ease.Smooth)
		delay(0.3, function()
			if not self.Visible and self.Mover.Parent then
				self.Mover.Visible = false
				self.Background:SetEnabled(false)
			end
		end)
	end
end
function Window:Toggle() self:SetVisible(not self.Visible) end
function Window:SetToggleKey(key) self.ToggleKey = key end

function Window:_BuildFloatingButton()
	local gui = Library.Gui
	local holder = New("Frame", { Name = "FloatingButton", Position = UDim2.new(0, 14, 0.5, -22), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 1, ZIndex = 20, Parent = gui })
	Effects.Shadow(holder, { Spread = 12, OffsetY = 4, Transparency = 0.45 })
	local body = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = holder })
	Corner("full", body)
	Theme.Bind(body, { BackgroundColor3 = "Accent" })
	Effects.Gloss(body, 0.25)
	Effects.FadeStroke(body, { Transparency = 0.5 })
	Icons.New(self.Config.Icon or "ghost", 20, "OnAccent", body, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 22 })
	local down, moved, origin, startPos
	body.InputBegan:Connect(function(input)
		local ut = input.UserInputType
		if ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch then
			down, moved, origin, startPos = input, false, input.Position, holder.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					if down == input and not moved then Sound.Play("Click"); self:Toggle() end
					down = nil
				end
			end)
		end
	end)
	connect(UIS.InputChanged, function(input)
		if down and (input == down or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local d = input.Position - origin
			if d.Magnitude > 6 then moved = true end
			if moved then
				local vp = gui.AbsoluteSize
				holder.Position = UDim2.fromOffset(clamp(startPos.X.Offset + d.X, 4, vp.X - 50), clamp(startPos.Y.Offset + d.Y + vp.Y * 0.5, 4, vp.Y - 50))
			end
		end
	end)
	self.FloatingButton = holder
end

function Window:Open()
	self:SetVisible(true)
end

function Window:Notify(o) return Notify.Push(o) end
function Window:SetTheme(name) return Theme.Set(name) end
function Window:SetAccent(color)
	Library.Themes.Custom = makeTheme(color)
	Theme.Set("Custom")
end
function Window:SetBackground(style) self.Background:Build(style) end

function Window:Destroy()
	if self._dead then return end
	self._dead = true
	self:SetVisible(false)
	delay(0.35, function()
		if self.Mover then self.Mover:Destroy() end
		if self.FloatingButton then self.FloatingButton:Destroy() end
		self.Background:Destroy()
	end)
	for i, w in ipairs(Library.Windows) do if w == self then table.remove(Library.Windows, i) break end end
	if #Library.Windows == 0 then delay(0.6, function() Library:Unload() end) end
end

---------------------------------------------------------------- tabs
function Window:CreateTabLabel(text)
	local lbl = New("TextLabel", {
		Text = tostring(text):upper(), TextSize = 10, Weight = "SemiBold", TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(12, self._tabY + 6), Size = UDim2.new(1, -12, 0, 14), ZIndex = 2, Parent = self.TabScroll,
	})
	Theme.Bind(lbl, { TextColor3 = "Muted" })
	self._tabY = self._tabY + 26
	self.TabScroll.CanvasSize = UDim2.fromOffset(0, self._tabY)
	return lbl
end

function Window:CreateTab(o)
	if type(o) == "string" then o = { Name = o } end
	o = o or {}
	local tab = setmetatable({ Window = self, Name = o.Name or "Tab", Selected = false, _order = 0 }, Tab)
	tab._y = self._tabY

	local btn = New("TextButton", {
		Name = tab.Name, Position = UDim2.fromOffset(0, tab._y), Size = UDim2.new(1, 0, 0, 36), ZIndex = 2, Parent = self.TabScroll,
	})
	tab.Icon = Icons.New(o.Icon or "layers", 16, "SubText", btn, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 13, 0.5, 0), ZIndex = 3 })
	Theme.Bind(tab.Icon, { ImageColor3 = function(t) return tab.Selected and t.Accent or t.SubText end })
	tab.Label = New("TextLabel", {
		Text = tab.Name, TextSize = 13, Weight = "Medium", TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -48, 1, 0), ZIndex = 3, Parent = btn,
	})
	Theme.Bind(tab.Label, { TextColor3 = function(t) return tab.Selected and t.Text or t.SubText end })
	tab.Button = btn
	self._tabY = self._tabY + 40
	self.TabScroll.CanvasSize = UDim2.fromOffset(0, self._tabY)

	btn.MouseEnter:Connect(function()
		if not tab.Selected then
			Sound.Play("Hover")
			tween(tab.Label, { TextColor3 = resolve("Text") }, Ease.Fast)
		end
	end)
	btn.MouseLeave:Connect(function()
		if not tab.Selected then tween(tab.Label, { TextColor3 = resolve("SubText") }, Ease.Smooth) end
	end)
	btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)

	tab.Page = New("CanvasGroup", { Name = tab.Name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, Parent = self.Pages })
	tab.Scroll = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarImageTransparency = 0.4, ScrollBarThickness = 3, Parent = tab.Page,
	})
	Theme.Bind(tab.Scroll, { ScrollBarImageColor3 = "AccentSoft" })
	Padding(14, 14, 16, 14, tab.Scroll)
	List(tab.Scroll, { Padding = UDim.new(0, 16) })

	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then self:SelectTab(tab, true) end
	return tab
end

function Window:SelectTab(tab, instant)
	if type(tab) == "string" then
		for _, t in ipairs(self.Tabs) do if t.Name == tab then tab = t break end end
	end
	if type(tab) ~= "table" or self.Current == tab then return end
	local prev = self.Current
	self.Current = tab
	if not instant then Sound.Play("Click") end
	if prev then
		prev.Selected = false
		tween(prev.Label, { TextColor3 = resolve("SubText") }, Ease.Smooth)
		tween(prev.Icon, { ImageColor3 = resolve("SubText") }, Ease.Smooth)
		tween(prev.Page, { GroupTransparency = 1 }, Ease.Fast)
		delay(0.16, function() if self.Current ~= prev then prev.Page.Visible = false end end)
	end
	tab.Selected = true
	tween(tab.Label, { TextColor3 = resolve("Text") }, Ease.Smooth)
	tween(tab.Icon, { ImageColor3 = resolve("Accent") }, Ease.Smooth)
	tab.Page.Visible = true
	if instant then
		tab.Page.GroupTransparency = 0
		self.Pill.Position = UDim2.fromOffset(0, tab._y)
		self.Pill.Visible = true
	else
		tab.Page.Position = UDim2.fromOffset(0, 10)
		tween(tab.Page, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Ease.Smooth)
		tween(self.Pill, { Position = UDim2.fromOffset(0, tab._y) }, Ease.Smooth)
	end
end

---------------------------------------------------------------- sections
function Tab:_DefaultSection()
	if not self._defSection then self._defSection = self:CreateSection({}) end
	return self._defSection
end

function Tab:CreateSection(o)
	if type(o) == "string" then o = { Title = o } end
	o = o or {}
	self._order = self._order + 1
	local sec = setmetatable({ Tab = self, _n = 0 }, Section)
	local frame = New("Frame", {
		Name = "Section", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		LayoutOrder = self._order, Parent = self.Scroll,
	})
	List(frame, { Padding = UDim.new(0, 10) })
	if o.Title then
		local head = New("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = frame })
		List(head, { Padding = UDim.new(0, 1) })
		Padding(0, 0, 0, 4, head)
		local t = New("TextLabel", {
			Text = o.Title, TextSize = 19, Weight = "Bold", TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1, Parent = head,
		})
		Theme.Bind(t, { TextColor3 = "Text" })
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.7, 0.7, 0.74)), Parent = t })
		if o.Subtitle then
			local s = New("TextLabel", {
				Text = o.Subtitle, TextSize = 12, Weight = "Medium", TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 2, Parent = head,
			})
			Theme.Bind(s, { TextColor3 = "Muted" })
		end
	end
	sec.Body, sec.Frame = frame, frame
	return sec
end

local function newBand(sec, wide)
	sec._n = sec._n + 1
	local f = New("Frame", {
		Name = "Band", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		LayoutOrder = sec._n + 1, Parent = sec.Body,
	})
	if wide then return { Frame = f, Wide = true, Cols = { f }, Est = { 0 } } end
	List(f, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), VerticalAlignment = Enum.VerticalAlignment.Top })
	local cols = {}
	for i = 1, 2 do
		local col = New("Frame", {
			Name = "Col" .. i, Size = UDim2.new(0.5, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, LayoutOrder = i, Parent = f,
		})
		List(col, { Padding = UDim.new(0, 10) })
		cols[i] = col
	end
	return { Frame = f, Cols = cols, Est = { 0, 0 } }
end

function Section:_DefaultCard()
	if not self._defCard then self._defCard = self:AddCard({ Wide = true }) end
	return self._defCard
end

-- AddCard{ Title?, Wide? }  — cards flow into two balanced columns; Wide spans both
function Section:AddCard(o)
	o = o or {}
	local band, ci
	if o.Wide then
		band, ci = newBand(self, true), 1
		self._band = nil
	else
		if not self._band or self._band.Wide then self._band = newBand(self, false) end
		band = self._band
		ci = (band.Est[1] <= band.Est[2]) and 1 or 2
	end
	self._n = self._n + 1
	local card = setmetatable({ Section = self, Band = band, Col = ci, _count = 0, _order = 0 }, Card)
	local frame = New("Frame", {
		Name = "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = self._n, Parent = band.Cols[ci],
	})
	Corner(10, frame)
	Theme.Bind(frame, { BackgroundColor3 = "Card" })
	Padding(5, 12, 5, 12, frame)
	List(frame)
	card.Frame = frame
	if o.Title then
		card._order = card._order + 1
		local t = New("TextLabel", {
			Text = tostring(o.Title):upper(), TextSize = 10, Weight = "SemiBold", TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 26), LayoutOrder = card._order, Parent = frame,
		})
		Theme.Bind(t, { TextColor3 = "Muted" })
		band.Est[ci] = band.Est[ci] + 26
	end
	band.Est[ci] = band.Est[ci] + 10
	return card
end

---------------------------------------------------------------- card plumbing
function Card:_Divider()
	self._order = self._order + 1
	fadeLine(self.Frame, { Name = "Divider", Size = UDim2.new(1, 0, 0, 1), LayoutOrder = self._order, BackgroundTransparency = 0.93 })
end

-- mode: "labels" (auto height + padded inner frame for label text) | "fixed" | "auto"
-- returns row, inner  (inner only exists in "labels" mode; put label text in it)
function Card:_Row(h, mode, noDivider)
	if self._count > 0 and not noDivider then self:_Divider() end
	self._count = self._count + 1
	self._order = self._order + 1
	mode = mode or "labels"
	local row = New("Frame", {
		Name = "Row", Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = self._order,
		AutomaticSize = (mode == "fixed") and Enum.AutomaticSize.None or Enum.AutomaticSize.Y, Parent = self.Frame,
	})
	local inner
	if mode == "labels" then
		local pad = math.max(0, math.floor((h - 18) / 2))
		inner = New("Frame", { Name = "Inner", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = row })
		Padding(pad, 0, pad, 0, inner)
	end
	self.Band.Est[self.Col] = self.Band.Est[self.Col] + h + 1
	return row, inner
end

function Card:_Labels(row, name, desc, rightPad)
	local box = New("Frame", {
		Name = "Labels", BackgroundTransparency = 1, Size = UDim2.new(1, -(rightPad or 0), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, Parent = row,
	})
	List(box, { Padding = UDim.new(0, 1) })
	local t = New("TextLabel", {
		Text = tostring(name or ""), TextSize = 13.5, Weight = "Medium", TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = box,
	})
	Theme.Bind(t, { TextColor3 = "Text" })
	local d
	if desc and desc ~= "" then
		d = New("TextLabel", {
			Text = tostring(desc), TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2, Parent = box,
		})
		Theme.Bind(d, { TextColor3 = "Muted" })
		self.Band.Est[self.Col] = self.Band.Est[self.Col] + 14
	end
	return t, d
end

-- Registers an element's value so it is saved by configs and readable via Library.Flags
function Card:_Register(o, kind, get, set)
	if not o.Flag then return end
	Library.Elements[o.Flag] = { Type = kind, Get = get, Set = set, Ignore = o.IgnoreConfig }
	Library.Flags[o.Flag] = get()
end

----------------------------------------------------------------------------
-- 10. ELEMENTS   (all are methods of Card; Section/Tab forward to a default card)
----------------------------------------------------------------------------
local WHITE = Color3.new(1, 1, 1)

local function elementLabel(parent, text, size, token, props)
	props = props or {}
	props.Text, props.TextSize, props.Weight = tostring(text or ""), size or 13.5, props.Weight or "Medium"
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.Parent = parent
	local l = New("TextLabel", props)
	Theme.Bind(l, { TextColor3 = token or "Text" })
	return l
end

local function finishObject(obj, row)
	obj.Frame = row
	function obj:SetVisible(v) row.Visible = v end
	function obj:Destroy() row:Destroy() end
	return obj
end

---------------------------------------------------------------- Label / Paragraph / Spacer
function Card:AddLabel(o)
	if type(o) == "string" then o = { Text = o } end
	o = o or {}
	local row, inner = self:_Row(30)
	local l = elementLabel(inner, o.Text or o.Name or "", 12.5, o.Color or "SubText", {
		Weight = "Regular", TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextYAlignment = Enum.TextYAlignment.Top,
	})
	local obj = { Type = "Label" }
	function obj:SetText(t) l.Text = tostring(t) end
	return finishObject(obj, row)
end

function Card:AddParagraph(o)
	o = o or {}
	local row, inner = self:_Row(40)
	local t, d = self:_Labels(inner, o.Title or o.Name or "", o.Content or o.Description)
	local obj = { Type = "Paragraph" }
	function obj:SetTitle(x) t.Text = x end
	function obj:SetContent(x) if d then d.Text = x end end
	return finishObject(obj, row)
end

function Card:AddSpacer(h)
	local row = self:_Row(h or 8, "fixed", true)
	return { Frame = row }
end

-- Build anything yourself: card:AddCustom(function(row, card) ... end, 60)
function Card:AddCustom(builder, height)
	local row = self:_Row(height or 40, "fixed")
	safe(builder, row, self)
	return { Type = "Custom", Frame = row }
end

---------------------------------------------------------------- Button
function Card:AddButton(o)
	if type(o) == "string" then o = { Name = o } end
	o = o or {}
	local row, obj
	if o.Description and o.Description ~= "" then
		local inner
		row, inner = self:_Row(44)
		self:_Labels(inner, o.Name or "Button", o.Description, (o.ButtonWidth or 78) + 10)
		obj = Components.Button(row, {
			Text = o.ButtonText or "Run", Icon = o.Icon, Style = o.Style or "Secondary", AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(o.ButtonWidth or 78, 28), Callback = o.Callback,
		})
	else
		row = self:_Row(46, "fixed")
		obj = Components.Button(row, {
			Text = o.Name or o.Text or "Button", Icon = o.Icon, Style = o.Style or "Secondary",
			Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 34), Callback = o.Callback,
		})
	end
	obj.Type = "Button"
	return finishObject(obj, row)
end

---------------------------------------------------------------- Toggle
function Card:AddToggle(o)
	o = o or {}
	local row, inner = self:_Row(38)
	local nameLbl = self:_Labels(inner, o.Name or "Toggle", o.Description, 52)
	local state = o.Default == true

	local track = New("Frame", {
		Name = "Track", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(38, 20), ZIndex = 3, Parent = row,
	})
	Corner("full", track)
	Theme.Bind(track, { BackgroundColor3 = function(t) return state and t.Accent or t.Track end })
	Effects.Gloss(track, 0.18)
	local stroke = Effects.FadeStroke(track, { Transparency = state and 0.45 or 0.88 })
	Theme.Bind(stroke, { Color = function(t) return state and t.AccentGlow or WHITE end })
	local knobHolder = New("Frame", {
		Name = "Knob", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, state and 20 or 2, 0.5, 0),
		Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, ZIndex = 4, Parent = track,
	})
	Effects.Shadow(knobHolder, { Spread = 6, OffsetY = 1, Transparency = 0.55 })
	local knob = New("Frame", { Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = knobHolder })
	Corner("full", knob)
	Theme.Bind(knob, { BackgroundColor3 = "Knob" })
	local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = row })

	local obj = { Type = "Toggle", Value = state }
	local function apply(v, silent)
		state = v and true or false
		obj.Value = state
		tween(track, { BackgroundColor3 = state and resolve("Accent") or resolve("Track") }, Ease.Smooth)
		tween(stroke, { Transparency = state and 0.45 or 0.88, Color = state and resolve("AccentGlow") or WHITE }, Ease.Smooth)
		tween(knobHolder, { Position = UDim2.new(0, state and 20 or 2, 0.5, 0) }, Ease.Smooth)
		if o.Flag then Library.Flags[o.Flag] = state end
		if not silent then
			Sound.Play("Toggle", state and 1.12 or 0.9)
			safe(o.Callback, state)
		end
	end
	function obj:Set(v, silent) if (v and true or false) ~= state then apply(v, silent) elseif not silent then safe(o.Callback, state) end end
	function obj:Get() return state end
	function obj:SetLabel(t) nameLbl.Text = t end
	hit.MouseButton1Click:Connect(function() apply(not state) end)
	hit.MouseEnter:Connect(function() Sound.Play("Hover"); tween(stroke, { Transparency = state and 0.25 or 0.6 }, Ease.Fast) end)
	hit.MouseLeave:Connect(function() tween(stroke, { Transparency = state and 0.45 or 0.88 }, Ease.Smooth) end)
	self:_Register(o, "Toggle", function() return state end, function(v) obj:Set(v) end)
	return finishObject(obj, row)
end

---------------------------------------------------------------- Slider
function Card:AddSlider(o)
	o = o or {}
	local min, max, inc = o.Min or 0, o.Max or 100, o.Increment or 1
	local value = clamp(o.Default or min, min, max)
	local row = self:_Row(54, "fixed")
	elementLabel(row, o.Name or "Slider", 13.5, "Text", { Position = UDim2.fromOffset(0, 7), Size = UDim2.new(1, -64, 0, 18) })
	local valLbl = elementLabel(row, "", 12, "Accent", {
		Weight = "SemiBold", TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 7), Size = UDim2.fromOffset(64, 18),
	})
	local track = New("Frame", { Position = UDim2.fromOffset(0, 35), Size = UDim2.new(1, 0, 0, 6), Parent = row })
	Corner("full", track)
	Theme.Bind(track, { BackgroundColor3 = "Track" })
	local fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), Parent = track })
	Corner("full", fill)
	Theme.Bind(fill, { BackgroundColor3 = "Accent" })
	Effects.Gloss(fill, 0.22)
	local knobHolder = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1, ZIndex = 3, Parent = track,
	})
	Effects.Shadow(knobHolder, { Spread = 7, OffsetY = 1, Transparency = 0.45 })
	local knob = New("Frame", { Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = knobHolder })
	Corner("full", knob)
	Theme.Bind(knob, { BackgroundColor3 = "Knob" })
	local hit = New("TextButton", { Position = UDim2.fromOffset(-6, 24), Size = UDim2.new(1, 12, 0, 28), ZIndex = 5, Parent = row })

	local obj = { Type = "Slider" }
	local function visual(instant)
		local ratio = (max == min) and 0 or (value - min) / (max - min)
		local info = instant and nil or Ease.Fast
		if instant then
			fill.Size, knobHolder.Position = UDim2.new(ratio, 0, 1, 0), UDim2.new(ratio, 0, 0.5, 0)
		else
			tween(fill, { Size = UDim2.new(ratio, 0, 1, 0) }, info)
			tween(knobHolder, { Position = UDim2.new(ratio, 0, 0.5, 0) }, info)
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
	local function grow(big) tween(knobHolder, { Size = big and UDim2.fromOffset(17, 17) or UDim2.fromOffset(14, 14) }, Ease.Fast) end
	Util.Drag(hit, function(pos)
		local ratio = clamp((pos.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		set(min + ratio * (max - min))
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
	return finishObject(obj, row)
end

---------------------------------------------------------------- Input
function Card:AddInput(o)
	o = o or {}
	local row = self:_Row(68, "fixed")
	elementLabel(row, o.Name or "Input", 13.5, "Text", { Position = UDim2.fromOffset(0, 7), Size = UDim2.new(1, 0, 0, 18) })
	local value = tostring(o.Default or "")
	local field = Components.Field(row, {
		Placeholder = o.Placeholder or "Type here…", Text = value, Numeric = o.Numeric,
		Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 32), Live = o.Live, OnChange = function(t)
			value = t
			if o.Flag then Library.Flags[o.Flag] = t end
			safe(o.OnChange, t)
		end,
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
	return finishObject(obj, row)
end

---------------------------------------------------------------- Number (stepper)
function Card:AddNumber(o)
	o = o or {}
	local min, max, inc = o.Min or -math.huge, o.Max or math.huge, o.Increment or 1
	local value = clamp(o.Default or 0, min, max)
	local row = self:_Row(68, "fixed")
	elementLabel(row, o.Name or "Number", 13.5, "Text", { Position = UDim2.fromOffset(0, 7), Size = UDim2.new(1, 0, 0, 18) })
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
		Position = UDim2.fromOffset(38, 30), Size = UDim2.new(1, -76, 0, 32), Callback = function(t) set(t) end,
	})
	local function stepper(iconName, dir, pos)
		local b = Components.Button(row, { Icon = iconName, Text = "", Style = "Secondary", Position = pos, Size = UDim2.fromOffset(32, 32) })
		local token = 0
		local down = false
		b.Body.MouseButton1Down:Connect(function()
			token = token + 1
			local my = token
			down = true
			set(value + dir * inc)
			delay(0.4, function()
				while down and token == my do set(value + dir * inc); wait(0.06) end
			end)
		end)
		local function up() down = false end
		b.Body.MouseButton1Up:Connect(up)
		b.Body.MouseLeave:Connect(up)
		b.Callback = nil
	end
	stepper("minus", -1, UDim2.fromOffset(0, 30))
	stepper("plus", 1, UDim2.new(1, -32, 0, 30))
	function obj:Set(v, silent) set(v, silent) end
	function obj:Get() return value end
	obj.Value = value
	if o.Flag then Library.Flags[o.Flag] = value end
	self:_Register(o, "Number", function() return value end, function(v) set(v) end)
	return finishObject(obj, row)
end

---------------------------------------------------------------- shared: expandable header (dropdown / colour picker)
local function expandable(card, name, headH)
	local row = card:_Row(headH, "auto")
	List(row)
	local head = New("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, headH), BackgroundTransparency = 1, LayoutOrder = 1, Parent = row })
	elementLabel(head, name, 13.5, "Text", { Size = UDim2.new(0.55, 0, 1, 0) })
	local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = head })
	local drop = New("Frame", { Name = "Drop", Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = 2, Parent = row })
	local box = New("Frame", { Name = "Box", Size = UDim2.new(1, 0, 1, -6), Parent = drop })
	Corner(8, box)
	Theme.Bind(box, { BackgroundColor3 = "CardAlt" })
	return row, head, hit, drop, box
end

---------------------------------------------------------------- Dropdown
function Card:AddDropdown(o)
	o = o or {}
	local multi = o.Multi == true
	local options = o.Options or {}
	local value, set = nil, {}
	local row, head, hit, drop, box = expandable(self, o.Name or "Dropdown", 38)

	local valLbl = elementLabel(head, "", 12, "SubText", {
		Weight = "Medium", TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.new(0.45, 0, 0, 18),
	})
	local chev = Icons.New("chevron-down", 14, "Muted", head, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0) })

	local scroll = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2,
		ScrollBarImageTransparency = 0.4, Parent = box,
	})
	Theme.Bind(scroll, { ScrollBarImageColor3 = "AccentSoft" })
	Padding(4, 4, 4, 4, scroll)
	List(scroll, { Padding = UDim.new(0, 2) })

	local obj = { Type = "Dropdown" }
	local buttons = {}
	local open = false
	local function isSel(n) if multi then return set[n] == true end return value == n end

	local function summary()
		if multi then
			local t = {}
			for _, n in ipairs(options) do if set[n] then table.insert(t, n) end end
			return #t > 0 and table.concat(t, ", ") or "None"
		end
		return value ~= nil and tostring(value) or "Select…"
	end
	local function list()
		local t = {}
		for _, n in ipairs(options) do if set[n] then table.insert(t, n) end end
		return t
	end
	local function current() if multi then return list() end return value end
	local function render()
		valLbl.Text = summary()
		for n, b in pairs(buttons) do
			local sel = isSel(n)
			tween(b.Label, { TextColor3 = sel and resolve("Text") or resolve("SubText") }, Ease.Smooth)
			tween(b.Check, { ImageTransparency = sel and 0 or 1 }, Ease.Smooth)
		end
		if o.Flag then Library.Flags[o.Flag] = current() end
	end
	local function targetH() return math.min(#options, 5) * 28 + 8 + 6 end
	local function setOpen(v)
		open = v
		tween(drop, { Size = UDim2.new(1, 0, 0, v and targetH() or 0) }, Ease.Smooth)
		tween(chev, { Rotation = v and 180 or 0 }, Ease.Smooth)
	end
	local function choose(n, silent)
		if multi then set[n] = not set[n] or nil else value = n end
		render()
		if not silent then
			Sound.Play("Click")
			safe(o.Callback, current())
		end
		if not multi and o.CloseOnSelect ~= false then setOpen(false) end
	end

	local function build()
		for _, b in pairs(buttons) do b.Btn:Destroy() end
		buttons = {}
		for i, n in ipairs(options) do
			local b = New("TextButton", { Size = UDim2.new(1, 0, 0, 26), LayoutOrder = i, Parent = scroll })
			Corner(6, b)
			Theme.Bind(b, { BackgroundColor3 = "Hover" })
			b.BackgroundTransparency = 1
			local lbl = elementLabel(b, n, 12.5, "SubText", { Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -30, 1, 0) })
			Theme.Bind(lbl, { TextColor3 = function(t) return isSel(n) and t.Text or t.SubText end })
			local chk = Icons.New("check", 13, "Accent", b, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), ImageTransparency = isSel(n) and 0 or 1 })
			b.MouseEnter:Connect(function() Sound.Play("Hover"); tween(b, { BackgroundTransparency = 0.35 }, Ease.Fast) end)
			b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 1 }, Ease.Smooth) end)
			b.MouseButton1Click:Connect(function() choose(n) end)
			buttons[n] = { Btn = b, Label = lbl, Check = chk }
		end
		if open then drop.Size = UDim2.new(1, 0, 0, targetH()) end
	end

	hit.MouseButton1Click:Connect(function() Sound.Play("Click"); setOpen(not open) end)
	hit.MouseEnter:Connect(function() Sound.Play("Hover"); tween(chev, { ImageColor3 = resolve("Text") }, Ease.Fast) end)
	hit.MouseLeave:Connect(function() tween(chev, { ImageColor3 = resolve("Muted") }, Ease.Smooth) end)

	function obj:Set(v, silent)
		if multi then
			set = {}
			if type(v) == "table" then for _, n in ipairs(v) do set[n] = true end elseif v ~= nil then set[v] = true end
		else
			value = v
		end
		render()
		if not silent then safe(o.Callback, current()) end
	end
	function obj:Get() return current() end
	function obj:Refresh(newOptions, keep)
		options = newOptions or {}
		if not keep then value, set = nil, {} end
		build()
		render()
	end
	function obj:Open(v) setOpen(v ~= false) end

	build()
	local def = o.Default
	if multi then if type(def) == "table" then for _, n in ipairs(def) do set[n] = true end end
	else value = def end
	render()
	self:_Register(o, "Dropdown", current, function(v) obj:Set(v) end)
	return finishObject(obj, row)
end

---------------------------------------------------------------- Keybind
local KEY_LABELS = {
	LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl", LeftAlt = "LAlt",
	RightAlt = "RAlt", Return = "Enter", Backspace = "Bksp", Escape = "Esc", MouseButton2 = "MB2", MouseButton3 = "MB3",
	Unknown = "None", CapsLock = "Caps", Delete = "Del", Insert = "Ins", PageUp = "PgUp", PageDown = "PgDn",
}
local function keyLabel(name) return KEY_LABELS[name] or name end

function Card:AddKeybind(o)
	o = o or {}
	local row, inner = self:_Row(38)
	self:_Labels(inner, o.Name or "Keybind", o.Description, 76)
	local keyName = "None"
	local def = o.Default
	if typeof(def) == "EnumItem" then keyName = def.Name elseif type(def) == "string" then keyName = def end
	local mode = o.Mode or "Press"
	local listening, held = false, false

	local btn = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3, Parent = row, Weight = "SemiBold", TextSize = 11.5, Text = "",
	})
	Padding(0, 10, 0, 10, btn)
	Corner(7, btn)
	Theme.Bind(btn, { BackgroundColor3 = "CardAlt", TextColor3 = "SubText" })
	btn.BackgroundTransparency = 0
	local stroke = Effects.FadeStroke(btn, { Transparency = 0.84 })
	Effects.Interact(btn, { Base = "CardAlt", Hover = "Hover", Stroke = stroke, StrokeBase = 0.84, ZIndex = 4 })

	local obj = { Type = "Keybind" }
	local function render() btn.Text = listening and "…" or keyLabel(keyName) end
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
			elseif ut == Enum.UserInputType.MouseButton2 or ut == Enum.UserInputType.MouseButton3 then
				pick = ut.Name
			end
			if pick then
				c:Disconnect()
				setKey(pick)
				Theme.Bind(btn, { TextColor3 = "SubText" })
				Sound.Play("Success", 1.1)
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
	finishObject(obj, row)
	function obj:Destroy() c1:Disconnect(); c2:Disconnect(); row:Destroy() end
	return obj
end

---------------------------------------------------------------- Color picker
function Card:AddColorPicker(o)
	o = o or {}
	local color = o.Default or Color3.fromRGB(150, 94, 255)
	local h, s, v = Color3.toHSV(color)
	local row, head, hit, drop, box = expandable(self, o.Name or "Color", 38)
	local open = false

	local swatch = New("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(34, 18), BackgroundColor3 = color, Parent = head })
	Corner(6, swatch)
	Effects.Gloss(swatch, 0.15)
	Effects.FadeStroke(swatch, { Transparency = 0.6 })

	Padding(8, 8, 8, 8, box)
	local sv = New("Frame", { Size = UDim2.new(1, -24, 0, 96), BackgroundColor3 = Color3.fromHSV(h, 1, 1), Parent = box })
	Corner(6, sv)
	local white = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = sv })
	Corner(6, white)
	New("UIGradient", { Transparency = NumberSequence.new({ kp(0, 0), kp(1, 1) }), Parent = white })
	local black = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = sv })
	Corner(6, black)
	New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 1), kp(1, 0) }), Parent = black })
	local cursor = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = WHITE, ZIndex = 5, Parent = sv })
	Corner("full", cursor)
	Effects.Shadow(cursor, { Spread = 5, OffsetY = 1, Transparency = 0.4 })
	local cursorDot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = color, ZIndex = 6, Parent = cursor })
	Corner("full", cursorDot)

	local hue = New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 14, 0, 96), BackgroundColor3 = WHITE, Parent = box })
	Corner(6, hue)
	local seq = {}
	for i = 0, 6 do table.insert(seq, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 == 1 and 0.999 or i / 6, 1, 1))) end
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(seq), Parent = hue })
	local hueMark = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, h, 0), Size = UDim2.new(1, 6, 0, 4), BackgroundColor3 = WHITE, ZIndex = 5, Parent = hue })
	Corner("full", hueMark)
	Effects.Shadow(hueMark, { Spread = 4, OffsetY = 1, Transparency = 0.4 })

	local hexField
	local obj = { Type = "ColorPicker" }
	local function hex(c) return ("#%02X%02X%02X"):format(math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
	local function refresh(silent, fromHex)
		color = Color3.fromHSV(h, s, v)
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		cursor.Position = UDim2.fromScale(s, 1 - v)
		cursorDot.BackgroundColor3 = color
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
		Placeholder = "#RRGGBB", Text = hex(color), Align = Enum.TextXAlignment.Center, TextSize = 12,
		Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 28), Token = "Card",
		Callback = function(text)
			local t = text:gsub("#", "")
			if #t == 6 and t:match("^%x+$") then
				local c = Color3.fromRGB(tonumber(t:sub(1, 2), 16), tonumber(t:sub(3, 4), 16), tonumber(t:sub(5, 6), 16))
				h, s, v = Color3.toHSV(c)
				refresh(false, true)
			else
				hexField.Set(hex(color))
			end
		end,
	})

	local function setOpen(b)
		open = b
		tween(drop, { Size = UDim2.new(1, 0, 0, b and 156 or 0) }, Ease.Smooth)
	end
	hit.MouseButton1Click:Connect(function() Sound.Play("Click"); setOpen(not open) end)
	hit.MouseEnter:Connect(function() Sound.Play("Hover") end)

	function obj:Set(c, silent)
		if typeof(c) == "table" then c = Color3.new(c.R or c.r or 0, c.G or c.g or 0, c.B or c.b or 0) end
		if typeof(c) ~= "Color3" then return end
		h, s, v = Color3.toHSV(c)
		refresh(silent)
	end
	function obj:Get() return color end
	refresh(true)
	self:_Register(o, "ColorPicker", function() return color end, function(c) obj:Set(c) end)
	return finishObject(obj, row)
end

----------------------------------------------------------------------------
-- 11. SETTINGS / CONFIG
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
	if name and name ~= "" then FS.write(Library.Folder .. "/autoload.txt", cleanName(name))
	else FS.delete(Library.Folder .. "/autoload.txt") end
end

function Library:GetAutoload()
	local n = Library.Folder and FS.read(Library.Folder .. "/autoload.txt")
	return n and trim(n) ~= "" and trim(n) or nil
end

-- Call once after you've built all your tabs
function Library:LoadAutoload()
	local n = Library:GetAutoload()
	if n and Library:LoadConfig(n) then
		Library:Notify({ Title = "Config loaded", Content = "Auto-loaded “" .. n .. "”.", Type = "Success", Duration = 3 })
		return true
	end
	return false
end

-- Ready-made settings tab: theme, accent, background, scale, sounds, menu key, configs
function Window:CreateSettingsTab(o)
	o = o or {}
	local win = self
	local tab = self:CreateTab({ Name = o.Name or "Settings", Icon = o.Icon or "settings" })

	local ap = tab:CreateSection({ Title = "Appearance", Subtitle = "Theme, accent colour and background" })
	local c1 = ap:AddCard({ Title = "Theme" })
	local names = {}
	for n in pairs(Library.Themes) do if n ~= "Custom" then table.insert(names, n) end end
	table.sort(names)
	c1:AddDropdown({ Name = "Preset", Options = names, Default = Library.Themes[Theme.Name] and Theme.Name or nil, Callback = function(v) Theme.Set(v) end })
	c1:AddColorPicker({ Name = "Custom accent", Default = Theme.Current.Accent, Callback = function(c) win:SetAccent(c) end })

	local c2 = ap:AddCard({ Title = "Interface" })
	c2:AddDropdown({ Name = "Background", Options = { "Dots", "Grid", "None" }, Default = self.Config.Background or "Dots", Callback = function(v) win:SetBackground(v) end })
	c2:AddSlider({ Name = "UI scale", Min = 60, Max = 150, Default = 100, Suffix = "%", Callback = function(v) win:SetScale(v / 100) end })
	c2:AddKeybind({
		Name = "Menu key", Default = self.ToggleKey,
		ChangedCallback = function(k)
			local ok, kc = pcall(function() return Enum.KeyCode[k] end)
			if ok and kc then win:SetToggleKey(kc) end
		end,
	})

	local fx = tab:CreateSection({ Title = "Feedback", Subtitle = "Sounds and motion" })
	local c3 = fx:AddCard({})
	c3:AddToggle({ Name = "UI sounds", Default = Library.Config.SoundsEnabled, Callback = function(v) Library.Config.SoundsEnabled = v end })
	c3:AddSlider({ Name = "Sound volume", Min = 0, Max = 100, Default = Library.Config.SoundVolume * 100, Suffix = "%", Callback = function(v) Library.Config.SoundVolume = v / 100 end })
	local c4 = fx:AddCard({})
	c4:AddToggle({ Name = "Animations", Default = Library.Config.Animations ~= false, Callback = function(v) Library.Config.Animations = v end })
	c4:AddSlider({ Name = "Animation speed", Min = 50, Max = 200, Default = Library.Config.AnimSpeed * 100, Suffix = "%", Callback = function(v) Library.Config.AnimSpeed = v / 100 end })

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
			if Library:SaveConfig(n) then
				Library:Notify({ Title = "Saved", Content = "“" .. n .. "” written to disk.", Type = "Success" })
				reload()
			else
				Library:Notify({ Title = "Failed", Content = "Could not write the config.", Type = "Error" })
			end
		end,
	})
	dd = cc:AddDropdown({ Name = "Saved configs", Options = Library:ListConfigs(), Callback = function(v) selected = v end })
	cc:AddButton({
		Name = "Load selected", Icon = "folder-open",
		Callback = function()
			if needFS() or not selected then return end
			if Library:LoadConfig(selected) then Library:Notify({ Title = "Loaded", Content = "“" .. selected .. "” applied.", Type = "Success" })
			else Library:Notify({ Title = "Failed", Content = "Config could not be read.", Type = "Error" }) end
		end,
	})
	cc:AddButton({
		Name = "Delete selected", Icon = "trash-2", Style = "Danger",
		Callback = function()
			if needFS() or not selected then return end
			Library:DeleteConfig(selected)
			selected = nil
			reload()
			Library:Notify({ Title = "Deleted", Content = "Config removed.", Type = "Info" })
		end,
	})
	cc:AddToggle({
		Name = "Auto-load selected", Description = "Applies it every time the script starts.",
		Callback = function(v) if selected then Library:SetAutoload(v and selected or nil) end end,
	})
	cc:AddButton({ Name = "Unload interface", Icon = "x", Style = "Danger", Callback = function() Library:Unload() end })
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
	if parent then
		gui.Parent = parent
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

local function defaultTasks(cfg)
	local tasks = {}
	local names = {}
	for _, n in ipairs(Icons.Needed) do table.insert(names, n) end
	for _, n in ipairs(cfg.Icons or {}) do table.insert(names, n) end

	table.insert(tasks, { Name = "Fetching icon pack", Weight = 3, Run = function(report) Icons.LoadProvider(report) end })
	table.insert(tasks, { Name = "Loading icons", Weight = 4, Run = function(report) Icons.Preload(names, report) end })
	table.insert(tasks, {
		Name = "Preparing assets", Weight = 2,
		Run = function(report)
			local items = { New("ImageLabel", { Image = Library.Config.ShadowImage, Size = UDim2.fromOffset(1, 1) }) }
			for _, w in ipairs({ "Regular", "Medium", "SemiBold", "Bold" }) do
				table.insert(items, New("TextLabel", { Text = "Aa", Weight = w }))
			end
			report(0.25, "Warming up fonts")
			for _, def in pairs(Library.Config.Sounds) do
				local snd = Instance.new("Sound")
				snd.SoundId = type(def) == "table" and def.Id or tostring(def)
				table.insert(items, snd)
			end
			report(0.5, "Warming up audio")
			if ContentProvider then pcall(function() ContentProvider:PreloadAsync(items) end) end
			for _, it in ipairs(items) do it:Destroy() end
			report(1)
		end,
	})
	local ks = cfg.KeySystem
	if ks and ks.Enabled ~= false and (ks.KeyUrl or ks.WhitelistUrl or ks.BlacklistUrl) then
		table.insert(tasks, { Name = "Syncing access lists", Weight = 1, Run = function(report) report(0.1); KeySystem.Prefetch(ks); report(1) end })
	end
	if type(cfg.Loader) == "table" and cfg.Loader.Tasks then
		for _, t in ipairs(cfg.Loader.Tasks) do table.insert(tasks, t) end
	end
	return tasks
end

--[[ CreateWindow(config) — shows the loader, then the key system, then builds the window.
   Yields until everything is done. Returns the Window, or nil if access was denied.

   Name, Icon, Subtitle, Size, Theme, LoaderTheme, Background ("Dots"|"Grid"|"None"), ToggleKey,
   FloatingButton, SidebarWidth, ConfigFolder, Icons = {...}, Sounds = {...}, Config = {...},
   Loader = false | { Tagline, Footer, MinTime, Tasks = {...}, Custom = function(ctx) end },
   KeySystem = false | { Keys, KeyUrl, Whitelist, WhitelistUrl, Blacklist, BlacklistUrl, ... }
]]
function Library:CreateWindow(cfg)
	cfg = cfg or {}
	cfg.Name = cfg.Name or "Library"
	local sz = cfg.Size
	if typeof(sz) == "UDim2" then sz = Vector2.new(sz.X.Offset, sz.Y.Offset) end
	if type(sz) == "table" then sz = Vector2.new(sz[1], sz[2]) end
	cfg.Size = sz or Vector2.new(605, 420)
	cfg.Theme = Library.Themes[cfg.Theme or ""] and cfg.Theme or "Purple"
	if cfg.Config then deepMerge(Library.Config, cfg.Config) end
	if cfg.Sounds then deepMerge(Library.Config.Sounds, cfg.Sounds) end
	if cfg.IconSources then Library.Config.IconSources = cfg.IconSources end

	Library.Folder = tostring(cfg.ConfigFolder or cfg.Name):gsub("[^%w_%-]", "_")
	FS.folder(Library.Folder)
	FS.folder(Library.Folder .. "/configs")

	if not Library.Gui then
		Library.Gui = createGui()
		Notify.Init(Library.Gui)
	end

	Theme.Set(cfg.LoaderTheme or "Purple", true)
	Library._RunLoader(cfg, defaultTasks(cfg), cfg.Loader == false)

	if not Library._RunKeySystem(cfg) then
		Library:Unload()
		return nil
	end

	Theme.Set(cfg.Theme, true)
	local win = Window.new(cfg)
	table.insert(Library.Windows, win)
	win:Open()
	return win
end

function Library:Notify(o) return Notify.Push(o) end
function Library:SetTheme(name) return Theme.Set(name) end

-- RegisterTheme("Sunset", Color3.fromRGB(255,120,60))  or  RegisterTheme("X", { Accent = ..., Card = ... })
function Library:RegisterTheme(name, spec)
	if typeof(spec) == "Color3" then
		Library.Themes[name] = makeTheme(spec)
	elseif type(spec) == "table" then
		local t = {}
		for k, v in pairs(spec.Accent and makeTheme(spec.Accent) or Library.Themes.Purple) do t[k] = v end
		for k, v in pairs(spec) do t[k] = v end
		Library.Themes[name] = t
	end
end

-- Add your own element type:  RegisterElement("Stat", function(card, opts, Library) ... end)  ->  card:AddStat{...}
function Library:RegisterElement(name, builder)
	Card["Add" .. name] = function(card, o) return builder(card, o or {}, Library) end
end

function Library:PreloadIcons(list) Icons.Preload(list, function() end) end

function Library:Unload()
	for _, w in ipairs(Library.Windows) do pcall(function() w.Mover:Destroy() end) end
	Library.Windows = {}
	Library._maid:Clean()
	if Library.Gui then Library.Gui:Destroy() Library.Gui = nil end
	Notify.Holder, Notify.Items = nil, {}
	Sound.Cache = {}
	Theme.Listeners = {}
	Library.Flags, Library.Elements = {}, {}
	if genv.__UILibraryInstance == Library then genv.__UILibraryInstance = nil end
end

Library.New, Library.Tween, Library.Ease = New, tween, Ease

return Library
