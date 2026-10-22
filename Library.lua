--!nocheck
--!nolint
--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║  Vesper UI Library                                  v2.0.0    ║
    ║  Single-file Roblox UI library · 1500+ built-in Lucide icons  ║
    ║  Docs: see README.md                                          ║
    ╚═══════════════════════════════════════════════════════════════╝

    Icons: Lucide (ISC License) via latte-soft/lucide-roblox (MIT).
]]

-- ─────────────────────────────────────────────────────────────
--  Services (executor-safe)
-- ─────────────────────────────────────────────────────────────
local cloneref = cloneref or function(o) return o end
local function Service(name)
	local ok, svc = pcall(function() return cloneref(game:GetService(name)) end)
	return ok and svc or nil
end

local Players          = Service("Players")
local RunService       = Service("RunService")
local TweenService     = Service("TweenService")
local UserInputService = Service("UserInputService")
local HttpService      = Service("HttpService")
local GuiService       = Service("GuiService")
local SoundService     = Service("SoundService")
local CoreGui          = Service("CoreGui")

-- Re-execution guard: tear down the previous copy cleanly
do
	local env = (getgenv and getgenv()) or _G
	if env.__VesperLib and env.__VesperLib.Destroy then
		pcall(function() env.__VesperLib:Destroy() end)
	end
end

-- ─────────────────────────────────────────────────────────────
--  Namespaces (kept as tables to stay far below the local limit)
-- ─────────────────────────────────────────────────────────────
local Vesper   = { Version = "2.0.0", Windows = {}, Flags = {}, Debug = false }
local Util     = {}
local Theme    = {}
local Icons    = {}
local Sound    = {}
local Loc      = {}
local Elements = {}
local Layer    = {}   -- global layer (notifications, popups)
local Config   = {}   -- config manager
local Shadow   = {}   -- depth shadows
local Lines    = {}   -- fading lines / dividers
local Fx       = {}   -- click effects, backgrounds, loaders

-- ─────────────────────────────────────────────────────────────
--  Maid (connection / instance cleanup)
-- ─────────────────────────────────────────────────────────────
local Maid = {}
Maid.__index = Maid
function Maid.new() return setmetatable({ _items = {} }, Maid) end
function Maid:Give(item) table.insert(self._items, item); return item end
function Maid:Clean()
	local items = self._items
	self._items = {}
	for _, item in items do
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			item:Disconnect()
		elseif kind == "Instance" then
			item:Destroy()
		elseif kind == "function" then
			pcall(item)
		elseif kind == "table" and item.Destroy then
			pcall(item.Destroy, item)
		end
	end
end

-- ─────────────────────────────────────────────────────────────
--  Fonts
-- ─────────────────────────────────────────────────────────────
Util.FontFamily = "rbxasset://fonts/families/GothamSSm.json"
local fontCache = {}
local WEIGHTS = {
	Regular  = Enum.FontWeight.Regular,
	Medium   = Enum.FontWeight.Medium,
	SemiBold = Enum.FontWeight.SemiBold,
	Bold     = Enum.FontWeight.Bold,
}
function Util.Font(weight)
	weight = weight or "Regular"
	local key = Util.FontFamily .. weight
	local f = fontCache[key]
	if not f then
		f = Font.new(Util.FontFamily, WEIGHTS[weight] or Enum.FontWeight.Regular, Enum.FontStyle.Normal)
		fontCache[key] = f
	end
	return f
end
Util.MonoFont = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

-- ─────────────────────────────────────────────────────────────
--  Instance creation with sane defaults
-- ─────────────────────────────────────────────────────────────
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

local DEFAULTS = {
	Frame       = { BorderSizePixel = 0, BackgroundColor3 = WHITE },
	CanvasGroup = { BorderSizePixel = 0, BackgroundColor3 = WHITE },
	TextLabel   = { BorderSizePixel = 0, BackgroundTransparency = 1, TextColor3 = WHITE, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left },
	TextButton  = { BorderSizePixel = 0, BackgroundTransparency = 1, AutoButtonColor = false, Text = "", TextColor3 = WHITE, TextSize = 14 },
	TextBox     = { BorderSizePixel = 0, BackgroundTransparency = 1, TextColor3 = WHITE, TextSize = 14, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left },
	ImageLabel  = { BorderSizePixel = 0, BackgroundTransparency = 1 },
	ImageButton = { BorderSizePixel = 0, BackgroundTransparency = 1, AutoButtonColor = false },
	ScrollingFrame = { BorderSizePixel = 0, BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(), ScrollBarImageTransparency = 1 },
	UIStroke    = { ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
}

function Util.New(class, props, children)
	local inst = Instance.new(class)
	local defaults = DEFAULTS[class]
	if defaults then
		for k, v in defaults do inst[k] = v end
	end
	if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
		inst.FontFace = Util.Font(props and props.Weight or "Regular")
	end
	local parent
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			elseif k ~= "Weight" then
				inst[k] = v
			end
		end
	end
	if children then
		for _, child in children do child.Parent = inst end
	end
	if parent then inst.Parent = parent end
	return inst
end
local New = Util.New

function Util.Corner(parent, radius)
	return New("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

function Util.Padding(parent, t, r, b, l)
	return New("UIPadding", {
		PaddingTop = UDim.new(0, t or 0), PaddingRight = UDim.new(0, r or t or 0),
		PaddingBottom = UDim.new(0, b or t or 0), PaddingLeft = UDim.new(0, l or r or t or 0),
		Parent = parent,
	})
end

function Util.List(parent, padding, dir, halign, valign)
	return New("UIListLayout", {
		Padding = UDim.new(0, padding or 0),
		FillDirection = dir or Enum.FillDirection.Vertical,
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

-- ─────────────────────────────────────────────────────────────
--  Tweening
-- ─────────────────────────────────────────────────────────────
local EASE = {
	Out     = { Enum.EasingStyle.Quint,       Enum.EasingDirection.Out },
	Quad    = { Enum.EasingStyle.Quad,        Enum.EasingDirection.Out },
	In      = { Enum.EasingStyle.Quint,       Enum.EasingDirection.In },
	Back    = { Enum.EasingStyle.Back,        Enum.EasingDirection.Out },
	Sine    = { Enum.EasingStyle.Sine,        Enum.EasingDirection.InOut },
	Linear  = { Enum.EasingStyle.Linear,      Enum.EasingDirection.InOut },
	Elastic = { Enum.EasingStyle.Elastic,     Enum.EasingDirection.Out },
	InOut   = { Enum.EasingStyle.Quint,       Enum.EasingDirection.InOut },
	Expo    = { Enum.EasingStyle.Exponential, Enum.EasingDirection.Out },
	Bounce  = { Enum.EasingStyle.Bounce,      Enum.EasingDirection.Out },
}
local infoCache = {}
function Util.Tween(obj, time, props, ease)
	if not obj then return end
	local e = EASE[ease or "Out"] or EASE.Out
	local key = time .. (ease or "Out")
	local info = infoCache[key]
	if not info then
		info = TweenInfo.new(time, e[1], e[2])
		infoCache[key] = info
	end
	local ok, tween = pcall(TweenService.Create, TweenService, obj, info, props)
	if ok then tween:Play(); return tween end
end

--- Endless tween (ambient animation). reverses = ping-pong, delay = seconds before each cycle
function Util.Loop(obj, time, props, ease, reverses, delay)
	if not obj then return end
	local e = EASE[ease or "Sine"] or EASE.Sine
	local ok, tween = pcall(function()
		local info = TweenInfo.new(time, e[1], e[2], -1, reverses == true, delay or 0)
		return TweenService:Create(obj, info, props)
	end)
	if ok and tween then
		tween:Play()
		pcall(function()
			obj.Destroying:Connect(function() pcall(function() tween:Cancel() end) end)
		end)
		return tween
	end
end

-- ─────────────────────────────────────────────────────────────
--  Misc helpers
-- ─────────────────────────────────────────────────────────────
function Util.Fire(callback, ...)
	if type(callback) ~= "function" then return end
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(callback, table.unpack(args, 1, args.n))
		if not ok then warn("[Vesper] callback error: " .. tostring(err)) end
	end)
end

-- Roblox instances reject unknown members, so extra handles (e.g. a button's label) live in a side table.
local partsTable = setmetatable({}, { __mode = "k" })
function Util.SetPart(inst, name, value)
	local parts = partsTable[inst]
	if not parts then parts = {}; partsTable[inst] = parts end
	parts[name] = value
end
function Util.Part(inst, name)
	local parts = partsTable[inst]
	return parts and parts[name]
end

function Util.Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function Util.Round(v, step)
	if not step or step <= 0 then return v end
	return math.floor(v / step + 0.5) * step
end
function Util.FormatNumber(v, step)
	if step and step >= 1 then return tostring(math.floor(v + 0.5)) end
	local decimals = 0
	if step and step > 0 then
		local s = string.format("%.6f", step)
		s = string.gsub(s, "0+$", "")
		local dot = string.find(s, ".", 1, true)
		decimals = dot and (#s - dot) or 0
	else
		decimals = 2
	end
	return string.format("%." .. decimals .. "f", v)
end

function Util.Luminance(c) return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B end

function Util.ToHex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
function Util.FromHex(hex)
	hex = string.gsub(tostring(hex), "#", "")
	if #hex == 3 then hex = string.gsub(hex, ".", function(c) return c .. c end) end
	if #hex ~= 6 or string.find(hex, "[^%x]") then return nil end
	return Color3.fromRGB(tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16), tonumber(string.sub(hex, 5, 6), 16))
end

function Util.EscapeRich(text)
	text = string.gsub(tostring(text), "&", "&amp;")
	text = string.gsub(text, "<", "&lt;")
	text = string.gsub(text, ">", "&gt;")
	text = string.gsub(text, '"', "&quot;")
	text = string.gsub(text, "'", "&apos;")
	return text
end

function Util.Trim(text)
	local out = string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1")
	return out
end

function Util.Viewport()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	if vp.X < 10 or vp.Y < 10 then vp = Vector2.new(1280, 720) end
	return vp
end

function Util.IsTouch()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Util.RandomName()
	local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local out = table.create(14)
	for i = 1, 14 do
		local n = math.random(1, #chars)
		out[i] = string.sub(chars, n, n)
	end
	return table.concat(out)
end

function Util.Copy(text)
	local fn = setclipboard or toclipboard or (Clipboard and Clipboard.set)
	if fn then
		local ok = pcall(fn, tostring(text))
		return ok
	end
	return false
end

function Util.IsInput(input, ...)
	for _, t in { ... } do
		if input.UserInputType == t then return true end
	end
	return false
end

--- Product of every UIScale from `inst` up to its ScreenGui (screen pixels per logical pixel)
function Util.GetScale(inst)
	local scale = 1
	local p = inst
	while p do
		local us = p:FindFirstChildOfClass("UIScale")
		if us then scale = scale * us.Scale end
		p = p.Parent
		if p and p:IsA("ScreenGui") then break end
	end
	return scale
end

--- Press-and-drag helper. `onMove(position: Vector3, input)` fires on press and on every move.
function Util.Drag(target, onMove, onBegin, onEnd)
	return target.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if onBegin and onBegin(input) == false then return end
		local moveConn, endConn
		local function finish()
			if moveConn then moveConn:Disconnect(); moveConn = nil end
			if endConn then endConn:Disconnect(); endConn = nil end
			if onEnd then onEnd(input) end
		end
		onMove(input.Position, input)
		moveConn = UserInputService.InputChanged:Connect(function(changed)
			if changed.UserInputType == Enum.UserInputType.MouseMovement or changed == input then
				onMove(changed.Position, changed)
			end
		end)
		endConn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then finish() end
		end)
	end)
end

-- ─────────────────────────────────────────────────────────────
--  Depth shadows
--  Floating surfaces (window, popups, dialogs, notifications) sit on three stacked
--  layers: a crisp 2px drop plus two soft ones. They live next to the CanvasGroup
--  (never inside it) and fade together with it, so nothing lingers after closing.
-- ─────────────────────────────────────────────────────────────
Shadow.Config   = { Depth = 2, Strength = 0.5, Soft = true }
Shadow.Registry = setmetatable({}, { __mode = "k" })

local SHADOW_LAYERS = {
	{ expand = 7, dy = 3, base = 0.94, soft = true,  radius = 7 },
	{ expand = 3, dy = 1, base = 0.87, soft = true,  radius = 3 },
	{ expand = 0, dy = 0, base = 0.64, soft = false, radius = 0 },
}

function Shadow.Apply(sh)
	local cfg = Shadow.Config
	local factor = Util.Clamp(cfg.Strength / 0.5, 0, 2)
	for i, def in SHADOW_LAYERS do
		local layer = sh.Layers[i]
		local on = cfg.Depth > 0 and (not def.soft or cfg.Soft)
		layer.Base = on and (1 - Util.Clamp((1 - def.base) * factor, 0, 1)) or 1
		local e = def.expand
		layer.Frame.Position = UDim2.new(0, -e, 0, -e + cfg.Depth + def.dy)
		layer.Frame.Size = UDim2.new(1, e * 2, 1, e * 2)
		sh.Corner[i].CornerRadius = UDim.new(0, sh.Radius + def.radius)
		layer.Frame.BackgroundTransparency = 1 - (1 - layer.Base) * (1 - sh.Alpha)
	end
end

function Shadow.Build(holder, radius)
	local sh = { Holder = holder, Radius = radius, Layers = {}, Corner = {}, Alpha = 1 }
	for i = 1, #SHADOW_LAYERS do
		local f = New("Frame", { Name = "Shadow", BackgroundColor3 = BLACK, BackgroundTransparency = 1, ZIndex = 0, Parent = holder })
		sh.Corner[i] = Util.Corner(f, radius)
		sh.Layers[i] = { Frame = f, Base = 1 }
	end
	Shadow.Registry[sh] = true
	Shadow.Apply(sh)
	return sh
end

--- a = group transparency of the surface it belongs to (0 visible, 1 gone)
function Shadow.Fade(sh, a, time, ease, instant)
	sh.Alpha = a
	for _, layer in sh.Layers do
		local target = 1 - (1 - layer.Base) * (1 - a)
		if instant then
			layer.Frame.BackgroundTransparency = target
		else
			Util.Tween(layer.Frame, time, { BackgroundTransparency = target }, ease)
		end
	end
end

function Shadow.ApplyAll()
	for sh in Shadow.Registry do pcall(Shadow.Apply, sh) end
end

--- Surface = transparent holder (position / size / scale live here) + shadow layers + CanvasGroup.
--- props go on the holder. auto = true makes the surface grow with its content (dialogs, notifications).
function Util.Surface(parent, props, radius, auto)
	local p = { BackgroundTransparency = 1, Parent = parent }
	for k, v in props or {} do p[k] = v end
	local holder = New("Frame", p)
	local shadow = Shadow.Build(holder, radius)
	local canvas = New("CanvasGroup", {
		Name = "Canvas", BackgroundColor3 = WHITE, GroupTransparency = 1, ZIndex = 1, Parent = holder,
		Size = auto and UDim2.new(1, 0, 0, 0) or UDim2.fromScale(1, 1),
		AutomaticSize = auto and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
	})
	Util.Corner(canvas, radius)
	Util.SetPart(canvas, "Shadow", shadow)
	return holder, canvas, shadow
end

--- Fade a surface's canvas and its shadow together
function Util.FadeCanvas(canvas, a, time, ease, instant)
	if instant then
		canvas.GroupTransparency = a
	else
		Util.Tween(canvas, time, { GroupTransparency = a }, ease)
	end
	local sh = Util.Part(canvas, "Shadow")
	if sh then Shadow.Fade(sh, a, time, ease, instant) end
end

-- ─────────────────────────────────────────────────────────────
--  Fading lines (dividers, edges, highlights)
--  Style: "Edges" (fades at both ends) | "Left" | "Right" | "Center" | "Solid"
--  Change them all at once with Vesper:SetLines({ Style, Thickness, Strength, Color })
-- ─────────────────────────────────────────────────────────────
Lines.Style     = "Edges"
Lines.Thickness = 1
Lines.Strength  = 0.5      -- global multiplier (0.5 = as designed)
Lines.Color     = "Stroke" -- theme token the lines are painted with ("Stroke" or "Accent")
Lines.Registry  = setmetatable({}, { __mode = "k" })

local function kp(t, v) return NumberSequenceKeypoint.new(t, v) end

function Lines.Sequence(style, strength)
	local tr = 1 - Util.Clamp(strength, 0, 1)
	if style == "Left" then
		return NumberSequence.new({ kp(0, tr), kp(1, 1) })
	elseif style == "Right" then
		return NumberSequence.new({ kp(0, 1), kp(1, tr) })
	elseif style == "Center" then
		return NumberSequence.new({ kp(0, 1), kp(0.5, tr), kp(1, 1) })
	elseif style == "Solid" then
		return NumberSequence.new({ kp(0, tr), kp(1, tr) })
	end
	return NumberSequence.new({ kp(0, 1), kp(0.18, tr), kp(0.82, tr), kp(1, 1) })
end

function Lines.Apply(line)
	local e = Lines.Registry[line]
	if not e then return end
	local strength = (e.Strength or 0.5) * (Lines.Strength / 0.5)
	e.Grad.Transparency = Lines.Sequence(e.Style or Lines.Style, Util.Clamp(strength, 0, 1))
	if not e.Fixed then
		local sz = line.Size
		if e.Vertical then
			line.Size = UDim2.new(0, Lines.Thickness, sz.Y.Scale, sz.Y.Offset)
		else
			line.Size = UDim2.new(sz.X.Scale, sz.X.Offset, 0, Lines.Thickness)
		end
	end
end

function Lines.ApplyAll()
	for line in Lines.Registry do pcall(Lines.Apply, line) end
end

--- o = { Vertical, Position, Size, AnchorPoint, Thickness, Strength (0-1), Style, Token, LayoutOrder, ZIndex }
function Util.FadeLine(parent, o)
	o = o or {}
	local vertical = o.Vertical == true
	local th = o.Thickness or Lines.Thickness
	local line = New("Frame", {
		Name = "Line", BackgroundColor3 = WHITE, AnchorPoint = o.AnchorPoint or Vector2.new(0, 0),
		Position = o.Position or UDim2.new(),
		Size = o.Size or (vertical and UDim2.new(0, th, 1, 0) or UDim2.new(1, 0, 0, th)),
		LayoutOrder = o.LayoutOrder or 0, ZIndex = o.ZIndex or 1, Parent = parent,
	})
	local grad = New("UIGradient", { Rotation = vertical and 90 or 0, Parent = line })
	Lines.Registry[line] = { Grad = grad, Vertical = vertical, Strength = o.Strength, Style = o.Style, Fixed = o.Thickness ~= nil }
	Theme.Bind(line, { BackgroundColor3 = o.Token or function(t) return t[Lines.Color] or t.Stroke end })
	Lines.Apply(line)
	return line
end

-- ─────────────────────────────────────────────────────────────
--  Contact shadow (the "2 pixel" depth under cards and buttons) + soft shading
-- ─────────────────────────────────────────────────────────────
Shadow.Edges = setmetatable({}, { __mode = "k" })

function Shadow.ApplyEdge(f)
	local base = Shadow.Edges[f]
	if not base then return end
	local cfg = Shadow.Config
	local factor = Util.Clamp(cfg.Strength / 0.5, 0, 2)
	f.BackgroundTransparency = cfg.Depth > 0 and (1 - Util.Clamp((1 - base) * factor, 0, 1)) or 1
	f.Size = UDim2.new(1, -(f:GetAttribute("Inset") or 5) * 2, 0, math.max(cfg.Depth, 1) + 1)
end

--- Thin shadow just below `parent`'s bottom edge. o = { Inset, Alpha (0-1 transparency at strength 0.5), Color }
function Shadow.Edge(parent, o)
	o = o or {}
	local inset = o.Inset or 5
	local f = New("Frame", {
		Name = "Depth", BackgroundColor3 = o.Color or BLACK, BackgroundTransparency = 1, ZIndex = 0, Active = false,
		Position = UDim2.new(0, inset, 1, -1), Size = UDim2.new(1, -inset * 2, 0, 3), Parent = parent,
	})
	f:SetAttribute("Inset", inset)
	Util.Corner(f, 2)
	New("UIGradient", { Transparency = NumberSequence.new({ kp(0, 1), kp(0.12, 0), kp(0.88, 0), kp(1, 1) }), Parent = f })
	Shadow.Edges[f] = o.Alpha or 0.8
	Shadow.ApplyEdge(f)
	return f
end

function Shadow.ApplyAll()
	for sh in Shadow.Registry do pcall(Shadow.Apply, sh) end
	for f in Shadow.Edges do pcall(Shadow.ApplyEdge, f) end
end

--- Static top-to-bottom shading. It multiplies BackgroundColor3, so colour tweens keep working.
function Util.Shade(parent, rotation, amount)
	amount = amount or 0.08
	local g = Color3.new(1 - amount, 1 - amount, 1 - amount)
	return New("UIGradient", { Rotation = rotation or 90, Color = ColorSequence.new(WHITE, g), Parent = parent })
end

-- ─────────────────────────────────────────────────────────────
--  Theme engine
--  Every themed instance is registered once; switching a theme
--  tweens all of them to the new palette.
--  Each theme also has a background STYLE (orbs, streaks, aurora…)
--  that can be overridden at runtime.
-- ─────────────────────────────────────────────────────────────
Theme.Themes         = {}
Theme.Order          = {}
Theme.Current        = nil
Theme.Registry       = setmetatable({}, { __mode = "k" })
Theme.Listeners      = {}
Theme.Watchers       = {}  -- inst -> fn(name, theme, inst)   (removed automatically when inst is destroyed)
Theme.StyleWatchers  = {}  -- inst -> fn(style, inst)
Theme.Styles         = { "Plain", "Orbs", "Streaks", "Aurora", "Stars", "Grid", "Shards", "Rings" }
Theme.StyleOverride  = nil
Theme.Animated       = true

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local STATUS_DARK  = { Success = rgb(74, 222, 128),  Warning = rgb(251, 191, 36), Danger = rgb(248, 90, 90),  Info = rgb(96, 165, 250) }
local STATUS_LIGHT = { Success = rgb(22, 163, 74),   Warning = rgb(217, 119, 6),  Danger = rgb(220, 38, 38),  Info = rgb(37, 99, 235) }

--- Build a full token set from a compact spec.
--- spec = { Mode = "Dark"|"Light", Base = Color3, Accent = Color3, Accent2 = Color3?, Style = string?, Override = {token = value}? }
function Theme.Make(name, spec)
	local dark = spec.Mode ~= "Light"
	local base = spec.Base
	local accent = spec.Accent
	local accent2 = spec.Accent2 or accent
	local t = { Name = name, Mode = dark and "Dark" or "Light", Accent = accent, Accent2 = accent2, Style = spec.Style or "Plain" }

	if dark then
		-- three-stop window gradient: lit corner -> accent-tinted middle -> deep tinted end
		t.Window     = base:Lerp(WHITE, 0.012)
		t.Window2    = base:Lerp(accent, 0.13)
		t.Window3    = base:Lerp(accent2, 0.10):Lerp(BLACK, 0.25)
		t.Sidebar    = base:Lerp(BLACK, 0.30)
		t.Sidebar2   = t.Sidebar:Lerp(accent, 0.12)
		t.Surface    = base:Lerp(WHITE, 0.028)
		t.Card       = base:Lerp(WHITE, 0.062)
		t.CardHover  = base:Lerp(WHITE, 0.105)
		t.Input      = base:Lerp(WHITE, 0.125)
		t.InputHover = base:Lerp(WHITE, 0.175)
		t.Stroke     = base:Lerp(WHITE, 0.34)
		t.Popup      = base:Lerp(WHITE, 0.085)
		t.Text       = base:Lerp(WHITE, 0.94)
		t.SubText    = base:Lerp(WHITE, 0.58)
		t.Muted      = base:Lerp(WHITE, 0.38)
		for k, v in STATUS_DARK do t[k] = v end
	else
		t.Window     = base:Lerp(WHITE, 0.30)
		t.Window2    = base:Lerp(accent, 0.16):Lerp(WHITE, 0.15)
		t.Window3    = base:Lerp(accent2, 0.20):Lerp(BLACK, 0.03)
		t.Sidebar    = base:Lerp(BLACK, 0.05)
		t.Sidebar2   = t.Sidebar:Lerp(accent, 0.10)
		t.Surface    = base:Lerp(BLACK, 0.04)
		t.Card       = base:Lerp(WHITE, 0.78)
		t.CardHover  = base:Lerp(WHITE, 0.50)
		t.Input      = base:Lerp(BLACK, 0.075)
		t.InputHover = base:Lerp(BLACK, 0.115)
		t.Stroke     = base:Lerp(BLACK, 0.34)
		t.Popup      = base:Lerp(WHITE, 0.92)
		t.Text       = base:Lerp(BLACK, 0.88)
		t.SubText    = base:Lerp(BLACK, 0.52)
		t.Muted      = base:Lerp(BLACK, 0.38)
		for k, v in STATUS_LIGHT do t[k] = v end
	end

	local lum = (Util.Luminance(accent) + Util.Luminance(accent2)) / 2
	t.AccentText = lum > 0.62 and rgb(18, 18, 22) or rgb(255, 255, 255)
	t.Shadow = BLACK

	if spec.Override then
		for k, v in spec.Override do t[k] = v end
	end
	return t
end

--- Register a theme. Pass either a compact spec (has `Base`) or a partial token table with `Extends`.
function Theme.Add(name, spec)
	local theme
	if spec.Base then
		theme = Theme.Make(name, spec)
	else
		local parent = Theme.Themes[spec.Extends or "Vesper"] or Theme.Themes.Vesper
		theme = { Name = name }
		for k, v in parent do theme[k] = v end
		for k, v in spec do
			if k ~= "Extends" then theme[k] = v end
		end
		theme.Name = name
		if spec.Accent and spec.Accent2 == nil then theme.Accent2 = spec.Accent end
		if spec.Accent and spec.AccentText == nil then
			local a = spec.Accent
			local lum = 0.2126 * a.R + 0.7152 * a.G + 0.0722 * a.B
			theme.AccentText = lum > 0.62 and Color3.fromRGB(18, 18, 22) or Color3.fromRGB(255, 255, 255)
		end
	end
	if not Theme.Themes[name] then table.insert(Theme.Order, name) end
	Theme.Themes[name] = theme
	if Theme.Current and Theme.Current.Name == name and Theme.Set then Theme.Set(name, true) end
	return theme
end

-- ── Built-in themes ──────────────────────────────────────────
-- Dark
Theme.Add("Vesper",     { Base = rgb(17, 18, 27),  Accent = rgb(124, 92, 255),  Accent2 = rgb(56, 189, 248),  Style = "Orbs" })
Theme.Add("Midnight",   { Base = rgb(11, 16, 29),  Accent = rgb(59, 130, 246),  Accent2 = rgb(34, 211, 238),  Style = "Stars" })
Theme.Add("Obsidian",   { Base = rgb(14, 14, 17),  Accent = rgb(226, 232, 240), Accent2 = rgb(148, 163, 184), Style = "Shards" })
Theme.Add("Graphite",   { Base = rgb(25, 26, 30),  Accent = rgb(96, 165, 250),  Accent2 = rgb(129, 140, 248), Style = "Grid" })
Theme.Add("Slate",      { Base = rgb(28, 37, 52),  Accent = rgb(56, 189, 248),  Accent2 = rgb(129, 140, 248), Style = "Aurora" })
Theme.Add("Abyss",      { Base = rgb(7, 12, 16),   Accent = rgb(45, 212, 191),  Accent2 = rgb(59, 130, 246),  Style = "Rings" })
Theme.Add("Ocean",      { Base = rgb(8, 21, 27),   Accent = rgb(20, 184, 166),  Accent2 = rgb(56, 189, 248),  Style = "Aurora" })
Theme.Add("Emerald",    { Base = rgb(10, 21, 16),  Accent = rgb(74, 222, 128),  Accent2 = rgb(163, 230, 53),  Style = "Orbs" })
Theme.Add("Aurora",     { Base = rgb(10, 17, 27),  Accent = rgb(52, 211, 153),  Accent2 = rgb(167, 139, 250), Style = "Aurora" })
Theme.Add("Crimson",    { Base = rgb(25, 12, 16),  Accent = rgb(244, 63, 94),   Accent2 = rgb(251, 146, 60),  Style = "Streaks" })
Theme.Add("Ember",      { Base = rgb(23, 15, 11),  Accent = rgb(251, 146, 60),  Accent2 = rgb(239, 68, 68),   Style = "Streaks" })
Theme.Add("Sunset",     { Base = rgb(25, 14, 29),  Accent = rgb(251, 113, 133), Accent2 = rgb(251, 191, 36),  Style = "Orbs" })
Theme.Add("Rose",       { Base = rgb(27, 14, 21),  Accent = rgb(251, 113, 133), Accent2 = rgb(244, 114, 182), Style = "Orbs" })
Theme.Add("Plum",       { Base = rgb(28, 16, 33),  Accent = rgb(217, 70, 239),  Accent2 = rgb(251, 113, 133), Style = "Shards" })
Theme.Add("Amethyst",   { Base = rgb(19, 13, 30),  Accent = rgb(168, 85, 247),  Accent2 = rgb(236, 72, 153),  Style = "Stars" })
Theme.Add("Nord",       { Base = rgb(30, 35, 45),  Accent = rgb(136, 192, 208), Accent2 = rgb(129, 161, 193), Style = "Aurora" })
Theme.Add("Dracula",    { Base = rgb(33, 34, 44),  Accent = rgb(189, 147, 249), Accent2 = rgb(255, 121, 198), Style = "Orbs" })
Theme.Add("Mocha",      { Base = rgb(30, 30, 46),  Accent = rgb(203, 166, 247), Accent2 = rgb(137, 180, 250), Style = "Rings" })
Theme.Add("Cyberpunk",  { Base = rgb(14, 10, 25),  Accent = rgb(252, 238, 10),  Accent2 = rgb(0, 240, 255),   Style = "Grid" })
Theme.Add("Nebula",     { Base = rgb(15, 10, 28),  Accent = rgb(192, 132, 252), Accent2 = rgb(244, 114, 182), Style = "Stars" })
Theme.Add("Inferno",    { Base = rgb(20, 9, 9),    Accent = rgb(248, 113, 53),  Accent2 = rgb(250, 204, 21),  Style = "Streaks" })
Theme.Add("Glacier",    { Base = rgb(9, 17, 26),   Accent = rgb(125, 211, 252), Accent2 = rgb(165, 180, 252), Style = "Rings" })
Theme.Add("Matrix",     { Base = rgb(6, 14, 9),    Accent = rgb(34, 197, 94),   Accent2 = rgb(132, 204, 22),  Style = "Grid" })
Theme.Add("Twilight",   { Base = rgb(14, 15, 32),  Accent = rgb(99, 102, 241),  Accent2 = rgb(45, 212, 191),  Style = "Aurora" })
-- Light
Theme.Add("Paper",      { Mode = "Light", Base = rgb(219, 219, 222), Accent = rgb(58, 58, 66),   Accent2 = rgb(112, 112, 124), Style = "Shards" })
Theme.Add("Daylight",   { Mode = "Light", Base = rgb(226, 229, 246), Accent = rgb(99, 102, 241),  Accent2 = rgb(14, 165, 233),  Style = "Orbs" })
Theme.Add("Blossom",    { Mode = "Light", Base = rgb(235, 222, 238), Accent = rgb(217, 70, 239),  Accent2 = rgb(244, 114, 182), Style = "Orbs" })
Theme.Add("Latte",      { Mode = "Light", Base = rgb(232, 234, 241), Accent = rgb(136, 57, 239),  Accent2 = rgb(30, 102, 245),  Style = "Aurora" })
Theme.Add("Mint",       { Mode = "Light", Base = rgb(220, 238, 231), Accent = rgb(16, 185, 129),  Accent2 = rgb(45, 212, 191),  Style = "Streaks" })
Theme.Add("Sand",       { Mode = "Light", Base = rgb(239, 230, 217), Accent = rgb(217, 119, 6),   Accent2 = rgb(234, 88, 12),   Style = "Orbs" })

Theme.Current = Theme.Themes.Vesper

-- ── Binding ──────────────────────────────────────────────────
local function resolve(token)
	if type(token) == "string" then return Theme.Current[token] end
	if type(token) == "function" then return token(Theme.Current) end
	return token
end

Theme.Resolve = resolve

--- Theme.Bind(instance, { Property = "Token" | function(theme) -> value })
function Theme.Bind(inst, map)
	local reg = Theme.Registry[inst]
	if not reg then reg = {}; Theme.Registry[inst] = reg end
	for prop, token in map do
		reg[prop] = token
		inst[prop] = resolve(token)
	end
	return inst
end

function Theme.AccentSeq(t)
	t = t or Theme.Current
	return ColorSequence.new(t.Accent, t.Accent2)
end

--- Gradient that always follows the accent pair
function Theme.AccentGradient(parent, rotation)
	local g = New("UIGradient", { Rotation = rotation or 0, Parent = parent })
	Theme.Bind(g, { Color = function(t) return ColorSequence.new(t.Accent, t.Accent2) end })
	return g
end

--- Window-style three stop gradient (lit -> tinted -> deep)
function Theme.WindowSeq(t)
	t = t or Theme.Current
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, t.Window),
		ColorSequenceKeypoint.new(0.55, t.Window2),
		ColorSequenceKeypoint.new(1, t.Window3),
	})
end

function Theme.WindowGradient(parent, rotation)
	local g = New("UIGradient", { Rotation = rotation or 35, Parent = parent })
	Theme.Bind(g, { Color = Theme.WindowSeq })
	return g
end

function Theme.Refresh(animate)
	for inst, map in Theme.Registry do
		for prop, token in map do
			local value = resolve(token)
			local kind = typeof(value)
			if animate and (kind == "Color3" or kind == "number") then
				Util.Tween(inst, 0.35, { [prop] = value }, "Quad")
			else
				pcall(function() inst[prop] = value end)
			end
		end
	end
end

function Theme.GetStyle()
	return Theme.StyleOverride or Theme.Current.Style or "Plain"
end

function Theme.FireStyle()
	local style = Theme.GetStyle()
	for inst, fn in Theme.StyleWatchers do pcall(fn, style, inst) end
end

--- Watch for theme / style changes while `inst` is alive (no manual cleanup needed)
function Theme.Watch(inst, fn)
	if Theme.Watchers[inst] == nil then
		inst.Destroying:Connect(function() Theme.Watchers[inst] = nil end)
	end
	Theme.Watchers[inst] = fn
end
function Theme.WatchStyle(inst, fn)
	if Theme.StyleWatchers[inst] == nil then
		inst.Destroying:Connect(function() Theme.StyleWatchers[inst] = nil end)
	end
	Theme.StyleWatchers[inst] = fn
end

function Theme.Set(name, silent)
	local theme = Theme.Themes[name]
	if not theme then return false end
	local prevStyle = Theme.GetStyle()
	Theme.Current = theme
	Theme.Refresh(not silent)
	for _, fn in Theme.Listeners do Util.Fire(fn, name, theme) end
	for inst, fn in Theme.Watchers do pcall(fn, name, theme, inst) end
	if Theme.GetStyle() ~= prevStyle then Theme.FireStyle() end
	return true
end

--- nil / "Default" follows the theme's own style
function Theme.SetStyle(style)
	if style == "Default" or style == "Theme" or style == "" then style = nil end
	if style ~= nil and not table.find(Theme.Styles, style) then return false end
	local prev = Theme.GetStyle()
	Theme.StyleOverride = style
	if Theme.GetStyle() ~= prev then Theme.FireStyle() end
	return true
end

function Theme.SetAnimated(on)
	on = on ~= false
	if Theme.Animated == on then return end
	Theme.Animated = on
	Theme.FireStyle()
end

function Theme.Swatch(name)
	local t = Theme.Themes[name]
	return t.Accent, t.Accent2, t.Window
end
-- GENERATED by tools/build.py from latte-soft/lucide-roblox (Lucide v0.363.0). Do not edit.
local ICON_DATA = {
	[48] = {
		sheets = {16898612629,16898612819,16898613044,16898613353,16898613509,16898613613,16898613699,16898613777,16898613869},
		raw = [==[a-arrow-down=1,771,0;a-arrow-up=1,0,771;a-large-small=1,771,257;accessibility=1,257,771;activity=1,514,771;activity-square=1,771,514;air-vent=1,820,0;airplay=1,771,49;alarm-check=1,49,771;alarm-clock=1,257,820;alarm-clock-check=1,0,820;alarm-clock-minus=1,820,257;alarm-clock-off=1,771,306;alarm-clock-plus=1,306,771;alarm-minus=1,820,514;alarm-plus=1,771,563;alarm-smoke=1,563,771;album=1,514,820;alert-circle=1,869,0;alert-octagon=1,820,49;alert-triangle=1,771,98;align-center=1,0,869;align-center-horizontal=1,98,771;align-center-vertical=1,49,820;align-end-horizontal=1,869,257;align-end-vertical=1,820,306;align-horizontal-distribute-center=1,771,355;align-horizontal-distribute-end=1,355,771;align-horizontal-distribute-start=1,306,820;align-horizontal-justify-center=1,257,869;align-horizontal-justify-end=1,869,514;align-horizontal-justify-start=1,820,563;align-horizontal-space-around=1,771,612;align-horizontal-space-between=1,612,771;align-justify=1,563,820;align-left=1,514,869;align-right=1,918,0;align-start-horizontal=1,869,49;align-start-vertical=1,820,98;align-vertical-distribute-center=1,771,147;align-vertical-distribute-end=1,147,771;align-vertical-distribute-start=1,98,820;align-vertical-justify-center=1,49,869;align-vertical-justify-end=1,0,918;align-vertical-justify-start=1,918,257;align-vertical-space-around=1,869,306;align-vertical-space-between=1,820,355;ambulance=1,771,404;ampersand=1,404,771;ampersands=1,355,820;anchor=1,306,869;angry=1,257,918;annoyed=1,918,514;antenna=1,869,563;anvil=1,820,612;aperture=1,771,661;app-window=1,612,820;app-window-mac=1,661,771;apple=1,563,869;archive=1,918,49;archive-restore=1,514,918;archive-x=1,967,0;area-chart=1,869,98;armchair=1,820,147;arrow-big-down=1,196,771;arrow-big-down-dash=1,771,196;arrow-big-left=1,98,869;arrow-big-left-dash=1,147,820;arrow-big-right=1,0,967;arrow-big-right-dash=1,49,918;arrow-big-up=1,918,306;arrow-big-up-dash=1,967,257;arrow-down=1,967,49;arrow-down-0-1=1,869,355;arrow-down-1-0=1,820,404;arrow-down-a-z=1,771,453;arrow-down-circle=1,453,771;arrow-down-from-line=1,404,820;arrow-down-left=1,257,967;arrow-down-left-from-circle=1,355,869;arrow-down-left-square=1,306,918;arrow-down-narrow-wide=1,967,514;arrow-down-right=1,820,661;arrow-down-right-from-circle=1,918,563;arrow-down-right-square=1,869,612;arrow-down-square=1,771,710;arrow-down-to-dot=1,710,771;arrow-down-to-line=1,661,820;arrow-down-up=1,612,869;arrow-down-wide-narrow=1,563,918;arrow-down-z-a=1,514,967;arrow-left=1,98,918;arrow-left-circle=1,918,98;arrow-left-from-line=1,869,147;arrow-left-right=1,820,196;arrow-left-square=1,196,820;arrow-left-to-line=1,147,869;arrow-right=1,453,820;arrow-right-circle=1,49,967;arrow-right-from-line=1,967,306;arrow-right-left=1,918,355;arrow-right-square=1,869,404;arrow-right-to-line=1,820,453;arrow-up=1,967,355;arrow-up-0-1=1,404,869;arrow-up-1-0=1,355,918;arrow-up-a-z=1,306,967;arrow-up-circle=1,967,563;arrow-up-down=1,918,612;arrow-up-from-dot=1,869,661;arrow-up-from-line=1,820,710;arrow-up-left=1,661,869;arrow-up-left-from-circle=1,771,759;arrow-up-left-square=1,710,820;arrow-up-narrow-wide=1,612,918;arrow-up-right=1,918,147;arrow-up-right-from-circle=1,563,967;arrow-up-right-square=1,967,98;arrow-up-square=1,869,196;arrow-up-to-line=1,196,869;arrow-up-wide-narrow=1,147,918;arrow-up-z-a=1,98,967;arrows-up-from-line=1,918,404;asterisk=1,869,453;at-sign=1,453,869;atom=1,404,918;audio-lines=1,355,967;audio-waveform=1,967,612;award=1,918,661;axe=1,869,710;axis-3d=1,820,759;baby=1,771,808;backpack=1,710,869;badge=1,661,967;badge-alert=1,661,918;badge-cent=1,612,967;badge-check=1,967,147;badge-dollar-sign=1,918,196;badge-euro=1,196,918;badge-help=1,147,967;badge-indian-rupee=1,967,404;badge-info=1,918,453;badge-japanese-yen=1,453,918;badge-minus=1,404,967;badge-percent=1,967,661;badge-plus=1,918,710;badge-pound-sterling=1,869,759;badge-russian-ruble=1,820,808;badge-swiss-franc=1,771,857;badge-x=1,710,918;baggage-claim=1,967,196;ban=1,196,967;banana=1,967,453;banknote=1,453,967;bar-chart=1,967,759;bar-chart-2=1,967,710;bar-chart-3=1,918,759;bar-chart-4=1,869,808;bar-chart-big=1,820,857;bar-chart-horizontal=1,710,967;bar-chart-horizontal-big=1,771,906;barcode=1,918,808;baseline=1,869,857;bath=1,820,906;battery=1,967,857;battery-charging=1,771,955;battery-full=1,967,808;battery-low=1,918,857;battery-medium=1,869,906;battery-warning=1,820,955;beaker=1,918,906;bean=1,967,906;bean-off=1,869,955;bed=2,771,0;bed-double=1,918,955;bed-single=1,967,955;beef=2,0,771;beer=2,257,771;beer-off=2,771,257;bell=2,820,257;bell-dot=2,771,514;bell-electric=2,514,771;bell-minus=2,820,0;bell-off=2,771,49;bell-plus=2,49,771;bell-ring=2,0,820;between-horizontal-end=2,771,306;between-horizontal-start=2,306,771;between-vertical-end=2,257,820;between-vertical-start=2,820,514;bike=2,771,563;binary=2,563,771;biohazard=2,514,820;bird=2,869,0;bitcoin=2,820,49;blend=2,771,98;blinds=2,98,771;blocks=2,49,820;bluetooth=2,771,355;bluetooth-connected=2,0,869;bluetooth-off=2,869,257;bluetooth-searching=2,820,306;bold=2,355,771;bolt=2,306,820;bomb=2,257,869;bone=2,869,514;book=2,820,612;book-a=2,820,563;book-audio=2,771,612;book-check=2,612,771;book-copy=2,563,820;book-dashed=2,514,869;book-down=2,918,0;book-headphones=2,869,49;book-heart=2,820,98;book-image=2,771,147;book-key=2,147,771;book-lock=2,98,820;book-marked=2,49,869;book-minus=2,0,918;book-open=2,820,355;book-open-check=2,918,257;book-open-text=2,869,306;book-plus=2,771,404;book-text=2,404,771;book-type=2,355,820;book-up=2,257,918;book-up-2=2,306,869;book-user=2,918,514;book-x=2,869,563;bookmark=2,514,918;bookmark-check=2,771,661;bookmark-minus=2,661,771;bookmark-plus=2,612,820;bookmark-x=2,563,869;boom-box=2,967,0;bot=2,869,98;bot-message-square=2,918,49;box=2,771,196;box-select=2,820,147;boxes=2,196,771;braces=2,147,820;brackets=2,98,869;brain=2,967,257;brain-circuit=2,49,918;brain-cog=2,0,967;brick-wall=2,918,306;briefcase=2,771,453;briefcase-business=2,869,355;briefcase-medical=2,820,404;bring-to-front=2,453,771;brush=2,404,820;bug=2,257,967;bug-off=2,355,869;bug-play=2,306,918;building=2,918,563;building-2=2,967,514;bus=2,820,661;bus-front=2,869,612;cable=2,710,771;cable-car=2,771,710;cake=2,612,869;cake-slice=2,661,820;calculator=2,563,918;calendar=2,355,918;calendar-check=2,967,49;calendar-check-2=2,514,967;calendar-clock=2,918,98;calendar-days=2,869,147;calendar-fold=2,820,196;calendar-heart=2,196,820;calendar-minus=2,98,918;calendar-minus-2=2,147,869;calendar-off=2,49,967;calendar-plus=2,918,355;calendar-plus-2=2,967,306;calendar-range=2,869,404;calendar-search=2,820,453;calendar-x=2,404,869;calendar-x-2=2,453,820;camera=2,967,563;camera-off=2,306,967;candlestick-chart=2,918,612;candy=2,771,759;candy-cane=2,869,661;candy-off=2,820,710;cannabis=2,710,820;captions=2,612,918;captions-off=2,661,869;car=2,918,147;car-front=2,563,967;car-taxi-front=2,967,98;caravan=2,869,196;carrot=2,196,869;case-lower=2,147,918;case-sensitive=2,98,967;case-upper=2,967,355;cassette-tape=2,918,404;cast=2,869,453;castle=2,453,869;cat=2,404,918;cctv=2,355,967;check=2,710,869;check-check=2,967,612;check-circle=2,869,710;check-circle-2=2,918,661;check-square=2,771,808;check-square-2=2,820,759;chef-hat=2,661,918;cherry=2,612,967;chevron-down=2,196,918;chevron-down-circle=2,967,147;chevron-down-square=2,918,196;chevron-first=2,147,967;chevron-last=2,967,404;chevron-left=2,404,967;chevron-left-circle=2,918,453;chevron-left-square=2,453,918;chevron-right=2,869,759;chevron-right-circle=2,967,661;chevron-right-square=2,918,710;chevron-up=2,710,918;chevron-up-circle=2,820,808;chevron-up-square=2,771,857;chevrons-down=2,967,196;chevrons-down-up=2,661,967;chevrons-left=2,967,453;chevrons-left-right=2,196,967;chevrons-right=2,967,710;chevrons-right-left=2,453,967;chevrons-up=2,869,808;chevrons-up-down=2,918,759;chrome=2,820,857;church=2,771,906;cigarette=2,967,759;cigarette-off=2,710,967;circle=3,771,355;circle-alert=2,918,808;circle-arrow-down=2,869,857;circle-arrow-left=2,820,906;circle-arrow-out-down-left=2,771,955;circle-arrow-out-down-right=2,967,808;circle-arrow-out-up-left=2,918,857;circle-arrow-out-up-right=2,869,906;circle-arrow-right=2,820,955;circle-arrow-up=2,967,857;circle-check=2,869,955;circle-check-big=2,918,906;circle-chevron-down=2,967,906;circle-chevron-left=2,918,955;circle-chevron-right=2,967,955;circle-chevron-up=3,771,0;circle-dashed=3,0,771;circle-divide=3,771,257;circle-dollar-sign=3,257,771;circle-dot=3,514,771;circle-dot-dashed=3,771,514;circle-ellipsis=3,820,0;circle-equal=3,771,49;circle-fading-plus=3,49,771;circle-gauge=3,0,820;circle-help=3,820,257;circle-minus=3,771,306;circle-off=3,306,771;circle-parking=3,820,514;circle-parking-off=3,257,820;circle-pause=3,771,563;circle-percent=3,563,771;circle-play=3,514,820;circle-plus=3,869,0;circle-power=3,820,49;circle-slash=3,98,771;circle-slash-2=3,771,98;circle-stop=3,49,820;circle-user=3,869,257;circle-user-round=3,0,869;circle-x=3,820,306;circuit-board=3,355,771;citrus=3,306,820;clapperboard=3,257,869;clipboard=3,49,869;clipboard-check=3,869,514;clipboard-copy=3,820,563;clipboard-edit=3,771,612;clipboard-list=3,612,771;clipboard-minus=3,563,820;clipboard-paste=3,514,869;clipboard-pen=3,869,49;clipboard-pen-line=3,918,0;clipboard-plus=3,820,98;clipboard-signature=3,771,147;clipboard-type=3,147,771;clipboard-x=3,98,820;clock=3,771,661;clock-1=3,0,918;clock-10=3,918,257;clock-11=3,869,306;clock-12=3,820,355;clock-2=3,771,404;clock-3=3,404,771;clock-4=3,355,820;clock-5=3,306,869;clock-6=3,257,918;clock-7=3,918,514;clock-8=3,869,563;clock-9=3,820,612;cloud=3,918,306;cloud-cog=3,661,771;cloud-download=3,612,820;cloud-drizzle=3,563,869;cloud-fog=3,514,918;cloud-hail=3,967,0;cloud-lightning=3,918,49;cloud-moon=3,820,147;cloud-moon-rain=3,869,98;cloud-off=3,771,196;cloud-rain=3,147,820;cloud-rain-wind=3,196,771;cloud-snow=3,98,869;cloud-sun=3,0,967;cloud-sun-rain=3,49,918;cloud-upload=3,967,257;cloudy=3,869,355;clover=3,820,404;club=3,771,453;code=3,355,869;code-2=3,453,771;code-xml=3,404,820;codepen=3,306,918;codesandbox=3,257,967;coffee=3,967,514;cog=3,918,563;coins=3,869,612;columns=3,661,820;columns-2=3,820,661;columns-3=3,771,710;columns-4=3,710,771;combine=3,612,869;command=3,563,918;compass=3,514,967;component=3,967,49;computer=3,918,98;concierge-bell=3,869,147;cone=3,820,196;construction=3,196,820;contact=3,49,967;contact-2=3,147,869;contact-round=3,98,918;container=3,967,306;contrast=3,918,355;cookie=3,869,404;cooking-pot=3,820,453;copy=3,918,612;copy-check=3,453,820;copy-minus=3,404,869;copy-plus=3,355,918;copy-slash=3,306,967;copy-x=3,967,563;copyleft=3,869,661;copyright=3,820,710;corner-down-left=3,771,759;corner-down-right=3,710,820;corner-left-down=3,661,869;corner-left-up=3,612,918;corner-right-down=3,563,967;corner-right-up=3,967,98;corner-up-left=3,918,147;corner-up-right=3,869,196;cpu=3,196,869;creative-commons=3,147,918;credit-card=3,98,967;croissant=3,967,355;crop=3,918,404;cross=3,869,453;crosshair=3,453,869;crown=3,404,918;cuboid=3,355,967;cup-soda=3,967,612;currency=3,918,661;cylinder=3,869,710;database=3,710,869;database-backup=3,820,759;database-zap=3,771,808;delete=3,661,918;dessert=3,612,967;diameter=3,967,147;diamond=3,196,918;diamond-percent=3,918,196;dice-1=3,147,967;dice-2=3,967,404;dice-3=3,918,453;dice-4=3,453,918;dice-5=3,404,967;dice-6=3,967,661;dices=3,918,710;diff=3,869,759;disc=3,661,967;disc-2=3,820,808;disc-3=3,771,857;disc-album=3,710,918;divide=3,967,453;divide-circle=3,967,196;divide-square=3,196,967;dna=3,967,710;dna-off=3,453,967;dock=3,918,759;dog=3,869,808;dollar-sign=3,820,857;donut=3,771,906;door-closed=3,710,967;door-open=3,967,759;dot=3,918,808;download=3,820,906;download-cloud=3,869,857;drafting-compass=3,771,955;drama=3,967,808;dribbble=3,918,857;drill=3,869,906;droplet=3,820,955;droplets=3,967,857;drum=3,918,906;drumstick=3,869,955;dumbbell=3,967,906;ear=3,967,955;ear-off=3,918,955;earth=4,0,771;earth-lock=4,771,0;eclipse=4,771,257;egg=4,514,771;egg-fried=4,257,771;egg-off=4,771,514;ellipsis=4,771,49;ellipsis-vertical=4,820,0;equal=4,0,820;equal-not=4,49,771;eraser=4,820,257;euro=4,771,306;expand=4,306,771;external-link=4,257,820;eye=4,771,563;eye-off=4,820,514;facebook=4,563,771;factory=4,514,820;fan=4,869,0;fast-forward=4,820,49;feather=4,771,98;fence=4,98,771;ferris-wheel=4,49,820;figma=4,0,869;file=4,820,661;file-archive=4,869,257;file-audio=4,771,355;file-audio-2=4,820,306;file-axis-3d=4,355,771;file-badge=4,257,869;file-badge-2=4,306,820;file-bar-chart=4,820,563;file-bar-chart-2=4,869,514;file-box=4,771,612;file-check=4,563,820;file-check-2=4,612,771;file-clock=4,514,869;file-code=4,869,49;file-code-2=4,918,0;file-cog=4,820,98;file-diff=4,771,147;file-digit=4,147,771;file-down=4,98,820;file-edit=4,49,869;file-heart=4,0,918;file-image=4,918,257;file-input=4,869,306;file-json=4,771,404;file-json-2=4,820,355;file-key=4,355,820;file-key-2=4,404,771;file-line-chart=4,306,869;file-lock=4,918,514;file-lock-2=4,257,918;file-minus=4,820,612;file-minus-2=4,869,563;file-music=4,771,661;file-output=4,661,771;file-pen=4,563,869;file-pen-line=4,612,820;file-pie-chart=4,514,918;file-plus=4,918,49;file-plus-2=4,967,0;file-question=4,869,98;file-scan=4,820,147;file-search=4,196,771;file-search-2=4,771,196;file-signature=4,147,820;file-sliders=4,98,869;file-spreadsheet=4,49,918;file-stack=4,0,967;file-symlink=4,967,257;file-terminal=4,918,306;file-text=4,869,355;file-type=4,771,453;file-type-2=4,820,404;file-up=4,453,771;file-video=4,355,869;file-video-2=4,404,820;file-volume=4,257,967;file-volume-2=4,306,918;file-warning=4,967,514;file-x=4,869,612;file-x-2=4,918,563;files=4,771,710;film=4,710,771;filter=4,612,869;filter-x=4,661,820;fingerprint=4,563,918;fire-extinguisher=4,514,967;fish=4,869,147;fish-off=4,967,49;fish-symbol=4,918,98;flag=4,98,918;flag-off=4,820,196;flag-triangle-left=4,196,820;flag-triangle-right=4,147,869;flame=4,967,306;flame-kindling=4,49,967;flashlight=4,869,404;flashlight-off=4,918,355;flask-conical=4,453,820;flask-conical-off=4,820,453;flask-round=4,404,869;flip-horizontal=4,306,967;flip-horizontal-2=4,355,918;flip-vertical=4,918,612;flip-vertical-2=4,967,563;flower=4,820,710;flower-2=4,869,661;focus=4,771,759;fold-horizontal=4,710,820;fold-vertical=4,661,869;folder=4,404,967;folder-archive=4,612,918;folder-check=4,563,967;folder-clock=4,967,98;folder-closed=4,918,147;folder-cog=4,869,196;folder-dot=4,196,869;folder-down=4,147,918;folder-edit=4,98,967;folder-git=4,918,404;folder-git-2=4,967,355;folder-heart=4,869,453;folder-input=4,453,869;folder-kanban=4,404,918;folder-key=4,355,967;folder-lock=4,967,612;folder-minus=4,918,661;folder-open=4,820,759;folder-open-dot=4,869,710;folder-output=4,771,808;folder-pen=4,710,869;folder-plus=4,661,918;folder-root=4,612,967;folder-search=4,918,196;folder-search-2=4,967,147;folder-symlink=4,196,918;folder-sync=4,147,967;folder-tree=4,967,404;folder-up=4,918,453;folder-x=4,453,918;folders=4,967,661;footprints=4,918,710;forklift=4,869,759;form-input=4,820,808;forward=4,771,857;frame=4,710,918;framer=4,661,967;frown=4,967,196;fuel=4,196,967;fullscreen=4,967,453;function-square=4,453,967;gallery-horizontal=4,918,759;gallery-horizontal-end=4,967,710;gallery-thumbnails=4,869,808;gallery-vertical=4,771,906;gallery-vertical-end=4,820,857;gamepad=4,967,759;gamepad-2=4,710,967;gantt-chart=4,869,857;gantt-chart-square=4,918,808;gauge=4,771,955;gauge-circle=4,820,906;gavel=4,967,808;gem=4,918,857;ghost=4,869,906;gift=4,820,955;git-branch=4,918,906;git-branch-plus=4,967,857;git-commit-horizontal=4,869,955;git-commit-vertical=4,967,906;git-compare=4,967,955;git-compare-arrows=4,918,955;git-fork=5,771,0;git-graph=5,0,771;git-merge=5,771,257;git-pull-request=5,49,771;git-pull-request-arrow=5,257,771;git-pull-request-closed=5,771,514;git-pull-request-create=5,820,0;git-pull-request-create-arrow=5,514,771;git-pull-request-draft=5,771,49;github=5,0,820;gitlab=5,820,257;glass-water=5,771,306;glasses=5,306,771;globe=5,771,563;globe-2=5,257,820;globe-lock=5,820,514;goal=5,563,771;grab=5,514,820;graduation-cap=5,869,0;grape=5,820,49;grid-2x2=5,771,98;grid-3x3=5,98,771;grip=5,869,257;grip-horizontal=5,49,820;grip-vertical=5,0,869;group=5,820,306;guitar=5,771,355;ham=5,355,771;hammer=5,306,820;hand=5,563,820;hand-coins=5,257,869;hand-heart=5,869,514;hand-helping=5,820,563;hand-metal=5,771,612;hand-platter=5,612,771;handshake=5,514,869;hard-drive=5,820,98;hard-drive-download=5,918,0;hard-drive-upload=5,869,49;hard-hat=5,771,147;hash=5,147,771;haze=5,98,820;hdmi-port=5,49,869;heading=5,355,820;heading-1=5,0,918;heading-2=5,918,257;heading-3=5,869,306;heading-4=5,820,355;heading-5=5,771,404;heading-6=5,404,771;headphones=5,306,869;headset=5,257,918;heart=5,661,771;heart-crack=5,918,514;heart-handshake=5,869,563;heart-off=5,820,612;heart-pulse=5,771,661;heater=5,612,820;help-circle=5,563,869;helping-hand=5,514,918;hexagon=5,967,0;highlighter=5,918,49;history=5,869,98;home=5,820,147;hop=5,196,771;hop-off=5,771,196;hospital=5,147,820;hotel=5,98,869;hourglass=5,49,918;ice-cream=5,869,355;ice-cream-2=5,0,967;ice-cream-bowl=5,967,257;ice-cream-cone=5,918,306;image=5,306,918;image-down=5,820,404;image-minus=5,771,453;image-off=5,453,771;image-plus=5,404,820;image-up=5,355,869;images=5,257,967;import=5,967,514;inbox=5,918,563;indent=5,771,710;indent-decrease=5,869,612;indent-increase=5,820,661;indian-rupee=5,710,771;infinity=5,661,820;info=5,612,869;inspection-panel=5,563,918;instagram=5,514,967;italic=5,967,49;iteration-ccw=5,918,98;iteration-cw=5,869,147;japanese-yen=5,820,196;joystick=5,196,820;kanban=5,49,967;kanban-square=5,98,918;kanban-square-dashed=5,147,869;key=5,869,404;key-round=5,967,306;key-square=5,918,355;keyboard=5,453,820;keyboard-music=5,820,453;lamp=5,869,661;lamp-ceiling=5,404,869;lamp-desk=5,355,918;lamp-floor=5,306,967;lamp-wall-down=5,967,563;lamp-wall-up=5,918,612;land-plot=5,820,710;landmark=5,771,759;languages=5,710,820;laptop=5,563,967;laptop-2=5,661,869;laptop-minimal=5,612,918;lasso=5,918,147;lasso-select=5,967,98;laugh=5,869,196;layers=5,98,967;layers-2=5,196,869;layers-3=5,147,918;layout=5,967,612;layout-dashboard=5,967,355;layout-grid=5,918,404;layout-list=5,869,453;layout-panel-left=5,453,869;layout-panel-top=5,404,918;layout-template=5,355,967;leaf=5,918,661;leafy-green=5,869,710;library=5,710,869;library-big=5,820,759;library-square=5,771,808;life-buoy=5,661,918;ligature=5,612,967;lightbulb=5,918,196;lightbulb-off=5,967,147;line-chart=5,196,918;link=5,918,453;link-2=5,967,404;link-2-off=5,147,967;linkedin=5,453,918;list=5,869,808;list-checks=5,404,967;list-collapse=5,967,661;list-end=5,918,710;list-filter=5,869,759;list-minus=5,820,808;list-music=5,771,857;list-ordered=5,710,918;list-plus=5,661,967;list-restart=5,967,196;list-start=5,196,967;list-todo=5,967,453;list-tree=5,453,967;list-video=5,967,710;list-x=5,918,759;loader=5,710,967;loader-2=5,820,857;loader-circle=5,771,906;locate=5,869,857;locate-fixed=5,967,759;locate-off=5,918,808;lock=5,918,857;lock-keyhole=5,771,955;lock-keyhole-open=5,820,906;lock-open=5,967,808;log-in=5,869,906;log-out=5,820,955;lollipop=5,967,857;luggage=5,918,906;m-square=5,869,955;magnet=5,967,906;mail=6,820,0;mail-check=5,918,955;mail-minus=5,967,955;mail-open=6,771,0;mail-plus=6,0,771;mail-question=6,771,257;mail-search=6,257,771;mail-warning=6,771,514;mail-x=6,514,771;mailbox=6,771,49;mails=6,49,771;map=6,306,771;map-pin=6,820,257;map-pin-off=6,0,820;map-pinned=6,771,306;martini=6,257,820;maximize=6,771,563;maximize-2=6,820,514;medal=6,563,771;megaphone=6,869,0;megaphone-off=6,514,820;meh=6,820,49;memory-stick=6,771,98;menu=6,49,820;menu-square=6,98,771;merge=6,0,869;message-circle=6,563,820;message-circle-code=6,869,257;message-circle-dashed=6,820,306;message-circle-heart=6,771,355;message-circle-more=6,355,771;message-circle-off=6,306,820;message-circle-plus=6,257,869;message-circle-question=6,869,514;message-circle-reply=6,820,563;message-circle-warning=6,771,612;message-circle-x=6,612,771;message-square=6,355,820;message-square-code=6,514,869;message-square-dashed=6,918,0;message-square-diff=6,869,49;message-square-dot=6,820,98;message-square-heart=6,771,147;message-square-more=6,147,771;message-square-off=6,98,820;message-square-plus=6,49,869;message-square-quote=6,0,918;message-square-reply=6,918,257;message-square-share=6,869,306;message-square-text=6,820,355;message-square-warning=6,771,404;message-square-x=6,404,771;messages-square=6,306,869;mic=6,820,612;mic-2=6,257,918;mic-off=6,918,514;mic-vocal=6,869,563;microscope=6,771,661;microwave=6,661,771;milestone=6,612,820;milk=6,514,918;milk-off=6,563,869;minimize=6,918,49;minimize-2=6,967,0;minus=6,771,196;minus-circle=6,869,98;minus-square=6,820,147;monitor=6,404,820;monitor-check=6,196,771;monitor-dot=6,147,820;monitor-down=6,98,869;monitor-off=6,49,918;monitor-pause=6,0,967;monitor-play=6,967,257;monitor-smartphone=6,918,306;monitor-speaker=6,869,355;monitor-stop=6,820,404;monitor-up=6,771,453;monitor-x=6,453,771;moon=6,306,918;moon-star=6,355,869;more-horizontal=6,257,967;more-vertical=6,967,514;mountain=6,869,612;mountain-snow=6,918,563;mouse=6,563,918;mouse-pointer=6,612,869;mouse-pointer-2=6,820,661;mouse-pointer-click=6,771,710;mouse-pointer-square=6,661,820;mouse-pointer-square-dashed=6,710,771;move=6,453,820;move-3d=6,514,967;move-diagonal=6,918,98;move-diagonal-2=6,967,49;move-down=6,196,820;move-down-left=6,869,147;move-down-right=6,820,196;move-horizontal=6,147,869;move-left=6,98,918;move-right=6,49,967;move-up=6,869,404;move-up-left=6,967,306;move-up-right=6,918,355;move-vertical=6,820,453;music=6,967,563;music-2=6,404,869;music-3=6,355,918;music-4=6,306,967;navigation=6,771,759;navigation-2=6,869,661;navigation-2-off=6,918,612;navigation-off=6,820,710;network=6,710,820;newspaper=6,661,869;nfc=6,612,918;notebook=6,869,196;notebook-pen=6,563,967;notebook-tabs=6,967,98;notebook-text=6,918,147;notepad-text=6,147,918;notepad-text-dashed=6,196,869;nut=6,967,355;nut-off=6,98,967;octagon=6,404,918;octagon-alert=6,918,404;octagon-pause=6,869,453;octagon-x=6,453,869;option=6,355,967;orbit=6,967,612;outdent=6,918,661;package=6,918,196;package-2=6,869,710;package-check=6,820,759;package-minus=6,771,808;package-open=6,710,869;package-plus=6,661,918;package-search=6,612,967;package-x=6,967,147;paint-bucket=6,196,918;paint-roller=6,147,967;paintbrush=6,918,453;paintbrush-2=6,967,404;palette=6,453,918;palmtree=6,404,967;panel-bottom=6,771,857;panel-bottom-close=6,967,661;panel-bottom-dashed=6,918,710;panel-bottom-inactive=6,869,759;panel-bottom-open=6,820,808;panel-left=6,967,453;panel-left-close=6,710,918;panel-left-dashed=6,661,967;panel-left-inactive=6,967,196;panel-left-open=6,196,967;panel-right=6,820,857;panel-right-close=6,453,967;panel-right-dashed=6,967,710;panel-right-inactive=6,918,759;panel-right-open=6,869,808;panel-top=6,869,857;panel-top-close=6,771,906;panel-top-dashed=6,710,967;panel-top-inactive=6,967,759;panel-top-open=6,918,808;panels-left-bottom=6,820,906;panels-right-bottom=6,771,955;panels-top-left=6,967,808;paperclip=6,918,857;parentheses=6,869,906;parking-circle=6,967,857;parking-circle-off=6,820,955;parking-meter=6,918,906;parking-square=6,967,906;parking-square-off=6,869,955;party-popper=6,918,955;pause=7,0,771;pause-circle=6,967,955;pause-octagon=7,771,0;paw-print=7,771,257;pc-case=7,257,771;pen=7,771,49;pen-line=7,771,514;pen-square=7,514,771;pen-tool=7,820,0;pencil=7,820,257;pencil-line=7,49,771;pencil-ruler=7,0,820;pentagon=7,771,306;percent=7,771,563;percent-circle=7,306,771;percent-diamond=7,257,820;percent-square=7,820,514;person-standing=7,563,771;phone=7,0,869;phone-call=7,514,820;phone-forwarded=7,869,0;phone-incoming=7,820,49;phone-missed=7,771,98;phone-off=7,98,771;phone-outgoing=7,49,820;pi=7,820,306;pi-square=7,869,257;piano=7,771,355;pickaxe=7,355,771;picture-in-picture=7,257,869;picture-in-picture-2=7,306,820;pie-chart=7,869,514;piggy-bank=7,820,563;pilcrow=7,612,771;pilcrow-square=7,771,612;pill=7,563,820;pin=7,918,0;pin-off=7,514,869;pipette=7,869,49;pizza=7,820,98;plane=7,98,820;plane-landing=7,771,147;plane-takeoff=7,147,771;play=7,918,257;play-circle=7,49,869;play-square=7,0,918;plug=7,404,771;plug-2=7,869,306;plug-zap=7,771,404;plug-zap-2=7,820,355;plus=7,257,918;plus-circle=7,355,820;plus-square=7,306,869;pocket=7,869,563;pocket-knife=7,918,514;podcast=7,820,612;pointer=7,661,771;pointer-off=7,771,661;popcorn=7,612,820;popsicle=7,563,869;pound-sterling=7,514,918;power=7,820,147;power-circle=7,967,0;power-off=7,918,49;power-square=7,869,98;presentation=7,771,196;printer=7,196,771;projector=7,147,820;proportions=7,98,869;puzzle=7,49,918;pyramid=7,0,967;qr-code=7,967,257;quote=7,918,306;rabbit=7,869,355;radar=7,820,404;radiation=7,771,453;radical=7,453,771;radio=7,306,918;radio-receiver=7,404,820;radio-tower=7,355,869;radius=7,257,967;rail-symbol=7,967,514;rainbow=7,918,563;rat=7,869,612;ratio=7,820,661;receipt=7,869,147;receipt-cent=7,771,710;receipt-euro=7,710,771;receipt-indian-rupee=7,661,820;receipt-japanese-yen=7,612,869;receipt-pound-sterling=7,563,918;receipt-russian-ruble=7,514,967;receipt-swiss-franc=7,967,49;receipt-text=7,918,98;rectangle-ellipsis=7,820,196;rectangle-horizontal=7,196,820;rectangle-vertical=7,147,869;recycle=7,98,918;redo=7,918,355;redo-2=7,49,967;redo-dot=7,967,306;refresh-ccw=7,820,453;refresh-ccw-dot=7,869,404;refresh-cw=7,404,869;refresh-cw-off=7,453,820;refrigerator=7,355,918;regex=7,306,967;remove-formatting=7,967,563;repeat=7,820,710;repeat-1=7,918,612;repeat-2=7,869,661;replace=7,710,820;replace-all=7,771,759;reply=7,612,918;reply-all=7,661,869;rewind=7,563,967;ribbon=7,967,98;rocket=7,918,147;rocking-chair=7,869,196;roller-coaster=7,196,869;rotate-3d=7,147,918;rotate-ccw=7,967,355;rotate-ccw-square=7,98,967;rotate-cw=7,869,453;rotate-cw-square=7,918,404;route=7,404,918;route-off=7,453,869;router=7,355,967;rows=7,820,759;rows-2=7,967,612;rows-3=7,918,661;rows-4=7,869,710;rss=7,771,808;ruler=7,710,869;russian-ruble=7,661,918;sailboat=7,612,967;salad=7,967,147;sandwich=7,918,196;satellite=7,147,967;satellite-dish=7,196,918;save=7,918,453;save-all=7,967,404;scale=7,404,967;scale-3d=7,453,918;scaling=7,967,661;scan=7,967,196;scan-barcode=7,918,710;scan-eye=7,869,759;scan-face=7,820,808;scan-line=7,771,857;scan-search=7,710,918;scan-text=7,661,967;scatter-chart=7,196,967;school=7,453,967;school-2=7,967,453;scissors=7,820,857;scissors-line-dashed=7,967,710;scissors-square=7,869,808;scissors-square-dashed-bottom=7,918,759;screen-share=7,710,967;screen-share-off=7,771,906;scroll=7,918,808;scroll-text=7,967,759;search=7,918,857;search-check=7,869,857;search-code=7,820,906;search-slash=7,771,955;search-x=7,967,808;send=7,967,857;send-horizontal=7,869,906;send-to-back=7,820,955;separator-horizontal=7,918,906;separator-vertical=7,869,955;server=8,771,0;server-cog=7,967,906;server-crash=7,918,955;server-off=7,967,955;settings=8,771,257;settings-2=8,0,771;shapes=8,257,771;share=8,514,771;share-2=8,771,514;sheet=8,820,0;shell=8,771,49;shield=8,869,0;shield-alert=8,49,771;shield-ban=8,0,820;shield-check=8,820,257;shield-ellipsis=8,771,306;shield-half=8,306,771;shield-minus=8,257,820;shield-off=8,820,514;shield-plus=8,771,563;shield-question=8,563,771;shield-x=8,514,820;ship=8,771,98;ship-wheel=8,820,49;shirt=8,98,771;shopping-bag=8,49,820;shopping-basket=8,0,869;shopping-cart=8,869,257;shovel=8,820,306;shower-head=8,771,355;shrink=8,355,771;shrub=8,306,820;shuffle=8,257,869;sigma=8,820,563;sigma-square=8,869,514;signal=8,918,0;signal-high=8,771,612;signal-low=8,612,771;signal-medium=8,563,820;signal-zero=8,514,869;signpost=8,820,98;signpost-big=8,869,49;siren=8,771,147;skip-back=8,147,771;skip-forward=8,98,820;skull=8,49,869;slack=8,0,918;slash=8,918,257;slice=8,869,306;sliders=8,404,771;sliders-horizontal=8,820,355;sliders-vertical=8,771,404;smartphone=8,257,918;smartphone-charging=8,355,820;smartphone-nfc=8,306,869;smile=8,869,563;smile-plus=8,918,514;snail=8,820,612;snowflake=8,771,661;sofa=8,661,771;soup=8,612,820;space=8,563,869;spade=8,514,918;sparkle=8,967,0;sparkles=8,918,49;speaker=8,869,98;speech=8,820,147;spell-check=8,196,771;spell-check-2=8,771,196;spline=8,147,820;split=8,0,967;split-square-horizontal=8,98,869;split-square-vertical=8,49,918;spray-can=8,967,257;sprout=8,918,306;square=8,869,710;square-activity=8,869,355;square-arrow-down=8,453,771;square-arrow-down-left=8,820,404;square-arrow-down-right=8,771,453;square-arrow-left=8,404,820;square-arrow-out-down-left=8,355,869;square-arrow-out-down-right=8,306,918;square-arrow-out-up-left=8,257,967;square-arrow-out-up-right=8,967,514;square-arrow-right=8,918,563;square-arrow-up=8,771,710;square-arrow-up-left=8,869,612;square-arrow-up-right=8,820,661;square-asterisk=8,710,771;square-bottom-dashed-scissors=8,661,820;square-check=8,563,918;square-check-big=8,612,869;square-chevron-down=8,514,967;square-chevron-left=8,967,49;square-chevron-right=8,918,98;square-chevron-up=8,869,147;square-code=8,820,196;square-dashed-bottom=8,147,869;square-dashed-bottom-code=8,196,820;square-dashed-kanban=8,98,918;square-dashed-mouse-pointer=8,49,967;square-divide=8,967,306;square-dot=8,918,355;square-equal=8,869,404;square-function=8,820,453;square-gantt-chart=8,453,820;square-kanban=8,404,869;square-library=8,355,918;square-m=8,306,967;square-menu=8,967,563;square-minus=8,918,612;square-mouse-pointer=8,869,661;square-parking=8,771,759;square-parking-off=8,820,710;square-pen=8,710,820;square-percent=8,661,869;square-pi=8,612,918;square-pilcrow=8,563,967;square-play=8,967,98;square-plus=8,918,147;square-power=8,869,196;square-radical=8,196,869;square-scissors=8,147,918;square-sigma=8,98,967;square-slash=8,967,355;square-split-horizontal=8,918,404;square-split-vertical=8,869,453;square-stack=8,453,869;square-terminal=8,404,918;square-user=8,967,612;square-user-round=8,355,967;square-x=8,918,661;squircle=8,820,759;squirrel=8,771,808;stamp=8,710,869;star=8,967,147;star-half=8,661,918;star-off=8,612,967;step-back=8,918,196;step-forward=8,196,918;stethoscope=8,147,967;sticker=8,967,404;sticky-note=8,918,453;stop-circle=8,453,918;store=8,404,967;stretch-horizontal=8,967,661;stretch-vertical=8,918,710;strikethrough=8,869,759;subscript=8,820,808;subtitles=8,771,857;sun=8,967,453;sun-dim=8,710,918;sun-medium=8,661,967;sun-moon=8,967,196;sun-snow=8,196,967;sunrise=8,453,967;sunset=8,967,710;superscript=8,918,759;swatch-book=8,869,808;swiss-franc=8,820,857;switch-camera=8,771,906;sword=8,710,967;swords=8,967,759;syringe=8,918,808;table=8,820,955;table-2=8,869,857;table-cells-merge=8,820,906;table-cells-split=8,771,955;table-columns-split=8,967,808;table-properties=8,918,857;table-rows-split=8,869,906;tablet=8,918,906;tablet-smartphone=8,967,857;tablets=8,869,955;tag=8,967,906;tags=8,918,955;tally-1=8,967,955;tally-2=9,771,0;tally-3=9,0,771;tally-4=9,771,257;tally-5=9,257,771;tangent=9,771,514;target=9,514,771;telescope=9,820,0;tent=9,49,771;tent-tree=9,771,49;terminal=9,820,257;terminal-square=9,0,820;test-tube=9,257,820;test-tube-2=9,771,306;test-tube-diagonal=9,306,771;test-tubes=9,820,514;text=9,771,98;text-cursor=9,563,771;text-cursor-input=9,771,563;text-quote=9,514,820;text-search=9,869,0;text-select=9,820,49;theater=9,98,771;thermometer=9,869,257;thermometer-snowflake=9,49,820;thermometer-sun=9,0,869;thumbs-down=9,820,306;thumbs-up=9,771,355;ticket=9,612,771;ticket-check=9,355,771;ticket-minus=9,306,820;ticket-percent=9,257,869;ticket-plus=9,869,514;ticket-slash=9,820,563;ticket-x=9,771,612;timer=9,918,0;timer-off=9,563,820;timer-reset=9,514,869;toggle-left=9,869,49;toggle-right=9,820,98;tornado=9,771,147;torus=9,147,771;touchpad=9,49,869;touchpad-off=9,98,820;tower-control=9,0,918;toy-brick=9,918,257;tractor=9,869,306;traffic-cone=9,820,355;train-front=9,404,771;train-front-tunnel=9,771,404;train-track=9,355,820;tram-front=9,306,869;trash=9,918,514;trash-2=9,257,918;tree-deciduous=9,869,563;tree-palm=9,820,612;tree-pine=9,771,661;trees=9,661,771;trello=9,612,820;trending-down=9,563,869;trending-up=9,514,918;triangle=9,869,98;triangle-alert=9,967,0;triangle-right=9,918,49;trophy=9,820,147;truck=9,771,196;turtle=9,196,771;tv=9,98,869;tv-2=9,147,820;twitch=9,49,918;twitter=9,0,967;type=9,967,257;umbrella=9,869,355;umbrella-off=9,918,306;underline=9,820,404;undo=9,404,820;undo-2=9,771,453;undo-dot=9,453,771;unfold-horizontal=9,355,869;unfold-vertical=9,306,918;ungroup=9,257,967;university=9,967,514;unlink=9,869,612;unlink-2=9,918,563;unlock=9,771,710;unlock-keyhole=9,820,661;unplug=9,710,771;upload=9,612,869;upload-cloud=9,661,820;usb=9,563,918;user=9,661,869;user-2=9,514,967;user-check=9,918,98;user-check-2=9,967,49;user-circle=9,820,196;user-circle-2=9,869,147;user-cog=9,147,869;user-cog-2=9,196,820;user-minus=9,49,967;user-minus-2=9,98,918;user-plus=9,918,355;user-plus-2=9,967,306;user-round=9,967,563;user-round-check=9,869,404;user-round-cog=9,820,453;user-round-minus=9,453,820;user-round-plus=9,404,869;user-round-search=9,355,918;user-round-x=9,306,967;user-search=9,918,612;user-square=9,820,710;user-square-2=9,869,661;user-x=9,710,820;user-x-2=9,771,759;users=9,967,98;users-2=9,612,918;users-round=9,563,967;utensils=9,869,196;utensils-crossed=9,918,147;utility-pole=9,196,869;variable=9,147,918;vault=9,98,967;vegan=9,967,355;venetian-mask=9,918,404;vibrate=9,453,869;vibrate-off=9,869,453;video=9,355,967;video-off=9,404,918;videotape=9,967,612;view=9,918,661;voicemail=9,869,710;volume=9,661,918;volume-1=9,820,759;volume-2=9,771,808;volume-x=9,710,869;vote=9,612,967;wallet=9,147,967;wallet-2=9,967,147;wallet-cards=9,918,196;wallet-minimal=9,196,918;wallpaper=9,967,404;wand=9,404,967;wand-2=9,918,453;wand-sparkles=9,453,918;warehouse=9,967,661;washing-machine=9,918,710;watch=9,869,759;waves=9,820,808;waypoints=9,771,857;webcam=9,710,918;webhook=9,967,196;webhook-off=9,661,967;weight=9,196,967;wheat=9,453,967;wheat-off=9,967,453;whole-word=9,967,710;wifi=9,869,808;wifi-off=9,918,759;wind=9,820,857;wine=9,710,967;wine-off=9,771,906;workflow=9,967,759;worm=9,918,808;wrap-text=9,869,857;wrench=9,820,906;x=9,869,906;x-circle=9,771,955;x-octagon=9,967,808;x-square=9,918,857;youtube=9,820,955;zap=9,918,906;zap-off=9,967,857;zoom-in=9,869,955;zoom-out=9,967,906;]==],
	},
	[256] = {
		sheets = {16898612629,16898612819,16898613044,16898613353,16898613509,16898613613,16898613699,16898613777,16898613869,16898614020,16898614166,16898614275,16898614410,16898614574,16898614755,16898614945,16898615022,16898615143,16898615240,16898615374,16898615428,16898615570,16898615799,16898616080,16898616322,16898616524,16898616650,16898616757,16898616879,16898616953,16898617053,16898617146,16898617249,16898617325,16898617411,16898617509,16898617626,16898617705,16898617803,16898617884,16898617944,16898618049,16898618228,16898618392,16898618583,16898618763,16898618899,16898619015,16898619182,16898619347,16898619423,16898668288,16898668482,16898668755,16898669042,16898669271,16898669433,16898669562,16898669689,16898669772,16898669897,16898669984,16898670072,16898670171,16898670241,16898670367,16898670469,16898670620,16898670775,16898670919,16898671019,16898671139,16898671263,16898671463,16898671684,16898672004,16898672166,16898672316,16898672450,16898672599,16898672700,16898672829,16898672954,16898673115,16898673271,16898673358,16898673447,16898673523,16898673616,16898673794,16898673999,16898674182,16898674337,16898674482,16898674572,16898674684,16898674825,16898675156,16898675359,16898675673,16898675752,16898675863,16898728402,16898728659,16898728878,16898729141,16898729337,16898729572,16898729752,16898730065,16898730298,16898730417,16898730641,16898730821,16898731024,16898731166,16898731301,16898731419,16898731539,16898731683,16898731819,16898731919,16898732061,16898732262,16898732504,16898732665,16898732855,16898733036,16898733146,16898733317,16898733415,16898733534,16898733674,16898733817,16898734065,16898734242,16898734421,16898734564,16898734664,16898734792,16898734905,16898735040,16898735175,16898735455,16898735593,16898735664,16898735845,16898736072,16898736237,16898736398,16898736597,16898736776,16898736967,16898787671,16898787819,16898788033,16898788248,16898788479,16898788660,16898788789,16898788908,16898789012,16898789153,16898789303,16898789451,16898789644,16898789825,16898790047,16898790259,16898790439,16898790615,16898790791,16898790996,16898791187,16898791349},
		raw = [==[a-arrow-down=1,0,0;a-arrow-up=1,257,0;a-large-small=1,0,257;accessibility=1,514,0;activity=1,0,514;activity-square=1,257,257;air-vent=1,514,257;airplay=1,257,514;alarm-check=1,514,514;alarm-clock=2,257,257;alarm-clock-check=2,0,0;alarm-clock-minus=2,257,0;alarm-clock-off=2,0,257;alarm-clock-plus=2,514,0;alarm-minus=2,0,514;alarm-plus=2,514,257;alarm-smoke=2,257,514;album=2,514,514;alert-circle=3,0,0;alert-octagon=3,257,0;alert-triangle=3,0,257;align-center=3,0,514;align-center-horizontal=3,514,0;align-center-vertical=3,257,257;align-end-horizontal=3,514,257;align-end-vertical=3,257,514;align-horizontal-distribute-center=3,514,514;align-horizontal-distribute-end=4,0,0;align-horizontal-distribute-start=4,257,0;align-horizontal-justify-center=4,0,257;align-horizontal-justify-end=4,514,0;align-horizontal-justify-start=4,257,257;align-horizontal-space-around=4,0,514;align-horizontal-space-between=4,514,257;align-justify=4,257,514;align-left=4,514,514;align-right=5,0,0;align-start-horizontal=5,257,0;align-start-vertical=5,0,257;align-vertical-distribute-center=5,514,0;align-vertical-distribute-end=5,257,257;align-vertical-distribute-start=5,0,514;align-vertical-justify-center=5,514,257;align-vertical-justify-end=5,257,514;align-vertical-justify-start=5,514,514;align-vertical-space-around=6,0,0;align-vertical-space-between=6,257,0;ambulance=6,0,257;ampersand=6,514,0;ampersands=6,257,257;anchor=6,0,514;angry=6,514,257;annoyed=6,257,514;antenna=6,514,514;anvil=7,0,0;aperture=7,257,0;app-window=7,514,0;app-window-mac=7,0,257;apple=7,257,257;archive=7,257,514;archive-restore=7,0,514;archive-x=7,514,257;area-chart=7,514,514;armchair=8,0,0;arrow-big-down=8,0,257;arrow-big-down-dash=8,257,0;arrow-big-left=8,257,257;arrow-big-left-dash=8,514,0;arrow-big-right=8,514,257;arrow-big-right-dash=8,0,514;arrow-big-up=8,514,514;arrow-big-up-dash=8,257,514;arrow-down=11,0,0;arrow-down-0-1=9,0,0;arrow-down-1-0=9,257,0;arrow-down-a-z=9,0,257;arrow-down-circle=9,514,0;arrow-down-from-line=9,257,257;arrow-down-left=9,257,514;arrow-down-left-from-circle=9,0,514;arrow-down-left-square=9,514,257;arrow-down-narrow-wide=9,514,514;arrow-down-right=10,0,257;arrow-down-right-from-circle=10,0,0;arrow-down-right-square=10,257,0;arrow-down-square=10,514,0;arrow-down-to-dot=10,257,257;arrow-down-to-line=10,0,514;arrow-down-up=10,514,257;arrow-down-wide-narrow=10,257,514;arrow-down-z-a=10,514,514;arrow-left=11,514,257;arrow-left-circle=11,257,0;arrow-left-from-line=11,0,257;arrow-left-right=11,514,0;arrow-left-square=11,257,257;arrow-left-to-line=11,0,514;arrow-right=12,514,0;arrow-right-circle=11,257,514;arrow-right-from-line=11,514,514;arrow-right-left=12,0,0;arrow-right-square=12,257,0;arrow-right-to-line=12,0,257;arrow-up=14,257,257;arrow-up-0-1=12,257,257;arrow-up-1-0=12,0,514;arrow-up-a-z=12,514,257;arrow-up-circle=12,257,514;arrow-up-down=12,514,514;arrow-up-from-dot=13,0,0;arrow-up-from-line=13,257,0;arrow-up-left=13,257,257;arrow-up-left-from-circle=13,0,257;arrow-up-left-square=13,514,0;arrow-up-narrow-wide=13,0,514;arrow-up-right=13,514,514;arrow-up-right-from-circle=13,514,257;arrow-up-right-square=13,257,514;arrow-up-square=14,0,0;arrow-up-to-line=14,257,0;arrow-up-wide-narrow=14,0,257;arrow-up-z-a=14,514,0;arrows-up-from-line=14,0,514;asterisk=14,514,257;at-sign=14,257,514;atom=14,514,514;audio-lines=15,0,0;audio-waveform=15,257,0;award=15,0,257;axe=15,514,0;axis-3d=15,257,257;baby=15,0,514;backpack=15,514,257;badge=17,0,514;badge-alert=15,257,514;badge-cent=15,514,514;badge-check=16,0,0;badge-dollar-sign=16,257,0;badge-euro=16,0,257;badge-help=16,514,0;badge-indian-rupee=16,257,257;badge-info=16,0,514;badge-japanese-yen=16,514,257;badge-minus=16,257,514;badge-percent=16,514,514;badge-plus=17,0,0;badge-pound-sterling=17,257,0;badge-russian-ruble=17,0,257;badge-swiss-franc=17,514,0;badge-x=17,257,257;baggage-claim=17,514,257;ban=17,257,514;banana=17,514,514;banknote=18,0,0;bar-chart=18,257,514;bar-chart-2=18,257,0;bar-chart-3=18,0,257;bar-chart-4=18,514,0;bar-chart-big=18,257,257;bar-chart-horizontal=18,514,257;bar-chart-horizontal-big=18,0,514;barcode=18,514,514;baseline=19,0,0;bath=19,257,0;battery=19,257,514;battery-charging=19,0,257;battery-full=19,514,0;battery-low=19,257,257;battery-medium=19,0,514;battery-warning=19,514,257;beaker=19,514,514;bean=20,257,0;bean-off=20,0,0;bed=20,257,257;bed-double=20,0,257;bed-single=20,514,0;beef=20,0,514;beer=20,257,514;beer-off=20,514,257;bell=21,0,514;bell-dot=20,514,514;bell-electric=21,0,0;bell-minus=21,257,0;bell-off=21,0,257;bell-plus=21,514,0;bell-ring=21,257,257;between-horizontal-end=21,514,257;between-horizontal-start=21,257,514;between-vertical-end=21,514,514;between-vertical-start=22,0,0;bike=22,257,0;binary=22,0,257;biohazard=22,514,0;bird=22,257,257;bitcoin=22,0,514;blend=22,514,257;blinds=22,257,514;blocks=22,514,514;bluetooth=23,514,0;bluetooth-connected=23,0,0;bluetooth-off=23,257,0;bluetooth-searching=23,0,257;bold=23,257,257;bolt=23,0,514;bomb=23,514,257;bone=23,257,514;book=26,257,257;book-a=23,514,514;book-audio=24,0,0;book-check=24,257,0;book-copy=24,0,257;book-dashed=24,514,0;book-down=24,257,257;book-headphones=24,0,514;book-heart=24,514,257;book-image=24,257,514;book-key=24,514,514;book-lock=25,0,0;book-marked=25,257,0;book-minus=25,0,257;book-open=25,0,514;book-open-check=25,514,0;book-open-text=25,257,257;book-plus=25,514,257;book-text=25,257,514;book-type=25,514,514;book-up=26,257,0;book-up-2=26,0,0;book-user=26,0,257;book-x=26,514,0;bookmark=27,0,0;bookmark-check=26,0,514;bookmark-minus=26,514,257;bookmark-plus=26,257,514;bookmark-x=26,514,514;boom-box=27,257,0;bot=27,514,0;bot-message-square=27,0,257;box=27,0,514;box-select=27,257,257;boxes=27,514,257;braces=27,257,514;brackets=27,514,514;brain=28,0,257;brain-circuit=28,0,0;brain-cog=28,257,0;brick-wall=28,514,0;briefcase=28,514,257;briefcase-business=28,257,257;briefcase-medical=28,0,514;bring-to-front=28,257,514;brush=28,514,514;bug=29,0,257;bug-off=29,0,0;bug-play=29,257,0;building=29,257,257;building-2=29,514,0;bus=29,514,257;bus-front=29,0,514;cable=29,514,514;cable-car=29,257,514;cake=30,257,0;cake-slice=30,0,0;calculator=30,0,257;calendar=32,0,0;calendar-check=30,257,257;calendar-check-2=30,514,0;calendar-clock=30,0,514;calendar-days=30,514,257;calendar-fold=30,257,514;calendar-heart=30,514,514;calendar-minus=31,257,0;calendar-minus-2=31,0,0;calendar-off=31,0,257;calendar-plus=31,257,257;calendar-plus-2=31,514,0;calendar-range=31,0,514;calendar-search=31,514,257;calendar-x=31,514,514;calendar-x-2=31,257,514;camera=32,0,257;camera-off=32,257,0;candlestick-chart=32,514,0;candy=32,514,257;candy-cane=32,257,257;candy-off=32,0,514;cannabis=32,257,514;captions=33,0,0;captions-off=32,514,514;car=33,514,0;car-front=33,257,0;car-taxi-front=33,0,257;caravan=33,257,257;carrot=33,0,514;case-lower=33,514,257;case-sensitive=33,257,514;case-upper=33,514,514;cassette-tape=34,0,0;cast=34,257,0;castle=34,0,257;cat=34,514,0;cctv=34,257,257;check=35,257,0;check-check=34,0,514;check-circle=34,257,514;check-circle-2=34,514,257;check-square=35,0,0;check-square-2=34,514,514;chef-hat=35,0,257;cherry=35,514,0;chevron-down=35,514,257;chevron-down-circle=35,257,257;chevron-down-square=35,0,514;chevron-first=35,257,514;chevron-last=35,514,514;chevron-left=36,0,257;chevron-left-circle=36,0,0;chevron-left-square=36,257,0;chevron-right=36,0,514;chevron-right-circle=36,514,0;chevron-right-square=36,257,257;chevron-up=36,514,514;chevron-up-circle=36,514,257;chevron-up-square=36,257,514;chevrons-down=37,257,0;chevrons-down-up=37,0,0;chevrons-left=37,514,0;chevrons-left-right=37,0,257;chevrons-right=37,0,514;chevrons-right-left=37,257,257;chevrons-up=37,257,514;chevrons-up-down=37,514,257;chrome=37,514,514;church=38,0,0;cigarette=38,0,257;cigarette-off=38,257,0;circle=42,257,514;circle-alert=38,514,0;circle-arrow-down=38,257,257;circle-arrow-left=38,0,514;circle-arrow-out-down-left=38,514,257;circle-arrow-out-down-right=38,257,514;circle-arrow-out-up-left=38,514,514;circle-arrow-out-up-right=39,0,0;circle-arrow-right=39,257,0;circle-arrow-up=39,0,257;circle-check=39,257,257;circle-check-big=39,514,0;circle-chevron-down=39,0,514;circle-chevron-left=39,514,257;circle-chevron-right=39,257,514;circle-chevron-up=39,514,514;circle-dashed=40,0,0;circle-divide=40,257,0;circle-dollar-sign=40,0,257;circle-dot=40,257,257;circle-dot-dashed=40,514,0;circle-ellipsis=40,0,514;circle-equal=40,514,257;circle-fading-plus=40,257,514;circle-gauge=40,514,514;circle-help=41,0,0;circle-minus=41,257,0;circle-off=41,0,257;circle-parking=41,257,257;circle-parking-off=41,514,0;circle-pause=41,0,514;circle-percent=41,514,257;circle-play=41,257,514;circle-plus=41,514,514;circle-power=42,0,0;circle-slash=42,0,257;circle-slash-2=42,257,0;circle-stop=42,514,0;circle-user=42,0,514;circle-user-round=42,257,257;circle-x=42,514,257;circuit-board=42,514,514;citrus=43,0,0;clapperboard=43,257,0;clipboard=44,0,514;clipboard-check=43,0,257;clipboard-copy=43,514,0;clipboard-edit=43,257,257;clipboard-list=43,0,514;clipboard-minus=43,514,257;clipboard-paste=43,257,514;clipboard-pen=44,0,0;clipboard-pen-line=43,514,514;clipboard-plus=44,257,0;clipboard-signature=44,0,257;clipboard-type=44,514,0;clipboard-x=44,257,257;clock=46,0,0;clock-1=44,514,257;clock-10=44,257,514;clock-11=44,514,514;clock-12=45,0,0;clock-2=45,257,0;clock-3=45,0,257;clock-4=45,514,0;clock-5=45,257,257;clock-6=45,0,514;clock-7=45,514,257;clock-8=45,257,514;clock-9=45,514,514;cloud=47,257,514;cloud-cog=46,257,0;cloud-download=46,0,257;cloud-drizzle=46,514,0;cloud-fog=46,257,257;cloud-hail=46,0,514;cloud-lightning=46,514,257;cloud-moon=46,514,514;cloud-moon-rain=46,257,514;cloud-off=47,0,0;cloud-rain=47,0,257;cloud-rain-wind=47,257,0;cloud-snow=47,514,0;cloud-sun=47,0,514;cloud-sun-rain=47,257,257;cloud-upload=47,514,257;cloudy=47,514,514;clover=48,0,0;club=48,257,0;code=48,257,257;code-2=48,0,257;code-xml=48,514,0;codepen=48,0,514;codesandbox=48,514,257;coffee=48,257,514;cog=48,514,514;coins=49,0,0;columns=49,257,257;columns-2=49,257,0;columns-3=49,0,257;columns-4=49,514,0;combine=49,0,514;command=49,514,257;compass=49,257,514;component=49,514,514;computer=50,0,0;concierge-bell=50,257,0;cone=50,0,257;construction=50,514,0;contact=50,514,257;contact-2=50,257,257;contact-round=50,0,514;container=50,257,514;contrast=50,514,514;cookie=51,0,0;cooking-pot=51,257,0;copy=51,257,514;copy-check=51,0,257;copy-minus=51,514,0;copy-plus=51,257,257;copy-slash=51,0,514;copy-x=51,514,257;copyleft=51,514,514;copyright=52,0,0;corner-down-left=52,257,0;corner-down-right=52,0,257;corner-left-down=52,514,0;corner-left-up=52,257,257;corner-right-down=52,0,514;corner-right-up=52,514,257;corner-up-left=52,257,514;corner-up-right=52,514,514;cpu=53,0,0;creative-commons=53,257,0;credit-card=53,0,257;croissant=53,514,0;crop=53,257,257;cross=53,0,514;crosshair=53,514,257;crown=53,257,514;cuboid=53,514,514;cup-soda=54,0,0;currency=54,257,0;cylinder=54,0,257;database=54,0,514;database-backup=54,514,0;database-zap=54,257,257;delete=54,514,257;dessert=54,257,514;diameter=54,514,514;diamond=55,257,0;diamond-percent=55,0,0;dice-1=55,0,257;dice-2=55,514,0;dice-3=55,257,257;dice-4=55,0,514;dice-5=55,514,257;dice-6=55,257,514;dices=55,514,514;diff=56,0,0;disc=56,257,257;disc-2=56,257,0;disc-3=56,0,257;disc-album=56,514,0;divide=56,257,514;divide-circle=56,0,514;divide-square=56,514,257;dna=57,0,0;dna-off=56,514,514;dock=57,257,0;dog=57,0,257;dollar-sign=57,514,0;donut=57,257,257;door-closed=57,0,514;door-open=57,514,257;dot=57,257,514;download=58,0,0;download-cloud=57,514,514;drafting-compass=58,257,0;drama=58,0,257;dribbble=58,514,0;drill=58,257,257;droplet=58,0,514;droplets=58,514,257;drum=58,257,514;drumstick=58,514,514;dumbbell=59,0,0;ear=59,0,257;ear-off=59,257,0;earth=59,257,257;earth-lock=59,514,0;eclipse=59,0,514;egg=59,514,514;egg-fried=59,514,257;egg-off=59,257,514;ellipsis=60,257,0;ellipsis-vertical=60,0,0;equal=60,514,0;equal-not=60,0,257;eraser=60,257,257;euro=60,0,514;expand=60,514,257;external-link=60,257,514;eye=61,0,0;eye-off=60,514,514;facebook=61,257,0;factory=61,0,257;fan=61,514,0;fast-forward=61,257,257;feather=61,0,514;fence=61,514,257;ferris-wheel=61,257,514;figma=61,514,514;file=68,0,514;file-archive=62,0,0;file-audio=62,0,257;file-audio-2=62,257,0;file-axis-3d=62,514,0;file-badge=62,0,514;file-badge-2=62,257,257;file-bar-chart=62,257,514;file-bar-chart-2=62,514,257;file-box=62,514,514;file-check=63,257,0;file-check-2=63,0,0;file-clock=63,0,257;file-code=63,257,257;file-code-2=63,514,0;file-cog=63,0,514;file-diff=63,514,257;file-digit=63,257,514;file-down=63,514,514;file-edit=64,0,0;file-heart=64,257,0;file-image=64,0,257;file-input=64,514,0;file-json=64,0,514;file-json-2=64,257,257;file-key=64,257,514;file-key-2=64,514,257;file-line-chart=64,514,514;file-lock=65,257,0;file-lock-2=65,0,0;file-minus=65,514,0;file-minus-2=65,0,257;file-music=65,257,257;file-output=65,0,514;file-pen=65,257,514;file-pen-line=65,514,257;file-pie-chart=65,514,514;file-plus=66,257,0;file-plus-2=66,0,0;file-question=66,0,257;file-scan=66,514,0;file-search=66,0,514;file-search-2=66,257,257;file-signature=66,514,257;file-sliders=66,257,514;file-spreadsheet=66,514,514;file-stack=67,0,0;file-symlink=67,257,0;file-terminal=67,0,257;file-text=67,514,0;file-type=67,0,514;file-type-2=67,257,257;file-up=67,514,257;file-video=67,514,514;file-video-2=67,257,514;file-volume=68,257,0;file-volume-2=68,0,0;file-warning=68,0,257;file-x=68,257,257;file-x-2=68,514,0;files=68,514,257;film=68,257,514;filter=69,0,0;filter-x=68,514,514;fingerprint=69,257,0;fire-extinguisher=69,0,257;fish=69,0,514;fish-off=69,514,0;fish-symbol=69,257,257;flag=70,0,0;flag-off=69,514,257;flag-triangle-left=69,257,514;flag-triangle-right=69,514,514;flame=70,0,257;flame-kindling=70,257,0;flashlight=70,257,257;flashlight-off=70,514,0;flask-conical=70,514,257;flask-conical-off=70,0,514;flask-round=70,257,514;flip-horizontal=71,0,0;flip-horizontal-2=70,514,514;flip-vertical=71,0,257;flip-vertical-2=71,257,0;flower=71,257,257;flower-2=71,514,0;focus=71,0,514;fold-horizontal=71,514,257;fold-vertical=71,257,514;folder=75,257,0;folder-archive=71,514,514;folder-check=72,0,0;folder-clock=72,257,0;folder-closed=72,0,257;folder-cog=72,514,0;folder-dot=72,257,257;folder-down=72,0,514;folder-edit=72,514,257;folder-git=72,514,514;folder-git-2=72,257,514;folder-heart=73,0,0;folder-input=73,257,0;folder-kanban=73,0,257;folder-key=73,514,0;folder-lock=73,257,257;folder-minus=73,0,514;folder-open=73,257,514;folder-open-dot=73,514,257;folder-output=73,514,514;folder-pen=74,0,0;folder-plus=74,257,0;folder-root=74,0,257;folder-search=74,257,257;folder-search-2=74,514,0;folder-symlink=74,0,514;folder-sync=74,514,257;folder-tree=74,257,514;folder-up=74,514,514;folder-x=75,0,0;folders=75,0,257;footprints=75,514,0;forklift=75,257,257;form-input=75,0,514;forward=75,514,257;frame=75,257,514;framer=75,514,514;frown=76,0,0;fuel=76,257,0;fullscreen=76,0,257;function-square=76,514,0;gallery-horizontal=76,0,514;gallery-horizontal-end=76,257,257;gallery-thumbnails=76,514,257;gallery-vertical=76,514,514;gallery-vertical-end=76,257,514;gamepad=77,257,0;gamepad-2=77,0,0;gantt-chart=77,514,0;gantt-chart-square=77,0,257;gauge=77,0,514;gauge-circle=77,257,257;gavel=77,514,257;gem=77,257,514;ghost=77,514,514;gift=78,0,0;git-branch=78,0,257;git-branch-plus=78,257,0;git-commit-horizontal=78,514,0;git-commit-vertical=78,257,257;git-compare=78,514,257;git-compare-arrows=78,0,514;git-fork=78,257,514;git-graph=78,514,514;git-merge=79,0,0;git-pull-request=79,514,257;git-pull-request-arrow=79,257,0;git-pull-request-closed=79,0,257;git-pull-request-create=79,257,257;git-pull-request-create-arrow=79,514,0;git-pull-request-draft=79,0,514;github=79,257,514;gitlab=79,514,514;glass-water=80,0,0;glasses=80,257,0;globe=80,257,257;globe-2=80,0,257;globe-lock=80,514,0;goal=80,0,514;grab=80,514,257;graduation-cap=80,257,514;grape=80,514,514;grid-2x2=81,0,0;grid-3x3=81,257,0;grip=81,257,257;grip-horizontal=81,0,257;grip-vertical=81,514,0;group=81,0,514;guitar=81,514,257;ham=81,257,514;hammer=81,514,514;hand=82,0,514;hand-coins=82,0,0;hand-heart=82,257,0;hand-helping=82,0,257;hand-metal=82,514,0;hand-platter=82,257,257;handshake=82,514,257;hard-drive=83,0,0;hard-drive-download=82,257,514;hard-drive-upload=82,514,514;hard-hat=83,257,0;hash=83,0,257;haze=83,514,0;hdmi-port=83,257,257;heading=84,0,257;heading-1=83,0,514;heading-2=83,514,257;heading-3=83,257,514;heading-4=83,514,514;heading-5=84,0,0;heading-6=84,257,0;headphones=84,514,0;headset=84,257,257;heart=85,0,0;heart-crack=84,0,514;heart-handshake=84,514,257;heart-off=84,257,514;heart-pulse=84,514,514;heater=85,257,0;help-circle=85,0,257;helping-hand=85,514,0;hexagon=85,257,257;highlighter=85,0,514;history=85,514,257;home=85,257,514;hop=86,0,0;hop-off=85,514,514;hospital=86,257,0;hotel=86,0,257;hourglass=86,514,0;ice-cream=86,257,514;ice-cream-2=86,257,257;ice-cream-bowl=86,0,514;ice-cream-cone=86,514,257;image=87,257,257;image-down=86,514,514;image-minus=87,0,0;image-off=87,257,0;image-plus=87,0,257;image-up=87,514,0;images=87,0,514;import=87,514,257;inbox=87,257,514;indent=88,257,0;indent-decrease=87,514,514;indent-increase=88,0,0;indian-rupee=88,0,257;infinity=88,514,0;info=88,257,257;inspection-panel=88,0,514;instagram=88,514,257;italic=88,257,514;iteration-ccw=88,514,514;iteration-cw=89,0,0;japanese-yen=89,257,0;joystick=89,0,257;kanban=89,0,514;kanban-square=89,257,257;kanban-square-dashed=89,514,0;key=89,514,514;key-round=89,514,257;key-square=89,257,514;keyboard=90,257,0;keyboard-music=90,0,0;lamp=90,257,514;lamp-ceiling=90,0,257;lamp-desk=90,514,0;lamp-floor=90,257,257;lamp-wall-down=90,0,514;lamp-wall-up=90,514,257;land-plot=90,514,514;landmark=91,0,0;languages=91,257,0;laptop=91,257,257;laptop-2=91,0,257;laptop-minimal=91,514,0;lasso=91,514,257;lasso-select=91,0,514;laugh=91,257,514;layers=92,257,0;layers-2=91,514,514;layers-3=92,0,0;layout=92,514,514;layout-dashboard=92,0,257;layout-grid=92,514,0;layout-list=92,257,257;layout-panel-left=92,0,514;layout-panel-top=92,514,257;layout-template=92,257,514;leaf=93,0,0;leafy-green=93,257,0;library=93,257,257;library-big=93,0,257;library-square=93,514,0;life-buoy=93,0,514;ligature=93,514,257;lightbulb=93,514,514;lightbulb-off=93,257,514;line-chart=94,0,0;link=94,514,0;link-2=94,0,257;link-2-off=94,257,0;linkedin=94,257,257;list=96,257,0;list-checks=94,0,514;list-collapse=94,514,257;list-end=94,257,514;list-filter=94,514,514;list-minus=95,0,0;list-music=95,257,0;list-ordered=95,0,257;list-plus=95,514,0;list-restart=95,257,257;list-start=95,0,514;list-todo=95,514,257;list-tree=95,257,514;list-video=95,514,514;list-x=96,0,0;loader=96,257,257;loader-2=96,0,257;loader-circle=96,514,0;locate=96,257,514;locate-fixed=96,0,514;locate-off=96,514,257;lock=97,0,257;lock-keyhole=97,0,0;lock-keyhole-open=96,514,514;lock-open=97,257,0;log-in=97,514,0;log-out=97,257,257;lollipop=97,0,514;luggage=97,514,257;m-square=97,257,514;magnet=97,514,514;mail=98,514,514;mail-check=98,0,0;mail-minus=98,257,0;mail-open=98,0,257;mail-plus=98,514,0;mail-question=98,257,257;mail-search=98,0,514;mail-warning=98,514,257;mail-x=98,257,514;mailbox=99,0,0;mails=99,257,0;map=99,0,514;map-pin=99,514,0;map-pin-off=99,0,257;map-pinned=99,257,257;martini=99,514,257;maximize=99,514,514;maximize-2=99,257,514;medal=100,0,0;megaphone=100,0,257;megaphone-off=100,257,0;meh=100,514,0;memory-stick=100,257,257;menu=100,514,257;menu-square=100,0,514;merge=100,257,514;message-circle=102,0,0;message-circle-code=100,514,514;message-circle-dashed=101,0,0;message-circle-heart=101,257,0;message-circle-more=101,0,257;message-circle-off=101,514,0;message-circle-plus=101,257,257;message-circle-question=101,0,514;message-circle-reply=101,514,257;message-circle-warning=101,257,514;message-circle-x=101,514,514;message-square=103,514,257;message-square-code=102,257,0;message-square-dashed=102,0,257;message-square-diff=102,514,0;message-square-dot=102,257,257;message-square-heart=102,0,514;message-square-more=102,514,257;message-square-off=102,257,514;message-square-plus=102,514,514;message-square-quote=103,0,0;message-square-reply=103,257,0;message-square-share=103,0,257;message-square-text=103,514,0;message-square-warning=103,257,257;message-square-x=103,0,514;messages-square=103,257,514;mic=104,0,257;mic-2=103,514,514;mic-off=104,0,0;mic-vocal=104,257,0;microscope=104,514,0;microwave=104,257,257;milestone=104,0,514;milk=104,257,514;milk-off=104,514,257;minimize=105,0,0;minimize-2=104,514,514;minus=105,514,0;minus-circle=105,257,0;minus-square=105,0,257;monitor=106,514,257;monitor-check=105,257,257;monitor-dot=105,0,514;monitor-down=105,514,257;monitor-off=105,257,514;monitor-pause=105,514,514;monitor-play=106,0,0;monitor-smartphone=106,257,0;monitor-speaker=106,0,257;monitor-stop=106,514,0;monitor-up=106,257,257;monitor-x=106,0,514;moon=106,514,514;moon-star=106,257,514;more-horizontal=107,0,0;more-vertical=107,257,0;mountain=107,514,0;mountain-snow=107,0,257;mouse=108,0,0;mouse-pointer=107,514,514;mouse-pointer-2=107,257,257;mouse-pointer-click=107,0,514;mouse-pointer-square=107,257,514;mouse-pointer-square-dashed=107,514,257;move=109,0,514;move-3d=108,257,0;move-diagonal=108,514,0;move-diagonal-2=108,0,257;move-down=108,514,257;move-down-left=108,257,257;move-down-right=108,0,514;move-horizontal=108,257,514;move-left=108,514,514;move-right=109,0,0;move-up=109,514,0;move-up-left=109,257,0;move-up-right=109,0,257;move-vertical=109,257,257;music=110,0,0;music-2=109,514,257;music-3=109,257,514;music-4=109,514,514;navigation=110,257,257;navigation-2=110,0,257;navigation-2-off=110,257,0;navigation-off=110,514,0;network=110,0,514;newspaper=110,514,257;nfc=110,257,514;notebook=111,0,257;notebook-pen=110,514,514;notebook-tabs=111,0,0;notebook-text=111,257,0;notepad-text=111,257,257;notepad-text-dashed=111,514,0;nut=111,514,257;nut-off=111,0,514;octagon=112,257,0;octagon-alert=111,257,514;octagon-pause=111,514,514;octagon-x=112,0,0;option=112,0,257;orbit=112,514,0;outdent=112,257,257;package=113,514,0;package-2=112,0,514;package-check=112,514,257;package-minus=112,257,514;package-open=112,514,514;package-plus=113,0,0;package-search=113,257,0;package-x=113,0,257;paint-bucket=113,257,257;paint-roller=113,0,514;paintbrush=113,257,514;paintbrush-2=113,514,257;palette=113,514,514;palmtree=114,0,0;panel-bottom=114,0,514;panel-bottom-close=114,257,0;panel-bottom-dashed=114,0,257;panel-bottom-inactive=114,514,0;panel-bottom-open=114,257,257;panel-left=115,257,0;panel-left-close=114,514,257;panel-left-dashed=114,257,514;panel-left-inactive=114,514,514;panel-left-open=115,0,0;panel-right=115,514,257;panel-right-close=115,0,257;panel-right-dashed=115,514,0;panel-right-inactive=115,257,257;panel-right-open=115,0,514;panel-top=116,0,257;panel-top-close=115,257,514;panel-top-dashed=115,514,514;panel-top-inactive=116,0,0;panel-top-open=116,257,0;panels-left-bottom=116,514,0;panels-right-bottom=116,257,257;panels-top-left=116,0,514;paperclip=116,514,257;parentheses=116,257,514;parking-circle=117,0,0;parking-circle-off=116,514,514;parking-meter=117,257,0;parking-square=117,514,0;parking-square-off=117,0,257;party-popper=117,257,257;pause=117,257,514;pause-circle=117,0,514;pause-octagon=117,514,257;paw-print=117,514,514;pc-case=118,0,0;pen=118,257,257;pen-line=118,257,0;pen-square=118,0,257;pen-tool=118,514,0;pencil=118,257,514;pencil-line=118,0,514;pencil-ruler=118,514,257;pentagon=118,514,514;percent=119,514,0;percent-circle=119,0,0;percent-diamond=119,257,0;percent-square=119,0,257;person-standing=119,257,257;phone=120,0,257;phone-call=119,0,514;phone-forwarded=119,514,257;phone-incoming=119,257,514;phone-missed=119,514,514;phone-off=120,0,0;phone-outgoing=120,257,0;pi=120,257,257;pi-square=120,514,0;piano=120,0,514;pickaxe=120,514,257;picture-in-picture=120,514,514;picture-in-picture-2=120,257,514;pie-chart=121,0,0;piggy-bank=121,257,0;pilcrow=121,514,0;pilcrow-square=121,0,257;pill=121,257,257;pin=121,514,257;pin-off=121,0,514;pipette=121,257,514;pizza=121,514,514;plane=122,0,257;plane-landing=122,0,0;plane-takeoff=122,257,0;play=122,0,514;play-circle=122,514,0;play-square=122,257,257;plug=123,0,0;plug-2=122,514,257;plug-zap=122,514,514;plug-zap-2=122,257,514;plus=123,514,0;plus-circle=123,257,0;plus-square=123,0,257;pocket=123,0,514;pocket-knife=123,257,257;podcast=123,514,257;pointer=123,514,514;pointer-off=123,257,514;popcorn=124,0,0;popsicle=124,257,0;pound-sterling=124,0,257;power=124,514,257;power-circle=124,514,0;power-off=124,257,257;power-square=124,0,514;presentation=124,257,514;printer=124,514,514;projector=125,0,0;proportions=125,257,0;puzzle=125,0,257;pyramid=125,514,0;qr-code=125,257,257;quote=125,0,514;rabbit=125,514,257;radar=125,257,514;radiation=125,514,514;radical=126,0,0;radio=126,514,0;radio-receiver=126,257,0;radio-tower=126,0,257;radius=126,257,257;rail-symbol=126,0,514;rainbow=126,514,257;rat=126,257,514;ratio=126,514,514;receipt=127,514,514;receipt-cent=127,0,0;receipt-euro=127,257,0;receipt-indian-rupee=127,0,257;receipt-japanese-yen=127,514,0;receipt-pound-sterling=127,257,257;receipt-russian-ruble=127,0,514;receipt-swiss-franc=127,514,257;receipt-text=127,257,514;rectangle-ellipsis=128,0,0;rectangle-horizontal=128,257,0;rectangle-vertical=128,0,257;recycle=128,514,0;redo=128,514,257;redo-2=128,257,257;redo-dot=128,0,514;refresh-ccw=128,514,514;refresh-ccw-dot=128,257,514;refresh-cw=129,257,0;refresh-cw-off=129,0,0;refrigerator=129,0,257;regex=129,514,0;remove-formatting=129,257,257;repeat=129,257,514;repeat-1=129,0,514;repeat-2=129,514,257;replace=130,0,0;replace-all=129,514,514;reply=130,0,257;reply-all=130,257,0;rewind=130,514,0;ribbon=130,257,257;rocket=130,0,514;rocking-chair=130,514,257;roller-coaster=130,257,514;rotate-3d=130,514,514;rotate-ccw=131,257,0;rotate-ccw-square=131,0,0;rotate-cw=131,514,0;rotate-cw-square=131,0,257;route=131,0,514;route-off=131,257,257;router=131,514,257;rows=132,257,0;rows-2=131,257,514;rows-3=131,514,514;rows-4=132,0,0;rss=132,0,257;ruler=132,514,0;russian-ruble=132,257,257;sailboat=132,0,514;salad=132,514,257;sandwich=132,257,514;satellite=133,0,0;satellite-dish=132,514,514;save=133,0,257;save-all=133,257,0;scale=133,257,257;scale-3d=133,514,0;scaling=133,0,514;scan=134,514,0;scan-barcode=133,514,257;scan-eye=133,257,514;scan-face=133,514,514;scan-line=134,0,0;scan-search=134,257,0;scan-text=134,0,257;scatter-chart=134,257,257;school=134,514,257;school-2=134,0,514;scissors=135,257,0;scissors-line-dashed=134,257,514;scissors-square=135,0,0;scissors-square-dashed-bottom=134,514,514;screen-share=135,514,0;screen-share-off=135,0,257;scroll=135,0,514;scroll-text=135,257,257;search=136,257,0;search-check=135,514,257;search-code=135,257,514;search-slash=135,514,514;search-x=136,0,0;send=136,257,257;send-horizontal=136,0,257;send-to-back=136,514,0;separator-horizontal=136,0,514;separator-vertical=136,514,257;server=137,257,0;server-cog=136,257,514;server-crash=136,514,514;server-off=137,0,0;settings=137,514,0;settings-2=137,0,257;shapes=137,257,257;share=137,514,257;share-2=137,0,514;sheet=137,257,514;shell=137,514,514;shield=139,257,0;shield-alert=138,0,0;shield-ban=138,257,0;shield-check=138,0,257;shield-ellipsis=138,514,0;shield-half=138,257,257;shield-minus=138,0,514;shield-off=138,514,257;shield-plus=138,257,514;shield-question=138,514,514;shield-x=139,0,0;ship=139,514,0;ship-wheel=139,0,257;shirt=139,257,257;shopping-bag=139,0,514;shopping-basket=139,514,257;shopping-cart=139,257,514;shovel=139,514,514;shower-head=140,0,0;shrink=140,257,0;shrub=140,0,257;shuffle=140,514,0;sigma=140,0,514;sigma-square=140,257,257;signal=141,257,0;signal-high=140,514,257;signal-low=140,257,514;signal-medium=140,514,514;signal-zero=141,0,0;signpost=141,514,0;signpost-big=141,0,257;siren=141,257,257;skip-back=141,0,514;skip-forward=141,514,257;skull=141,257,514;slack=141,514,514;slash=142,0,0;slice=142,257,0;sliders=142,257,257;sliders-horizontal=142,0,257;sliders-vertical=142,514,0;smartphone=142,257,514;smartphone-charging=142,0,514;smartphone-nfc=142,514,257;smile=143,0,0;smile-plus=142,514,514;snail=143,257,0;snowflake=143,0,257;sofa=143,514,0;soup=143,257,257;space=143,0,514;spade=143,514,257;sparkle=143,257,514;sparkles=143,514,514;speaker=144,0,0;speech=144,257,0;spell-check=144,514,0;spell-check-2=144,0,257;spline=144,257,257;split=144,257,514;split-square-horizontal=144,0,514;split-square-vertical=144,514,257;spray-can=144,514,514;sprout=145,0,0;square=151,257,257;square-activity=145,257,0;square-arrow-down=145,257,257;square-arrow-down-left=145,0,257;square-arrow-down-right=145,514,0;square-arrow-left=145,0,514;square-arrow-out-down-left=145,514,257;square-arrow-out-down-right=145,257,514;square-arrow-out-up-left=145,514,514;square-arrow-out-up-right=146,0,0;square-arrow-right=146,257,0;square-arrow-up=146,257,257;square-arrow-up-left=146,0,257;square-arrow-up-right=146,514,0;square-asterisk=146,0,514;square-bottom-dashed-scissors=146,514,257;square-check=146,514,514;square-check-big=146,257,514;square-chevron-down=147,0,0;square-chevron-left=147,257,0;square-chevron-right=147,0,257;square-chevron-up=147,514,0;square-code=147,257,257;square-dashed-bottom=147,514,257;square-dashed-bottom-code=147,0,514;square-dashed-kanban=147,257,514;square-dashed-mouse-pointer=147,514,514;square-divide=148,0,0;square-dot=148,257,0;square-equal=148,0,257;square-function=148,514,0;square-gantt-chart=148,257,257;square-kanban=148,0,514;square-library=148,514,257;square-m=148,257,514;square-menu=148,514,514;square-minus=149,0,0;square-mouse-pointer=149,257,0;square-parking=149,514,0;square-parking-off=149,0,257;square-pen=149,257,257;square-percent=149,0,514;square-pi=149,514,257;square-pilcrow=149,257,514;square-play=149,514,514;square-plus=150,0,0;square-power=150,257,0;square-radical=150,0,257;square-scissors=150,514,0;square-sigma=150,257,257;square-slash=150,0,514;square-split-horizontal=150,514,257;square-split-vertical=150,257,514;square-stack=150,514,514;square-terminal=151,0,0;square-user=151,0,257;square-user-round=151,257,0;square-x=151,514,0;squircle=151,0,514;squirrel=151,514,257;stamp=151,257,514;star=152,257,0;star-half=151,514,514;star-off=152,0,0;step-back=152,0,257;step-forward=152,514,0;stethoscope=152,257,257;sticker=152,0,514;sticky-note=152,514,257;stop-circle=152,257,514;store=152,514,514;stretch-horizontal=153,0,0;stretch-vertical=153,257,0;strikethrough=153,0,257;subscript=153,514,0;subtitles=153,257,257;sun=154,0,0;sun-dim=153,0,514;sun-medium=153,514,257;sun-moon=153,257,514;sun-snow=153,514,514;sunrise=154,257,0;sunset=154,0,257;superscript=154,514,0;swatch-book=154,257,257;swiss-franc=154,0,514;switch-camera=154,514,257;sword=154,257,514;swords=154,514,514;syringe=155,0,0;table=155,257,514;table-2=155,257,0;table-cells-merge=155,0,257;table-cells-split=155,514,0;table-columns-split=155,257,257;table-properties=155,0,514;table-rows-split=155,514,257;tablet=156,0,0;tablet-smartphone=155,514,514;tablets=156,257,0;tag=156,0,257;tags=156,514,0;tally-1=156,257,257;tally-2=156,0,514;tally-3=156,514,257;tally-4=156,257,514;tally-5=156,514,514;tangent=157,0,0;target=157,257,0;telescope=157,0,257;tent=157,257,257;tent-tree=157,514,0;terminal=157,514,257;terminal-square=157,0,514;test-tube=158,0,0;test-tube-2=157,257,514;test-tube-diagonal=157,514,514;test-tubes=158,257,0;text=158,257,514;text-cursor=158,514,0;text-cursor-input=158,0,257;text-quote=158,257,257;text-search=158,0,514;text-select=158,514,257;theater=158,514,514;thermometer=159,0,257;thermometer-snowflake=159,0,0;thermometer-sun=159,257,0;thumbs-down=159,514,0;thumbs-up=159,257,257;ticket=160,0,257;ticket-check=159,0,514;ticket-minus=159,514,257;ticket-percent=159,257,514;ticket-plus=159,514,514;ticket-slash=160,0,0;ticket-x=160,257,0;timer=160,0,514;timer-off=160,514,0;timer-reset=160,257,257;toggle-left=160,514,257;toggle-right=160,257,514;tornado=160,514,514;torus=161,0,0;touchpad=161,0,257;touchpad-off=161,257,0;tower-control=161,514,0;toy-brick=161,257,257;tractor=161,0,514;traffic-cone=161,514,257;train-front=161,514,514;train-front-tunnel=161,257,514;train-track=162,0,0;tram-front=162,257,0;trash=162,514,0;trash-2=162,0,257;tree-deciduous=162,257,257;tree-palm=162,0,514;tree-pine=162,514,257;trees=162,257,514;trello=162,514,514;trending-down=163,0,0;trending-up=163,257,0;triangle=163,257,257;triangle-alert=163,0,257;triangle-right=163,514,0;trophy=163,0,514;truck=163,514,257;turtle=163,257,514;tv=164,0,0;tv-2=163,514,514;twitch=164,257,0;twitter=164,0,257;type=164,514,0;umbrella=164,0,514;umbrella-off=164,257,257;underline=164,514,257;undo=165,0,0;undo-2=164,257,514;undo-dot=164,514,514;unfold-horizontal=165,257,0;unfold-vertical=165,0,257;ungroup=165,514,0;university=165,257,257;unlink=165,514,257;unlink-2=165,0,514;unlock=165,514,514;unlock-keyhole=165,257,514;unplug=166,0,0;upload=166,0,257;upload-cloud=166,257,0;usb=166,514,0;user=169,0,0;user-2=166,257,257;user-check=166,514,257;user-check-2=166,0,514;user-circle=166,514,514;user-circle-2=166,257,514;user-cog=167,257,0;user-cog-2=167,0,0;user-minus=167,514,0;user-minus-2=167,0,257;user-plus=167,0,514;user-plus-2=167,257,257;user-round=168,514,0;user-round-check=167,514,257;user-round-cog=167,257,514;user-round-minus=167,514,514;user-round-plus=168,0,0;user-round-search=168,257,0;user-round-x=168,0,257;user-search=168,257,257;user-square=168,514,257;user-square-2=168,0,514;user-x=168,514,514;user-x-2=168,257,514;users=169,514,0;users-2=169,257,0;users-round=169,0,257;utensils=169,0,514;utensils-crossed=169,257,257;utility-pole=169,514,257;variable=169,257,514;vault=169,514,514;vegan=170,0,0;venetian-mask=170,257,0;vibrate=170,514,0;vibrate-off=170,0,257;video=170,0,514;video-off=170,257,257;videotape=170,514,257;view=170,257,514;voicemail=170,514,514;volume=171,514,0;volume-1=171,0,0;volume-2=171,257,0;volume-x=171,0,257;vote=171,257,257;wallet=171,514,514;wallet-2=171,0,514;wallet-cards=171,514,257;wallet-minimal=171,257,514;wallpaper=172,0,0;wand=172,514,0;wand-2=172,257,0;wand-sparkles=172,0,257;warehouse=172,257,257;washing-machine=172,0,514;watch=172,514,257;waves=172,257,514;waypoints=172,514,514;webcam=173,0,0;webhook=173,0,257;webhook-off=173,257,0;weight=173,514,0;wheat=173,0,514;wheat-off=173,257,257;whole-word=173,514,257;wifi=173,514,514;wifi-off=173,257,514;wind=174,0,0;wine=174,0,257;wine-off=174,257,0;workflow=174,514,0;worm=174,257,257;wrap-text=174,0,514;wrench=174,514,257;x=175,257,0;x-circle=174,257,514;x-octagon=174,514,514;x-square=175,0,0;youtube=175,0,257;zap=175,257,257;zap-off=175,514,0;zoom-in=175,0,514;zoom-out=175,514,257;]==],
	},
}

-- ─────────────────────────────────────────────────────────────
--  Icons  (Lucide, embedded — see 08_icondata)
-- ─────────────────────────────────────────────────────────────
local iconParsed = {}
local iconNames
local iconWarned = {}

-- A few newer Lucide names mapped to the names in the embedded (v0.363) set
Icons.Aliases = {
	["house"] = "home", ["chart-bar"] = "bar-chart-3", ["circle-user-round"] = "user-circle-2",
	["layout-list"] = "list", ["funnel"] = "filter", ["settings-2"] = "settings",
}

local function parseIcons(size)
	local parsed = iconParsed[size]
	if parsed then return parsed end
	parsed = {}
	for name, sheet, x, y in string.gmatch(ICON_DATA[size].raw, "([^=;]+)=(%d+),(%d+),(%d+);") do
		parsed[name] = { tonumber(sheet), tonumber(x), tonumber(y) }
	end
	iconParsed[size] = parsed
	return parsed
end

local function cleanName(name)
	name = string.lower(tostring(name))
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	name = string.gsub(name, "^lucide[:%-]", "")
	name = string.gsub(name, "_", "-")
	return Icons.Aliases[name] or name
end

--- Sorted array of every built-in icon name
function Icons.GetNames()
	if not iconNames then
		iconNames = {}
		for name in parseIcons(48) do table.insert(iconNames, name) end
		table.sort(iconNames)
	end
	return iconNames
end

function Icons.Has(name) return parseIcons(48)[cleanName(name)] ~= nil end

--- Resolve any icon input to { Image, RectSize, RectOffset, Lucide }
--- Accepts: lucide name ("home" / "lucide:home"), "rbxassetid://id", a number id, or a ready table.
function Icons.Resolve(icon, px)
	local kind = typeof(icon)
	if icon == nil or icon == "" then return nil end
	if kind == "number" then return { Image = "rbxassetid://" .. icon } end
	if kind == "table" then return icon end
	if kind ~= "string" then return nil end
	if string.find(icon, "^rbxassetid://") or string.find(icon, "^rbxasset://") or string.find(icon, "^http") then
		return { Image = icon }
	end
	local name = cleanName(icon)
	local size = (px and px > 48) and 256 or 48
	local entry = parseIcons(size)[name]
	if not entry then
		if not iconWarned[name] then
			iconWarned[name] = true
			warn(("[Vesper] Unknown icon '%s' (use Vesper.Icons.GetNames() for the full list)"):format(name))
		end
		return nil
	end
	return {
		Image = "rbxassetid://" .. ICON_DATA[size].sheets[entry[1]],
		RectSize = Vector2.new(size, size),
		RectOffset = Vector2.new(entry[2], entry[3]),
		Lucide = true,
	}
end

--- Apply an icon to an ImageLabel / ImageButton. `color` is a theme token or Color3 (Lucide icons are tinted).
function Icons.Apply(img, icon, px, color)
	local data = Icons.Resolve(icon, px)
	if not data then
		img.Image = ""
		img.ImageTransparency = 1
		return false
	end
	img.Image = data.Image
	img.ImageTransparency = 0
	if data.RectSize then
		img.ImageRectSize = data.RectSize
		img.ImageRectOffset = data.RectOffset
	else
		img.ImageRectSize = Vector2.zero
		img.ImageRectOffset = Vector2.zero
	end
	if data.Lucide then
		if type(color) == "string" or type(color) == "function" then
			Theme.Bind(img, { ImageColor3 = color })
		elseif typeof(color) == "Color3" then
			img.ImageColor3 = color
		end
	else
		img.ImageColor3 = WHITE
	end
	return true
end

function Util.Icon(parent, icon, px, color, props)
	local img = New("ImageLabel", {
		Size = UDim2.fromOffset(px, px),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Parent = parent,
	})
	if props then for k, v in props do img[k] = v end end
	Icons.Apply(img, icon, px, color or "Text")
	return img
end

-- ─────────────────────────────────────────────────────────────
--  Localization
-- ─────────────────────────────────────────────────────────────
Loc.Enabled  = false
Loc.Prefix   = "loc:"
Loc.Language = "en"
Loc.Default  = "en"
Loc.Tables   = {}
Loc.Bound    = setmetatable({}, { __mode = "k" })

function Loc.Resolve(raw)
	if raw == nil then return "" end
	if type(raw) ~= "string" then return tostring(raw) end
	if Loc.Enabled and string.sub(raw, 1, #Loc.Prefix) == Loc.Prefix then
		local key = string.sub(raw, #Loc.Prefix + 1)
		local active = Loc.Tables[Loc.Language]
		local fallback = Loc.Tables[Loc.Default]
		return (active and active[key]) or (fallback and fallback[key]) or key
	end
	return raw
end

function Loc.Refresh()
	for obj, info in Loc.Bound do
		pcall(function() obj[info[2]] = Loc.Resolve(info[1]) end)
	end
end

--- Set a text property, remembering the raw (possibly "loc:KEY") string so it can be re-translated.
function Util.SetText(obj, raw, prop)
	prop = prop or "Text"
	Loc.Bound[obj] = { raw, prop }
	obj[prop] = Loc.Resolve(raw)
end


-- ─────────────────────────────────────────────────────────────
--  Fx: click effects, shine, loaders and animated backdrops
--  Nothing here uses a stroke on a CanvasGroup, and every temporary
--  effect is destroyed by the time it has faded out.
-- ─────────────────────────────────────────────────────────────
Fx.Enabled = true
Fx.Style   = "Ripple"                                  -- Ripple | Burst | Pulse | Sheen | None
Fx.Styles  = { "Ripple", "Burst", "Pulse", "Sheen", "None" }

local function cornerOf(inst)
	local c = inst:FindFirstChildOfClass("UICorner")
	return c and c.CornerRadius or UDim.new(0, 8)
end

local function fxColor(c)
	if typeof(c) == "Color3" then return c end
	return Theme.Resolve(c or "Accent")
end

local function fullCircle(parent, props)
	props.Parent = nil
	local f = New("Frame", props)
	New("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	f.Parent = parent
	return f
end

--- Pointer position inside `target`, in logical pixels, plus the target's logical size.
--- Falls back to the centre when the pointer is not over the target (touch, odd inset).
local function pointerIn(target)
	local scale = Util.GetScale(target)
	local abs, size = target.AbsolutePosition, target.AbsoluteSize
	local w, h = size.X / scale, size.Y / scale
	local ok, loc = pcall(UserInputService.GetMouseLocation, UserInputService)
	if ok and loc then
		local x, y = (loc.X - abs.X) / scale, (loc.Y - abs.Y) / scale
		if x >= -4 and y >= -4 and x <= w + 4 and y <= h + 4 then
			return Util.Clamp(x, 0, w), Util.Clamp(y, 0, h), w, h
		end
	end
	return w / 2, h / 2, w, h
end
Fx.PointerIn = pointerIn

--- Temporary rounded clip (ClipsDescendants ignores UICorner, a CanvasGroup does not).
--- Compensates for a UIPadding on the target. Do not use on frames that own a list layout.
function Fx.Clip(target, radius)
	local clip = New("CanvasGroup", {
		Name = "FxClip", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0, Active = false, Parent = target,
	})
	New("UICorner", { CornerRadius = radius or cornerOf(target), Parent = clip })
	local pad = target:FindFirstChildOfClass("UIPadding")
	if pad then
		local l, t = pad.PaddingLeft.Offset, pad.PaddingTop.Offset
		clip.Position = UDim2.fromOffset(-l, -t)
		clip.Size = UDim2.new(1, l + pad.PaddingRight.Offset, 1, t + pad.PaddingBottom.Offset)
	end
	return clip
end

local function cleanup(inst, after)
	task.delay(after, function() if inst then inst:Destroy() end end)
end

--- Expanding circle + ring from the click point. o = { Color, Alpha, Duration, Radius, X, Y, Ring }
function Fx.Ripple(target, o)
	if not Fx.Enabled or not target or not target.Parent then return end
	o = o or {}
	local x, y, w, h = pointerIn(target)
	if o.X then x, y = o.X, o.Y or y end
	local color = fxColor(o.Color)
	local dur = o.Duration or 0.6
	local reach = math.sqrt(math.max(x, w - x) ^ 2 + math.max(y, h - y) ^ 2) * 2 + 6
	local clip = Fx.Clip(target, o.Radius)

	local blob = fullCircle(clip, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = color, BackgroundTransparency = o.Alpha or 0.8,
	})
	Util.Tween(blob, dur * 0.95, { Size = UDim2.fromOffset(reach, reach) }, "Out")
	Util.Tween(blob, dur, { BackgroundTransparency = 1 }, "Quad")

	if o.Ring ~= false then
		local ring = fullCircle(clip, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(6, 6),
			BackgroundTransparency = 1,
		})
		local st = New("UIStroke", { Thickness = 1.5, Color = color, Transparency = 0.25, Parent = ring })
		Util.Tween(ring, dur * 0.8, { Size = UDim2.fromOffset(reach * 0.75, reach * 0.75) }, "Out")
		Util.Tween(st, dur * 0.8, { Transparency = 1 }, "Quad")
	end
	cleanup(clip, dur + 0.1)
end

--- Particles flying out of a point. o = { Parent, X, Y, Color, Count, Distance, Size, Duration, ZIndex }
function Fx.Burst(target, o)
	if not Fx.Enabled or not target or not target.Parent then return end
	o = o or {}
	local parent = o.Parent or target
	local x, y = o.X, o.Y
	if not x then x, y = pointerIn(parent) end
	local a, b = fxColor(o.Color), fxColor(o.Color2 or (o.Color == nil and "Accent2" or o.Color))
	local count, dist, size, dur = o.Count or 7, o.Distance or 26, o.Size or 4, o.Duration or 0.55
	local seed = math.random() * math.pi
	for i = 1, count do
		local ang = seed + (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.5
		local d = dist * (0.65 + math.random() * 0.55)
		local s = size * (0.7 + math.random() * 0.7)
		local dot = fullCircle(parent, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(s, s),
			BackgroundColor3 = (i % 2 == 0) and b or a, BackgroundTransparency = 0.05, ZIndex = o.ZIndex or 20,
		})
		Util.Tween(dot, dur, {
			Position = UDim2.fromOffset(x + math.cos(ang) * d, y + math.sin(ang) * d),
			Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1,
		}, "Out")
		cleanup(dot, dur + 0.05)
	end
end

--- Quick colour wash over a surface. o = { Color, Alpha, Duration, Radius }
function Fx.Flash(target, o)
	if not Fx.Enabled or not target or not target.Parent then return end
	o = o or {}
	local clip = Fx.Clip(target, o.Radius)
	local f = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = fxColor(o.Color), BackgroundTransparency = o.Alpha or 0.82, Parent = clip })
	local dur = o.Duration or 0.45
	Util.Tween(f, dur, { BackgroundTransparency = 1 }, "Quad")
	cleanup(clip, dur + 0.05)
end

--- Diagonal light sweep across a surface. o = { Color, Alpha, Duration, Radius }
function Fx.Sheen(target, o)
	if not Fx.Enabled or not target or not target.Parent then return end
	o = o or {}
	local clip = Fx.Clip(target, o.Radius)
	local bar = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(-0.25, 0, 0.5, 0), Size = UDim2.new(0.3, 0, 3, 0),
		Rotation = 16, BackgroundColor3 = fxColor(o.Color or WHITE), Parent = clip,
	})
	New("UIGradient", {
		Transparency = NumberSequence.new({ kp(0, 1), kp(0.5, o.Alpha or 0.8), kp(1, 1) }), Parent = bar,
	})
	local dur = o.Duration or 0.7
	Util.Tween(bar, dur, { Position = UDim2.new(1.25, 0, 0.5, 0) }, "Sine")
	cleanup(clip, dur + 0.05)
end

--- The click effect used by every control (change it with Vesper:SetClickEffect)
--- o = { Color, Radius, Style }
function Fx.Click(target, o)
	if not Fx.Enabled then return end
	o = o or {}
	local style = o.Style or Fx.Style
	if style == "None" then return end
	if style == "Burst" then
		Fx.Ripple(target, { Color = o.Color, Radius = o.Radius, Alpha = 0.86, Ring = false, Duration = 0.5 })
		Fx.Burst(target, { Color = o.Color, Count = 6, Distance = 22, Size = 3.5 })
	elseif style == "Pulse" then
		Fx.Flash(target, { Color = o.Color, Radius = o.Radius, Alpha = 0.86, Duration = 0.5 })
		Fx.Ripple(target, { Color = o.Color, Radius = o.Radius, Alpha = 1, Duration = 0.6 })
	elseif style == "Sheen" then
		Fx.Sheen(target, { Color = o.Sheen or WHITE, Radius = o.Radius, Alpha = 0.75, Duration = 0.55 })
		Fx.Ripple(target, { Color = o.Color, Radius = o.Radius, Alpha = 0.9, Ring = false, Duration = 0.5 })
	else
		Fx.Ripple(target, { Color = o.Color, Radius = o.Radius })
	end
end

function Fx.SetStyle(style)
	if type(style) ~= "string" then return false end
	for _, s in Fx.Styles do
		if string.lower(s) == string.lower(style) then Fx.Style = s; return true end
	end
	return false
end

--- Small wiggle used on icons when their control is pressed
function Fx.Pop(img, deg)
	if not img or not img.Parent then return end
	img.Rotation = 0
	Util.Tween(img, 0.1, { Rotation = deg or 14 }, "Quad")
	task.delay(0.1, function()
		if img and img.Parent then Util.Tween(img, 0.45, { Rotation = 0 }, "Elastic") end
	end)
end

--- Rotating gradient arc, used by the loader and the key system.
--- o = { Size, Thickness, Speed, Position, AnchorPoint, ZIndex }
function Fx.SpinRing(parent, o)
	o = o or {}
	local size, th = o.Size or 36, o.Thickness or 3
	local holder = New("Frame", {
		Name = "Spinner", BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), AnchorPoint = o.AnchorPoint or Vector2.new(),
		Position = o.Position or UDim2.new(), ZIndex = o.ZIndex or 1, Parent = parent,
	})
	local track = fullCircle(holder, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local ts = New("UIStroke", { Thickness = th, Transparency = 0.86, Parent = track })
	Theme.Bind(ts, { Color = "Stroke" })

	local arc = fullCircle(holder, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local as = New("UIStroke", { Thickness = th, Color = WHITE, Parent = arc })
	local g = New("UIGradient", {
		Transparency = NumberSequence.new({ kp(0, 1), kp(0.45, 1), kp(0.75, 0.25), kp(1, 0) }), Parent = as,
	})
	Theme.Bind(g, { Color = Theme.AccentSeq })
	if Theme.Animated then Util.Loop(g, o.Speed or 1.1, { Rotation = 360 }, "Linear") end
	return holder
end

-- ─────────────────────────────────────────────────────────────
--  Backdrops (window background styles)
--  Plain | Orbs | Streaks | Aurora | Stars | Grid | Shards | Rings
--  Colours come from the theme tokens, so they follow theme changes.
-- ─────────────────────────────────────────────────────────────
local BUILDERS = {}

local function mixToken(t) return t.Accent:Lerp(t.Accent2, 0.5) end

local function fadeEnds(strength)
	return NumberSequence.new({ kp(0, 1), kp(0.5, strength), kp(1, 1) })
end

--- Soft radial glow made of stacked circles. cx, cy are scale coordinates, d is the diameter in pixels
local function orb(parent, cx, cy, d, token, strength, animated, drift, dur)
	local holder = New("Frame", {
		Name = "Orb", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(cx, cy), Size = UDim2.fromOffset(d, d), Parent = parent,
	})
	local layers = 9
	local a = (strength or 0.5) * 0.09
	for i = 1, layers do
		local s = 1 - (i - 1) / layers * 0.9
		local layer = fullCircle(holder, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(s, s),
			BackgroundTransparency = 1 - a,
		})
		Theme.Bind(layer, { BackgroundColor3 = token })
	end
	if animated then
		local dx, dy = (drift and drift[1]) or 0.05, (drift and drift[2]) or 0.05
		Util.Loop(holder, dur or 9, { Position = UDim2.fromScale(cx + dx, cy + dy), Size = UDim2.fromOffset(d * 1.14, d * 1.14) }, "Sine", true)
	end
	return holder
end

--- A long soft beam. Rotated, faded at both edges.
local function beam(parent, x, width, length, rot, token, alpha)
	local b = New("Frame", {
		Name = "Beam", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5),
		Size = UDim2.fromOffset(width, length), Rotation = rot, BackgroundColor3 = WHITE, Parent = parent,
	})
	Theme.Bind(b, { BackgroundColor3 = token })
	New("UIGradient", { Transparency = fadeEnds(alpha), Parent = b })
	return b
end

--- A comet crossing the backdrop. Self-reschedules while `root` lives.
local function comet(root, token, rng)
	if not root.Parent then return end
	local sx, sy = rng:NextNumber(0.45, 1.0), rng:NextNumber(-0.1, 0.35)
	local len = rng:NextNumber(60, 110)
	local star = New("Frame", {
		Name = "Comet", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(sx, 0, sy, 0), Size = UDim2.fromOffset(2, len),
		Rotation = 60, BackgroundColor3 = WHITE, BackgroundTransparency = 0.1, Parent = root,
	})
	Theme.Bind(star, { BackgroundColor3 = token })
	New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 1), kp(1, 0) }), Parent = star })
	local dur = rng:NextNumber(0.9, 1.5)
	Util.Tween(star, dur, { Position = UDim2.new(sx, -520, sy, 300), BackgroundTransparency = 1 }, "Quad")
	task.delay(dur + 0.05, function() star:Destroy() end)
end

local function scheduleComets(root, token, rng, minWait, maxWait)
	task.delay(rng:NextNumber(minWait, maxWait), function()
		if not root.Parent then return end
		comet(root, token, rng)
		scheduleComets(root, token, rng, minWait, maxWait)
	end)
end

BUILDERS.Plain = function() end

BUILDERS.Orbs = function(root, animated)
	orb(root, 0.92, 0.08, 400, "Accent", 0.62, animated, { -0.06, 0.07 }, 9)
	orb(root, 0.08, 1.0, 360, "Accent2", 0.5, animated, { 0.07, -0.06 }, 12)
	orb(root, 0.62, 0.72, 230, mixToken, 0.34, animated, { -0.08, 0.05 }, 7)
	orb(root, 0.3, 0.1, 150, "Accent2", 0.22, animated, { 0.05, 0.08 }, 8)
end

BUILDERS.Streaks = function(root, animated)
	local defs = {
		{ 0.18, 120, "Accent",  0.955, 11 }, { 0.52, 160, "Accent2", 0.965, 14 }, { 0.86, 100, "Accent",  0.95, 9 },
		{ 0.34, 2,   "Accent",  0.72,  10 }, { 0.62, 2,   "Accent2", 0.78,  13 }, { 0.78, 3,   "Accent",  0.82, 8 },
		{ 0.08, 1,   "Accent2", 0.8,   12 },
	}
	for i, d in defs do
		local b = beam(root, d[1], d[2], 1500, 24, d[3], d[4])
		if animated then
			Util.Loop(b, d[5], { Position = UDim2.fromScale(d[1] + (i % 2 == 0 and 0.07 or -0.07), 0.5) }, "Sine", true)
			if d[2] <= 3 then Util.Loop(b, 2.2 + i * 0.3, { BackgroundTransparency = 0.55 }, "Sine", true, i * 0.2) end
		end
	end
	if animated then scheduleComets(root, "Accent2", Random.new(3), 1.5, 4) end
end

BUILDERS.Aurora = function(root, animated)
	local rib = {
		{ 0.18, 120, -8,  0.93, 9  },
		{ 0.52, 150,  5,  0.94, 12 },
		{ 0.86, 110, -4,  0.92, 10 },
	}
	for i, d in rib do
		local group = New("Frame", {
			Name = "Ribbon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, d[1]),
			Size = UDim2.new(1.6, 0, 0, d[2]), Rotation = d[3], Parent = root,
		})
		for layer = 1, 3 do
			local h = (layer == 1 and 1) or (layer == 2 and 0.58) or 0.26
			local band = fullCircle(group, {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, h),
				BackgroundColor3 = WHITE, BackgroundTransparency = d[4] - (layer - 1) * 0.012,
			})
			local g = New("UIGradient", { Transparency = NumberSequence.new({ kp(0, 1), kp(0.25, 0.1), kp(0.75, 0.1), kp(1, 1) }), Parent = band })
			Theme.Bind(g, { Color = function(t)
				local a, b = t.Accent, t.Accent2
				if i % 2 == 0 then a, b = b, a end
				return ColorSequence.new({ ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(0.5, b), ColorSequenceKeypoint.new(1, a) })
			end })
			if animated then
				g.Offset = Vector2.new(-0.22, 0)
				Util.Loop(g, d[5] + layer, { Offset = Vector2.new(0.22, 0) }, "Sine", true)
			end
		end
		if animated then
			Util.Loop(group, d[5] * 0.9, { Position = UDim2.fromScale(0.5, d[1] + 0.07), Rotation = d[3] + 4 }, "Sine", true)
		end
	end
	orb(root, 0.95, 0.0, 260, "Accent", 0.3, animated, { -0.04, 0.05 }, 10)
end

BUILDERS.Stars = function(root, animated)
	local rng = Random.new(11)
	orb(root, 0.85, 0.15, 300, "Accent2", 0.24, animated, { -0.05, 0.05 }, 12)
	orb(root, 0.1, 0.9, 330, "Accent", 0.26, animated, { 0.05, -0.05 }, 14)
	for i = 1, 36 do
		local s = rng:NextNumber(1, 2.6)
		local dot = fullCircle(root, {
			Name = "Star", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(rng:NextNumber(0.02, 0.98), rng:NextNumber(0.02, 0.98)), Size = UDim2.fromOffset(s, s),
			BackgroundTransparency = rng:NextNumber(0.35, 0.8),
		})
		Theme.Bind(dot, { BackgroundColor3 = (i % 5 == 0 and "Accent") or (i % 7 == 0 and "Accent2") or "Text" })
		if animated then
			Util.Loop(dot, rng:NextNumber(1.2, 3.4), { BackgroundTransparency = 0.96 }, "Sine", true, rng:NextNumber(0, 2))
		end
	end
	for i = 1, 5 do
		local px, py = rng:NextNumber(0.1, 0.9), rng:NextNumber(0.1, 0.9)
		local cross = New("Frame", {
			Name = "Sparkle", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(px, py),
			Size = UDim2.fromOffset(11, 11), Parent = root,
		})
		for k = 1, 2 do
			local arm = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = WHITE,
				Size = k == 1 and UDim2.new(1, 0, 0, 1) or UDim2.new(0, 1, 1, 0), BackgroundTransparency = 0.35, Parent = cross,
			})
			Theme.Bind(arm, { BackgroundColor3 = i % 2 == 0 and "Accent2" or "Text" })
			New("UIGradient", { Rotation = k == 1 and 0 or 90, Transparency = fadeEnds(0), Parent = arm })
			if animated then Util.Loop(arm, rng:NextNumber(1.6, 3), { BackgroundTransparency = 0.95 }, "Sine", true, rng:NextNumber(0, 1.5)) end
		end
	end
	if animated then scheduleComets(root, "Text", rng, 3, 7) end
end

BUILDERS.Grid = function(root, animated)
	local cols, rows = 18, 11
	for i = 1, cols - 1 do
		local v = New("Frame", {
			Name = "GridV", Position = UDim2.fromScale(i / cols, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.9, Parent = root,
		})
		Theme.Bind(v, { BackgroundColor3 = "Accent" })
		New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 1), kp(1, 0.1) }), Parent = v })
	end
	for i = 1, rows - 1 do
		local hline = New("Frame", {
			Name = "GridH", Position = UDim2.fromScale(0, i / rows), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.9, Parent = root,
		})
		Theme.Bind(hline, { BackgroundColor3 = "Accent" })
		New("UIGradient", { Transparency = NumberSequence.new({ kp(0, 0.9), kp(0.5, 0), kp(1, 0.9) }), Parent = hline })
	end
	local rng = Random.new(5)
	for i = 1, 6 do
		local node = fullCircle(root, {
			Name = "Node", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(rng:NextInteger(2, cols - 2) / cols, rng:NextInteger(2, rows - 2) / rows),
			Size = UDim2.fromOffset(4, 4), BackgroundTransparency = 0.3,
		})
		Theme.Bind(node, { BackgroundColor3 = i % 2 == 0 and "Accent2" or "Accent" })
		if animated then Util.Loop(node, rng:NextNumber(1.2, 2.4), { BackgroundTransparency = 0.95 }, "Sine", true, rng:NextNumber(0, 1.5)) end
	end
	local scan = New("Frame", { Name = "Scan", Position = UDim2.fromScale(0, -0.2), Size = UDim2.new(1, 0, 0, 90), BackgroundColor3 = WHITE, Parent = root })
	Theme.Bind(scan, { BackgroundColor3 = "Accent" })
	New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 1), kp(0.85, 0.9), kp(1, 1) }), Parent = scan })
	if animated then Util.Loop(scan, 6.5, { Position = UDim2.fromScale(0, 1.1) }, "Linear", false, 1.2) end
	orb(root, 0.5, 1.15, 420, "Accent", 0.3, animated, { 0, -0.03 }, 9)
end

BUILDERS.Shards = function(root, animated)
	local defs = {
		{ 0.22, 0.55, -24, 0.955, "Accent",  13 },
		{ 0.78, 0.5,  -24, 0.965, "Accent2", 16 },
		{ 0.52, 0.34,  34, 0.972, "Accent",  11 },
		{ 0.05, 0.28,  18, 0.968, "Accent2", 14 },
	}
	for i, d in defs do
		local shard = New("Frame", {
			Name = "Shard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(d[1], 0.5), Size = UDim2.fromScale(d[2], 2.2),
			Rotation = d[3], BackgroundColor3 = WHITE, BackgroundTransparency = d[4], Parent = root,
		})
		Theme.Bind(shard, { BackgroundColor3 = d[5] })
		New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 0), kp(0.6, 0.35), kp(1, 1) }), Parent = shard })
		local edge = New("Frame", {
			Name = "Edge", Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, Parent = shard,
		})
		Theme.Bind(edge, { BackgroundColor3 = d[5] })
		New("UIGradient", { Rotation = 90, Transparency = fadeEnds(0), Parent = edge })
		if animated then
			Util.Loop(shard, d[6], { Position = UDim2.fromScale(d[1] + (i % 2 == 0 and 0.05 or -0.05), 0.5), Rotation = d[3] + (i % 2 == 0 and 4 or -4) }, "Sine", true)
		end
	end
	orb(root, 0.9, 0.9, 260, "Accent", 0.22, animated, { -0.04, -0.04 }, 10)
end

BUILDERS.Rings = function(root, animated)
	local function ringSet(cx, cy, base, step, count, spin)
		for i = 1, count do
			local d = base + (i - 1) * step
			local ring = fullCircle(root, {
				Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cx, cy),
				Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1,
			})
			local st = New("UIStroke", { Thickness = 1.5, Color = WHITE, Transparency = 0.8 + i * 0.02, Parent = ring })
			local g = New("UIGradient", { Rotation = 35, Transparency = NumberSequence.new({ kp(0, 0.1), kp(0.5, 0.75), kp(1, 1) }), Parent = st })
			Theme.Bind(g, { Color = Theme.AccentSeq })
			local dot = fullCircle(ring, {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(5, 5),
				BackgroundTransparency = 0.2,
			})
			Theme.Bind(dot, { BackgroundColor3 = i % 2 == 0 and "Accent2" or "Accent" })
			if animated then
				Util.Loop(ring, spin + i * 5, { Rotation = (i % 2 == 0) and -360 or 360 }, "Linear")
				Util.Loop(st, 3 + i * 0.7, { Transparency = 0.96 }, "Sine", true, i * 0.3)
			end
		end
	end
	ringSet(0.9, 0.1, 110, 90, 5, 16)
	ringSet(0.05, 1.0, 160, 110, 4, 22)
	orb(root, 0.9, 0.1, 260, "Accent", 0.28, animated, { -0.03, 0.03 }, 10)
end

--- Build (and keep rebuilt) the animated backdrop for a window / gate. Returns the backdrop frame.
function Fx.Backdrop(parent, zindex)
	local root = New("Frame", {
		Name = "Backdrop", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = zindex or 0,
		ClipsDescendants = true, Active = false, Parent = parent,
	})
	local function build(inst, style)
		inst:ClearAllChildren()
		local builder = BUILDERS[style] or BUILDERS.Plain
		builder(inst, Theme.Animated)
	end
	Theme.WatchStyle(root, build)
	build(root, Theme.GetStyle())
	return root
end

--- Top highlight line + bottom vignette that give a surface its sheen. Returns the container.
function Fx.Gloss(parent, zindex)
	local box = New("Frame", { Name = "Gloss", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = zindex or 1, Active = false, Parent = parent })
	local vignette = New("Frame", {
		Name = "Vignette", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.45, 0),
		BackgroundColor3 = BLACK, BackgroundTransparency = 0.5, Parent = box,
	})
	New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 1), kp(1, 0.55) }), Parent = vignette })
	local top = Util.FadeLine(box, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.6, Token = "Accent", ZIndex = 2, Thickness = 1 })
	return box, top
end

-- ─────────────────────────────────────────────────────────────
--  Sound
--  Defaults are built-in Roblox client sounds (no asset permissions needed).
--  Each default lists a few candidate files; the first one that actually loads is used,
--  and if none loads the sound stays silent instead of erroring.
--  Override any of them with Vesper:SetSound(name, id).
-- ─────────────────────────────────────────────────────────────
Sound.Enabled = true
Sound.Volume  = 1
Sound.Parent  = nil
Sound.Pool    = {}
Sound.Map = {
	Click     = { Ids = { "rbxasset://sounds/button.wav", "rbxasset://sounds/button.mp3", "rbxasset://sounds/clickfast.wav" }, Volume = 0.35, Speed = 1.05 },
	Select    = { Ids = { "rbxasset://sounds/clickfast.wav", "rbxasset://sounds/clickfast.mp3", "rbxasset://sounds/button.wav" }, Volume = 0.30, Speed = 1.00 },
	Tick      = { Ids = { "rbxasset://sounds/clickfast.wav", "rbxasset://sounds/clickfast.mp3" }, Volume = 0.12, Speed = 1.60 },
	ToggleOn  = { Ids = { "rbxasset://sounds/switch.wav", "rbxasset://sounds/switch.mp3", "rbxasset://sounds/button.wav" }, Volume = 0.40, Speed = 1.12 },
	ToggleOff = { Ids = { "rbxasset://sounds/switch.wav", "rbxasset://sounds/switch.mp3", "rbxasset://sounds/button.wav" }, Volume = 0.40, Speed = 0.88 },
	Open      = { Ids = { "rbxasset://sounds/snap.mp3", "rbxasset://sounds/snap.wav", "rbxasset://sounds/button.wav" }, Volume = 0.25, Speed = 1.25 },
	Close     = { Ids = { "rbxasset://sounds/snap.mp3", "rbxasset://sounds/snap.wav", "rbxasset://sounds/button.wav" }, Volume = 0.25, Speed = 0.85 },
	Notify    = { Ids = { "rbxasset://sounds/electronicpingshort.wav", "rbxasset://sounds/electronicpingshort.mp3", "rbxasset://sounds/button.wav" }, Volume = 0.35, Speed = 1.00 },
	Success   = { Ids = { "rbxasset://sounds/electronicpingshort.wav", "rbxasset://sounds/electronicpingshort.mp3", "rbxasset://sounds/button.wav" }, Volume = 0.35, Speed = 1.28 },
	Error     = { Ids = { "rbxasset://sounds/Kerplunk.wav", "rbxasset://sounds/Kerplunk.mp3", "rbxasset://sounds/snap.mp3" }, Volume = 0.35, Speed = 0.80 },
}

--- Finds the first candidate that loads (runs once per sound, in the background)
local function resolveSound(cfg)
	if cfg.Resolving then return end
	cfg.Resolving = true
	task.spawn(function()
		local probe = New("Sound", { Name = "Probe", Volume = 0, Parent = Sound.Parent })
		for _, id in cfg.Ids do
			probe.SoundId = id
			local t0 = os.clock()
			while not probe.IsLoaded and os.clock() - t0 < 1.5 do task.wait(0.05) end
			if probe.IsLoaded and probe.TimeLength > 0 then cfg.Resolved = id; break end
		end
		probe:Destroy()
		if cfg.Resolved == nil then cfg.Resolved = false end
		cfg.Resolving = false
	end)
end

function Sound.Play(name)
	if not Sound.Enabled or not Sound.Parent then return end
	local cfg = Sound.Map[name]
	if not cfg then return end
	local id = cfg.Id
	if not id and cfg.Ids then
		if cfg.Resolved == nil then resolveSound(cfg); return end
		id = cfg.Resolved
	end
	if not id then return end
	local s = Sound.Pool[name]
	if not s or not s.Parent then
		s = New("Sound", { Name = name, Parent = Sound.Parent })
		Sound.Pool[name] = s
	end
	if s.SoundId ~= id then s.SoundId = id end
	s.Volume = (cfg.Volume or 0.4) * Sound.Volume
	s.PlaybackSpeed = cfg.Speed or 1
	s.TimePosition = 0
	s:Play()
end

-- ─────────────────────────────────────────────────────────────
--  Host: a ScreenGui with a UIScale root. Everything inside a host
--  lives in "logical" pixels, so the UI scales cleanly per device.
-- ─────────────────────────────────────────────────────────────
local Host = {}
Host.__index = Host

local function mountGui(gui)
	if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
	if gethui then
		local ok, container = pcall(gethui)
		if ok and container then
			local set = pcall(function() gui.Parent = container end)
			if set and gui.Parent then return end
		end
	end
	if CoreGui then
		local ok = pcall(function() gui.Parent = CoreGui end)
		if ok and gui.Parent then return end
	end
	local player = Players and Players.LocalPlayer
	if player then
		local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
		if playerGui then gui.Parent = playerGui; return end
	end
	warn("[Vesper] Could not find anywhere to mount the interface")
end

function Host.new(displayOrder)
	local self = setmetatable({}, Host)
	self.Maid = Maid.new()
	self.Gui = New("ScreenGui", {
		Name = Util.RandomName(), ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = displayOrder or 1000,
	})
	self.Root = New("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = self.Gui })
	self.UIScale = New("UIScale", { Parent = self.Root })
	mountGui(self.Gui)
	self.Maid:Give(self.Gui)
	return self
end

function Host:SetScale(s)
	s = Util.Clamp(s, 0.35, 2)
	self.UIScale.Scale = s
	self.Root.Size = UDim2.fromScale(1 / s, 1 / s)
end
function Host:GetScale() return self.UIScale.Scale end

--- Size of the host in logical pixels
function Host:LogicalSize()
	local s = self.UIScale.Scale
	local vp = Util.Viewport()
	return Vector2.new(vp.X / s, vp.Y / s)
end

--- Re-run `fn()` whenever the viewport changes (fn should call SetScale)
function Host:OnViewport(fn)
	local conn
	local function bind()
		if conn then conn:Disconnect(); conn = nil end
		local cam = workspace.CurrentCamera
		if cam then
			conn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(fn)
			self.Maid:Give(conn)
		end
	end
	bind()
	self.Maid:Give(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() bind(); fn() end))
	fn()
end

function Host:Destroy() self.Maid:Clean() end

-- ─────────────────────────────────────────────────────────────
--  Hover / press feedback
-- ─────────────────────────────────────────────────────────────
function Util.HoverFx(btn, target, normal, hover, press, prop)
	prop = prop or "BackgroundColor3"
	local hovering, pressing = false, false
	local function apply()
		local token = (pressing and (press or hover)) or (hovering and hover) or normal
		Util.Tween(target, 0.14, { [prop] = Theme.Resolve(token) }, "Quad")
	end
	btn.MouseEnter:Connect(function() hovering = true; apply() end)
	btn.MouseLeave:Connect(function() hovering = false; pressing = false; apply() end)
	btn.MouseButton1Down:Connect(function() pressing = true; apply() end)
	btn.MouseButton1Up:Connect(function()
		pressing = false
		if Util.IsTouch() then hovering = false end
		apply()
	end)
	return apply
end

-- ─────────────────────────────────────────────────────────────
--  Button (shared by dialogs, notifications, key system, rows)
--  Variants: Primary | Secondary | Danger | Ghost
--  The label lives in an inner frame so the click effect can sit on the button itself.
-- ─────────────────────────────────────────────────────────────
function Util.MakeButton(o)
	local variant = o.Variant or "Secondary"
	local height = o.Height or 32
	local fixed = o.Width ~= nil
	local radius = o.Radius or 9
	local btn = New("TextButton", {
		Name = "Button", BackgroundTransparency = 0, AutomaticSize = fixed and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		Size = UDim2.new(0, o.Width or 0, 0, height), LayoutOrder = o.LayoutOrder or 0, Parent = o.Parent,
	})
	Util.Corner(btn, radius)

	local inner = New("Frame", {
		Name = "Inner", BackgroundTransparency = 1, Active = false, ZIndex = 2,
		Size = fixed and UDim2.fromScale(1, 1) or UDim2.new(0, 0, 1, 0),
		AutomaticSize = fixed and Enum.AutomaticSize.None or Enum.AutomaticSize.X, Parent = btn,
	})
	Util.Padding(inner, 0, fixed and 8 or 16, 0, fixed and 8 or 16)
	Util.List(inner, 7, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

	local textToken = "Text"
	local normal, hover, press = "Input", "InputHover", function(t) return t.InputHover:Lerp(BLACK, 0.12) end
	local fxColor = "Accent"
	local depth
	if variant == "Primary" then
		textToken = "AccentText"
		btn.BackgroundColor3 = WHITE
		Theme.AccentGradient(btn, 20)
		normal, hover, press = nil, nil, nil
		fxColor = WHITE
		depth = Shadow.Edge(btn, { Alpha = 0.72, Inset = 6 })
		Theme.Bind(depth, { BackgroundColor3 = function(t) return t.Accent:Lerp(BLACK, 0.55) end })
	elseif variant == "Danger" then
		textToken = function() return WHITE end
		normal, hover, press = "Danger", function(t) return t.Danger:Lerp(WHITE, 0.12) end, function(t) return t.Danger:Lerp(BLACK, 0.15) end
		fxColor = WHITE
		depth = Shadow.Edge(btn, { Alpha = 0.72, Inset = 6 })
		Theme.Bind(depth, { BackgroundColor3 = function(t) return t.Danger:Lerp(BLACK, 0.6) end })
	elseif variant == "Ghost" then
		btn.BackgroundTransparency = 1
		normal, hover, press = "Input", "Input", "InputHover"
		Util.FadeLine(btn, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.5, ZIndex = 3, Thickness = 1 })
		Util.FadeLine(btn, { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), Strength = 0.5, ZIndex = 3, Thickness = 1 })
	else
		Util.Shade(btn, 90, 0.09)
		depth = Shadow.Edge(btn, { Alpha = 0.8, Inset = 6 })
		Util.FadeLine(btn, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.32, ZIndex = 3, Thickness = 1 })
	end

	if normal then
		Theme.Bind(btn, { BackgroundColor3 = normal })
		Util.HoverFx(btn, btn, normal, hover, press)
		if variant == "Ghost" then
			btn.MouseEnter:Connect(function() Util.Tween(btn, 0.14, { BackgroundTransparency = 0 }, "Quad") end)
			btn.MouseLeave:Connect(function() Util.Tween(btn, 0.14, { BackgroundTransparency = 1 }, "Quad") end)
		end
	else
		btn.MouseEnter:Connect(function()
			Util.Tween(btn, 0.14, { BackgroundColor3 = Color3.new(0.9, 0.9, 0.9) }, "Quad")
			Fx.Sheen(btn, { Radius = UDim.new(0, radius), Alpha = 0.78, Duration = 0.6 })
		end)
		btn.MouseLeave:Connect(function() Util.Tween(btn, 0.14, { BackgroundColor3 = WHITE }, "Quad") end)
		btn.MouseButton1Down:Connect(function() Util.Tween(btn, 0.08, { BackgroundColor3 = Color3.new(0.76, 0.76, 0.76) }, "Quad") end)
		btn.MouseButton1Up:Connect(function() Util.Tween(btn, 0.14, { BackgroundColor3 = Color3.new(0.9, 0.9, 0.9) }, "Quad") end)
	end

	-- pressed = the contents sink 1px
	btn.MouseButton1Down:Connect(function() Util.Tween(inner, 0.07, { Position = UDim2.fromOffset(0, 1) }, "Quad") end)
	local function release() Util.Tween(inner, 0.2, { Position = UDim2.fromOffset(0, 0) }, "Back") end
	btn.MouseButton1Up:Connect(release)
	btn.MouseLeave:Connect(release)

	if o.Icon then
		Util.SetPart(btn, "Icon", Util.Icon(inner, o.Icon, 14, textToken, { LayoutOrder = 1 }))
	end
	if o.Text and o.Text ~= "" then
		local label = New("TextLabel", {
			Weight = "Medium", TextSize = o.TextSize or 13, AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Center, Parent = inner,
		})
		Theme.Bind(label, { TextColor3 = textToken })
		Util.SetText(label, o.Text)
		Util.SetPart(btn, "Label", label)
	end

	btn.Activated:Connect(function()
		Sound.Play("Click")
		Fx.Click(btn, { Color = fxColor, Radius = UDim.new(0, radius) })
		Fx.Pop(Util.Part(btn, "Icon"))
		Util.Fire(o.Callback)
	end)
	return btn
end

-- ─────────────────────────────────────────────────────────────
--  Popover (dropdown lists, colour picker, search results …)
-- ─────────────────────────────────────────────────────────────
--- opts: { Width, Height, Align = "Right"|"Left", Build = function(canvas, popover), OnClose = function(), Gap }
--- The popover is a Surface (shadow + canvas); it grows from the corner nearest its anchor.
function Util.OpenPopover(host, overlay, anchor, opts)
	if host._popover then host._popover.Close() end

	local scale = host:GetScale()
	local rootPos = host.Root.AbsolutePosition
	local rel = (anchor.AbsolutePosition - rootPos) / scale
	local asz = anchor.AbsoluteSize / scale
	local logical = host:LogicalSize()
	local gap = opts.Gap or 6

	local w, h = opts.Width, opts.Height
	local alignRight = opts.Align ~= "Left"
	local x = alignRight and (rel.X + asz.X - w) or rel.X
	local y = rel.Y + asz.Y + gap
	local openUp = false
	if y + h > logical.Y - 8 then
		local above = rel.Y - h - gap
		if above >= 8 then y, openUp = above, true else y = math.max(8, logical.Y - h - 8) end
	end
	x = Util.Clamp(x, 8, math.max(8, logical.X - w - 8))

	local blocker = New("TextButton", {
		Name = "PopoverBlocker", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
		ZIndex = 200, Parent = overlay,
	})
	local ax, ay = alignRight and 1 or 0, openUp and 1 or 0
	local holder, canvas = Util.Surface(overlay, {
		Name = "Popover", AnchorPoint = Vector2.new(ax, ay),
		Position = UDim2.fromOffset(x + ax * w, y + ay * h), Size = UDim2.fromOffset(w, h), ZIndex = 201,
	}, 12)
	Theme.Bind(canvas, { BackgroundColor3 = "Popup" })
	Util.Shade(canvas, 90, 0.07)
	local pop = New("UIScale", { Scale = 0.94, Parent = holder })
	Util.FadeLine(canvas, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.7, Token = "Accent", ZIndex = 5, Thickness = 1 })

	local closed = false
	local object = { Holder = holder, Frame = canvas }
	function object.Close()
		if closed then return end
		closed = true
		if host._popover == object then host._popover = nil end
		blocker:Destroy()
		Util.FadeCanvas(canvas, 1, 0.14, "Quad")
		Util.Tween(pop, 0.16, { Scale = 0.96 }, "Quad")
		task.delay(0.2, function() holder:Destroy() end)
		if opts.OnClose then Util.Fire(opts.OnClose) end
	end
	blocker.Activated:Connect(object.Close)
	host._popover = object

	if opts.Build then opts.Build(canvas, object) end
	Util.FadeCanvas(canvas, 0, 0.18, "Out")
	Util.Tween(pop, 0.26, { Scale = 1 }, "Back")
	return object
end

-- ─────────────────────────────────────────────────────────────
--  Dialog card (used by Window:Dialog and Vesper:Popup)
--  opts: { Title, Content, Icon, Buttons = {{Title, Variant, Callback, Close}}, Dismissable, Width, Type }
-- ─────────────────────────────────────────────────────────────
function Util.Dialog(parent, opts)
	local backdrop = New("TextButton", {
		Name = "DialogBackdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1,
		ZIndex = 300, Parent = parent,
	})
	New("UIGradient", {
		Rotation = 90, Transparency = NumberSequence.new({ kp(0, 0.0), kp(0.5, 0.25), kp(1, 0.0) }), Parent = backdrop,
	})
	local holder, card = Util.Surface(parent, {
		Name = "Dialog", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, opts.Width or 350, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 301,
	}, 16, true)
	Theme.Bind(card, { BackgroundColor3 = "Popup" })
	Util.Shade(card, 90, 0.08)
	local scale = New("UIScale", { Scale = 0.9, Parent = holder })
	Util.FadeLine(card, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.9, Token = "Accent", ZIndex = 5, Thickness = 1 })

	local body = New("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
	Util.Padding(body, 20, 20, 18, 20)
	Util.List(body, 14)

	local head = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = body })
	Util.List(head, 14, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
	local bubbleIcon
	if opts.Icon then
		local bubble = New("Frame", { Size = UDim2.fromOffset(38, 38), LayoutOrder = 1, BackgroundColor3 = WHITE, Parent = head })
		Util.Corner(bubble, 11)
		Theme.AccentGradient(bubble, 45)
		bubbleIcon = Util.Icon(bubble, opts.Icon, 19, "AccentText", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	end
	local texts = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, opts.Icon and -52 or 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = head })
	Util.List(texts, 5)
	local title = New("TextLabel", {
		Weight = "SemiBold", TextSize = 16, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1, Parent = texts,
	})
	Theme.Bind(title, { TextColor3 = "Text" })
	Util.SetText(title, opts.Title or "")
	if opts.Content and opts.Content ~= "" then
		local text = New("TextLabel", {
			TextSize = 13, TextWrapped = true, LineHeight = 1.18, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2, RichText = true, Parent = texts,
		})
		Theme.Bind(text, { TextColor3 = "SubText" })
		Util.SetText(text, opts.Content)
	end

	local object = { Frame = card, Holder = holder }
	local closed = false
	function object.Close()
		if closed then return end
		closed = true
		Util.Tween(backdrop, 0.18, { BackgroundTransparency = 1 }, "Quad")
		Util.FadeCanvas(card, 1, 0.16, "Quad")
		Util.Tween(scale, 0.16, { Scale = 0.95 }, "Quad")
		Sound.Play("Close")
		task.delay(0.22, function() backdrop:Destroy(); holder:Destroy() end)
	end

	local buttons = opts.Buttons
	if buttons and #buttons > 0 then
		Util.FadeLine(body, { Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 2, Strength = 0.4 })
		local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 3, Parent = body })
		Util.List(row, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
		for i, def in buttons do
			Util.MakeButton({
				Parent = row, Text = def.Title or "OK", Variant = def.Variant or (i == #buttons and "Primary" or "Secondary"),
				Icon = def.Icon, LayoutOrder = i, Height = 34,
				Callback = function()
					Util.Fire(def.Callback)
					if def.Close ~= false then object.Close() end
				end,
			})
		end
	end

	if opts.Dismissable ~= false then
		backdrop.Activated:Connect(function()
			if opts.OnDismiss then Util.Fire(opts.OnDismiss) end
			object.Close()
		end)
	end

	Sound.Play("Open")
	Util.Tween(backdrop, 0.22, { BackgroundTransparency = 0.45 }, "Quad")
	Util.FadeCanvas(card, 0, 0.22, "Out")
	Util.Tween(scale, 0.34, { Scale = 1 }, "Back")
	if bubbleIcon then task.delay(0.2, function() Fx.Pop(bubbleIcon, 12) end) end
	return object
end

-- ─────────────────────────────────────────────────────────────
--  Global layer: notifications + standalone popups
-- ─────────────────────────────────────────────────────────────
Layer.Counter = 0
Layer.Active  = {}
Layer.Options = {
	Position  = "BottomRight",   -- TopLeft | TopCenter | TopRight | BottomLeft | BottomCenter | BottomRight
	Width     = 320,             -- card width in pixels
	Gap       = 8,               -- space between cards
	Margin    = 14,              -- distance from the screen edge
	Max       = 5,               -- how many can be on screen at once
	Duration  = 5,               -- default seconds (0 = stays until closed)
	Scale     = 1,               -- overall size multiplier (0.6 - 1.6)
	Compact   = false,           -- smaller, tighter cards
	Animation = "Slide",         -- Slide | Pop | Drop | Fade
	Progress  = true,            -- timer bar along the bottom
	Sound     = true,
	Closable  = true,            -- show the close button
}

local NOTIFY_ANCHORS = {
	BottomRight  = { Enum.VerticalAlignment.Bottom, Enum.HorizontalAlignment.Right,   1, true  },
	TopRight     = { Enum.VerticalAlignment.Top,    Enum.HorizontalAlignment.Right,   1, false },
	BottomLeft   = { Enum.VerticalAlignment.Bottom, Enum.HorizontalAlignment.Left,   -1, true  },
	TopLeft      = { Enum.VerticalAlignment.Top,    Enum.HorizontalAlignment.Left,   -1, false },
	TopCenter    = { Enum.VerticalAlignment.Top,    Enum.HorizontalAlignment.Center,  0, false },
	BottomCenter = { Enum.VerticalAlignment.Bottom, Enum.HorizontalAlignment.Center,  0, true  },
}
Layer.Positions = { "TopLeft", "TopCenter", "TopRight", "BottomLeft", "BottomCenter", "BottomRight" }
local ANIMATIONS = { Slide = true, Pop = true, Drop = true, Fade = true }

function Layer.Rescale()
	local host = Layer.Host
	if not host then return end
	local vp = Util.Viewport()
	local base = Util.Clamp(math.min(vp.X / 1000, vp.Y / 560), 0.7, 1)
	host:SetScale(base * Util.Clamp(Layer.Options.Scale, 0.6, 1.6))
end

function Layer.ApplyOptions()
	local o = Layer.Options
	local holder = Layer.NotifyHolder
	if not holder then return end
	local cfg = NOTIFY_ANCHORS[o.Position] or NOTIFY_ANCHORS.BottomRight
	holder.Position = UDim2.fromOffset(o.Margin, o.Margin)
	holder.Size = UDim2.new(1, -o.Margin * 2, 1, -o.Margin * 2)
	Layer.NotifyList.VerticalAlignment = cfg[1]
	Layer.NotifyList.HorizontalAlignment = cfg[2]
	Layer.NotifyList.Padding = UDim.new(0, o.Gap)
	Layer.Rescale()
end

function Layer.Init()
	if Layer.Host and Layer.Host.Gui and Layer.Host.Gui.Parent then return Layer.Host end
	local host = Host.new(2000)
	Layer.Host = host
	Sound.Parent = host.Gui
	table.clear(Sound.Pool)
	host:OnViewport(Layer.Rescale)
	local holder = New("Frame", { Name = "Notifications", BackgroundTransparency = 1, Active = false, Size = UDim2.fromScale(1, 1), Parent = host.Root })
	Layer.NotifyList = Util.List(holder, Layer.Options.Gap)
	Layer.NotifyHolder = holder
	Layer.ApplyOptions()
	return host
end

local NOTIFY_TOKENS = { Info = "Info", Success = "Success", Warning = "Warning", Error = "Danger" }
local NOTIFY_ICONS = { Info = "info", Success = "circle-check", Warning = "triangle-alert", Error = "circle-x" }
local NOTIFY_SOUNDS = { Info = "Notify", Success = "Success", Warning = "Notify", Error = "Error" }

--- Vesper:Notify({ Title, Content, Type = "Info"|"Success"|"Warning"|"Error", Icon, Duration, Buttons, Width, Compact, Animation, Sound, Progress, Closable, OnClose })
function Vesper:Notify(opts)
	Layer.Init()
	if type(opts) == "string" then opts = { Title = opts } end
	opts = opts or {}
	local cfg = Layer.Options
	local kind = NOTIFY_TOKENS[opts.Type] and opts.Type or "Info"
	local token = NOTIFY_TOKENS[kind]
	local duration = tonumber(opts.Duration)
	if duration == nil then duration = cfg.Duration end
	if type(opts.Buttons) ~= "table" then opts.Buttons = nil end
	local compact = opts.Compact
	if compact == nil then compact = cfg.Compact end
	local width = Util.Clamp(opts.Width or cfg.Width, 180, 640)
	local animation = ANIMATIONS[opts.Animation] and opts.Animation or (ANIMATIONS[cfg.Animation] and cfg.Animation or "Slide")
	local showProgress = opts.Progress
	if showProgress == nil then showProgress = cfg.Progress end
	local closable = opts.Closable
	if closable == nil then closable = cfg.Closable end

	local anchor = NOTIFY_ANCHORS[cfg.Position] or NOTIFY_ANCHORS.BottomRight
	local side = anchor[3]
	local fromBottom = anchor[4]

	Layer.Counter += 1
	local holder = New("Frame", {
		Name = "Notification", BackgroundTransparency = 1, Size = UDim2.new(0, width, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = Layer.Counter, Parent = Layer.NotifyHolder,
	})
	local surface, card = Util.Surface(holder, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, compact and 10 or 12, true)
	Theme.Bind(card, { BackgroundColor3 = "Popup" })
	Util.Shade(card, 90, 0.08)
	local pop = New("UIScale", { Scale = animation == "Pop" and 0.84 or 1, Parent = surface })

	-- accent bar on the leading edge
	local accent = New("Frame", { Name = "Accent", Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = WHITE, ZIndex = 3, Parent = card })
	Theme.Bind(accent, { BackgroundColor3 = function(t) return opts.Color or t[token] end })
	New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 0.1), kp(0.7, 0.2), kp(1, 0.9) }), Parent = accent })
	Util.FadeLine(card, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.6, Token = function(t) return opts.Color or t[token] end, ZIndex = 4, Thickness = 1 })

	local body = New("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
	local pad = compact and 9 or 13
	Util.Padding(body, pad, pad + 2, pad + 2, pad + 5)
	Util.List(body, compact and 6 or 9)

	local top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = body })
	local bubbleSize = compact and 24 or 32
	local bubble = New("Frame", { Size = UDim2.fromOffset(bubbleSize, bubbleSize), BackgroundTransparency = 0.82, BackgroundColor3 = WHITE, Parent = top })
	Theme.Bind(bubble, { BackgroundColor3 = function(t) return opts.Color or t[token] end })
	Util.Corner(bubble, compact and 8 or 10)
	local icon = Util.Icon(bubble, opts.Icon or NOTIFY_ICONS[kind], compact and 13 or 17, function(t) return opts.Color or t[token] end, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })

	local texts = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, bubbleSize), AutomaticSize = Enum.AutomaticSize.Y, Parent = top })
	Util.Padding(texts, 0, closable and 22 or 0, 0, bubbleSize + 10)
	Util.List(texts, 2, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local title = New("TextLabel", {
		Weight = "SemiBold", TextSize = compact and 12 or 14, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1, Parent = texts,
	})
	Theme.Bind(title, { TextColor3 = "Text" })
	Util.SetText(title, opts.Title or "Notification")
	if opts.Content and opts.Content ~= "" then
		local content = New("TextLabel", {
			TextSize = compact and 11 or 12, TextWrapped = true, RichText = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2, Parent = texts,
		})
		Theme.Bind(content, { TextColor3 = "SubText" })
		Util.SetText(content, opts.Content)
	end

	local object = { Frame = card, Holder = holder }
	local closed = false
	function object:Close()
		if closed then return end
		closed = true
		local idx = table.find(Layer.Active, object)
		if idx then table.remove(Layer.Active, idx) end
		if opts.OnClose then Util.Fire(opts.OnClose) end
		Util.FadeCanvas(card, 1, 0.22, "In")
		if animation == "Pop" then
			Util.Tween(pop, 0.22, { Scale = 0.9 }, "In")
		elseif animation == "Drop" then
			Util.Tween(surface, 0.22, { Position = UDim2.fromScale(0, fromBottom and 0.25 or -0.25) }, "In")
		elseif animation == "Slide" then
			Util.Tween(surface, 0.22, { Position = UDim2.fromOffset(side * 50, 0) }, "In")
		end
		task.delay(0.2, function()
			if not holder.Parent then return end
			local scale = Layer.Host and Layer.Host:GetScale() or 1
			local h = holder.AbsoluteSize.Y / scale
			holder.AutomaticSize = Enum.AutomaticSize.None
			holder.Size = UDim2.new(0, width, 0, h)
			holder.ClipsDescendants = true
			Util.Tween(holder, 0.22, { Size = UDim2.new(0, width, 0, 0) }, "Quad")
			task.delay(0.24, function() holder:Destroy() end)
		end)
	end
	function object:SetTitle(text) Util.SetText(title, text) end

	if closable then
		local closeBtn = New("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -1), Size = UDim2.fromOffset(22, 22), Parent = top })
		local closeIcon = Util.Icon(closeBtn, "x", 12, "Muted", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		closeBtn.MouseEnter:Connect(function() Theme.Bind(closeIcon, { ImageColor3 = "Text" }) end)
		closeBtn.MouseLeave:Connect(function() Theme.Bind(closeIcon, { ImageColor3 = "Muted" }) end)
		closeBtn.Activated:Connect(function() object:Close() end)
	end

	if opts.Buttons and #opts.Buttons > 0 then
		local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, compact and 24 or 28), LayoutOrder = 2, Parent = body })
		Util.List(row, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
		for i, def in opts.Buttons do
			Util.MakeButton({
				Parent = row, Text = def.Title, Icon = def.Icon, Variant = def.Variant or (i == #opts.Buttons and "Primary" or "Secondary"),
				Height = compact and 24 or 28, LayoutOrder = i, TextSize = 12, Radius = 8,
				Callback = function() Util.Fire(def.Callback); if def.Close ~= false then object:Close() end end,
			})
		end
	end

	if duration and duration > 0 and showProgress then
		local bar = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = WHITE, BackgroundTransparency = 0.25, ZIndex = 4, Parent = card })
		Theme.Bind(bar, { BackgroundColor3 = function(t) return opts.Color or t[token] end })
		Util.Tween(bar, duration, { Size = UDim2.new(0, 0, 0, 2) }, "Linear")
	end
	if duration and duration > 0 then
		task.delay(duration, function() object:Close() end)
	end

	table.insert(Layer.Active, object)
	while #Layer.Active > cfg.Max do Layer.Active[1]:Close() end

	-- entrance
	if animation == "Slide" then
		surface.Position = UDim2.fromOffset(side * 60, 0)
	elseif animation == "Drop" then
		surface.Position = UDim2.fromScale(0, fromBottom and 0.35 or -0.35)
	end
	if opts.Sound ~= false and cfg.Sound then Sound.Play(NOTIFY_SOUNDS[kind]) end
	Util.FadeCanvas(card, 0, 0.32, "Out")
	if animation == "Pop" then
		Util.Tween(pop, 0.4, { Scale = 1 }, "Back")
	else
		Util.Tween(surface, 0.4, { Position = UDim2.new() }, animation == "Slide" and "Out" or "Back")
	end
	task.delay(0.25, function() Fx.Pop(icon, 16) end)
	return object
end

--- Vesper:SetNotifyOptions({ Position, Width, Gap, Margin, Max, Duration, Scale, Compact, Animation, Progress, Sound, Closable })
function Vesper:SetNotifyOptions(o)
	if type(o) ~= "table" then return end
	local cfg = Layer.Options
	if NOTIFY_ANCHORS[o.Position] then cfg.Position = o.Position end
	if type(o.Width) == "number" then cfg.Width = Util.Clamp(o.Width, 180, 640) end
	if type(o.Gap) == "number" then cfg.Gap = Util.Clamp(o.Gap, 0, 40) end
	if type(o.Margin) == "number" then cfg.Margin = Util.Clamp(o.Margin, 0, 120) end
	if type(o.Max) == "number" then cfg.Max = Util.Clamp(math.floor(o.Max), 1, 12) end
	if type(o.Duration) == "number" then cfg.Duration = math.max(o.Duration, 0) end
	if type(o.Scale) == "number" then cfg.Scale = Util.Clamp(o.Scale, 0.6, 1.6) end
	if type(o.Compact) == "boolean" then cfg.Compact = o.Compact end
	if ANIMATIONS[o.Animation] then cfg.Animation = o.Animation end
	if type(o.Progress) == "boolean" then cfg.Progress = o.Progress end
	if type(o.Sound) == "boolean" then cfg.Sound = o.Sound end
	if type(o.Closable) == "boolean" then cfg.Closable = o.Closable end
	if Layer.NotifyHolder then Layer.ApplyOptions() end
end

function Vesper:GetNotifyOptions() return table.clone(Layer.Options) end

function Vesper:SetNotifyPosition(pos)
	if NOTIFY_ANCHORS[pos] then Vesper:SetNotifyOptions({ Position = pos }) end
end

--- Standalone popup, not tied to a window
function Vesper:Popup(opts)
	Layer.Init()
	return Util.Dialog(Layer.Host.Root, opts or {})
end

-- ─────────────────────────────────────────────────────────────
--  Window
-- ─────────────────────────────────────────────────────────────
local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab
local TabSection = {}
TabSection.__index = TabSection

local SIDEBAR_W, SIDEBAR_C, TOPBAR_H = 188, 58, 50
local PILL_W, PILL_H = 250, 42
local HANDLE_H = 22    -- room kept under the window for the move handle
local EDGE = 8         -- the window never gets closer than this to the screen edge

-- How see-through the layers are (the animated background shows through them)
local Look = { Panel = 0.34, Card = 0.1, Sidebar = 0.08 }

local function setOrTween(inst, time, props, instant, ease)
	if instant then
		for k, v in props do inst[k] = v end
	else
		Util.Tween(inst, time, props, ease)
	end
end

--- Small square icon button used in the top bar / pill
local function iconButton(parent, icon, size, order, filled)
	local rest = filled and 0 or 1
	local btn = New("TextButton", { Size = UDim2.fromOffset(size, size), LayoutOrder = order or 0, BackgroundTransparency = rest, Parent = parent })
	btn.BackgroundColor3 = WHITE
	Theme.Bind(btn, { BackgroundColor3 = "Input" })
	Util.Corner(btn, 9)
	local img = Util.Icon(btn, icon, 16, "SubText", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	btn.MouseEnter:Connect(function()
		Util.Tween(btn, 0.14, { BackgroundTransparency = 0 }, "Quad")
		Theme.Bind(img, { ImageColor3 = "Text" })
	end)
	btn.MouseLeave:Connect(function()
		Util.Tween(btn, 0.14, { BackgroundTransparency = rest }, "Quad")
		Theme.Bind(img, { ImageColor3 = "SubText" })
	end)
	btn.MouseButton1Down:Connect(function() Util.Tween(img, 0.08, { Size = UDim2.fromOffset(13, 13) }, "Quad") end)
	btn.MouseButton1Up:Connect(function() Util.Tween(img, 0.2, { Size = UDim2.fromOffset(16, 16) }, "Back") end)
	btn.Activated:Connect(function() Fx.Click(btn, { Radius = UDim.new(0, 9) }) end)
	Util.SetPart(btn, "Image", img)
	return btn
end
Util.IconButton = iconButton

--- Logo tile: accent gradient with a Lucide icon, or a custom image
local function makeLogo(parent, icon, size, radius)
	local tile = New("Frame", { Name = "Logo", Size = UDim2.fromOffset(size, size), BackgroundColor3 = WHITE, Parent = parent })
	Util.Corner(tile, radius)
	local data = Icons.Resolve(icon or "sparkles", 48)
	if data and not data.Lucide then
		tile.BackgroundTransparency = 1
		Util.Corner(New("ImageLabel", { Size = UDim2.fromScale(1, 1), Image = data.Image, Parent = tile }), radius)
	else
		Theme.AccentGradient(tile, 45)
		Util.SetPart(tile, "Icon", Util.Icon(tile, icon or "sparkles", math.floor(size * 0.5), "AccentText", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) }))
	end
	return tile
end
Util.MakeLogo = makeLogo

function Vesper:CreateWindow(opts)
	opts = opts or {}
	local self = setmetatable({}, Window)
	self.Maid = Maid.new()
	self.Opts = opts
	self.Tabs, self.FooterTabs, self.TabSections = {}, {}, {}
	self.Flags = {}
	self.Visible, self.Minimized, self.Fullscreen, self.Collapsed = false, false, false, false
	self.Destroyed = false
	self.ToggleKey = Util.ParseKeyCode(opts.ToggleKey) or Enum.KeyCode.RightShift
	self.Folder = opts.Folder or "Vesper"
	self.Opacity = Util.Clamp(opts.Opacity or 0, 0, 0.6)
	self.UserScale = Util.Clamp(opts.Scale or 1, 0.6, 1.5)
	self.ConfirmClose = opts.ConfirmClose ~= false
	self.Resizable = opts.Resizable ~= false
	self.HandleEnabled = opts.Handle ~= false and opts.ToggleHandle ~= false
	self.Density = "Normal"
	self.AutoDensity = opts.Density == nil or opts.Density == "Auto"
	self._tabCounter = 0
	self._index = {}
	self._dense = {}

	-- intro: true (default) | false | "Horizon" | "Pop" | "None" | { Style, Duration, Title, Subtitle }
	local introCfg = { Style = "Horizon", Duration = 1.9 }
	local intro = opts.Intro
	if intro == false or intro == "None" then
		introCfg.Style = "None"
	elseif type(intro) == "string" then
		introCfg.Style = intro
	elseif type(intro) == "table" then
		for k, v in intro do introCfg[k] = v end
	end
	self._introCfg = introCfg

	if opts.Sounds ~= nil then Sound.Enabled = opts.Sounds end
	if opts.Localization then Vesper:Localization(opts.Localization) end
	Layer.Init()
	if opts.Theme and Theme.Themes[opts.Theme] then Theme.Set(opts.Theme, true) end
	if opts.Background then Theme.SetStyle(opts.Background) end

	-- Size ────────────────────────────────────────────────
	local touch = Util.IsTouch()
	local W, H = touch and 560 or 700, touch and 340 or 430
	if typeof(opts.Size) == "UDim2" then W, H = opts.Size.X.Offset, opts.Size.Y.Offset
	elseif typeof(opts.Size) == "Vector2" then W, H = opts.Size.X, opts.Size.Y end
	self.DesignSize = Vector2.new(W, H)
	self.Size = Vector2.new(W, H)
	local mn = opts.MinSize or Vector2.new(460, 300)
	self.MinSize = typeof(mn) == "UDim2" and Vector2.new(mn.X.Offset, mn.Y.Offset) or mn
	self.Offset = Vector2.zero

	-- Host + root structure ───────────────────────────────
	self.Host = Host.new(1000)
	local root = self.Host.Root

	local holder, main = Util.Surface(root, {
		Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H), Visible = false,
	}, 16)
	self.Holder, self.Main = holder, main
	Theme.WindowGradient(main, 35)
	self.Scaler = New("UIScale", { Scale = 0.95, Parent = holder })

	self.Backdrop = Fx.Backdrop(main, 0)
	self.Gloss = Fx.Gloss(main, 1)

	self.Overlay = New("Frame", { Name = "Overlay", BackgroundTransparency = 1, Active = false, Size = UDim2.fromScale(1, 1), ZIndex = 100, Parent = root })

	-- Sidebar ─────────────────────────────────────────────
	local sidebar = New("Frame", { Name = "Sidebar", Size = UDim2.new(0, SIDEBAR_W, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = Look.Sidebar, ZIndex = 2, Parent = main })
	Theme.Bind(New("UIGradient", { Rotation = 90, Parent = sidebar }), {
		Color = function(t) return ColorSequence.new(t.Sidebar, t.Sidebar2) end,
	})
	self.Sidebar = sidebar
	Util.FadeLine(sidebar, { Vertical = true, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 1, 1, 0), Strength = 0.45, ZIndex = 5 })

	local header = New("TextButton", { Name = "Header", Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, Parent = sidebar })
	self.HeaderDrag = header
	local logo = makeLogo(header, opts.Icon or "sparkles", 34, 10)
	logo.AnchorPoint = Vector2.new(0, 0.5)
	logo.Position = UDim2.new(0, 14, 0.5, 0)
	self.Logo = logo
	local htexts = New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 58, 0, 0), Size = UDim2.new(1, -66, 1, 0), Parent = header })
	Util.List(htexts, 1, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	self.TitleLabel = New("TextLabel", { Weight = "SemiBold", TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = htexts })
	Theme.Bind(self.TitleLabel, { TextColor3 = "Text" })
	Util.SetText(self.TitleLabel, opts.Title or "Vesper")
	self.SubtitleLabel = New("TextLabel", { TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 2, Parent = htexts })
	Theme.Bind(self.SubtitleLabel, { TextColor3 = "Muted" })
	Util.SetText(self.SubtitleLabel, opts.Subtitle or opts.Author or "")
	self.SubtitleLabel.Visible = (opts.Subtitle or opts.Author) ~= nil
	Util.FadeLine(sidebar, { Position = UDim2.new(0, 10, 0, 63), Size = UDim2.new(1, -20, 0, 1), Strength = 0.5, ZIndex = 4 })

	self.TabScroll = New("ScrollingFrame", {
		Name = "Tabs", Position = UDim2.new(0, 0, 0, 66), Size = UDim2.new(1, 0, 1, -66), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = sidebar,
	})
	Util.Padding(self.TabScroll, 6, 10, 10, 10)
	Util.List(self.TabScroll, 4)

	self.Footer = New("Frame", { Name = "Footer", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = sidebar })
	Util.Padding(self.Footer, 6, 10, 10, 10)
	Util.List(self.Footer, 4)
	self.FooterLine = Util.FadeLine(sidebar, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -1), Size = UDim2.new(1, -20, 0, 1), Strength = 0.4, ZIndex = 4 })
	self.FooterLine.Visible = false

	-- Content: top bar + pages ───────────────────────────
	local content = New("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.new(0, SIDEBAR_W, 0, 0), Size = UDim2.new(1, -SIDEBAR_W, 1, 0), ClipsDescendants = true, ZIndex = 2, Parent = main })
	self.Content = content

	local topbar = New("Frame", { Name = "Topbar", Size = UDim2.new(1, 0, 0, TOPBAR_H), BackgroundTransparency = 1, Parent = content })
	self.Topbar = topbar
	self.TopbarDrag = New("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = topbar })
	Util.FadeLine(topbar, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), Strength = 0.4, ZIndex = 4 })

	local left = New("Frame", { Name = "Left", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 18, 0.5, 0), Size = UDim2.new(0, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.X, Parent = topbar })
	Util.List(left, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	self.PageTitle = New("TextLabel", { Weight = "Medium", TextSize = 19, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Parent = left })
	Theme.Bind(self.PageTitle, { TextColor3 = "Text" })
	self.TagHolder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = left })
	Util.List(self.TagHolder, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

	local right = New("Frame", { Name = "Right", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.new(0, 0, 0, 30), AutomaticSize = Enum.AutomaticSize.X, Parent = topbar })
	Util.List(right, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

	-- search pill (results panel lives in window/search section)
	local search = New("Frame", { Name = "Search", Size = UDim2.fromOffset(160, 30), LayoutOrder = 1, BackgroundColor3 = WHITE, Parent = right })
	Theme.Bind(search, { BackgroundColor3 = "Input" })
	Util.Corner(search, 10)
	Util.Shade(search, 90, 0.07)
	self.SearchFrame = search
	Util.Icon(search, "search", 15, "SubText", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0) })
	local searchBox = New("TextBox", {
		Weight = "Medium", PlaceholderText = "Search everything", Text = "", TextSize = 13, Position = UDim2.new(0, 32, 0, 0), Size = UDim2.new(1, -62, 1, 0),
		ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = search,
	})
	Theme.Bind(searchBox, { TextColor3 = "Text", PlaceholderColor3 = "Muted" })
	self.SearchBox = searchBox
	local searchGlow = Util.FadeLine(search, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(0, 0, 0, 2), Strength = 1, Token = "Accent", ZIndex = 4, Thickness = 2, Style = "Edges" })
	self.SearchGlow = searchGlow
	local keyHint = New("TextLabel", {
		Weight = "SemiBold", TextSize = 10, Text = "/", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0), Size = UDim2.fromOffset(14, 14),
		TextXAlignment = Enum.TextXAlignment.Center, Parent = search,
	})
	Theme.Bind(keyHint, { TextColor3 = "Muted" })
	self.SearchHint = keyHint
	if opts.Search == false then search.Visible = false end

	self.CollapseBtn = iconButton(right, "chevrons-right", 30, 2, true)
	self.CollapseBtn.Activated:Connect(function() Sound.Play("Click"); self:SetSidebarCollapsed(not self.Collapsed) end)
	Util.Part(self.CollapseBtn, "Image").Rotation = 180

	New("Frame", { Size = UDim2.fromOffset(4, 1), BackgroundTransparency = 1, LayoutOrder = 3, Parent = right })
	self.MinBtn = iconButton(right, "minus", 28, 4)
	self.MaxBtn = iconButton(right, "maximize", 28, 5)
	self.CloseBtn = iconButton(right, "x", 28, 6)
	self.MinBtn.Activated:Connect(function() Sound.Play("Click"); self:Minimize() end)
	self.MaxBtn.Activated:Connect(function() Sound.Play("Click"); self:ToggleFullscreen() end)
	self.CloseBtn.Activated:Connect(function() Sound.Play("Click"); self:RequestClose() end)
	self.CloseBtn.MouseEnter:Connect(function() Theme.Bind(Util.Part(self.CloseBtn, "Image"), { ImageColor3 = "Danger" }) end)

	self.Pages = New("Frame", { Name = "Pages", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, TOPBAR_H), Size = UDim2.new(1, 0, 1, -TOPBAR_H), Parent = content })
	Util.Padding(self.Pages, 4, 12, 12, 12)

	-- Resize grip
	local grip = New("TextButton", { Name = "Resize", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(22, 22), ZIndex = 20, Parent = main })
	Util.Icon(grip, "move-diagonal-2", 11, "Muted", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -6), Rotation = 90 })
	self.ResizeGrip = grip
	grip.Visible = self.Resizable

	-- Behaviour ───────────────────────────────────────────
	self.Host:OnViewport(function() self:_Rescale() end)
	self:_SetupInteractions()
	self:_SetupSearch()
	self:_SetupStats()

	self.Maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if self.Destroyed or self._locked or Vesper._KeyListening then return end
		if input.KeyCode == self.ToggleKey and not processed then
			self:Toggle()
		elseif input.KeyCode == Enum.KeyCode.Slash and not processed and self.Visible and not self.Minimized and opts.Search ~= false then
			task.defer(function()
				searchBox:CaptureFocus()
				task.defer(function() if searchBox.Text == "/" then searchBox.Text = "" end end)
			end)
		end
	end))

	self:_MakeHandle()
	table.insert(Vesper.Windows, self)
	if Config and Config.Attach then Config.Attach(self) end
	self:_OnResized()

	if opts.KeySystem then
		self._locked = true
		Vesper._KeyGate(self, opts.KeySystem)
	else
		self:Show()
	end

	task.defer(function()
		if opts.BuiltIn and not self.Destroyed then self:AddBuiltIn(opts.BuiltIn) end
	end)
	return self
end

-- ─────────────────────────────────────────────────────────────
--  Sizing / scaling / density
--  The interface shrinks in two ways: the whole thing scales a little on small
--  screens, and below that the window itself gets smaller and its controls get
--  tighter ("Compact" density) so everything still fits properly.
-- ─────────────────────────────────────────────────────────────
function Window:_OnDensity(fn)
	self._dense[fn] = true
	fn(self.Density == "Compact")
	return function() self._dense[fn] = nil end
end

function Window:_ApplyDensity(mode)
	if self.Density == mode then return end
	self.Density = mode
	local compact = mode == "Compact"
	for fn in self._dense do pcall(fn, compact) end
end

--- "Normal" | "Compact" | "Auto"
function Window:SetDensity(mode)
	if mode == "Auto" then
		self.AutoDensity = true
		self:_OnResized()
	else
		self.AutoDensity = false
		self:_ApplyDensity(mode == "Compact" and "Compact" or "Normal")
	end
end

function Window:_Rescale()
	local vp = Util.Viewport()
	local s = Util.Clamp(math.min(vp.X / 940, vp.Y / 560), 0.72, 1) * self.UserScale
	self.Host:SetScale(s)
	self:_ClampSize()
end

--- Largest size the window may have in logical pixels
function Window:_MaxSize()
	local logical = self.Host:LogicalSize()
	local reserve = self.HandleEnabled and HANDLE_H or 0
	return Vector2.new(math.max(300, logical.X - EDGE * 2), math.max(240, logical.Y - EDGE * 2 - reserve))
end

function Window:_ClampSize()
	local max = self:_MaxSize()
	if self.Fullscreen then
		self.Size, self.Offset = max, Vector2.zero
	end
	local w = Util.Clamp(self.Size.X, math.min(self.MinSize.X, max.X), max.X)
	local h = Util.Clamp(self.Size.Y, math.min(self.MinSize.Y, max.Y), max.Y)
	self.Size = Vector2.new(w, h)
	if not self._introPlaying then self.Holder.Size = UDim2.fromOffset(w, h) end
	self:_SetOffset(self.Offset)
	self:_OnResized()
end

--- Keeps a surface of `size` (centre offset `off`) fully on screen. Returns the corrected offset.
function Window:_Clamped(off, size, reserve)
	local logical = self.Host:LogicalSize()
	local halfW, halfH = size.X / 2, size.Y / 2
	local maxX = math.max(0, logical.X / 2 - EDGE - halfW)
	local minY, maxY = EDGE - logical.Y / 2 + halfH, logical.Y / 2 - EDGE - halfH - (reserve or 0)
	if minY > maxY then minY, maxY = 0, 0 end
	return Vector2.new(Util.Clamp(off.X, -maxX, maxX), Util.Clamp(off.Y, minY, maxY))
end

function Window:_SetOffset(off)
	local reserve = self.HandleEnabled and HANDLE_H or 0
	self.Offset = self:_Clamped(off, self.Size, reserve)
	self.Holder.Position = UDim2.new(0.5, self.Offset.X, 0.5, self.Offset.Y)
	self:_UpdateHandle()
end

function Window:_SetPillOffset(off)
	local reserve = self.HandleEnabled and HANDLE_H or 0
	self.PillOffset = self:_Clamped(off, Vector2.new(PILL_W, PILL_H), reserve)
	self.Pill.Position = UDim2.new(0.5, self.PillOffset.X, 0.5, self.PillOffset.Y)
	self:_UpdateHandle()
end

function Window:_OnResized()
	local w = self.Size.X
	if w < 590 and not self.Collapsed then
		self:SetSidebarCollapsed(true, true)
	elseif w >= 620 and self.Collapsed and self._autoCollapsed then
		self:SetSidebarCollapsed(false, true)
	end
	self.TagHolder.Visible = w > 600
	self.SearchFrame.Size = UDim2.fromOffset(w < 600 and 120 or 160, 30)
	if self.AutoDensity then
		self:_ApplyDensity((self.Size.X < 600 or self.Size.Y < 360) and "Compact" or "Normal")
	end
end

function Window:SetScale(s)
	self.UserScale = Util.Clamp(s, 0.6, 1.5)
	self:_Rescale()
end

function Window:SetOpacity(o)
	self.Opacity = Util.Clamp(o, 0, 0.6)
	if self.Visible and not self.Minimized and not self._introPlaying then
		Util.FadeCanvas(self.Main, self.Opacity, 0.2, "Quad")
	end
end

-- ─────────────────────────────────────────────────────────────
--  Sidebar collapse
-- ─────────────────────────────────────────────────────────────
function Window:SetSidebarCollapsed(collapsed, auto, instant)
	if self.Collapsed == collapsed then return end
	self.Collapsed = collapsed
	self._autoCollapsed = auto == true
	local w = collapsed and SIDEBAR_C or SIDEBAR_W
	setOrTween(self.Sidebar, 0.3, { Size = UDim2.new(0, w, 1, 0) }, instant)
	setOrTween(self.Content, 0.3, { Position = UDim2.new(0, w, 0, 0), Size = UDim2.new(1, -w, 1, 0) }, instant)
	setOrTween(Util.Part(self.CollapseBtn, "Image"), 0.3, { Rotation = collapsed and 0 or 180 }, instant)
	setOrTween(self.Logo, 0.3, {
		AnchorPoint = collapsed and Vector2.new(0.5, 0.5) or Vector2.new(0, 0.5),
		Position = collapsed and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(0, 14, 0.5, 0),
	}, instant)
	setOrTween(self.TitleLabel, 0.2, { TextTransparency = collapsed and 1 or 0 }, instant)
	setOrTween(self.SubtitleLabel, 0.2, { TextTransparency = collapsed and 1 or 0 }, instant)
	for _, tab in self.Tabs do tab:_ApplyCollapse(collapsed, instant) end
	for _, tab in self.FooterTabs do tab:_ApplyCollapse(collapsed, instant) end
	for _, section in self.TabSections do section:_ApplyCollapse(collapsed, instant) end
end

-- ─────────────────────────────────────────────────────────────
--  Tooltip (used by sidebar icons while the sidebar is collapsed)
-- ─────────────────────────────────────────────────────────────
function Window:_ShowTip(anchor, text)
	if not self._tip then
		local frame = New("Frame", {
			Name = "Tip", AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1, ZIndex = 150, Visible = false, Parent = self.Overlay,
		})
		Theme.Bind(frame, { BackgroundColor3 = "Popup" })
		Util.Corner(frame, 8)
		Util.Padding(frame, 0, 10, 0, 10)
		Shadow.Edge(frame, { Alpha = 0.7, Inset = 4 })
		local label = New("TextLabel", { Weight = "Medium", TextSize = 12, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextTransparency = 1, Parent = frame })
		Theme.Bind(label, { TextColor3 = "Text" })
		self._tip = { Frame = frame, Label = label }
	end
	local tip = self._tip
	local scale = self.Host:GetScale()
	local rel = (anchor.AbsolutePosition - self.Host.Root.AbsolutePosition) / scale
	local asz = anchor.AbsoluteSize / scale
	Util.SetText(tip.Label, text)
	tip.Frame.Position = UDim2.fromOffset(rel.X + asz.X + 10, rel.Y + asz.Y / 2)
	tip.Frame.Visible = true
	tip.Frame.BackgroundTransparency = 1
	Util.Tween(tip.Frame, 0.15, { BackgroundTransparency = 0.05 }, "Quad")
	Util.Tween(tip.Label, 0.15, { TextTransparency = 0 }, "Quad")
end

function Window:_HideTip()
	local tip = self._tip
	if not tip then return end
	Util.Tween(tip.Frame, 0.1, { BackgroundTransparency = 1 }, "Quad")
	Util.Tween(tip.Label, 0.1, { TextTransparency = 1 }, "Quad")
	task.delay(0.12, function()
		if tip.Label.TextTransparency >= 0.99 then tip.Frame.Visible = false end
	end)
end

-- ─────────────────────────────────────────────────────────────
--  Tabs
--  The active tab gets a gradient wash and two fading hairlines instead of a stroke,
--  so it looks the same expanded and collapsed to icons.
-- ─────────────────────────────────────────────────────────────
function Tab:_ApplyCollapse(collapsed, instant)
	setOrTween(self.Label, 0.2, { TextTransparency = collapsed and 1 or 0 }, instant)
	setOrTween(self.Icon, 0.3, {
		AnchorPoint = collapsed and Vector2.new(0.5, 0.5) or Vector2.new(0, 0.5),
		Position = collapsed and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(0, 14, 0.5, 0),
	}, instant)
end

function Tab:_Paint(active, instant)
	self.Active = active
	local iconColor = Theme.Resolve(active and "Accent" or "SubText")
	local textColor = Theme.Resolve(active and "Text" or "SubText")
	setOrTween(self.Fill, 0.25, { BackgroundTransparency = active and 0.78 or 1 }, instant, "Quad")
	setOrTween(self.LineTop, 0.25, { BackgroundTransparency = active and 0 or 1 }, instant, "Quad")
	setOrTween(self.LineBottom, 0.25, { BackgroundTransparency = active and 0 or 1 }, instant, "Quad")
	setOrTween(self.Icon, 0.2, { ImageColor3 = iconColor }, instant, "Quad")
	setOrTween(self.Label, 0.2, { TextColor3 = textColor }, instant, "Quad")
	setOrTween(self.Bar, 0.3, { Size = UDim2.fromOffset(3, active and 20 or 0) }, instant, active and "Back" or "Quad")
end

function Window:_BuildTabButton(parent, opts, tab, order)
	local btn = New("TextButton", { Name = "Tab", Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	Util.Corner(btn, 10)
	tab.NavButton = btn

	-- gradient wash that fades out to the right
	tab.Fill = New("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Active = false, Parent = btn })
	Util.Corner(tab.Fill, 10)
	local fillGrad = New("UIGradient", { Transparency = NumberSequence.new({ kp(0, 0), kp(0.55, 0.45), kp(1, 1) }), Parent = tab.Fill })
	Theme.Bind(fillGrad, { Color = Theme.AccentSeq })

	tab.LineTop = Util.FadeLine(btn, { Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(1, -8, 0, 1), Style = "Left", Strength = 1, Token = "Accent", ZIndex = 2, Thickness = 1 })
	tab.LineBottom = Util.FadeLine(btn, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, 0), Size = UDim2.new(1, -8, 0, 1), Style = "Left", Strength = 0.7, Token = "Accent", ZIndex = 2, Thickness = 1 })
	tab.LineTop.BackgroundTransparency = 1
	tab.LineBottom.BackgroundTransparency = 1

	tab.Icon = Util.Icon(btn, opts.Icon or "layout-dashboard", 18, "SubText", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), ZIndex = 3 })
	Theme.Bind(tab.Icon, { ImageColor3 = function(t) return tab.Active and t.Accent or t.SubText end })
	tab.Label = New("TextLabel", { Weight = "Medium", TextSize = 14, Position = UDim2.new(0, 44, 0, 0), Size = UDim2.new(1, -52, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = btn })
	Theme.Bind(tab.Label, { TextColor3 = function(t) return tab.Active and t.Text or t.SubText end })
	Util.SetText(tab.Label, opts.Title or "Tab")
	tab.Bar = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(3, 0), BackgroundColor3 = WHITE, ZIndex = 3, Parent = btn })
	Util.Corner(tab.Bar, 2)
	Theme.AccentGradient(tab.Bar, 90)

	btn.MouseEnter:Connect(function()
		if not tab.Active then
			Util.Tween(tab.Fill, 0.14, { BackgroundTransparency = 0.9 }, "Quad")
			Util.Tween(tab.Icon, 0.14, { ImageColor3 = Theme.Resolve("Text") }, "Quad")
		end
		if self.Collapsed then self:_ShowTip(btn, tab.Title) end
	end)
	btn.MouseLeave:Connect(function()
		if not tab.Active then
			Util.Tween(tab.Fill, 0.14, { BackgroundTransparency = 1 }, "Quad")
			Util.Tween(tab.Icon, 0.14, { ImageColor3 = Theme.Resolve("SubText") }, "Quad")
		end
		self:_HideTip()
	end)
	btn.Activated:Connect(function()
		Sound.Play("Select")
		Fx.Click(btn, { Radius = UDim.new(0, 10) })
		Fx.Pop(tab.Icon, 12)
		self:_CloseSearch(true)
		self:SelectTab(tab)
	end)
end

function Window:_NewTab(opts, parent, footer)
	if type(opts) == "string" then opts = { Title = opts } end
	opts = opts or {}
	local tab = setmetatable({}, Tab)
	tab.Window, tab.Title, tab.Footer = self, opts.Title or "Tab", footer
	tab.IconName = opts.Icon or "layout-dashboard"
	tab.Active = false
	self._tabCounter += 1
	tab.Order = self._tabCounter

	self:_BuildTabButton(parent, opts, tab, footer and (1000 + tab.Order) or tab.Order)

	tab.Page = New("CanvasGroup", { Name = "Page", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, GroupTransparency = 1, Parent = self.Pages })
	tab.Panel = New("ScrollingFrame", {
		Name = "Panel", Size = UDim2.fromScale(1, 1), BackgroundTransparency = Look.Panel, BackgroundColor3 = WHITE,
		ScrollBarThickness = 3, ScrollBarImageTransparency = 0.45, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, VerticalScrollBarInset = Enum.ScrollBarInset.None, Parent = tab.Page,
	})
	Theme.Bind(tab.Panel, { BackgroundColor3 = "Surface", ScrollBarImageColor3 = "Muted" })
	Util.Corner(tab.Panel, 14)
	Util.Padding(tab.Panel, 10, 10, 12, 10)
	tab.PanelList = Util.List(tab.Panel, 8)

	Elements.Attach(tab, tab.Panel, self, tab)
	tab.Type = "Tab"
	tab._entries = {}
	table.insert(footer and self.FooterTabs or self.Tabs, tab)
	if footer then self:_UpdateFooter() end
	tab:_ApplyCollapse(self.Collapsed, true)

	-- searchable like everything else
	tab._indexEntry = { Kind = "tab", Tab = tab, Type = "Tab", Icon = tab.IconName, RawTitle = tab.Title, RawDesc = "", Frame = tab.NavButton, Dead = false }
	table.insert(self._index, tab._indexEntry)

	if not self.SelectedTab and not footer then self:SelectTab(tab, true) end
	return tab
end

function Window:Tab(opts) return self:_NewTab(opts, self.TabScroll, false) end
function Window:_FooterTab(opts) return self:_NewTab(opts, self.Footer, true) end

function Window:_UpdateFooter()
	local n = #self.FooterTabs
	local h = n > 0 and (n * 42 + 16) or 0
	self.TabScroll.Size = UDim2.new(1, 0, 1, -66 - h)
	self.FooterLine.Visible = n > 0
end

function Window:SelectTab(tab, instant)
	if type(tab) == "number" then
		tab = self.Tabs[tab]
	elseif type(tab) == "string" then
		-- by title (main tabs first, then the footer ones)
		local found
		for _, list in { self.Tabs, self.FooterTabs } do
			for _, t in list do
				if t.Title == tab then found = t; break end
			end
			if found then break end
		end
		tab = found
	end
	if type(tab) ~= "table" or tab.Destroyed or tab.Window ~= self or self.SelectedTab == tab then return end
	local prev = self.SelectedTab
	self.SelectedTab = tab
	if self.Host._popover then self.Host._popover.Close() end

	if prev then
		prev:_Paint(false, instant)
		local page = prev.Page
		Util.Tween(page, 0.12, { GroupTransparency = 1 }, "Quad")
		task.delay(0.13, function() if self.SelectedTab ~= prev then page.Visible = false end end)
	end
	tab:_Paint(true, instant)
	local page = tab.Page
	page.Visible = true
	if instant then
		page.GroupTransparency = 0
		page.Position = UDim2.new()
	else
		page.Position = UDim2.fromOffset(0, 12)
		task.delay(0.08, function()
			if self.SelectedTab ~= tab then return end
			Util.Tween(page, 0.34, { GroupTransparency = 0, Position = UDim2.new() }, "Out")
			Fx.Scan(page)
		end)
	end

	-- animated page title
	local title = self.PageTitle
	if instant then
		Util.SetText(title, tab.Title)
	else
		Util.Tween(title, 0.1, { TextTransparency = 1 }, "Quad")
		task.delay(0.1, function()
			Util.SetText(title, tab.Title)
			Util.Tween(title, 0.2, { TextTransparency = 0 }, "Quad")
		end)
	end
end

function Tab:Select() self.Window:SelectTab(self) end
function Tab:SetTitle(title)
	self.Title = title
	Util.SetText(self.Label, title)
	if self._indexEntry then self._indexEntry.RawTitle = title end
	if self.Window.SelectedTab == self then Util.SetText(self.Window.PageTitle, title) end
end
function Tab:SetIcon(icon)
	self.IconName = icon
	local tinted = Icons.Apply(self.Icon, icon, 18, "SubText")
	if tinted and Icons.Resolve(icon, 18) and Icons.Resolve(icon, 18).Lucide then
		Theme.Bind(self.Icon, { ImageColor3 = function(t) return self.Active and t.Accent or t.SubText end })
	end
	if self._indexEntry then self._indexEntry.Icon = icon end
end
function Tab:Destroy()
	local w = self.Window
	local list = self.Footer and w.FooterTabs or w.Tabs
	local idx = table.find(list, self)
	if idx then table.remove(list, idx) end
	if self._indexEntry then
		self._indexEntry.Dead = true
		local at = table.find(w._index, self._indexEntry)
		if at then table.remove(w._index, at) end
	end
	self.Destroyed = true
	-- drops every control (search entries, flags, density hooks), nested sections included
	for _, entry in table.clone(self._entries) do Elements.Unregister(entry.Container or self, entry) end
	self.NavButton:Destroy(); self.Page:Destroy()
	if w.SelectedTab == self then
		w.SelectedTab = nil
		local nxt = w.Tabs[1] or w.FooterTabs[1]
		if nxt then w:SelectTab(nxt, true) end
	end
	if self.Footer then w:_UpdateFooter() end
end

-- ─────────────────────────────────────────────────────────────
--  Tab section (group of tabs in the sidebar)
-- ─────────────────────────────────────────────────────────────
function Window:TabSection(opts)
	if type(opts) == "string" then opts = { Title = opts } end
	opts = opts or {}
	local section = setmetatable({}, TabSection)
	section.Window = self
	self._tabCounter += 1
	local frame = New("Frame", { Name = "TabSection", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = self._tabCounter, Parent = self.TabScroll })
	Util.List(frame, 4)
	local head = New("TextButton", { Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0, Parent = frame })
	section.Label = New("TextLabel", { Weight = "SemiBold", TextSize = 11, Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(1, -30, 1, 0), Parent = head })
	Theme.Bind(section.Label, { TextColor3 = "Muted" })
	Util.SetText(section.Label, opts.Title or "Section")
	section.Line = Util.FadeLine(head, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.new(1, -8, 0, 1), Strength = 0.6, ZIndex = 2, Thickness = 1 })
	section.Line.BackgroundTransparency = 1
	local chevron = Util.Icon(head, "chevron-down", 13, "Muted", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0) })
	chevron.Visible = opts.Collapsible == true
	section.Body = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = frame })
	Util.List(section.Body, 4)

	section.Opened = opts.Opened ~= false
	function section.SetOpen(open)
		section.Opened = open
		section.Body.Visible = open
		Util.Tween(chevron, 0.2, { Rotation = open and 0 or -90 }, "Quad")
	end
	if opts.Collapsible then
		head.Activated:Connect(function()
			section.SetOpen(not section.Opened)
			Sound.Play("Click")
		end)
		if not section.Opened then section.Body.Visible = false; chevron.Rotation = -90 end
	else
		head.Active = false
	end
	table.insert(self.TabSections, section)
	function section:Tab(tabOpts)
		local tab = self.Window:_NewTab(tabOpts, self.Body, false)
		tab.TabSection = self
		return tab
	end
	return section
end

function TabSection:_ApplyCollapse(collapsed, instant)
	setOrTween(self.Label, 0.2, { TextTransparency = collapsed and 1 or 0 }, instant)
	setOrTween(self.Line, 0.2, { BackgroundTransparency = collapsed and 0 or 1 }, instant)
end

-- ─────────────────────────────────────────────────────────────
--  Window behaviour: drag, resize, move handle, minimise pill
-- ─────────────────────────────────────────────────────────────
local function v2(pos) return Vector2.new(pos.X, pos.Y) end

--- One-shot accent line sweeping down a surface (used when a page opens)
function Fx.Scan(target, o)
	if not Fx.Enabled or not target or not target.Parent then return end
	o = o or {}
	local line = Util.FadeLine(target, {
		Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 2), Strength = 0.9, Token = "Accent", ZIndex = 30, Thickness = 2, Style = "Edges",
	})
	local dur = o.Duration or 0.5
	Util.Tween(line, dur, { Position = UDim2.new(0, 0, 1, -2) }, "Quad")
	Util.Tween(line, dur, { BackgroundTransparency = 1 }, "In")
	task.delay(dur + 0.05, function() line:Destroy() end)
end

function Window:_SetupInteractions()
	local host = self.Host
	local main = self.Main

	-- Dragging (top bar + sidebar header). The window is always kept fully on screen.
	local function bindDrag(handle)
		local startPos, startOffset
		self.Maid:Give(Util.Drag(handle, function(pos)
			if not startPos then return end
			self:_SetOffset(startOffset + (v2(pos) - startPos) / host:GetScale())
		end, function(input)
			if self.Fullscreen or self._introPlaying then return false end
			startPos, startOffset = v2(input.Position), self.Offset
			if host._popover then host._popover.Close() end
		end, function() startPos = nil end))
	end
	bindDrag(self.TopbarDrag)
	bindDrag(self.HeaderDrag)

	-- Resizing (bottom-right grip)
	local rStart, rSize, rOffset
	self.Maid:Give(Util.Drag(self.ResizeGrip, function(pos)
		if not rStart then return end
		local d = (v2(pos) - rStart) / host:GetScale()
		local max = self:_MaxSize()
		local w = Util.Clamp(rSize.X + d.X, math.min(self.MinSize.X, max.X), max.X)
		local h = Util.Clamp(rSize.Y + d.Y, math.min(self.MinSize.Y, max.Y), max.Y)
		self.Size = Vector2.new(w, h)
		self.Holder.Size = UDim2.fromOffset(w, h)
		self.Offset = rOffset + (self.Size - rSize) / 2
		self:_SetOffset(self.Offset)
		self:_OnResized()
	end, function(input)
		if self.Fullscreen or self._introPlaying then return false end
		rStart, rSize, rOffset = v2(input.Position), self.Size, self.Offset
		if host._popover then host._popover.Close() end
		Util.Tween(self.ResizeGrip, 0.1, { Size = UDim2.fromOffset(26, 26) }, "Quad")
	end, function()
		rStart = nil
		Util.Tween(self.ResizeGrip, 0.2, { Size = UDim2.fromOffset(22, 22) }, "Quad")
	end))

	-- Minimised pill
	local pill, pcanvas = Util.Surface(host.Root, {
		Name = "Pill", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(PILL_W, PILL_H), Visible = false,
	}, 14)
	self.Pill, self.PillCanvas = pill, pcanvas
	Theme.WindowGradient(pcanvas, 35)
	local pillDrag = New("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = pcanvas })
	local plogo = makeLogo(pcanvas, self.Opts.Icon or "sparkles", 28, 8)
	plogo.AnchorPoint = Vector2.new(0, 0.5)
	plogo.Position = UDim2.new(0, 8, 0.5, 0)
	local ptitle = New("TextLabel", { Weight = "SemiBold", TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.new(0, 44, 0, 0), Size = UDim2.new(1, -120, 1, 0), Parent = pcanvas })
	Theme.Bind(ptitle, { TextColor3 = "Text" })
	Util.SetText(ptitle, self.Opts.Title or "Vesper")
	local pbtns = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.X, Parent = pcanvas })
	Util.List(pbtns, 4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local restore = iconButton(pbtns, "maximize-2", 28, 1)
	local pclose = iconButton(pbtns, "x", 28, 2)
	restore.Activated:Connect(function() Sound.Play("Click"); self:Restore() end)
	pclose.Activated:Connect(function() Sound.Play("Click"); self:RequestClose() end)
	Util.FadeLine(pcanvas, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.7, Token = "Accent", ZIndex = 5, Thickness = 1 })

	self.PillOffset = Vector2.zero
	local pStart, pOffset
	self.Maid:Give(Util.Drag(pillDrag, function(pos)
		if not pStart then return end
		self:_SetPillOffset(pOffset + (v2(pos) - pStart) / host:GetScale())
	end, function(input) pStart, pOffset = v2(input.Position), self.PillOffset end, function() pStart = nil end))
end

-- ── Move handle ──────────────────────────────────────────────
-- The little bar under the window. Drag it to move the window (or the minimised pill);
-- both stay on screen. It never closes or hides anything.
function Window:_MakeHandle()
	local root = self.Host.Root
	local hh, hc = Util.Surface(root, {
		Name = "Handle", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(92, 7), Visible = false, ZIndex = 5,
	}, 4)
	Theme.Bind(hc, { BackgroundColor3 = "Sidebar" })
	Util.Shade(hc, 90, 0.1)
	local glow = New("Frame", { Name = "Glow", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Parent = hc })
	Theme.AccentGradient(glow, 0)
	local dots = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 3), ZIndex = 2, Parent = hc })
	Util.List(dots, 4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	for i = 1, 3 do
		local dot = New("Frame", { Size = UDim2.fromOffset(4, 3), BackgroundColor3 = WHITE, LayoutOrder = i, Parent = dots })
		Theme.Bind(dot, { BackgroundColor3 = "Muted" })
		Util.Corner(dot, 2)
	end
	local hit = New("TextButton", { Name = "Hit", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 48, 1, 20), ZIndex = 6, Parent = hh })
	self.Handle, self.HandleCanvas = hh, hc

	local hovering, dragging = false, false
	local function look()
		local active = dragging or hovering
		Util.Tween(hh, 0.22, { Size = dragging and UDim2.fromOffset(132, 10) or (hovering and UDim2.fromOffset(116, 9) or UDim2.fromOffset(92, 7)) }, "Back")
		Util.Tween(glow, 0.2, { BackgroundTransparency = dragging and 0.1 or (hovering and 0.6 or 1) }, "Quad")
		for _, d in dots:GetChildren() do
			if d:IsA("Frame") then Util.Tween(d, 0.2, { BackgroundTransparency = active and 0.1 or 0 }, "Quad") end
		end
	end
	hit.MouseEnter:Connect(function() hovering = true; look() end)
	hit.MouseLeave:Connect(function() hovering = false; look() end)

	local startPos, startOffset
	self.Maid:Give(Util.Drag(hit, function(pos)
		if not startPos then return end
		local d = (v2(pos) - startPos) / self.Host:GetScale()
		if self.Minimized then
			self:_SetPillOffset(startOffset + d)
		else
			self:_SetOffset(startOffset + d)
		end
	end, function(input)
		if self.Fullscreen or self._introPlaying then return false end
		startPos = v2(input.Position)
		startOffset = self.Minimized and self.PillOffset or self.Offset
		dragging = true
		look()
		if self.Host._popover then self.Host._popover.Close() end
	end, function()
		startPos, dragging = nil, false
		look()
	end))
end

function Window:_UpdateHandle(animate)
	local h = self.Handle
	if not h then return end
	local show = self.HandleEnabled and self.Visible and not self._locked and not self.Destroyed and not self._introPlaying
	local size = self.Minimized and Vector2.new(PILL_W, PILL_H) or self.Size
	local off = self.Minimized and self.PillOffset or self.Offset
	local pos = UDim2.new(0.5, off.X, 0.5, off.Y + size.Y / 2 + 7)
	if animate then
		Util.Tween(h, 0.35, { Position = pos }, "Out")
	else
		h.Position = pos
	end
	if show ~= self._handleShown then
		self._handleShown = show
		if show then
			h.Visible = true
			Util.FadeCanvas(self.HandleCanvas, 0, 0.35, "Out")
		else
			Util.FadeCanvas(self.HandleCanvas, 1, 0.2, "Quad")
			task.delay(0.22, function() if not self._handleShown then h.Visible = false end end)
		end
	end
end

--- Turn the move handle on or off
function Window:SetHandle(enabled)
	self.HandleEnabled = enabled ~= false
	self:_ClampSize()
	self:_UpdateHandle()
end

-- ── Intro ────────────────────────────────────────────────────
--  "Horizon": a glowing line splits open into the window while the logo spins up,
--  the title types itself, and the cover dissolves to reveal the interface.
--  Intro = false | "None" | "Pop" | "Horizon" | { Style, Duration, Title, Subtitle }
function Window:_EndIntro()
	if not self._introPlaying then return end
	self._introToken = (self._introToken or 0) + 1
	self._introPlaying = false
	if self._introCover then self._introCover:Destroy(); self._introCover = nil end
	self.Sidebar.Position = UDim2.new()
	self.Content.Position = UDim2.new(0, self.Collapsed and SIDEBAR_C or SIDEBAR_W, 0, 0)
	self.Holder.Size = UDim2.fromOffset(self.Size.X, self.Size.Y)
	self:_UpdateHandle()
end

function Window:_PlayIntro()
	local cfg = self._introCfg
	self._introDone = true
	local holder, main = self.Holder, self.Main
	if cfg.Style ~= "Horizon" then
		holder.Visible = true
		if cfg.Style == "None" then
			self.Scaler.Scale = 1
			Util.FadeCanvas(main, self.Opacity, 0.2, "Quad")
		else
			Util.FadeCanvas(main, self.Opacity, 0.4, "Out")
			Util.Tween(self.Scaler, 0.45, { Scale = 1 }, "Back")
		end
		return
	end

	local token = (self._introToken or 0) + 1
	self._introToken = token
	local k = Util.Clamp((cfg.Duration or 1.9) / 1.9, 0.4, 3)
	local W, H = self.Size.X, self.Size.Y
	self._introPlaying = true
	self:_UpdateHandle()

	holder.Visible = true
	holder.Size = UDim2.fromOffset(W, 3)
	self.Scaler.Scale = 1
	Util.FadeCanvas(main, 0, 0, nil, true)

	local cover = New("CanvasGroup", {
		Name = "Intro", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = WHITE, ZIndex = 60, Parent = main,
	})
	self._introCover = cover
	Util.Corner(cover, 16)
	Theme.WindowGradient(cover, 35)
	Fx.Backdrop(cover, 0)
	local coverScale = New("UIScale", { Parent = cover })

	-- the glowing line the window opens from
	local core = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = WHITE, ZIndex = 5, Parent = cover })
	Theme.AccentGradient(core, 0)
	local coreFade = New("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({ kp(0, 1), kp(0.2, 0), kp(0.8, 0), kp(1, 1) }), Parent = core })

	-- logo with a spinning ring
	local logoBox = New("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -34), Size = UDim2.fromOffset(68, 68), ZIndex = 4, Parent = cover,
	})
	local logoScale = New("UIScale", { Scale = 0.4, Parent = logoBox })
	local spin = Fx.SpinRing(logoBox, { Size = 68, Thickness = 3, Speed = 0.9, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local tile = makeLogo(logoBox, self.Opts.Icon or "sparkles", 40, 12)
	tile.AnchorPoint = Vector2.new(0.5, 0.5)
	tile.Position = UDim2.fromScale(0.5, 0.5)

	local titleText = cfg.Title or self.Opts.Title or "Vesper"
	local title = New("TextLabel", {
		Weight = "SemiBold", TextSize = 21, Text = titleText, MaxVisibleGraphemes = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 14),
		Size = UDim2.new(0, 420, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = cover,
	})
	Theme.Bind(title, { TextColor3 = "Text" })
	local sub = New("TextLabel", {
		TextSize = 12, Text = cfg.Subtitle or self.Opts.Subtitle or self.Opts.Author or "Loading", TextTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 44), Size = UDim2.new(0, 420, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = cover,
	})
	Theme.Bind(sub, { TextColor3 = "Muted" })
	local track = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 72), Size = UDim2.fromOffset(150, 3), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 4, Parent = cover })
	Theme.Bind(track, { BackgroundColor3 = "Input" })
	Util.Corner(track, 2)
	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, Parent = track })
	Util.Corner(fill, 2)
	Theme.AccentGradient(fill, 0)

	local function alive() return self._introToken == token and not self.Destroyed end

	Sound.Play("Open")
	task.spawn(function()
		-- 1. the slit opens into the window
		Util.Tween(holder, 0.62 * k, { Size = UDim2.fromOffset(W, H) }, "Out")
		task.wait(0.18 * k)
		if not alive() then return end
		Util.Tween(logoScale, 0.5 * k, { Scale = 1 }, "Back")
		task.wait(0.3 * k)
		if not alive() then return end
		Util.Tween(core, 0.5 * k, { BackgroundTransparency = 1 }, "Quad")

		-- 2. the title types itself, the bar fills
		Util.Tween(sub, 0.4 * k, { TextTransparency = 0 }, "Quad")
		Util.Tween(track, 0.3 * k, { BackgroundTransparency = 0 }, "Quad")
		Util.Tween(fill, 0.85 * k, { Size = UDim2.fromScale(1, 1) }, "Sine")
		local n = utf8.len(titleText) or #titleText
		task.spawn(function()
			for i = 1, n do
				if not alive() then return end
				title.MaxVisibleGraphemes = i
				task.wait(math.min(0.045, 0.5 * k / math.max(n, 1)))
			end
			title.MaxVisibleGraphemes = -1
		end)
		task.wait(0.95 * k)
		if not alive() then return end

		-- 3. flourish, then the cover dissolves
		Fx.Burst(cover, { X = W / 2, Y = H / 2 - 34, Count = 12, Distance = 70, Size = 4.5, Duration = 0.75, ZIndex = 20 })
		Sound.Play("Success")
		Util.Tween(spin, 0.3 * k, { Size = UDim2.fromOffset(86, 86) }, "Out")
		task.wait(0.22 * k)
		if not alive() then return end

		local sw = self.Collapsed and SIDEBAR_C or SIDEBAR_W
		self.Sidebar.Position = UDim2.fromOffset(-28, 0)
		self.Content.Position = UDim2.new(0, sw, 0, 16)
		Util.Tween(self.Sidebar, 0.55 * k, { Position = UDim2.new() }, "Out")
		Util.Tween(self.Content, 0.55 * k, { Position = UDim2.new(0, sw, 0, 0) }, "Out")
		Util.Tween(cover, 0.5 * k, { GroupTransparency = 1 }, "Quad")
		Util.Tween(coverScale, 0.5 * k, { Scale = 1.05 }, "Quad")
		task.wait(0.55 * k)
		if not alive() then return end
		self:_EndIntro()
		Util.FadeCanvas(main, self.Opacity, 0.2, "Quad")
	end)
end

-- ── Visibility ───────────────────────────────────────────────
function Window:_Active() return self.Minimized and self.Pill or self.Holder end
function Window:_ActiveCanvas() return self.Minimized and self.PillCanvas or self.Main end

function Window:Show()
	if self.Destroyed then return end
	self.Visible = true
	if self.Minimized then
		self.Pill.Visible = true
		Util.FadeCanvas(self.PillCanvas, 0, 0.3, "Out")
	elseif not self._introDone then
		self:_PlayIntro()
	else
		self.Holder.Visible = true
		Util.FadeCanvas(self.Main, self.Opacity, 0.4, "Out")
		Util.Tween(self.Scaler, 0.45, { Scale = 1 }, "Back")
	end
	self:_UpdateHandle()
	if self._introDone and not self._introPlaying then Sound.Play("Open") end
end

function Window:Hide()
	if self.Destroyed then return end
	self:_EndIntro()
	self.Visible = false
	if self.Host._popover then self.Host._popover.Close() end
	self:_CloseSearch(true)
	Util.FadeCanvas(self:_ActiveCanvas(), 1, 0.22, "Quad")
	if not self.Minimized then Util.Tween(self.Scaler, 0.25, { Scale = 0.95 }, "Quad") end
	Sound.Play("Close")
	self:_UpdateHandle()
	task.delay(0.26, function()
		if not self.Visible and not self.Destroyed then self.Holder.Visible = false; self.Pill.Visible = false end
	end)
end

function Window:Toggle()
	if self._locked then return end
	if self._introPlaying then self:_EndIntro() end
	if self.Visible then self:Hide() else self:Show() end
end

function Window:Minimize()
	if self.Minimized or not self.Visible then return end
	self:_EndIntro()
	self.Minimized = true
	if self.Host._popover then self.Host._popover.Close() end
	self:_CloseSearch(true)
	local start = Vector2.new(self.Offset.X, self.Offset.Y - self.Size.Y / 2 + PILL_H / 2 + 8)
	self.Pill.Position = UDim2.new(0.5, start.X, 0.5, start.Y)
	self.Pill.Visible = true
	self:_SetPillOffset(start)
	local target = self.PillOffset
	Util.FadeCanvas(self.Main, 1, 0.24, "Quad")
	Util.Tween(self.Scaler, 0.28, { Scale = 0.55 }, "In")
	Util.Tween(self.Holder, 0.28, { Position = UDim2.new(0.5, target.X, 0.5, target.Y) }, "In")
	Util.FadeCanvas(self.PillCanvas, 0, 0.3, "Out")
	self:_UpdateHandle(true)
	task.delay(0.3, function()
		if self.Minimized and not self.Destroyed then
			self.Holder.Visible = false
			self.Scaler.Scale = 1
			self.Holder.Position = UDim2.new(0.5, self.Offset.X, 0.5, self.Offset.Y)
		end
	end)
end

function Window:Restore()
	if not self.Minimized or self.Destroyed then return end
	local pillOff = self.PillOffset
	self.Minimized = false
	local final = self:_Clamped(Vector2.new(pillOff.X, pillOff.Y + self.Size.Y / 2 - PILL_H / 2 - 8), self.Size, self.HandleEnabled and HANDLE_H or 0)
	self.Offset = final
	if not self.Visible then
		-- hidden while minimised: just remember the restored state, Show() brings the window back
		self.Pill.Visible = false
		self.Holder.Visible = false
		self.Scaler.Scale = 0.95
		self.Holder.Position = UDim2.new(0.5, final.X, 0.5, final.Y)
		self:_UpdateHandle()
		return
	end
	self.Holder.Position = UDim2.new(0.5, pillOff.X, 0.5, pillOff.Y)
	self.Scaler.Scale = 0.55
	self.Holder.Visible = true
	Util.FadeCanvas(self.PillCanvas, 1, 0.2, "Quad")
	Util.FadeCanvas(self.Main, self.Opacity, 0.35, "Out")
	Util.Tween(self.Scaler, 0.4, { Scale = 1 }, "Back")
	Util.Tween(self.Holder, 0.4, { Position = UDim2.new(0.5, final.X, 0.5, final.Y) }, "Out")
	self:_UpdateHandle(true)
	task.delay(0.24, function() if not self.Minimized then self.Pill.Visible = false end end)
end

function Window:ToggleFullscreen()
	if self.Minimized then return end
	self:_EndIntro()
	if self.Host._popover then self.Host._popover.Close() end
	if self.Fullscreen then
		self.Fullscreen = false
		self.Size, self.Offset = self._savedSize, self._savedOffset
	else
		self._savedSize, self._savedOffset = self.Size, self.Offset
		self.Fullscreen = true
		self.Size, self.Offset = self:_MaxSize(), Vector2.zero
		self.Offset = self:_Clamped(Vector2.zero, self.Size, self.HandleEnabled and HANDLE_H or 0)
	end
	Util.Tween(self.Holder, 0.38, {
		Size = UDim2.fromOffset(self.Size.X, self.Size.Y),
		Position = UDim2.new(0.5, self.Offset.X, 0.5, self.Offset.Y),
	}, "Out")
	self:_UpdateHandle(true)
	self:_OnResized()
	Icons.Apply(Util.Part(self.MaxBtn, "Image"), self.Fullscreen and "minimize" or "maximize", 16, "SubText")
	self.ResizeGrip.Visible = self.Resizable and not self.Fullscreen
end

-- ── Close / destroy ──────────────────────────────────────────
function Window:RequestClose()
	if self.Destroyed then return end
	if self.ConfirmClose then
		if not self.Visible and not self._locked then self:Show() end
		self:Dialog({
			Title = "Close window?", Content = "The interface will be removed until you run the script again.", Icon = "power",
			Buttons = {
				{ Title = "Cancel", Variant = "Secondary" },
				{ Title = "Close", Variant = "Danger", Callback = function() self:Destroy() end },
			},
		})
		if self.Minimized then self:Restore() end
	else
		self:Destroy()
	end
end

function Window:Destroy()
	if self.Destroyed then return end
	self:_EndIntro()
	self.Destroyed = true
	self.Visible = false
	local idx = table.find(Vesper.Windows, self)
	if idx then table.remove(Vesper.Windows, idx) end
	if self.OnDestroy then Util.Fire(self.OnDestroy) end
	for flag, element in self.Flags do
		if Vesper.Flags[flag] == element then Vesper.Flags[flag] = nil end
	end
	Util.FadeCanvas(self:_ActiveCanvas(), 1, 0.25, "Quad")
	Util.Tween(self.Scaler, 0.25, { Scale = 0.94 }, "Quad")
	self:_UpdateHandle()
	Sound.Play("Close")
	task.delay(0.32, function()
		self.Maid:Clean()
		self.Host:Destroy()
	end)
end

-- ── Dialog / Tag ─────────────────────────────────────────────
function Window:Dialog(opts)
	return Util.Dialog(self.Main, opts or {})
end

function Window:Tag(opts)
	if type(opts) == "string" then opts = { Title = opts } end
	opts = opts or {}
	local tag = { Color = opts.Color }
	local frame = New("Frame", { Name = "Tag", Size = UDim2.new(0, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0.82, LayoutOrder = #self.TagHolder:GetChildren(), Parent = self.TagHolder })
	Theme.Bind(frame, { BackgroundColor3 = function(t) return tag.Color or t.Accent end })
	Util.Corner(frame, 6)
	Util.Padding(frame, 0, 8, 0, 8)
	Util.List(frame, 4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	if opts.Icon then
		local img = Util.Icon(frame, opts.Icon, 11, "Accent", { LayoutOrder = 1 })
		Theme.Bind(img, { ImageColor3 = function(t) return tag.Color or t.Accent end })
	end
	local label = New("TextLabel", { Weight = "SemiBold", TextSize = 11, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = frame })
	Theme.Bind(label, { TextColor3 = function(t) return tag.Color or t.Accent end })
	Util.SetText(label, opts.Title or "Tag")
	tag.Frame = frame
	function tag:SetTitle(t) Util.SetText(label, t) end
	function tag:SetColor(c)
		tag.Color = c
		Util.Tween(frame, 0.2, { BackgroundColor3 = c }, "Quad")
		label.TextColor3 = c
	end
	function tag:Destroy() frame:Destroy() end
	return tag
end

function Window:SetTitle(title, subtitle)
	if title then Util.SetText(self.TitleLabel, title) end
	if subtitle ~= nil then
		Util.SetText(self.SubtitleLabel, subtitle)
		self.SubtitleLabel.Visible = subtitle ~= ""
	end
end

function Window:SetToggleKey(key) self.ToggleKey = Util.ParseKeyCode(key) or self.ToggleKey end
function Window:SetTheme(name) return Theme.Set(name) end
function Window:Notify(opts) return Vesper:Notify(opts) end

-- ─────────────────────────────────────────────────────────────
--  Live stat cards  (Tab:Stats)
-- ─────────────────────────────────────────────────────────────
local STAT_H = 66

local function getPing()
	local ok, value = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
	if ok and value then return value end
	local ok2, ping = pcall(function() return Players.LocalPlayer:GetNetworkPing() * 2000 end)
	return ok2 and ping or 0
end

local STAT_PRESETS = {
	FPS     = { Title = "FPS",     Suffix = "Client", Max = 120, Format = "%d", Get = function(w) return w._fps or 60 end },
	Ping    = { Title = "Ping",    Suffix = "Ms",     Max = 300, Format = "%d", Get = getPing },
	Players = { Title = "Players", Suffix = "Server", Max = function() return Players.MaxPlayers end, Format = "%d", Get = function() return #Players:GetPlayers() end },
}

function Window:_SetupStats()
	self._stats = {}
	local acc, frames = 0, 0
	self.Maid:Give(RunService.Heartbeat:Connect(function(dt)
		frames += 1
		acc += dt
		if acc >= 0.5 then
			self._fps = frames / acc
			frames, acc = 0, 0
			if self.Visible and not self.Minimized then
				for _, stat in self._stats do stat:Update() end
			end
		end
	end))
end

--- Tab:Stats({ "FPS", "Ping", "Players" })  or custom { Title, Suffix, Get = function() return n end, Max = 100, Format = "%d" }
function Tab:Stats(list)
	local window = self.Window
	list = list or { "FPS", "Ping", "Players" }
	if self.StatsRow then
		self.StatsRow:Destroy()
		for i = #window._stats, 1, -1 do
			if window._stats[i].Tab == self then table.remove(window._stats, i) end
		end
	end
	local gap = 8
	local n = #list
	local row = New("Frame", { Name = "Stats", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, STAT_H), Parent = self.Page })
	Util.List(row, gap, Enum.FillDirection.Horizontal)
	self.StatsRow = row
	self.Panel.Position = UDim2.fromOffset(0, STAT_H + gap)
	self.Panel.Size = UDim2.new(1, 0, 1, -(STAT_H + gap))

	local objects = {}
	for i, def in list do
		if type(def) == "string" then def = STAT_PRESETS[def] or { Title = def, Get = function() return 0 end } end
		local card = New("Frame", { Name = "Stat", Size = UDim2.new(1 / n, -math.ceil(gap * (n - 1) / n), 1, -3), BackgroundColor3 = WHITE, BackgroundTransparency = Look.Card, LayoutOrder = i, Parent = row })
		Theme.Bind(card, { BackgroundColor3 = "Card" })
		Util.Corner(card, 12)
		Util.Shade(card, 90, 0.08)
		Shadow.Edge(card, { Inset = 8, Alpha = 0.82 })
		Util.FadeLine(card, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.3, ZIndex = 3 })
		local bar = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(3, 30), BackgroundColor3 = WHITE, Parent = card })
		Util.Corner(bar, 2)
		Theme.AccentGradient(bar, 90)
		local title = New("TextLabel", { Weight = "Medium", TextSize = 11, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -60, 0, 13), TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
		Theme.Bind(title, { TextColor3 = "Muted" })
		Util.SetText(title, def.Title or "Stat")
		local value = New("TextLabel", { Weight = "SemiBold", TextSize = 22, Position = UDim2.fromOffset(14, 20), Size = UDim2.new(1, -60, 0, 26), Text = "–", Parent = card })
		Theme.Bind(value, { TextColor3 = "Text" })
		local suffix = New("TextLabel", { TextSize = 11, Position = UDim2.fromOffset(14, 47), Size = UDim2.new(1, -60, 0, 13), TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
		Theme.Bind(suffix, { TextColor3 = "Muted" })
		Util.SetText(suffix, def.Suffix or "")

		local bars = {}
		for b = 1, 3 do
			local f = New("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14 - (3 - b) * 8, 1, -14), Size = UDim2.fromOffset(3, 10), BackgroundColor3 = WHITE, Parent = card })
			Util.Corner(f, 2)
			Theme.Bind(f, { BackgroundColor3 = b == 3 and "Accent" or "SubText" })
			f.BackgroundTransparency = b == 3 and 0.05 or 0.5
			bars[b] = f
		end

		local history = {}
		local stat = { Tab = self, Card = card }
		function stat:Update()
			local ok, v = pcall(def.Get, window)
			if not ok or type(v) ~= "number" then return end
			local max = type(def.Max) == "function" and def.Max() or def.Max or 100
			table.insert(history, v)
			while #history > 3 do table.remove(history, 1) end
			value.Text = string.format(def.Format or "%d", v)
			for b = 1, 3 do
				local sample = history[#history - 3 + b] or history[1] or v
				local ratio = Util.Clamp(sample / math.max(max, 1), 0, 1)
				Util.Tween(bars[b], 0.35, { Size = UDim2.fromOffset(3, 8 + math.floor(ratio * 26)) }, "Out")
			end
		end
		stat:Update()
		table.insert(window._stats, stat)
		objects[i] = stat
	end
	return objects
end

-- ─────────────────────────────────────────────────────────────
--  Global search
--  Every tab, section and control registers itself in window._index. The search box
--  ranks them, shows what each result is and where it lives, and jumps to it on click.
-- ─────────────────────────────────────────────────────────────
local TYPE_LABEL = {
	Toggle = "Toggle", Slider = "Slider", ToggleSlider = "Toggle slider", Checkbox = "Checkbox", Dropdown = "Dropdown",
	Input = "Textbox", Keybind = "Keybind", Colorpicker = "Color picker", Button = "Button", ButtonRow = "Buttons",
	Paragraph = "Text", Code = "Code", Stepper = "Stepper", Segmented = "Options", Progress = "Progress", Section = "Section", Tab = "Tab",
}
local TYPE_ICON = {
	Toggle = "toggle-right", Slider = "sliders-horizontal", ToggleSlider = "sliders-horizontal", Checkbox = "square-check",
	Dropdown = "list", Input = "pencil", Keybind = "keyboard", Colorpicker = "palette", Button = "mouse-pointer-click",
	ButtonRow = "mouse-pointer-click", Paragraph = "file-text", Code = "file-text", Stepper = "plus", Segmented = "list",
	Progress = "gauge", Section = "layout-grid", Tab = "layout-dashboard",
}
Util.TypeLabel, Util.TypeIcon = TYPE_LABEL, TYPE_ICON

local PATH_SEP = "  >  "

--- { Tab title, Section title, … } for an index entry
local function entryPath(entry)
	local names = {}
	if entry.Tab then table.insert(names, Loc.Resolve(entry.Tab.Title)) end
	local chain = {}
	local c = entry.Container
	while c and c.Type == "Section" do
		table.insert(chain, 1, Loc.Resolve(c.Title or ""))
		c = c.ParentContainer
	end
	for _, name in chain do table.insert(names, name) end
	if entry.Kind == "tab" then names = { "Tab" } end
	return names
end

local function splitWords(query)
	local words = {}
	for w in string.gmatch(string.lower(query), "%S+") do table.insert(words, w) end
	return words
end

--- Returns a list sorted best-first: { Entry, Title, Path, Type, Icon, Score }
function Window:_RunSearch(query, limit)
	local words = splitWords(query)
	local results = {}
	if #words == 0 then return results end
	local whole = string.lower(Util.Trim(query))
	for order, entry in self._index do
		if not entry.Dead and not entry.Hidden and entry.Searchable ~= false and entry.Kind ~= "decor" and (not entry.Tab or not entry.Tab.Destroyed) then
			local title = string.lower(Loc.Resolve(entry.RawTitle or ""))
			local desc = string.lower(Loc.Resolve(entry.RawDesc or ""))
			local path = entryPath(entry)
			local where = string.lower(table.concat(path, " "))
			local kind = string.lower(TYPE_LABEL[entry.Type or ""] or "")
			local score, ok = 0, true
			for _, w in words do
				local s = 0
				local at = string.find(title, w, 1, true)
				if at then
					if at == 1 then s = 6
					elseif string.sub(title, at - 1, at - 1) == " " then s = 5
					else s = 4 end
				elseif string.find(where, w, 1, true) then s = 2
				elseif string.find(desc, w, 1, true) then s = 1.5
				elseif string.find(kind, w, 1, true) then s = 1 end
				if s == 0 then ok = false; break end
				score += s
			end
			if ok then
				if title == whole then score += 8 end
				if entry.Kind == "tab" then score += 0.5 end
				local shown = Loc.Resolve(entry.RawTitle or "")
				if shown == "" then shown = TYPE_LABEL[entry.Type or ""] or "Item" end
				table.insert(results, {
					Entry = entry, Title = shown, Path = path, Type = TYPE_LABEL[entry.Type or ""] or "Item",
					Icon = entry.Icon or TYPE_ICON[entry.Type or ""] or "search", Score = score - order * 0.0001,
				})
			end
		end
	end
	table.sort(results, function(a, b) return a.Score > b.Score end)
	if limit and #results > limit then
		for i = #results, limit + 1, -1 do results[i] = nil end
	end
	return results
end

--- Window:Search("speed") -> { { Title, Path = "Tab > Section", Type, Go = function() } }
function Window:Search(query, limit)
	local out = {}
	for _, r in self:_RunSearch(tostring(query or ""), limit or 20) do
		table.insert(out, {
			Title = r.Title, Path = table.concat(r.Path, PATH_SEP), Type = r.Type, Tab = r.Entry.Tab,
			Go = function() self:Goto(r.Entry) end,
		})
	end
	return out
end

-- ── Navigation ───────────────────────────────────────────────
local function scrollTo(panel, frame)
	local scale = Util.GetScale(panel)
	for _ = 1, 4 do
		if not panel.Parent or not frame.Parent then return end
		local delta = (frame.AbsolutePosition.Y - panel.AbsolutePosition.Y) - 10 * scale
		if math.abs(delta) < 4 then return end
		local before = panel.CanvasPosition.Y
		panel.CanvasPosition = Vector2.new(0, math.max(0, before + delta / scale))
		task.wait()
		if math.abs(panel.CanvasPosition.Y - before) < 0.5 then return end
	end
end

--- Jump to a tab / section / control (an entry of the search index) and highlight it
function Window:Goto(entry)
	if type(entry) ~= "table" then return false end
	-- a result of Window:Search() can be passed straight in
	if entry.Entry == nil and entry.Frame == nil and type(entry.Go) == "function" then return entry.Go() end
	if entry.Dead then return false end
	local tab = entry.Tab
	if not tab or tab.Destroyed then return false end
	self:_CloseSearch(true)
	if self.Minimized then self:Restore() end
	if not self.Visible and not self._locked then self:Show() end

	local opened = false
	local function unfold(c)
		while c and c.Type == "Section" do
			if not c.Opened then c:Open(); opened = true end
			c = c.ParentContainer
		end
	end
	if entry.Kind == "section" and entry.Obj then
		if not entry.Obj.Opened then entry.Obj:Open(); opened = true end
	end
	unfold(entry.Container)
	if tab.TabSection and not tab.TabSection.Opened then tab.TabSection.SetOpen(true) end

	local same = self.SelectedTab == tab
	self:SelectTab(tab)
	if entry.Kind == "tab" then return true end

	task.spawn(function()
		task.wait((same and 0.05 or 0.4) + (opened and 0.35 or 0))
		if self.Destroyed or entry.Dead or not entry.Frame or not entry.Frame.Parent then return end
		scrollTo(tab.Panel, entry.Frame)
		local target = entry.FxTarget
		if target == nil then target = entry.Frame end
		if target then
			Fx.Flash(target, { Color = "Accent", Alpha = 0.55, Duration = 0.9 })
			Fx.Sheen(target, { Alpha = 0.7, Duration = 0.7 })
			task.wait(0.55)
			if target.Parent then Fx.Flash(target, { Color = "Accent", Alpha = 0.7, Duration = 0.8 }) end
		end
	end)
	return true
end

-- ── Panel ────────────────────────────────────────────────────
function Window:_SetupSearch()
	local box = self.SearchBox
	local frame = self.SearchFrame
	local glow = self.SearchGlow
	local hint = self.SearchHint
	local host = self.Host

	local ROW_H, GAP, HEAD_H, FOOT_H, MAX_ROWS, PANEL_W = 46, 3, 26, 24, 6, 350
	local touch = Util.IsTouch()

	local holder, canvas = Util.Surface(self.Overlay, {
		Name = "SearchResults", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(PANEL_W, 120), Visible = false, ZIndex = 120,
	}, 13)
	Theme.Bind(canvas, { BackgroundColor3 = "Popup" })
	Util.Shade(canvas, 90, 0.07)
	local pop = New("UIScale", { Scale = 0.95, Parent = holder })
	Util.FadeLine(canvas, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.8, Token = "Accent", ZIndex = 6, Thickness = 1 })

	local header = New("TextLabel", { Weight = "SemiBold", TextSize = 11, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 0, HEAD_H), Text = "", Parent = canvas })
	Theme.Bind(header, { TextColor3 = "Muted" })
	Util.FadeLine(canvas, { Position = UDim2.new(0, 10, 0, HEAD_H), Size = UDim2.new(1, -20, 0, 1), Strength = 0.35, ZIndex = 4 })

	local list = New("ScrollingFrame", {
		Position = UDim2.fromOffset(0, HEAD_H + 1), Size = UDim2.new(1, 0, 1, -(HEAD_H + 1 + (touch and 6 or FOOT_H))), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2, ScrollBarImageTransparency = 0.4, VerticalScrollBarInset = Enum.ScrollBarInset.None, Parent = canvas,
	})
	Theme.Bind(list, { ScrollBarImageColor3 = "Muted" })
	Util.Padding(list, 4, 6, 4, 6)
	Util.List(list, GAP)

	local empty = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, HEAD_H + 1), Size = UDim2.new(1, 0, 0, 64), Visible = false, Parent = canvas })
	local emptyIcon = Util.Icon(empty, "search", 20, "Muted", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10) })
	local emptyText = New("TextLabel", { TextSize = 12, Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 36), Size = UDim2.new(1, -24, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, Parent = empty })
	Theme.Bind(emptyText, { TextColor3 = "Muted" })

	if not touch then
		Util.FadeLine(canvas, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -FOOT_H), Size = UDim2.new(1, -20, 0, 1), Strength = 0.3, ZIndex = 4 })
		local foot = New("TextLabel", {
			TextSize = 10, Text = "Up / Down to browse     Enter to open     Esc to close", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, -28, 0, FOOT_H), Parent = canvas,
		})
		foot.Position = UDim2.new(0, 14, 1, 0)
		Theme.Bind(foot, { TextColor3 = "Muted" })
	end

	local rows, results, selected = {}, {}, nil
	local isOpen, picking = false, false

	local function paint()
		for i, row in rows do
			if row.Btn.Visible then
				local on = i == selected
				Util.Tween(row.Fill, 0.15, { BackgroundTransparency = on and 0.78 or 1 }, "Quad")
				Util.Tween(row.Icon, 0.15, { ImageColor3 = Theme.Resolve(on and "Accent" or "SubText") }, "Quad")
			end
		end
	end

	local function choose(i)
		local r = results[i]
		if not r then return end
		Sound.Play("Select")
		self:Goto(r.Entry)
	end

	local function makeRow(i)
		local btn = New("TextButton", { Name = "Result", Size = UDim2.new(1, 0, 0, ROW_H), BackgroundTransparency = 1, LayoutOrder = i, Visible = false, Parent = list })
		Util.Corner(btn, 10)
		local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Active = false, Parent = btn })
		Util.Corner(fill, 10)
		Theme.Bind(New("UIGradient", { Transparency = NumberSequence.new({ kp(0, 0), kp(0.6, 0.45), kp(1, 1) }), Parent = fill }), { Color = Theme.AccentSeq })
		local bubble = New("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = WHITE, Parent = btn })
		Theme.Bind(bubble, { BackgroundColor3 = "Input" })
		Util.Corner(bubble, 9)
		local icon = Util.Icon(bubble, "search", 15, "SubText", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		local title = New("TextLabel", { Weight = "Medium", TextSize = 13, RichText = true, Position = UDim2.fromOffset(48, 7), Size = UDim2.new(1, -140, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn })
		Theme.Bind(title, { TextColor3 = "Text" })
		local sub = New("TextLabel", { TextSize = 11, Position = UDim2.fromOffset(48, 25), Size = UDim2.new(1, -140, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn })
		Theme.Bind(sub, { TextColor3 = "Muted" })
		local badge = New("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = WHITE, Parent = btn })
		Theme.Bind(badge, { BackgroundColor3 = "Input" })
		Util.Corner(badge, 6)
		Util.Padding(badge, 0, 7, 0, 7)
		local badgeText = New("TextLabel", { Weight = "SemiBold", TextSize = 10, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = badge })
		Theme.Bind(badgeText, { TextColor3 = "SubText" })
		Util.FadeLine(btn, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 1), Size = UDim2.new(1, -24, 0, 1), Strength = 0.22, ZIndex = 2 })

		btn.MouseEnter:Connect(function() selected = i; paint() end)
		btn.MouseButton1Down:Connect(function() picking = true end)
		btn.MouseButton1Up:Connect(function() task.delay(0.3, function() picking = false end) end)
		btn.Activated:Connect(function()
			picking = false
			choose(i)
		end)
		rows[i] = { Btn = btn, Fill = fill, Icon = icon, Title = title, Sub = sub, BadgeText = badgeText }
		return rows[i]
	end

	local function placePanel(height)
		local scale = host:GetScale()
		local rel = (frame.AbsolutePosition - host.Root.AbsolutePosition) / scale
		local asz = frame.AbsoluteSize / scale
		local logical = host:LogicalSize()
		local w = math.min(PANEL_W, logical.X - 16)
		local right = math.max(rel.X + asz.X, w + 8)
		right = math.min(right, logical.X - 8)
		holder.Position = UDim2.fromOffset(right, rel.Y + asz.Y + 8)
		holder.Size = UDim2.fromOffset(w, height)
	end

	local function closePanel()
		if not isOpen then return end
		isOpen = false
		Util.FadeCanvas(canvas, 1, 0.14, "Quad")
		Util.Tween(pop, 0.16, { Scale = 0.96 }, "Quad")
		task.delay(0.18, function() if not isOpen then holder.Visible = false end end)
	end

	local function render()
		local n = #results
		local accent = Util.ToHex(Theme.Current.Accent)
		local q = splitWords(box.Text)[1] or ""
		for i = 1, n do
			local row = rows[i] or makeRow(i)
			local r = results[i]
			row.Btn.Visible = true
			local shown = r.Title
			local at = q ~= "" and string.find(string.lower(shown), q, 1, true) or nil
			if at then
				row.Title.Text = Util.EscapeRich(string.sub(shown, 1, at - 1))
					.. '<font color="' .. accent .. '"><b>' .. Util.EscapeRich(string.sub(shown, at, at + #q - 1)) .. "</b></font>"
					.. Util.EscapeRich(string.sub(shown, at + #q))
			else
				row.Title.Text = Util.EscapeRich(shown)
			end
			row.Sub.Text = table.concat(r.Path, PATH_SEP)
			row.BadgeText.Text = r.Type
			Icons.Apply(row.Icon, r.Icon, 15, "SubText")
		end
		for i = n + 1, #rows do rows[i].Btn.Visible = false end
		header.Text = n == 0 and "No matches" or (n == 1 and "1 result" or (n .. " results"))
		empty.Visible = n == 0
		emptyText.Text = n == 0 and ('Nothing found for "' .. Util.Trim(box.Text) .. '"') or ""
		list.Visible = n > 0
		list.CanvasPosition = Vector2.new(0, 0)
		local bodyH = n == 0 and 64 or (math.min(n, MAX_ROWS) * (ROW_H + GAP) + 8)
		local height = HEAD_H + 1 + bodyH + (touch and 6 or FOOT_H)
		placePanel(height)
		paint()
	end

	local function openPanel()
		if isOpen then return end
		isOpen = true
		holder.Visible = true
		Util.FadeCanvas(canvas, 0, 0.18, "Out")
		Util.Tween(pop, 0.26, { Scale = 1 }, "Back")
	end

	local function refresh()
		if self._searchMuted then return end
		local q = Util.Trim(box.Text)
		if q == "" then
			results, selected = {}, nil
			closePanel()
			return
		end
		results = self:_RunSearch(q, 40)
		selected = #results > 0 and 1 or nil
		render()
		openPanel()
	end

	local function move(dir)
		if #results == 0 then return end
		selected = ((selected or 0) - 1 + dir) % #results + 1
		paint()
		local top = 4 + (selected - 1) * (ROW_H + GAP)
		local view = math.min(#results, MAX_ROWS) * (ROW_H + GAP)
		local pos = list.CanvasPosition.Y
		if top < pos then
			list.CanvasPosition = Vector2.new(0, top - 4)
		elseif top + ROW_H > pos + view then
			list.CanvasPosition = Vector2.new(0, top + ROW_H - view + 4)
		end
	end

	box:GetPropertyChangedSignal("Text"):Connect(refresh)
	box.Focused:Connect(function()
		hint.Visible = false
		glow.Position = UDim2.fromScale(0.5, 1)
		Util.Tween(glow, 0.3, { Size = UDim2.new(1, -16, 0, 2) }, "Out")
		if Util.Trim(box.Text) ~= "" then refresh() end
	end)
	box.FocusLost:Connect(function(enter)
		hint.Visible = Util.Trim(box.Text) == ""
		Util.Tween(glow, 0.2, { Size = UDim2.new(0, 0, 0, 2) }, "Quad")
		if enter and selected then
			choose(selected)
			return
		end
		task.delay(0.22, function()
			if not box:IsFocused() and not picking then closePanel() end
		end)
	end)

	self.Maid:Give(UserInputService.InputBegan:Connect(function(input)
		if not box:IsFocused() then return end
		if input.KeyCode == Enum.KeyCode.Down then move(1)
		elseif input.KeyCode == Enum.KeyCode.Up then move(-1)
		elseif input.KeyCode == Enum.KeyCode.Escape then
			self:_CloseSearch(true)
			box:ReleaseFocus()
		end
	end))

	-- the panel follows the window when it moves
	self.Maid:Give(RunService.Heartbeat:Connect(function()
		if isOpen and self.Visible then
			local scale = host:GetScale()
			local rel = (frame.AbsolutePosition - host.Root.AbsolutePosition) / scale
			local asz = frame.AbsoluteSize / scale
			local logical = host:LogicalSize()
			local w = holder.Size.X.Offset
			local right = math.min(math.max(rel.X + asz.X, w + 8), logical.X - 8)
			holder.Position = UDim2.fromOffset(right, rel.Y + asz.Y + 8)
		end
	end))

	function self:_CloseSearch(clear)
		if clear and box.Text ~= "" then
			self._searchMuted = true
			box.Text = ""
			self._searchMuted = false
			hint.Visible = not box:IsFocused()
		end
		picking = false
		results, selected = {}, nil
		closePanel()
	end
	function self:FocusSearch() box:CaptureFocus() end
end

function Window:_CloseSearch() end
function Window:FocusSearch() end

-- ─────────────────────────────────────────────────────────────
--  Elements: shared foundation
-- ─────────────────────────────────────────────────────────────
Elements.Create = {}   -- name -> function(container, opts)

--- Give `obj` (a Tab or Section) every element method.
function Elements.Attach(obj, content, window, tab)
	obj.Content = content
	obj.Window = window
	obj.Tab = tab or obj
	obj._entries = obj._entries or {}
	obj._order = 0
	for name, fn in Elements.Create do
		obj[name] = function(self, opts)
			if type(opts) == "string" then opts = { Title = opts } end
			return fn(self, opts or {})
		end
	end
end

function Elements.NextOrder(container)
	container._order += 1
	return container._order
end

--- kind: "element" (searchable) | "decor" (hidden while filtering) | "section"
--- info: { Type, Icon, Obj, FxTarget, Searchable }
function Elements.Register(container, frame, kind, title, desc, info)
	info = info or {}
	local entry = {
		Frame = frame, Kind = kind, Hidden = false, Container = container, Tab = container.Tab, Dead = false,
		Type = info.Type, Icon = info.Icon, Obj = info.Obj, FxTarget = info.FxTarget, Searchable = info.Searchable,
		RawTitle = title or "", RawDesc = desc or "",
		Text = string.lower(Loc.Resolve(title or "") .. " " .. Loc.Resolve(desc or "")),
	}
	table.insert(container._entries, entry)
	local window = container.Window
	if window and kind ~= "decor" then table.insert(window._index, entry) end
	return entry
end

function Elements.Unregister(container, entry)
	if entry.Dead then return end
	entry.Dead = true
	local idx = table.find(container._entries, entry)
	if idx then table.remove(container._entries, idx) end
	local window = container.Window
	if window then
		local at = table.find(window._index, entry)
		if at then table.remove(window._index, at) end
	end
	if entry.Detach then pcall(entry.Detach); entry.Detach = nil end
	-- release the flag (only if it still points at this control; a rebuilt control may have taken it over)
	local flag = entry.Obj and entry.Obj.Flag
	if flag then
		if Vesper.Flags[flag] == entry.Obj then Vesper.Flags[flag] = nil end
		if window and window.Flags[flag] == entry.Obj then window.Flags[flag] = nil end
	end
	-- a section takes everything inside it along
	if entry.Entries then
		for _, child in table.clone(entry.Entries) do
			Elements.Unregister(child.Container or container, child)
		end
	end
end

local function applySearch(entries, query)
	local count = 0
	for _, e in entries do
		if query == "" then
			e.Frame.Visible = not e.Hidden
			if e.Entries then applySearch(e.Entries, "") end
		elseif e.Kind == "element" then
			local match = string.find(e.Text, query, 1, true) ~= nil
			e.Frame.Visible = match and not e.Hidden
			if match then count += 1 end
		elseif e.Kind == "section" then
			local c = applySearch(e.Entries, query)
			e.Frame.Visible = c > 0
			count += c
		else
			e.Frame.Visible = false
		end
	end
	return count
end

--- Filter the controls of this tab in place (the top bar search covers every tab instead)
function Tab:Search(query)
	applySearch(self._entries, string.lower(query or ""))
end

--- Click effect for a row
function Elements.Click(row, color)
	Fx.Click(row.Frame, { Color = color or "Accent", Radius = UDim.new(0, 12) })
end

-- ─────────────────────────────────────────────────────────────
--  Row: [icon] title / description ........ [control]
--  Compact by design: a row without a description is only as tall as its control.
--  The description wraps and the row grows with it.
-- ─────────────────────────────────────────────────────────────
function Elements.Row(container, opts, rightW, rightH, interactive)
	-- interactive: true = clickable + hover feedback, "plain" = clickable without hover feedback, false = static
	local window = container.Window
	local card = New(interactive and "TextButton" or "Frame", {
		Name = tostring(opts.Title or "Row"), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = Look.Card, BackgroundColor3 = WHITE, LayoutOrder = Elements.NextOrder(container), Parent = container.Content,
	})
	Theme.Bind(card, { BackgroundColor3 = "Card" })
	Util.Corner(card, 12)
	local shade = Util.Shade(card, 90, 0.07)
	local depth = Shadow.Edge(card, { Inset = 9, Alpha = 0.84 })
	local topLine = Util.FadeLine(card, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.26, ZIndex = 4 })

	local body = New("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Active = false, Parent = card })
	local pad = Util.Padding(body, 8, 16, 8, 16)
	local minC = New("UISizeConstraint", { Parent = body })

	local row = { Frame = card, Body = body, Container = container, Shade = shade, Depth = depth, TopLine = topLine }
	if opts.Icon then
		row.Icon = Util.Icon(body, opts.Icon, 16, "SubText", { Position = UDim2.fromOffset(0, 0) })
	end
	local reserve = (rightW and rightW > 0) and (rightW + 12) or 0
	local left = New("Frame", { Name = "Left", BackgroundTransparency = 1, Size = UDim2.new(1, -reserve, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = body })
	local leftPad = Util.Padding(left, 0, 0, 0, opts.Icon and 26 or 0)
	Util.List(left, 2)
	row.Left = left

	row.TitleLabel = New("TextLabel", {
		Weight = "Medium", TextSize = 14, TextWrapped = true, Size = UDim2.new(1, 0, 0, 16), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1, Parent = left,
	})
	Theme.Bind(row.TitleLabel, { TextColor3 = "Text" })
	Util.SetText(row.TitleLabel, opts.Title or "")

	row.DescLabel = New("TextLabel", {
		TextSize = 11, TextWrapped = true, RichText = true, TextTransparency = 0.1, Size = UDim2.new(1, 0, 0, 13), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2, Visible = (opts.Desc ~= nil and opts.Desc ~= ""), Parent = left,
	})
	Theme.Bind(row.DescLabel, { TextColor3 = "Muted" })
	Util.SetText(row.DescLabel, opts.Desc or "")

	if rightW and rightW > 0 then
		row.Right = New("Frame", {
			Name = "Right", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(rightW, rightH or 26), Parent = body,
		})
	end

	local metrics = { padH = 16, compact = false }
	local titleH = 17

	--- sizes that depend on density and on whether there is a description
	local function fit()
		local compact = metrics.compact
		local padV = compact and 6 or 8
		metrics.padH = compact and 12 or 16
		titleH = compact and 16 or 17
		row.TitleLabel.TextSize = compact and 13 or 14
		row.DescLabel.TextSize = compact and 10 or 11
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, padV), UDim.new(0, padV)
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, metrics.padH), UDim.new(0, metrics.padH)
		local contentH = math.max(rightH or 0, titleH)
		minC.MinSize = Vector2.new(0, contentH + padV * 2)
		local hasDesc = row.DescLabel.Visible
		local topPad = (not hasDesc and contentH > titleH) and math.floor((contentH - titleH) / 2) or 0
		leftPad.PaddingTop = UDim.new(0, topPad)
		if row.Icon then row.Icon.Position = UDim2.fromOffset(0, topPad + math.floor((titleH - 16) / 2)) end
	end
	row.Fit = fit

	--- the control on the right never takes more than about half the row
	local lastW = 0
	local function reflow()
		if not row.Right then return end
		local scale = Util.GetScale(card)
		local w = card.AbsoluteSize.X / scale
		if w <= 0 then return end
		lastW = w
		local avail = w - metrics.padH * 2
		local r = math.min(rightW, math.max(avail * 0.52, 96))
		row.Right.Size = UDim2.fromOffset(r, rightH or 26)
		left.Size = UDim2.new(1, -(r + 12), 0, 0)
	end
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local scale = Util.GetScale(card)
		if math.abs(card.AbsoluteSize.X / scale - lastW) > 1 then reflow() end
	end)

	fit()
	if window then
		row.Detach = window:_OnDensity(function(compact)
			metrics.compact = compact
			fit()
			reflow()
		end)
	end

	if interactive == true then
		Util.HoverFx(card, card, "Card", "CardHover", function(t) return t.CardHover:Lerp(t.Input, 0.5) end)
	end
	return row
end

--- Shared API for every element object. `obj` is the public object, `row` the Row result.
function Elements.Finish(obj, container, row, kind, opts)
	obj.Frame = row.Frame
	obj.Container = container
	obj.Locked = false
	local entry = Elements.Register(container, row.Frame, kind or "element", opts.Title, opts.Desc, {
		Type = obj.Type, Icon = opts.Icon, Obj = obj, Searchable = opts.Search ~= false,
	})
	entry.Detach = row.Detach
	obj._entry = entry

	function obj:SetTitle(text)
		Util.SetText(row.TitleLabel, text)
		entry.RawTitle = text
		entry.Text = string.lower(Loc.Resolve(text) .. " " .. (row.DescLabel.Text or ""))
	end
	function obj:SetDesc(text)
		Util.SetText(row.DescLabel, text or "")
		row.DescLabel.Visible = text ~= nil and text ~= ""
		entry.RawDesc = text or ""
		entry.Text = string.lower(Loc.Resolve(entry.RawTitle or "") .. " " .. Loc.Resolve(text or ""))
		row.Fit()
	end
	function obj:SetVisible(visible)
		entry.Hidden = not visible
		row.Frame.Visible = visible
	end
	function obj:SetLocked(locked)
		obj.Locked = locked
		if locked and not obj._lock then
			obj._lock = New("TextButton", {
				Name = "Lock", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 10, Parent = row.Frame,
			})
			Theme.Bind(obj._lock, { BackgroundColor3 = "Card" })
			Util.Corner(obj._lock, 12)
			obj._lockIcon = Util.Icon(obj._lock, "lock", 14, "Muted", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), ImageTransparency = 1 })
		end
		if obj._lock then
			obj._lock.Active = locked
			obj._lock.Visible = locked
			Util.Tween(obj._lock, 0.2, { BackgroundTransparency = locked and 0.45 or 1 }, "Quad")
			Util.Tween(obj._lockIcon, 0.2, { ImageTransparency = locked and 0.1 or 1 }, "Quad")
		end
	end
	function obj:Destroy()
		Elements.Unregister(container, entry)
		row.Frame:Destroy()
	end

	if opts.Flag then
		obj.Flag = opts.Flag
		Vesper.Flags[opts.Flag] = obj
		if container.Window then container.Window.Flags[opts.Flag] = obj end
	end
	if opts.Visible == false then obj:SetVisible(false) end
	if opts.Locked then obj:SetLocked(true) end
	return obj
end

-- ─────────────────────────────────────────────────────────────
--  Reusable control builders
-- ─────────────────────────────────────────────────────────────

--- Switch (pill with knob). Returns { Frame, Set(on, instant), Press(down), Burst() }
function Elements.MakeSwitch(parent, w, h)
	w, h = w or 40, h or 22
	local pad = 3
	local knobSize = h - pad * 2
	local track = New("Frame", { Name = "Switch", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(w, h), BackgroundColor3 = WHITE, Parent = parent })
	Theme.Bind(track, { BackgroundColor3 = "Input" })
	Util.Corner(track, h)
	Util.Shade(track, 90, 0.12)
	local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Parent = track })
	Util.Corner(fill, h)
	Theme.AccentGradient(fill, 0)
	local knob = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, pad, 0.5, 0), Size = UDim2.fromOffset(knobSize, knobSize), BackgroundColor3 = WHITE, ZIndex = 2, Parent = track })
	Theme.Bind(knob, { BackgroundColor3 = "Muted" })
	Util.Corner(knob, h)
	local core = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0), BackgroundColor3 = WHITE, Parent = knob })
	Util.Corner(core, h)
	Theme.AccentGradient(core, 45)

	local sw = { Frame = track, On = false }
	local function knobX(on) return on and (w - knobSize - pad) or pad end
	function sw.Set(on, instant)
		sw.On = on
		local pos = UDim2.new(0, knobX(on), 0.5, 0)
		local dot = UDim2.fromOffset(on and math.max(knobSize - 8, 4) or 0, on and math.max(knobSize - 8, 4) or 0)
		if instant then
			knob.Position = pos
			core.Size = dot
			fill.BackgroundTransparency = on and 0 or 1
			knob.BackgroundColor3 = on and WHITE or Theme.Current.Muted
		else
			Util.Tween(knob, 0.3, { Position = pos }, "Back")
			Util.Tween(core, 0.3, { Size = dot }, on and "Back" or "Quad")
			Util.Tween(fill, 0.22, { BackgroundTransparency = on and 0 or 1 }, "Quad")
			Util.Tween(knob, 0.22, { BackgroundColor3 = on and WHITE or Theme.Current.Muted }, "Quad")
		end
		Theme.Registry[knob].BackgroundColor3 = function(t) return sw.On and WHITE or t.Muted end
	end
	function sw.Press(down)
		Util.Tween(knob, 0.12, { Size = UDim2.fromOffset(down and knobSize + 4 or knobSize, knobSize) }, "Quad")
	end
	function sw.Burst()
		Fx.Burst(track, { X = knobX(sw.On) + knobSize / 2, Y = h / 2, Count = 6, Distance = 18, Size = 3, Duration = 0.45 })
	end
	return sw
end

--- Slider core: track + fill + thumb (with halo and a value bubble while dragging) + value label.
--- o = { Min, Max, Default, Step, Suffix, OnChange(value), OnEnd(value) }
function Elements.MakeSlider(parent, o)
	local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
	local holder = New("Frame", { Name = "Slider", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = parent })
	local valueLabel = New("TextLabel", {
		Weight = "Medium", TextSize = 11, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(1, 0, 0, 12),
		TextXAlignment = Enum.TextXAlignment.Right, Parent = holder,
	})
	Theme.Bind(valueLabel, { TextColor3 = "Muted" })

	local hit = New("TextButton", { Name = "Hit", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 22), Parent = holder })
	local trackInset = 8
	local track = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, trackInset, 0.5, 0), Size = UDim2.new(1, -trackInset * 2, 0, 4), BackgroundColor3 = WHITE, Parent = hit })
	Theme.Bind(track, { BackgroundColor3 = "Input" })
	Util.Corner(track, 3)
	Util.Shade(track, 90, 0.14)
	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, Parent = track })
	Util.Corner(fill, 3)
	Theme.AccentGradient(fill, 0)
	local tick = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(1, 9), BackgroundColor3 = WHITE, BackgroundTransparency = 0.5, Visible = false, Parent = track })
	Theme.Bind(tick, { BackgroundColor3 = "Muted" })
	local thumb = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = WHITE, ZIndex = 3, Parent = track })
	Theme.Bind(thumb, { BackgroundColor3 = "Text" })
	Util.Corner(thumb, 14)
	local halo = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 2, Parent = thumb })
	Theme.Bind(halo, { BackgroundColor3 = "Accent" })
	Util.Corner(halo, 30)
	local core = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = WHITE, ZIndex = 4, Parent = thumb })
	Util.Corner(core, 6)
	Theme.AccentGradient(core, 45)

	local bubble = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -9), Size = UDim2.new(0, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 6, Parent = thumb,
	})
	Theme.Bind(bubble, { BackgroundColor3 = "Popup" })
	Util.Corner(bubble, 7)
	Util.Padding(bubble, 0, 8, 0, 8)
	Shadow.Edge(bubble, { Inset = 3, Alpha = 0.7 })
	local bubbleText = New("TextLabel", { Weight = "SemiBold", TextSize = 11, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextTransparency = 1, ZIndex = 7, Parent = bubble })
	Theme.Bind(bubbleText, { TextColor3 = "Text" })

	local s = { Value = min, Min = min, Max = max, Holder = holder, Hit = hit, Enabled = true }
	local lastTick = 0

	local function render(value, instant)
		local ratio = max > min and (value - min) / (max - min) or 0
		local fillSize, pos = UDim2.fromScale(ratio, 1), UDim2.fromScale(ratio, 0.5)
		if instant then
			fill.Size, thumb.Position = fillSize, pos
		else
			Util.Tween(fill, 0.08, { Size = fillSize }, "Quad")
			Util.Tween(thumb, 0.08, { Position = pos }, "Quad")
		end
		local text = Util.FormatNumber(value, step) .. (o.Suffix or "")
		valueLabel.Text = text
		bubbleText.Text = text
	end

	function s.Set(value, silent, instant)
		value = Util.Clamp(Util.Round((tonumber(value) or min) - min, step) + min, min, max)
		value = tonumber(string.format("%.8f", value)) -- strip float noise (0.30000000000000004 -> 0.3)
		local changed = value ~= s.Value
		s.Value = value
		render(value, instant)
		if changed and not silent and o.OnChange then o.OnChange(value) end
	end

	function s.SetRange(newMin, newMax, newStep)
		min, max, step = newMin or min, newMax or max, newStep or step
		s.Min, s.Max = min, max
		s.Set(s.Value, true, true)
	end

	function s.SetEnabled(on)
		s.Enabled = on
		local a = on and 0 or 0.6
		Util.Tween(valueLabel, 0.2, { TextTransparency = a }, "Quad")
		Util.Tween(fill, 0.2, { BackgroundTransparency = a }, "Quad")
		Util.Tween(thumb, 0.2, { BackgroundTransparency = a }, "Quad")
		Util.Tween(track, 0.2, { BackgroundTransparency = a }, "Quad")
		hit.Active = on
	end

	local function bubbleShow(show)
		Util.Tween(bubble, 0.16, { BackgroundTransparency = show and 0.02 or 1 }, "Quad")
		Util.Tween(bubbleText, 0.16, { TextTransparency = show and 0 or 1 }, "Quad")
		Util.Tween(bubble, 0.22, { Position = UDim2.new(0.5, 0, 0, show and -11 or -6) }, "Out")
	end

	Util.Drag(hit, function(pos)
		if not s.Enabled then return end
		local ratio = Util.Clamp((pos.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local before = s.Value
		s.Set(min + ratio * (max - min))
		if s.Value ~= before and os.clock() - lastTick > 0.045 then
			lastTick = os.clock()
			Sound.Play("Tick")
		end
	end, function()
		if not s.Enabled then return false end
		Util.Tween(thumb, 0.18, { Size = UDim2.fromOffset(17, 17) }, "Back")
		Util.Tween(halo, 0.2, { Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 0.82 }, "Out")
		Theme.Bind(valueLabel, { TextColor3 = "Text" })
		bubbleShow(true)
	end, function()
		Util.Tween(thumb, 0.22, { Size = UDim2.fromOffset(14, 14) }, "Quad")
		Util.Tween(halo, 0.25, { Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1 }, "Quad")
		Theme.Bind(valueLabel, { TextColor3 = "Muted" })
		bubbleShow(false)
		if o.OnEnd then o.OnEnd(s.Value) end
	end)

	function s.SetTick(value)
		if value == nil then tick.Visible = false; return end
		local ratio = max > min and (value - min) / (max - min) or 0
		tick.Position = UDim2.fromScale(ratio, 0.5)
		tick.Visible = true
	end

	s.Set(o.Default or min, true, true)
	return s
end

-- ─────────────────────────────────────────────────────────────
--  Button
-- ─────────────────────────────────────────────────────────────
Elements.Create.Button = function(container, opts)
	local variant = opts.Variant or "Default"
	local row = Elements.Row(container, opts, 22, 22, variant == "Primary" and "plain" or true)
	local card = row.Frame
	local iconToken = "Muted"
	local fxColor = "Accent"

	if variant == "Primary" then
		-- filled with the accent gradient
		Theme.Registry[card].BackgroundColor3 = nil
		row.Shade:Destroy()
		card.BackgroundColor3 = WHITE
		card.BackgroundTransparency = 0
		Theme.AccentGradient(card, 20)
		Theme.Bind(row.TitleLabel, { TextColor3 = "AccentText" })
		Theme.Bind(row.DescLabel, { TextColor3 = "AccentText" })
		row.DescLabel.TextTransparency = 0.25
		Theme.Bind(row.Depth, { BackgroundColor3 = function(t) return t.Accent:Lerp(BLACK, 0.55) end })
		iconToken = "AccentText"
		fxColor = WHITE
		card.MouseEnter:Connect(function()
			Util.Tween(card, 0.14, { BackgroundColor3 = Color3.new(0.9, 0.9, 0.9) }, "Quad")
			Fx.Sheen(card, { Radius = UDim.new(0, 12), Alpha = 0.78, Duration = 0.7 })
		end)
		card.MouseLeave:Connect(function() Util.Tween(card, 0.14, { BackgroundColor3 = WHITE }, "Quad") end)
	elseif variant == "Danger" then
		Theme.Bind(row.TitleLabel, { TextColor3 = "Danger" })
		iconToken = "Danger"
		fxColor = "Danger"
	end

	local icon = Util.Icon(row.Right, opts.ButtonIcon or "chevron-right", 16, iconToken, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5) })
	card.MouseEnter:Connect(function() Util.Tween(icon, 0.2, { Position = UDim2.new(1, 3, 0.5, 0) }, "Quad") end)
	card.MouseLeave:Connect(function() Util.Tween(icon, 0.2, { Position = UDim2.new(1, 0, 0.5, 0) }, "Quad") end)

	local obj = { Type = "Button" }
	function obj:Fire() Util.Fire(opts.Callback) end
	card.Activated:Connect(function()
		if obj.Locked then return end
		Sound.Play("Click")
		Elements.Click(row, fxColor)
		Fx.Pop(icon, 0)
		obj:Fire()
	end)
	return Elements.Finish(obj, container, row, "element", opts)
end

--- A single line of compact buttons: { Buttons = { {Title, Icon, Variant = "Primary"|"Secondary"|"Ghost"|"Danger", Callback} } }
Elements.Create.ButtonRow = function(container, opts)
	local frame = New("Frame", {
		Name = "ButtonRow", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = Elements.NextOrder(container), Parent = container.Content,
	})
	Util.Padding(frame, 0, 2, 3, 2)
	local list = Util.List(frame, 8, Enum.FillDirection.Horizontal, opts.Align == "Right" and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	list.Wraps = true
	local texts = {}
	local buttons = {}
	for i, def in opts.Buttons or {} do
		buttons[i] = Util.MakeButton({
			Parent = frame, Text = def.Title, Icon = def.Icon, Variant = def.Variant or "Secondary", Height = 32, LayoutOrder = i, Callback = def.Callback,
		})
		table.insert(texts, def.Title or "")
	end
	local obj = { Type = "ButtonRow", Frame = frame, Buttons = buttons, Container = container }
	obj._entry = Elements.Register(container, frame, "element", table.concat(texts, " "), "", { Type = "ButtonRow", Obj = obj, FxTarget = false })
	function obj:SetVisible(v) obj._entry.Hidden = not v; frame.Visible = v end
	function obj:Destroy() Elements.Unregister(container, obj._entry); frame:Destroy() end
	return obj
end

-- ─────────────────────────────────────────────────────────────
--  Toggle
-- ─────────────────────────────────────────────────────────────
Elements.Create.Toggle = function(container, opts)
	local row = Elements.Row(container, opts, 42, 22, true)
	local sw = Elements.MakeSwitch(row.Right, 40, 22)
	local obj = { Type = "Toggle", Value = opts.Default == true }

	function obj:Set(value, silent)
		value = value == true
		local changed = value ~= obj.Value
		obj.Value = value
		sw.Set(value)
		if changed and not silent then
			Sound.Play(value and "ToggleOn" or "ToggleOff")
			if value then sw.Burst() end
			Util.Fire(opts.Callback, value)
		end
	end
	function obj:Toggle() obj:Set(not obj.Value) end

	row.Frame.Activated:Connect(function()
		if obj.Locked then return end
		Elements.Click(row, obj.Value and "Muted" or "Accent")
		obj:Toggle()
	end)
	row.Frame.MouseButton1Down:Connect(function() sw.Press(true) end)
	row.Frame.MouseButton1Up:Connect(function() sw.Press(false) end)
	row.Frame.MouseLeave:Connect(function() sw.Press(false) end)

	sw.Set(obj.Value, true)
	obj.GetConfig = function() return obj.Value end
	obj.SetConfig = function(v) obj:Set(v == true) end
	return Elements.Finish(obj, container, row, "element", opts)
end

-- ─────────────────────────────────────────────────────────────
--  Checkbox  (Style = "Square" | "Round")
-- ─────────────────────────────────────────────────────────────
Elements.Create.Checkbox = function(container, opts)
	local row = Elements.Row(container, opts, 24, 24, true)
	local round = opts.Style == "Round"
	local size = 22
	local radius = round and size or 7
	local obj = { Type = "Checkbox", Value = opts.Default == true }

	local box = New("Frame", { Name = "Box", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(size, size), BackgroundColor3 = WHITE, Parent = row.Right })
	Theme.Bind(box, { BackgroundColor3 = "Input" })
	Util.Corner(box, radius)
	Util.Shade(box, 90, 0.14)
	Shadow.Edge(box, { Inset = 3, Alpha = 0.8 })
	local fill = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Parent = box })
	Util.Corner(fill, radius)
	Theme.AccentGradient(fill, 45)
	local mark = Util.Icon(box, "check", 14, "AccentText", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 4), ImageTransparency = 1, ZIndex = 3 })

	local function paint(instant)
		local on = obj.Value
		local fillSize = UDim2.fromOffset(on and size or 0, on and size or 0)
		local markSize = UDim2.fromOffset(on and 14 or 4, on and 14 or 4)
		if instant then
			fill.Size, fill.BackgroundTransparency = fillSize, on and 0 or 1
			mark.Size, mark.ImageTransparency = markSize, on and 0 or 1
		else
			Util.Tween(fill, 0.26, { Size = fillSize, BackgroundTransparency = on and 0 or 1 }, on and "Back" or "Quad")
			Util.Tween(mark, 0.3, { Size = markSize, ImageTransparency = on and 0 or 1 }, on and "Back" or "Quad")
		end
	end

	function obj:Set(value, silent)
		value = value == true
		local changed = value ~= obj.Value
		obj.Value = value
		paint()
		if changed and not silent then
			Sound.Play(value and "ToggleOn" or "ToggleOff")
			if value then Fx.Burst(box, { X = size / 2, Y = size / 2, Count = 7, Distance = 20, Size = 3.5, Duration = 0.5 }) end
			Util.Fire(opts.Callback, value)
		end
	end
	function obj:Toggle() obj:Set(not obj.Value) end

	row.Frame.Activated:Connect(function()
		if obj.Locked then return end
		Elements.Click(row, obj.Value and "Muted" or "Accent")
		obj:Toggle()
	end)
	row.Frame.MouseButton1Down:Connect(function() Util.Tween(box, 0.1, { Size = UDim2.fromOffset(size - 3, size - 3) }, "Quad") end)
	local function release() Util.Tween(box, 0.25, { Size = UDim2.fromOffset(size, size) }, "Back") end
	row.Frame.MouseButton1Up:Connect(release)
	row.Frame.MouseLeave:Connect(release)

	paint(true)
	obj.GetConfig = function() return obj.Value end
	obj.SetConfig = function(v) obj:Set(v == true) end
	return Elements.Finish(obj, container, row, "element", opts)
end

-- ─────────────────────────────────────────────────────────────
--  Slider
-- ─────────────────────────────────────────────────────────────
Elements.Create.Slider = function(container, opts)
	local row = Elements.Row(container, opts, 220, 36, false)
	local obj = { Type = "Slider" }
	local core = Elements.MakeSlider(row.Right, {
		Min = opts.Min, Max = opts.Max, Default = opts.Default, Step = opts.Step, Suffix = opts.Suffix,
		OnChange = function(v) obj.Value = v; Util.Fire(opts.Callback, v) end,
	})
	obj.Value = core.Value
	if opts.Default ~= nil and opts.ShowDefault ~= false then core.SetTick(opts.Default) end

	function obj:Set(value, silent)
		core.Set(value, silent)
		obj.Value = core.Value
	end
	function obj:SetRange(min, max, step) core.SetRange(min, max, step); obj.Value = core.Value end
	obj.GetConfig = function() return obj.Value end
	obj.SetConfig = function(v) obj:Set(v) end
	return Elements.Finish(obj, container, row, "element", opts)
end

-- ─────────────────────────────────────────────────────────────
--  Toggle slider: ONE control. A slider whose knob is also the switch.
--    · drag the knob (or press the track) to change the value
--    · tap the knob to turn it on / off
--  Callback(enabled, value)
-- ─────────────────────────────────────────────────────────────
Elements.Create.ToggleSlider = function(container, opts)
	local row = Elements.Row(container, opts, 236, 28, false)
	local min, max, step = opts.Min or 0, opts.Max or 100, opts.Step or 1
	local obj = { Type = "ToggleSlider", Enabled = opts.Enabled == true or opts.Default_Enabled == true, Value = Util.Clamp(opts.Default or min, min, max) }

	local VALUE_W, KNOB, TRACK_H = 48, 20, 24
	local valueLabel = New("TextLabel", {
		Weight = "SemiBold", TextSize = 12, Size = UDim2.new(0, VALUE_W - 6, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row.Right,
	})
	local track = New("Frame", {
		Name = "Track", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(1, -VALUE_W, 0, TRACK_H),
		BackgroundColor3 = WHITE, Parent = row.Right,
	})
	Theme.Bind(track, { BackgroundColor3 = "Input" })
	Util.Corner(track, TRACK_H)
	Util.Shade(track, 90, 0.12)
	local fillClip = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = track })
	local fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = WHITE, Parent = fillClip })
	Util.Corner(fill, TRACK_H)
	Theme.AccentGradient(fill, 0)
	local hit = New("TextButton", { Size = UDim2.new(1, 0, 1, 8), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5, Parent = track })

	local knob = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(KNOB, KNOB), BackgroundColor3 = WHITE, ZIndex = 3, Parent = track })
	Theme.Bind(knob, { BackgroundColor3 = "Muted" })
	Util.Corner(knob, KNOB)
	local halo = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(KNOB, KNOB), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 2, Parent = knob })
	Theme.Bind(halo, { BackgroundColor3 = "Accent" })
	Util.Corner(halo, 40)
	local dot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0), BackgroundColor3 = WHITE, ZIndex = 4, Parent = knob })
	Util.Corner(dot, 12)
	Theme.AccentGradient(dot, 45)

	-- knob centre sits `KNOB/2 + 2` inside the track at both ends
	local inset = KNOB / 2 + 2
	local function at(ratio) return UDim2.new(ratio, inset - ratio * inset * 2, 0.5, 0) end
	local function atFill(ratio) return UDim2.new(ratio, inset - ratio * inset * 2, 1, 0) end
	local function ratioOf(value) return max > min and (value - min) / (max - min) or 0 end

	local function paintValue(instant)
		local r = ratioOf(obj.Value)
		if instant then
			knob.Position, fill.Size = at(r), atFill(r)
		else
			Util.Tween(knob, 0.08, { Position = at(r) }, "Quad")
			Util.Tween(fill, 0.08, { Size = atFill(r) }, "Quad")
		end
		valueLabel.Text = Util.FormatNumber(obj.Value, step) .. (opts.Suffix or "")
	end
	local function paintState(instant)
		local on = obj.Enabled
		local props = { fillT = on and 0 or 0.72, dot = on and UDim2.fromOffset(8, 8) or UDim2.fromOffset(0, 0) }
		local labelColor = Theme.Resolve(on and "Text" or "Muted")
		if instant then
			fill.BackgroundTransparency, dot.Size = props.fillT, props.dot
			knob.BackgroundColor3 = on and WHITE or Theme.Current.Muted
			valueLabel.TextColor3 = labelColor
		else
			Util.Tween(fill, 0.25, { BackgroundTransparency = props.fillT }, "Quad")
			Util.Tween(dot, 0.3, { Size = props.dot }, on and "Back" or "Quad")
			Util.Tween(knob, 0.22, { BackgroundColor3 = on and WHITE or Theme.Current.Muted }, "Quad")
			Util.Tween(valueLabel, 0.22, { TextColor3 = labelColor }, "Quad")
		end
		Theme.Registry[knob].BackgroundColor3 = function(t) return obj.Enabled and WHITE or t.Muted end
		if Theme.Registry[valueLabel] then Theme.Registry[valueLabel].TextColor3 = function(t) return obj.Enabled and t.Text or t.Muted end end
	end
	Theme.Bind(valueLabel, { TextColor3 = function(t) return obj.Enabled and t.Text or t.Muted end })

	local function fire() Util.Fire(opts.Callback, obj.Enabled, obj.Value) end

	function obj:SetEnabled(on, silent)
		on = on == true
		local changed = on ~= obj.Enabled
		obj.Enabled = on
		paintState()
		if changed and not silent then
			Sound.Play(on and "ToggleOn" or "ToggleOff")
			if on then Fx.Burst(track, { X = knob.AbsolutePosition.X and (knob.AbsolutePosition.X - track.AbsolutePosition.X + KNOB / 2) / Util.GetScale(track) or 0, Y = TRACK_H / 2, Count = 6, Distance = 18, Size = 3, Duration = 0.45 }) end
			fire()
		end
	end
	function obj:Set(value, silent)
		value = Util.Clamp(Util.Round((tonumber(value) or min) - min, step) + min, min, max)
		value = tonumber(string.format("%.8f", value))
		local changed = value ~= obj.Value
		obj.Value = value
		paintValue()
		if changed and not silent then fire() end
	end
	function obj:Toggle() obj:SetEnabled(not obj.Enabled) end

	-- one pointer gesture: tap on the knob = switch, drag = slide
	local startX, onKnob, dragged
	local lastTick = 0
	local function setFromPointer(x)
		local w = math.max(track.AbsoluteSize.X, 1)
		local scale = Util.GetScale(track)
		local pad = inset * scale
		local ratio = Util.Clamp((x - track.AbsolutePosition.X - pad) / math.max(w - pad * 2, 1), 0, 1)
		local before = obj.Value
		obj:Set(min + ratio * (max - min))
		if obj.Value ~= before and os.clock() - lastTick > 0.045 then
			lastTick = os.clock()
			Sound.Play("Tick")
		end
	end
	Util.Drag(hit, function(pos)
		if obj.Locked or not startX then return end
		local scale = Util.GetScale(track)
		if not onKnob then
			dragged = true
			setFromPointer(pos.X)
		elseif dragged or math.abs(pos.X - startX) > 4 * scale then
			dragged = true
			setFromPointer(pos.X)
		end
	end, function(input)
		if obj.Locked then return false end
		startX, dragged = input.Position.X, false
		local scale = Util.GetScale(track)
		local knobX = knob.AbsolutePosition.X + knob.AbsoluteSize.X / 2
		onKnob = math.abs(startX - knobX) <= (KNOB / 2 + 6) * scale
		Util.Tween(knob, 0.16, { Size = UDim2.fromOffset(KNOB + 4, KNOB + 4) }, "Back")
		Util.Tween(halo, 0.2, { Size = UDim2.fromOffset(KNOB + 14, KNOB + 14), BackgroundTransparency = 0.82 }, "Out")
	end, function()
		Util.Tween(knob, 0.22, { Size = UDim2.fromOffset(KNOB, KNOB) }, "Quad")
		Util.Tween(halo, 0.25, { Size = UDim2.fromOffset(KNOB, KNOB), BackgroundTransparency = 1 }, "Quad")
		if onKnob and not dragged and startX then
			Elements.Click(row, obj.Enabled and "Muted" or "Accent")
			obj:Toggle()
		end
		startX = nil
	end)

	paintValue(true)
	paintState(true)
	obj.GetConfig = function() return { Enabled = obj.Enabled, Value = obj.Value } end
	obj.SetConfig = function(v)
		if type(v) ~= "table" then return end
		obj:Set(v.Value)
		obj:SetEnabled(v.Enabled == true)
	end
	return Elements.Finish(obj, container, row, "element", opts)
end

-- ─────────────────────────────────────────────────────────────
--  Stepper  ( − 3 + )
-- ─────────────────────────────────────────────────────────────
Elements.Create.Stepper = function(container, opts)
	local row = Elements.Row(container, opts, 108, 28, false)
	local min, max, step = opts.Min or 0, opts.Max or 100, opts.Step or 1
	local obj = { Type = "Stepper", Value = Util.Clamp(opts.Default or min, min, max) }

	local chip = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = row.Right })
	Theme.Bind(chip, { BackgroundColor3 = "Input" })
	Util.Corner(chip, 9)
	Util.Shade(chip, 90, 0.1)
	Shadow.Edge(chip, { Inset = 5, Alpha = 0.82 })
	local label = New("TextLabel", { Weight = "SemiBold", TextSize = 13, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = chip })
	Theme.Bind(label, { TextColor3 = "Text" })

	function obj:Set(value, silent)
		value = Util.Clamp(Util.Round((tonumber(value) or min) - min, step) + min, min, max)
		value = tonumber(string.format("%.8f", value))
		local changed = value ~= obj.Value
		obj.Value = value
		label.Text = Util.FormatNumber(value, step) .. (opts.Suffix or "")
		if changed and not silent then
			Sound.Play("Tick")
			label.TextSize = 15
			Util.Tween(label, 0.25, { TextSize = 13 }, "Back")
			Util.Fire(opts.Callback, value)
		end
	end

	local holdId = 0
	local function bind(side, icon, dir)
		local btn = New("TextButton", {
			AnchorPoint = Vector2.new(side == "left" and 0 or 1, 0.5), Position = UDim2.new(side == "left" and 0 or 1, 0, 0.5, 0),
			Size = UDim2.new(0, 30, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Parent = chip,
		})
		Theme.Bind(btn, { BackgroundColor3 = "InputHover" })
		Util.Corner(btn, 9)
		local img = Util.Icon(btn, icon, 13, "SubText", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		btn.MouseEnter:Connect(function() Util.Tween(btn, 0.12, { BackgroundTransparency = 0 }, "Quad") end)
		btn.MouseLeave:Connect(function() holdId += 1; Util.Tween(btn, 0.12, { BackgroundTransparency = 1 }, "Quad") end)
		btn.MouseButton1Up:Connect(function() holdId += 1 end)
		btn.MouseButton1Down:Connect(function()
			if obj.Locked then return end
			holdId += 1
			local id = holdId
			Fx.Ripple(btn, { Alpha = 0.8, Ring = false, Duration = 0.4, Radius = UDim.new(0, 9) })
			Fx.Pop(img, dir * 18)
			obj:Set(obj.Value + dir * step)
			task.delay(0.4, function()
				while holdId == id do
					obj:Set(obj.Value + dir * step)
					task.wait(0.07)
				end
			end)
		end)
	end
	bind("left", "minus", -1)
	bind("right", "plus", 1)

	obj:Set(obj.Value, true)
	obj.GetConfig = function() return obj.Value end
	obj.SetConfig = function(v) obj:Set(v) end
	return Elements.Finish(obj, container, row, "element", opts)
end

-- ─────────────────────────────────────────────────────────────
--  Segmented control  ( Low | Medium | High )
-- ─────────────────────────────────────────────────────────────
Elements.Create.Segmented = function(container, opts)
	local row = Elements.Row(container, opts, 0, 0, false)
	local values = opts.Values or {}
	local n = math.max(#values, 1)
	local obj = { Type = "Segmented", Value = values[1] }

	New("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundTransparency = 1, LayoutOrder = 3, Parent = row.Left })
	local bar = New("Frame", { Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 4, BackgroundColor3 = WHITE, Parent = row.Left })
	Theme.Bind(bar, { BackgroundColor3 = "Input" })
	Util.Corner(bar, 10)
	Util.Shade(bar, 90, 0.12)
	local inner = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = bar })
	Util.Padding(inner, 3, 3, 3, 3)
	local pill = New("Frame", { Size = UDim2.fromScale(1 / n, 1), BackgroundColor3 = WHITE, Parent = inner })
	Util.Corner(pill, 8)
	Theme.AccentGradient(pill, 20)
	Shadow.Edge(pill, { Inset = 5, Alpha = 0.7 })
	Util.FadeLine(pill, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.5, Token = function() return WHITE end, ZIndex = 3 })

	local labels = {}
	for i, value in values do
		local btn = New("TextButton", { Position = UDim2.fromScale((i - 1) / n, 0), Size = UDim2.fromScale(1 / n, 1), ZIndex = 2, Parent = inner })
		local text = New("TextLabel", { Weight = "Medium", TextSize = 12, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2, Parent = btn })
		Theme.Bind(text, { TextColor3 = function(t) return obj.Value == value and t.AccentText or t.SubText end })
		Util.SetText(text, tostring(value))
		labels[value] = text
		btn.Activated:Connect(function()
			if obj.Locked then return end
			Sound.Play("Select")
			Fx.Ripple(btn, { Alpha = 0.88, Ring = false, Duration = 0.45, Radius = UDim.new(0, 8) })
			obj:Set(value)
		end)
	end

	function obj:Set(value, silent)
		if type(value) == "number" and values[value] ~= nil and not table.find(values, value) then value = values[value] end
		local index = table.find(values, value)
		if not index then return end
		local changed = obj.Value ~= value
		obj.Value = value
		Util.Tween(pill, 0.34, { Position = UDim2.fromScale((index - 1) / n, 0) }, "Out")
		for v, label in labels do
			Util.Tween(label, 0.2, { TextColor3 = Theme.Resolve(v == value and "AccentText" or "SubText") }, "Quad")
		end
		if changed and not silent then Util.Fire(opts.Callback, value) end
	end

	local start = values[1]
	if opts.Default ~= nil and table.find(values, opts.Default) then start = opts.Default end
	obj.Value = start
	local startIndex = table.find(values, start) or 1
	pill.Position = UDim2.fromScale((startIndex - 1) / n, 0)
	for v, label in labels do label.TextColor3 = Theme.Resolve(v == start and "AccentText" or "SubText") end

	obj.GetConfig = function() return obj.Value end
	obj.SetConfig = function(v) obj:Set(v) end
	return Elements.Finish(obj, container, row, "element", opts)
end

-- ─────────────────────────────────────────────────────────────
--  Progress bar
-- ─────────────────────────────────────────────────────────────
Elements.Create.Progress = function(container, opts)
	local row = Elements.Row(container, opts, 52, 18, false)
	local min, max = opts.Min or 0, opts.Max or 100
	local obj = { Type = "Progress", Value = min }

	local percent = New("TextLabel", {
		Weight = "SemiBold", TextSize = 12, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Right, Parent = row.Right,
	})
	Theme.Bind(percent, { TextColor3 = "SubText" })

	New("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundTransparency = 1, LayoutOrder = 3, Parent = row.Left })
	local track = New("Frame", { Size = UDim2.new(1, 0, 0, 7), LayoutOrder = 4, BackgroundColor3 = WHITE, Parent = row.Left })
	Theme.Bind(track, { BackgroundColor3 = "Input" })
	Util.Corner(track, 4)
	Util.Shade(track, 90, 0.14)
	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, Parent = track })
	Util.Corner(fill, 4)
	Theme.AccentGradient(fill, 0)
	local head = New("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(2, 11), BackgroundColor3 = WHITE, BackgroundTransparency = 0.2, Parent = fill })
	Util.Corner(head, 2)

	function obj:Set(value, text)
		value = Util.Clamp(tonumber(value) or min, min, max)
		obj.Value = value
		local ratio = max > min and (value - min) / (max - min) or 0
		Util.Tween(fill, 0.5, { Size = UDim2.fromScale(ratio, 1) }, "Out")
		head.Visible = ratio > 0.02 and ratio < 0.999
		percent.Text = text or string.format("%d%%", math.floor(ratio * 100 + 0.5))
	end
	obj:Set(opts.Default or min)
	fill.Size = UDim2.fromScale(max > min and (obj.Value - min) / (max - min) or 0, 1)
	return Elements.Finish(obj, container, row, "element", opts)
end
local LUA_KEYWORDS = {}
for _, w in { "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "continue" } do
	LUA_KEYWORDS[w] = true
end
local LUA_BUILTINS = {}
for _, w in { "print", "warn", "error", "pairs", "ipairs", "game", "workspace", "script", "task", "wait", "spawn", "loadstring", "require", "typeof", "type", "tostring", "tonumber", "pcall", "xpcall", "math", "string", "table", "Instance", "Vector3", "Vector2", "CFrame", "Color3", "Enum", "UDim2", "UDim", "getgenv", "setmetatable", "getmetatable", "select", "next", "unpack", "assert", "HttpGet" } do
	LUA_BUILTINS[w] = true
end

local function escapeRich(text)
	text = string.gsub(text, "&", "&amp;")
	text = string.gsub(text, "<", "&lt;")
	text = string.gsub(text, ">", "&gt;")
	text = string.gsub(text, '"', "&quot;")
	text = string.gsub(text, "'", "&apos;")
	return text
end

function Util.Highlight(src)
	local t = Theme.Current
	local colors = {
		kw = Util.ToHex(t.Accent), str = Util.ToHex(t.Success), num = Util.ToHex(t.Warning),
		com = Util.ToHex(t.Muted), fn = Util.ToHex(t.Info),
	}
	local out = {}
	local function push(kind, text)
		text = escapeRich(text)
		if kind then
			table.insert(out, '<font color="' .. colors[kind] .. '">' .. text .. "</font>")
		else
			table.insert(out, text)
		end
	end
	local i, n = 1, #src
	while i <= n do
		local c = string.sub(src, i, i)
		local two = string.sub(src, i, i + 1)
		if two == "--" then
			local level = string.match(src, "^%-%-%[(=*)%[", i)
			if level then
				local close = "]" .. level .. "]"
				local e = string.find(src, close, i, true)
				e = e and (e + #close - 1) or n
				push("com", string.sub(src, i, e)); i = e + 1
			else
				local e = string.find(src, "\n", i, true)
				e = e and (e - 1) or n
				push("com", string.sub(src, i, e)); i = e + 1
			end
		elseif c == '"' or c == "'" then
			local j = i + 1
			while j <= n do
				local d = string.sub(src, j, j)
				if d == "\\" then j += 2
				elseif d == c or d == "\n" then break
				else j += 1 end
			end
			push("str", string.sub(src, i, j)); i = j + 1
		elseif string.match(src, "^%[=*%[", i) then
			local level = string.match(src, "^%[(=*)%[", i)
			local close = "]" .. level .. "]"
			local e = string.find(src, close, i, true)
			e = e and (e + #close - 1) or n
			push("str", string.sub(src, i, e)); i = e + 1
		elseif string.match(c, "%d") then
			local num = string.match(src, "^0[xX]%x+", i)
			if not num then
				num = string.match(src, "^%d+%.?%d*", i)
				local exp = string.match(src, "^[eE][+-]?%d+", i + #num)
				if exp then num ..= exp end
			end
			push("num", num); i += #num
		elseif string.match(c, "[%a_]") then
			local word = string.match(src, "^[%w_]+", i)
			if LUA_KEYWORDS[word] then push("kw", word)
			elseif LUA_BUILTINS[word] then push("fn", word)
			else push(nil, word) end
			i += #word
		else
			push(nil, c); i += 1
		end
	end
	return table.concat(out)
end


-- ─────────────────────────────────────────────────────────────
--  Dropdown (single + multi, optional search)
--    · items slide in one after another
--    · a fading line separates the items, the picked one gets an accent bar and a glow
--    · the indicator is a glowing orb (single) or a gradient checkbox (multi), not a plain tick
-- ─────────────────────────────────────────────────────────────
local function normalizeItems(list)
	local out = {}
	for _, v in list or {} do
		if type(v) == "table" then
			table.insert(out, { Title = tostring(v.Title or v.Value), Value = v.Value ~= nil and v.Value or v.Title, Icon = v.Icon })
		else
			table.insert(out, { Title = tostring(v), Value = v })
		end
	end
	return out
end

--- Orb (radio) or rounded box (multi). Returns { Set(on, instant, pop) }
local function makeIndicator(parent, multi)
	local size = 18
	local radius = multi and 6 or size
	local ind = New("Frame", {
		Name = "Indicator", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = WHITE, Parent = parent,
	})
	Theme.Bind(ind, { BackgroundColor3 = "Input" })
	Util.Corner(ind, radius)
	Util.Shade(ind, 90, 0.18)
	local halo = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 0, Parent = ind,
	})
	Theme.Bind(halo, { BackgroundColor3 = "Accent" })
	Util.Corner(halo, multi and 10 or 40)
	local fill = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 2, Parent = ind,
	})
	Util.Corner(fill, radius)
	Theme.AccentGradient(fill, 45)
	local mark
	if multi then
		mark = Util.Icon(ind, "check", 12, "AccentText", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, 3), ImageTransparency = 1, ZIndex = 3,
		})
	else
		mark = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = WHITE, ZIndex = 3, Parent = ind,
		})
		Util.Corner(mark, 8)
	end

	local api = {}
	function api.Set(on, instant, pop)
		local full = UDim2.fromOffset(on and size or 0, on and size or 0)
		local markSize = multi and UDim2.fromOffset(on and 12 or 3, on and 12 or 3) or UDim2.fromOffset(on and 6 or 0, on and 6 or 0)
		if instant then
			fill.Size, fill.BackgroundTransparency = full, on and 0 or 1
			mark.Size = markSize
			if multi then mark.ImageTransparency = on and 0 or 1 end
			return
		end
		Util.Tween(fill, 0.26, { Size = full, BackgroundTransparency = on and 0 or 1 }, on and "Back" or "Quad")
		Util.Tween(mark, 0.3, { Size = markSize }, on and "Back" or "Quad")
		if multi then Util.Tween(mark, 0.2, { ImageTransparency = on and 0 or 1 }, "Quad") end
		if on and pop then
			halo.Size = UDim2.fromOffset(size, size)
			halo.BackgroundTransparency = 0.55
			Util.Tween(halo, 0.5, { Size = UDim2.fromOffset(size + 16, size + 16), BackgroundTransparency = 1 }, "Out")
		end
	end
	return api
end

Elements.Create.Dropdown = function(container, opts)
	local CHIP_W = opts.Width or 138
	local ITEM_H, GAP = 34, 3
	local row = Elements.Row(container, opts, CHIP_W, 28, true)
	local multi = opts.Multi == true
	local obj = { Type = "Dropdown", Multi = multi, Items = normalizeItems(opts.Values) }
	obj.Value = multi and {} or nil

	local chip = New("Frame", { Name = "Chip", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = row.Right })
	Theme.Bind(chip, { BackgroundColor3 = "Input" })
	Util.Corner(chip, 9)
	Util.Shade(chip, 90, 0.1)
	Shadow.Edge(chip, { Inset = 6, Alpha = 0.8 })
	Util.FadeLine(chip, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.3, ZIndex = 3, Thickness = 1 })
	local underline = Util.FadeLine(chip, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(0, 0, 0, 2),
		Token = "Accent", Strength = 1, Thickness = 2, ZIndex = 4,
	})
	local chipLabel = New("TextLabel", {
		Weight = "Medium", TextSize = 12, Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -34, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = chip,
	})
	Theme.Bind(chipLabel, { TextColor3 = "Text" })
	local chevron = Util.Icon(chip, "chevron-down", 13, "SubText", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -16, 0.5, 0) })
	row.Frame.MouseEnter:Connect(function() Util.Tween(chip, 0.14, { BackgroundColor3 = Theme.Current.InputHover }, "Quad") end)
	row.Frame.MouseLeave:Connect(function() Util.Tween(chip, 0.14, { BackgroundColor3 = Theme.Current.Input }, "Quad") end)

	local function titleOf(value)
		for _, item in obj.Items do
			if item.Value == value then return item.Title end
		end
		return tostring(value)
	end
	local function isSelected(value)
		if multi then return table.find(obj.Value, value) ~= nil end
		return obj.Value == value
	end
	local function renderChip()
		local text
		if multi then
			local n = #obj.Value
			if n == 0 then
				text = opts.Placeholder or "None"
			elseif n <= 2 then
				local titles = {}
				for _, v in obj.Value do table.insert(titles, titleOf(v)) end
				text = table.concat(titles, ", ")
			else
				text = n .. " selected"
			end
		else
			text = obj.Value ~= nil and titleOf(obj.Value) or (opts.Placeholder or "Select")
		end
		chipLabel.Text = text
		local empty = (multi and #obj.Value == 0) or (not multi and obj.Value == nil)
		chipLabel.TextTransparency = empty and 0.45 or 0
	end

	local function fire()
		Util.Fire(opts.Callback, multi and table.clone(obj.Value) or obj.Value)
	end

	function obj:Set(value, silent)
		if multi then
			local new = {}
			for _, v in (type(value) == "table" and value or {}) do
				for _, item in obj.Items do
					if item.Value == v or item.Title == v then table.insert(new, item.Value); break end
				end
			end
			obj.Value = new
		else
			local found
			for _, item in obj.Items do
				if item.Value == value or item.Title == value then found = item.Value; break end
			end
			if found == nil and value ~= nil and not opts.AllowNone then return end
			obj.Value = found
		end
		renderChip()
		if obj._paint then obj._paint() end
		if not silent then fire() end
	end

	function obj:Refresh(values, keep)
		obj.Items = normalizeItems(values)
		local previous = obj.Value
		obj.Value = multi and {} or nil
		if keep then obj:Set(previous, true) else renderChip() end
	end
	function obj:Close() if obj._popover then obj._popover.Close() end end

	function obj:Open()
		local window = container.Window
		local host = window.Host
		local items = obj.Items
		local searchable = opts.SearchBar == true or (opts.SearchBar ~= false and #items > 7)
		local top = searchable and 50 or 0
		local foot = multi and opts.Footer ~= false and 36 or 0
		local width = opts.ListWidth or math.max(CHIP_W + 44, 196)
		local listH = Util.Clamp(#items * (ITEM_H + GAP) + 10, 58, opts.MaxHeight or 238)
		local height = listH + top + foot
		local entries = {}
		local emptyLabel

		obj._popover = Util.OpenPopover(host, window.Overlay, row.Right, {
			Width = width, Height = height, Align = "Right",
			OnClose = function()
				obj._popover = nil
				obj._paint = nil
				Util.Tween(chevron, 0.25, { Rotation = 0 }, "Back")
				Util.Tween(underline, 0.25, { Size = UDim2.new(0, 0, 0, 2) }, "Quad")
			end,
			Build = function(frame, popover)
				local list = New("ScrollingFrame", {
					Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 1, -(top + foot)), AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollBarThickness = 2, ScrollBarImageTransparency = 0.4, VerticalScrollBarInset = Enum.ScrollBarInset.None, Parent = frame,
				})
				Theme.Bind(list, { ScrollBarImageColor3 = "Muted" })
				Util.Padding(list, 5, 6, 5, 6)
				Util.List(list, GAP)

				local countLabel
				local function paint(instant)
					for _, e in entries do
						local on = e.Item.Value ~= nil and isSelected(e.Item.Value)
						Util.Tween(e.Tint, 0.22, { BackgroundTransparency = on and 0 or 1 }, "Quad")
						Util.Tween(e.Bar, 0.28, { Size = UDim2.fromOffset(3, on and 16 or 0) }, on and "Back" or "Quad")
						Util.Tween(e.Label, 0.18, { TextColor3 = Theme.Resolve(on and "Text" or "SubText") }, "Quad")
						Util.Tween(e.Label, 0.22, { Position = UDim2.fromOffset(e.X + (on and 4 or 0), 0) }, "Out")
						e.Indicator.Set(on, instant, e.Pop)
						e.Pop = false
					end
					if countLabel then
						countLabel.Text = #obj.Value == 0 and "Nothing selected" or (#obj.Value .. " selected")
					end
				end
				obj._paint = function() paint(false) end

				local function build(filter, animate)
					for _, e in entries do e.Button:Destroy() end
					table.clear(entries)
					if emptyLabel then emptyLabel:Destroy(); emptyLabel = nil end
					local shown = 0
					for index, item in items do
						local title = Loc.Resolve(item.Title)
						if filter == "" or string.find(string.lower(title), filter, 1, true) then
							shown += 1
							local btn = New("TextButton", {
								Name = "Item", Size = UDim2.new(1, 0, 0, ITEM_H), BackgroundColor3 = WHITE, BackgroundTransparency = 1, LayoutOrder = index, Parent = list,
							})
							Theme.Bind(btn, { BackgroundColor3 = "InputHover" })
							Util.Corner(btn, 9)
							local inner = New("CanvasGroup", {
								Name = "Inner", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Active = false,
								GroupTransparency = animate and 1 or 0, Position = animate and UDim2.fromOffset(16, 0) or UDim2.new(), Parent = btn,
							})
							local tint = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Parent = inner })
							Theme.Bind(tint, { BackgroundColor3 = "Accent" })
							Util.Corner(tint, 9)
							New("UIGradient", { Transparency = NumberSequence.new({ kp(0, 0.8), kp(0.7, 0.95), kp(1, 1) }), Parent = tint })
							local bar = New("Frame", {
								AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(3, 0), BackgroundColor3 = WHITE, Parent = inner,
							})
							Util.Corner(bar, 2)
							Theme.AccentGradient(bar, 90)

							local x = 14
							if item.Icon then
								Util.Icon(inner, item.Icon, 14, "SubText", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0) })
								x = 36
							end
							local label = New("TextLabel", {
								Weight = "Medium", TextSize = 12, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -(x + 40), 1, 0),
								TextTruncate = Enum.TextTruncate.AtEnd, Text = title, Parent = inner,
							})
							Theme.Bind(label, { TextColor3 = function(t) return (item.Value ~= nil and isSelected(item.Value)) and t.Text or t.SubText end })
							local indicator = makeIndicator(inner, multi)

							if index < #items and filter == "" then
								Util.FadeLine(btn, { Position = UDim2.new(0, 16, 1, 1), Size = UDim2.new(1, -32, 0, 1), Strength = 0.3, ZIndex = 3, Thickness = 1 })
							end

							local entry = { Button = btn, Label = label, Tint = tint, Bar = bar, Indicator = indicator, Item = item, X = x, Pop = false }
							table.insert(entries, entry)

							btn.MouseEnter:Connect(function() Util.Tween(btn, 0.12, { BackgroundTransparency = 0.55 }, "Quad") end)
							btn.MouseLeave:Connect(function() Util.Tween(btn, 0.15, { BackgroundTransparency = 1 }, "Quad") end)
							btn.Activated:Connect(function()
								Sound.Play("Select")
								Fx.Ripple(btn, { Alpha = 0.86, Ring = false, Duration = 0.45, Radius = UDim.new(0, 9) })
								if multi then
									local at = table.find(obj.Value, item.Value)
									if at then
										if #obj.Value > 1 or opts.AllowNone ~= false then table.remove(obj.Value, at) end
									else
										table.insert(obj.Value, item.Value)
										entry.Pop = true
									end
									renderChip(); paint(false); fire()
								else
									local changed = obj.Value ~= item.Value
									obj.Value = item.Value
									entry.Pop = changed
									renderChip(); paint(false)
									if changed then fire() end
									task.delay(0.16, popover.Close)
								end
							end)

							if animate and shown <= 9 then
								task.delay((shown - 1) * 0.03, function()
									if inner.Parent then Util.Tween(inner, 0.3, { GroupTransparency = 0, Position = UDim2.new() }, "Out") end
								end)
							elseif animate then
								inner.GroupTransparency, inner.Position = 0, UDim2.new()
							end
						end
					end
					if shown == 0 then
						emptyLabel = New("TextLabel", {
							TextSize = 12, Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, Text = "No matches", Parent = list,
						})
						Theme.Bind(emptyLabel, { TextColor3 = "Muted" })
					end
					paint(true)
				end

				if searchable then
					local box = New("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 32), BackgroundColor3 = WHITE, Parent = frame })
					Theme.Bind(box, { BackgroundColor3 = "Input" })
					Util.Corner(box, 9)
					Util.Shade(box, 90, 0.1)
					local sIcon = Util.Icon(box, "search", 14, "SubText", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0) })
					local input = New("TextBox", {
						Weight = "Medium", TextSize = 12, PlaceholderText = "Search", Text = "", Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -40, 1, 0), Parent = box,
					})
					Theme.Bind(input, { TextColor3 = "Text", PlaceholderColor3 = "Muted" })
					local focusLine = Util.FadeLine(box, {
						AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(0, 0, 0, 2),
						Token = "Accent", Strength = 1, Thickness = 2, ZIndex = 3,
					})
					input.Focused:Connect(function()
						Util.Tween(focusLine, 0.3, { Size = UDim2.new(1, -8, 0, 2) }, "Out")
						Util.Tween(sIcon, 0.2, { ImageColor3 = Theme.Current.Accent }, "Quad")
					end)
					input.FocusLost:Connect(function()
						Util.Tween(focusLine, 0.25, { Size = UDim2.new(0, 0, 0, 2) }, "Quad")
						Util.Tween(sIcon, 0.2, { ImageColor3 = Theme.Current.SubText }, "Quad")
					end)
					input:GetPropertyChangedSignal("Text"):Connect(function() build(string.lower(input.Text), false) end)
					Util.FadeLine(frame, { Position = UDim2.new(0, 12, 0, top - 3), Size = UDim2.new(1, -24, 0, 1), Strength = 0.35, ZIndex = 4 })
				end

				if foot > 0 then
					Util.FadeLine(frame, { Position = UDim2.new(0, 12, 1, -foot), Size = UDim2.new(1, -24, 0, 1), Strength = 0.35, ZIndex = 4 })
					countLabel = New("TextLabel", {
						Weight = "Medium", TextSize = 11, Position = UDim2.new(0, 14, 1, -foot), Size = UDim2.new(0.5, 0, 0, foot), Parent = frame,
					})
					Theme.Bind(countLabel, { TextColor3 = "Muted" })
					local clear = New("TextButton", {
						AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 1, -foot / 2), Size = UDim2.fromOffset(54, 24), BackgroundColor3 = WHITE,
						BackgroundTransparency = 1, Parent = frame,
					})
					Theme.Bind(clear, { BackgroundColor3 = "InputHover" })
					Util.Corner(clear, 7)
					local clearText = New("TextLabel", { Weight = "SemiBold", TextSize = 11, Text = "Clear", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = clear })
					Theme.Bind(clearText, { TextColor3 = "SubText" })
					clear.MouseEnter:Connect(function() Util.Tween(clear, 0.12, { BackgroundTransparency = 0.3 }, "Quad") end)
					clear.MouseLeave:Connect(function() Util.Tween(clear, 0.15, { BackgroundTransparency = 1 }, "Quad") end)
					clear.Activated:Connect(function()
						Sound.Play("Click")
						if opts.AllowNone == false then return end
						obj.Value = {}
						renderChip(); paint(false); fire()
					end)
				end

				build("", true)
			end,
		})
		Util.Tween(chevron, 0.3, { Rotation = 180 }, "Back")
		Util.Tween(underline, 0.35, { Size = UDim2.new(1, -8, 0, 2) }, "Out")
	end

	row.Frame.Activated:Connect(function()
		if obj.Locked then return end
		Sound.Play("Click")
		Elements.Click(row)
		if obj._popover then obj._popover.Close() else obj:Open() end
	end)

	-- default value
	if multi then
		obj:Set(opts.Default or {}, true)
	elseif opts.Default ~= nil then
		obj:Set(opts.Default, true)
	elseif opts.AllowNone ~= true and obj.Items[1] and opts.Placeholder == nil then
		obj.Value = obj.Items[1].Value
	end
	renderChip()

	obj.GetConfig = function() return obj.Value end
	obj.SetConfig = function(v) obj:Set(v) end
	return Elements.Finish(obj, container, row, "element", opts)
end

-- ─────────────────────────────────────────────────────────────
--  Input (textbox) — an accent line grows under the text while it has focus
-- ─────────────────────────────────────────────────────────────
Elements.Create.Input = function(container, opts)
	local W = opts.Width or 160
	local row = Elements.Row(container, opts, W, 28, false)
	local obj = { Type = "Input", Value = tostring(opts.Default or "") }

	local chip = New("Frame", { Name = "Chip", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = row.Right })
	Theme.Bind(chip, { BackgroundColor3 = "Input" })
	Util.Corner(chip, 9)
	Util.Shade(chip, 90, 0.1)
	Shadow.Edge(chip, { Inset = 6, Alpha = 0.8 })
	Util.FadeLine(chip, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.3, ZIndex = 3, Thickness = 1 })
	local underline = Util.FadeLine(chip, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(0, 0, 0, 2),
		Token = "Accent", Strength = 1, Thickness = 2, ZIndex = 4,
	})
	local box = New("TextBox", {
		Weight = "Medium", TextSize = 12, Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -22, 1, 0), Text = obj.Value,
		PlaceholderText = Loc.Resolve(opts.Placeholder or "Type here..."), ClearTextOnFocus = opts.ClearOnFocus == true, ClipsDescendants = true, Parent = chip,
	})
	Theme.Bind(box, { TextColor3 = "Text", PlaceholderColor3 = "Muted" })

	local function commit(silent)
		local text = box.Text
		if opts.MaxLength and #text > opts.MaxLength then text = string.sub(text, 1, opts.MaxLength); box.Text = text end
		local changed = text ~= obj.Value
		obj.Value = text
		if changed and not silent then Util.Fire(opts.Callback, text) end
	end

	box.Focused:Connect(function()
		Util.Tween(underline, 0.35, { Size = UDim2.new(1, -8, 0, 2) }, "Out")
		Util.Tween(chip, 0.15, { BackgroundColor3 = Theme.Current.InputHover }, "Quad")
	end)
	box.FocusLost:Connect(function()
		Util.Tween(underline, 0.28, { Size = UDim2.new(0, 0, 0, 2) }, "Quad")
		Util.Tween(chip, 0.2, { BackgroundColor3 = Theme.Current.Input }, "Quad")
		commit()
	end)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if opts.Numeric then
			local cleaned = string.gsub(box.Text, "[^%d%.%-]", "")
			if cleaned ~= box.Text then box.Text = cleaned; return end
		end
		if opts.Live then commit() end
	end)

	function obj:Set(text, silent)
		box.Text = tostring(text or "")
		commit(silent)
	end
	function obj:Clear(silent) obj:Set("", silent) end
	function obj:Focus() box:CaptureFocus() end
	function obj:GetNumber() return tonumber(obj.Value) end

	obj.GetConfig = function() return obj.Value end
	obj.SetConfig = function(v) obj:Set(v) end
	return Elements.Finish(obj, container, row, "element", opts)
end

-- ─────────────────────────────────────────────────────────────
--  Keybind
-- ─────────────────────────────────────────────────────────────
local KEY_NAMES = {
	LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl", LeftAlt = "LAlt", RightAlt = "RAlt",
	Return = "Enter", Backquote = "`", One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0",
	MouseButton2 = "MB2", MouseButton3 = "MB3", Space = "Space", CapsLock = "Caps", Backspace = "Back",
}

local function keyToString(key)
	if key == nil then return "None" end
	return KEY_NAMES[key.Name] or key.Name
end

-- Enum[...] throws for names that do not exist, so every lookup is protected.
local function enumItem(enum, name)
	local ok, value = pcall(function() return enum[name] end)
	if ok and typeof(value) == "EnumItem" then return value end
	return nil
end

local function parseKey(value)
	if value == nil or value == "None" or value == "" then return nil end
	if typeof(value) == "EnumItem" then return value end
	if type(value) == "string" then
		local kind, name = string.match(value, "^(%a+):(.+)$")
		if kind == "Input" then return enumItem(Enum.UserInputType, name) end
		name = name or value
		return enumItem(Enum.KeyCode, name) or enumItem(Enum.UserInputType, name)
	end
	return nil
end
Util.ParseKey = parseKey
Util.KeyToString = keyToString
--- Like ParseKey, but only accepts keyboard keys (what the window toggle key needs)
function Util.ParseKeyCode(value)
	local key = parseKey(value)
	if key and key.EnumType == Enum.KeyCode then return key end
	return nil
end

Elements.Create.Keybind = function(container, opts)
	local row = Elements.Row(container, opts, 92, 28, true)
	local obj = { Type = "Keybind", Value = parseKey(opts.Default), Mode = opts.Mode or "Press", State = false, Listening = false }

	local chip = New("Frame", { Name = "Chip", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = row.Right })
	Theme.Bind(chip, { BackgroundColor3 = "Input" })
	Util.Corner(chip, 9)
	Util.Shade(chip, 90, 0.1)
	Shadow.Edge(chip, { Inset = 6, Alpha = 0.8 })
	Util.FadeLine(chip, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.3, ZIndex = 3, Thickness = 1 })
	local underline = Util.FadeLine(chip, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(0, 0, 0, 2),
		Token = "Accent", Strength = 1, Thickness = 2, ZIndex = 4,
	})
	local label = New("TextLabel", { Weight = "SemiBold", TextSize = 12, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = chip })
	Theme.Bind(label, { TextColor3 = "Text" })

	local pulse
	local function setListening(on)
		obj.Listening = on
		if on then
			Vesper._KeyListening = true
		else
			-- cleared a tick later so the window toggle handler still sees "listening" for this key press
			task.defer(function() if not obj.Listening then Vesper._KeyListening = nil end end)
		end
	end

	local function render()
		if obj.Listening then
			label.Text = "Press key"
			Theme.Bind(label, { TextColor3 = "Accent" })
			Util.Tween(underline, 0.3, { Size = UDim2.new(1, -8, 0, 2) }, "Out")
			if not pulse then pulse = Util.Loop(underline, 0.6, { BackgroundTransparency = 0.65 }, "Sine", true) end
		else
			if pulse then
				pulse:Cancel()
				pulse = nil
				underline.BackgroundTransparency = 0
			end
			label.Text = keyToString(obj.Value)
			Theme.Bind(label, { TextColor3 = obj.Value and "Text" or "Muted" })
			Util.Tween(underline, 0.25, { Size = UDim2.new(0, 0, 0, 2) }, "Quad")
		end
	end

	function obj:Set(key, silent)
		key = parseKey(key)
		obj.Value = key
		render()
		if not silent then Util.Fire(opts.ChangedCallback, key) end
	end

	function obj:Listen()
		setListening(true)
		render()
	end
	local function matches(input)
		local key = obj.Value
		if not key then return false end
		if key.EnumType == Enum.KeyCode then return input.KeyCode == key end
		return input.UserInputType == key
	end

	local window = container.Window
	window.Maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if obj.Listening then
			local utype = input.UserInputType
			if utype == Enum.UserInputType.Keyboard then
				setListening(false)
				if input.KeyCode == Enum.KeyCode.Escape then
					render()
				elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
					obj:Set(nil)
				else
					obj:Set(input.KeyCode)
					Sound.Play("Select")
					Fx.Flash(chip, { Color = "Accent", Alpha = 0.7, Duration = 0.5, Radius = UDim.new(0, 9) })
				end
			elseif utype == Enum.UserInputType.MouseButton2 or utype == Enum.UserInputType.MouseButton3 then
				setListening(false)
				obj:Set(utype)
				Sound.Play("Select")
			end
			return
		end
		if processed or obj.Locked or not matches(input) then return end
		if obj.Mode == "Toggle" then
			obj.State = not obj.State
			Util.Fire(opts.Callback, obj.State)
		elseif obj.Mode == "Hold" then
			obj.State = true
			Util.Fire(opts.Callback, true)
		else
			Util.Fire(opts.Callback, obj.Value)
		end
	end))
	window.Maid:Give(UserInputService.InputEnded:Connect(function(input)
		if obj.Mode == "Hold" and obj.State and matches(input) then
			obj.State = false
			Util.Fire(opts.Callback, false)
		end
	end))

	row.Frame.Activated:Connect(function()
		if obj.Locked then return end
		Sound.Play("Click")
		Elements.Click(row)
		setListening(not obj.Listening)
		render()
	end)

	render()
	obj.GetConfig = function()
		local key = obj.Value
		if not key then return "None" end
		return (key.EnumType == Enum.KeyCode and "" or "Input:") .. key.Name
	end
	obj.SetConfig = function(v) obj:Set(v) end
	return Elements.Finish(obj, container, row, "element", opts)
end

-- ─────────────────────────────────────────────────────────────
--  Colour picker
-- ─────────────────────────────────────────────────────────────
local HUE_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)), ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)), ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
})

Elements.Create.Colorpicker = function(container, opts)
	local row = Elements.Row(container, opts, 48, 24, true)
	local useAlpha = opts.Transparency == true or opts.Alpha == true
	local startColor = opts.Default
	if type(startColor) == "string" then startColor = Util.FromHex(startColor) end
	startColor = startColor or Color3.fromRGB(255, 255, 255)
	local h, s, v = startColor:ToHSV()
	local obj = { Type = "Colorpicker", Value = startColor, Alpha = opts.DefaultAlpha or 1 }

	local swatchBack = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = row.Right,
	})
	Theme.Bind(swatchBack, { BackgroundColor3 = "Input" })
	Util.Corner(swatchBack, 8)
	Shadow.Edge(swatchBack, { Inset = 5, Alpha = 0.78 })
	local swatch = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -6, 1, -6), BackgroundColor3 = startColor, Parent = swatchBack,
	})
	Util.Corner(swatch, 6)
	Util.Shade(swatch, 90, 0.16)
	Util.FadeLine(swatch, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.55, Token = function() return WHITE end, ZIndex = 3, Thickness = 1 })

	local function fire() Util.Fire(opts.Callback, obj.Value, obj.Alpha) end
	local function apply(silent)
		obj.Value = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = obj.Value
		swatch.BackgroundTransparency = 1 - obj.Alpha
		if obj._refresh then obj._refresh() end
		if not silent then fire() end
	end

	function obj:Set(color, alpha, silent)
		if type(color) == "string" then color = Util.FromHex(color) end
		if typeof(color) == "Color3" then h, s, v = color:ToHSV() end
		if alpha then obj.Alpha = Util.Clamp(alpha, 0, 1) end
		apply(silent)
	end
	function obj:Close() if obj._popover then obj._popover.Close() end end

	function obj:Open()
		local window = container.Window
		local host = window.Host
		local W = 236
		local inner = W - 20
		local alphaY = 10 + 116 + 10 + 12 + 10
		local hexY = alphaY + (useAlpha and 22 or 0)
		local presetY = hexY + 30 + 10
		local H = presetY + 22 + 12

		obj._popover = Util.OpenPopover(host, window.Overlay, row.Right, {
			Width = W, Height = H, Align = "Right",
			OnClose = function() obj._popover = nil; obj._refresh = nil end,
			Build = function(frame)
				-- saturation / value box
				local sv = New("TextButton", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(inner, 116), BackgroundColor3 = Color3.fromHSV(h, 1, 1), Parent = frame })
				Util.Corner(sv, 9)
				local white = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = sv })
				Util.Corner(white, 9)
				New("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
				local black = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, Parent = sv })
				Util.Corner(black, 9)
				New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black })
				local cursor = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = WHITE, ZIndex = 3, Parent = sv })
				Util.Corner(cursor, 16)
				local cursorFill = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(11, 11), BackgroundColor3 = obj.Value, ZIndex = 4, Parent = cursor })
				Util.Corner(cursorFill, 11)

				-- hue bar
				local hue = New("TextButton", { Position = UDim2.fromOffset(10, 136), Size = UDim2.fromOffset(inner, 12), BackgroundColor3 = WHITE, Parent = frame })
				Util.Corner(hue, 6)
				New("UIGradient", { Color = HUE_SEQUENCE, Parent = hue })
				local hueBack = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(h, 0.5), Size = UDim2.fromOffset(10, 18), BackgroundColor3 = BLACK, BackgroundTransparency = 0.6, ZIndex = 2, Parent = hue })
				Util.Corner(hueBack, 5)
				local hueThumb = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(7, 15), BackgroundColor3 = WHITE, ZIndex = 3, Parent = hueBack })
				Util.Corner(hueThumb, 4)

				-- alpha bar
				local alpha, alphaFill, alphaBack
				if useAlpha then
					alpha = New("TextButton", { Position = UDim2.fromOffset(10, alphaY), Size = UDim2.fromOffset(inner, 12), BackgroundColor3 = WHITE, Parent = frame })
					Theme.Bind(alpha, { BackgroundColor3 = "Input" })
					Util.Corner(alpha, 6)
					alphaFill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = obj.Value, Parent = alpha })
					Util.Corner(alphaFill, 6)
					New("UIGradient", { Transparency = NumberSequence.new(1, 0), Parent = alphaFill })
					alphaBack = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(obj.Alpha, 0.5), Size = UDim2.fromOffset(10, 18), BackgroundColor3 = BLACK, BackgroundTransparency = 0.6, ZIndex = 2, Parent = alpha })
					Util.Corner(alphaBack, 5)
					local alphaThumb = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(7, 15), BackgroundColor3 = WHITE, ZIndex = 3, Parent = alphaBack })
					Util.Corner(alphaThumb, 4)
				end

				-- hex row
				local preview = New("Frame", { Position = UDim2.fromOffset(10, hexY), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = obj.Value, Parent = frame })
				Util.Corner(preview, 9)
				Shadow.Edge(preview, { Inset = 4, Alpha = 0.8 })
				local hexBox = New("Frame", { Position = UDim2.fromOffset(48, hexY), Size = UDim2.fromOffset(inner - 38, 30), BackgroundColor3 = WHITE, Parent = frame })
				Theme.Bind(hexBox, { BackgroundColor3 = "Input" })
				Util.Corner(hexBox, 9)
				Util.Shade(hexBox, 90, 0.1)
				local hexInput = New("TextBox", {
					Weight = "Medium", TextSize = 12, Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -22, 1, 0), Text = Util.ToHex(obj.Value), PlaceholderText = "#RRGGBB", Parent = hexBox,
				})
				Theme.Bind(hexInput, { TextColor3 = "Text", PlaceholderColor3 = "Muted" })
				local hexLine = Util.FadeLine(hexBox, {
					AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(0, 0, 0, 2),
					Token = "Accent", Strength = 1, Thickness = 2, ZIndex = 4,
				})
				hexInput.Focused:Connect(function() Util.Tween(hexLine, 0.3, { Size = UDim2.new(1, -8, 0, 2) }, "Out") end)
				hexInput.FocusLost:Connect(function()
					Util.Tween(hexLine, 0.25, { Size = UDim2.new(0, 0, 0, 2) }, "Quad")
					local color = Util.FromHex(hexInput.Text)
					if color then h, s, v = color:ToHSV(); apply() else hexInput.Text = Util.ToHex(obj.Value) end
				end)

				-- presets
				local t = Theme.Current
				local presets = { t.Accent, t.Accent2, t.Success, t.Warning, t.Danger, t.Info, WHITE, BLACK }
				local count = #presets
				local gap = (inner - count * 22) / (count - 1)
				for i, color in presets do
					local chipBtn = New("TextButton", {
						Position = UDim2.fromOffset(10 + (i - 1) * (22 + gap), presetY), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = color, Parent = frame,
					})
					Util.Corner(chipBtn, 7)
					Util.Shade(chipBtn, 90, 0.14)
					chipBtn.MouseEnter:Connect(function() Util.Tween(chipBtn, 0.15, { Position = UDim2.fromOffset(10 + (i - 1) * (22 + gap), presetY - 2) }, "Back") end)
					chipBtn.MouseLeave:Connect(function() Util.Tween(chipBtn, 0.2, { Position = UDim2.fromOffset(10 + (i - 1) * (22 + gap), presetY) }, "Quad") end)
					chipBtn.Activated:Connect(function()
						Sound.Play("Tick")
						h, s, v = color:ToHSV()
						apply()
					end)
				end

				obj._refresh = function()
					sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
					cursor.Position = UDim2.fromScale(s, 1 - v)
					cursorFill.BackgroundColor3 = obj.Value
					hueBack.Position = UDim2.fromScale(h, 0.5)
					preview.BackgroundColor3 = obj.Value
					if not hexInput:IsFocused() then hexInput.Text = Util.ToHex(obj.Value) end
					if alphaFill then alphaFill.BackgroundColor3 = obj.Value; alphaBack.Position = UDim2.fromScale(obj.Alpha, 0.5) end
				end
				obj._refresh()

				local function ratioOf(gui, pos, axis)
					local size = axis == "X" and gui.AbsoluteSize.X or gui.AbsoluteSize.Y
					local origin = axis == "X" and gui.AbsolutePosition.X or gui.AbsolutePosition.Y
					return Util.Clamp(((axis == "X" and pos.X or pos.Y) - origin) / math.max(size, 1), 0, 1)
				end
				Util.Drag(sv, function(pos)
					s, v = ratioOf(sv, pos, "X"), 1 - ratioOf(sv, pos, "Y")
					apply()
				end, function() Util.Tween(cursor, 0.15, { Size = UDim2.fromOffset(20, 20) }, "Back") end,
				function() Util.Tween(cursor, 0.2, { Size = UDim2.fromOffset(16, 16) }, "Quad") end)
				Util.Drag(hue, function(pos) h = ratioOf(hue, pos, "X"); apply() end)
				if alpha then Util.Drag(alpha, function(pos) obj.Alpha = ratioOf(alpha, pos, "X"); apply() end) end
			end,
		})
	end

	row.Frame.Activated:Connect(function()
		if obj.Locked then return end
		Sound.Play("Click")
		Elements.Click(row, obj.Value)
		if obj._popover then obj._popover.Close() else obj:Open() end
	end)

	apply(true)
	obj.GetConfig = function() return { Hex = Util.ToHex(obj.Value), Alpha = obj.Alpha } end
	obj.SetConfig = function(c)
		if type(c) == "table" then obj:Set(c.Hex, c.Alpha) elseif type(c) == "string" then obj:Set(c) end
	end
	return Elements.Finish(obj, container, row, "element", opts)
end

-- ─────────────────────────────────────────────────────────────
--  Paragraph
-- ─────────────────────────────────────────────────────────────
Elements.Create.Paragraph = function(container, opts)
	local copy = { Title = opts.Title, Desc = opts.Content or opts.Desc, Icon = opts.Icon, Flag = opts.Flag, Visible = opts.Visible, Search = opts.Search }
	local row = Elements.Row(container, copy, 0, 0, false)
	row.DescLabel.TextTransparency = 0
	Theme.Bind(row.DescLabel, { TextColor3 = "SubText" })
	row.DescLabel.LineHeight = 1.15
	if opts.Title == nil or opts.Title == "" then row.TitleLabel.Visible = false end
	if opts.Accent ~= false then
		Util.FadeLine(row.Frame, {
			Vertical = true, Position = UDim2.new(0, 0, 0, 6), Size = UDim2.new(0, 2, 1, -12), Token = "Accent", Strength = 0.9, Thickness = 2, ZIndex = 4,
		})
	end

	if opts.Buttons and #opts.Buttons > 0 then
		New("Frame", { Size = UDim2.new(1, 0, 0, 5), BackgroundTransparency = 1, LayoutOrder = 3, Parent = row.Left })
		local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = row.Left })
		local list = Util.List(holder, 8, Enum.FillDirection.Horizontal)
		list.Wraps = true
		for i, def in opts.Buttons do
			Util.MakeButton({
				Parent = holder, Text = def.Title, Icon = def.Icon, Variant = def.Variant or "Secondary", Height = 28, TextSize = 12, LayoutOrder = i, Callback = def.Callback,
			})
		end
	end

	local obj = { Type = "Paragraph" }
	function obj:SetContent(text) obj:SetDesc(text) end
	return Elements.Finish(obj, container, row, "element", copy)
end

-- ─────────────────────────────────────────────────────────────
--  Code block with Lua syntax highlighting
-- ─────────────────────────────────────────────────────────────
Elements.Create.Code = function(container, opts)
	local copy = { Title = opts.Title, Desc = opts.Desc, Icon = opts.Icon, Flag = opts.Flag, Visible = opts.Visible, Search = opts.Search }
	local row = Elements.Row(container, copy, 0, 0, false)
	if opts.Title == nil or opts.Title == "" then row.TitleLabel.Visible = false end

	New("Frame", { Size = UDim2.new(1, 0, 0, 5), BackgroundTransparency = 1, LayoutOrder = 3, Parent = row.Left })
	local box = New("Frame", { Name = "CodeBox", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, BackgroundColor3 = WHITE, Parent = row.Left })
	Theme.Bind(box, { BackgroundColor3 = "Sidebar" })
	Util.Corner(box, 10)
	Util.Shade(box, 90, 0.12)
	Util.FadeLine(box, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.45, ZIndex = 3, Thickness = 1 })
	Util.FadeLine(box, { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), Strength = 0.25, ZIndex = 3, Thickness = 1 })
	local pad = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = box })
	Util.Padding(pad, 11, 42, 11, 13)

	local label = New("TextLabel", {
		TextSize = 12, TextWrapped = true, RichText = true, LineHeight = 1.2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextYAlignment = Enum.TextYAlignment.Top, Parent = pad,
	})
	label.FontFace = Util.MonoFont
	Theme.Bind(label, { TextColor3 = "Text" })

	local obj = { Type = "Code", Code = tostring(opts.Code or "") }
	local lang = string.lower(tostring(opts.Language or "lua"))
	local highlight = lang == "lua" or lang == "luau"
	local function render()
		label.Text = highlight and Util.Highlight(obj.Code) or escapeRich(obj.Code)
	end
	render()
	Theme.Watch(label, function() render() end)

	if opts.Copy ~= false then
		local btn = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -7, 0, 7), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 5, Parent = box,
		})
		Theme.Bind(btn, { BackgroundColor3 = "InputHover" })
		Util.Corner(btn, 8)
		local icon = Util.Icon(btn, "copy", 14, "SubText", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		btn.MouseEnter:Connect(function()
			Util.Tween(btn, 0.12, { BackgroundTransparency = 0.35 }, "Quad")
			Theme.Bind(icon, { ImageColor3 = "Text" })
		end)
		btn.MouseLeave:Connect(function()
			Util.Tween(btn, 0.15, { BackgroundTransparency = 1 }, "Quad")
			if icon.Parent and not Util.Part(icon, "Copied") then Theme.Bind(icon, { ImageColor3 = "SubText" }) end
		end)
		btn.Activated:Connect(function()
			Sound.Play("Click")
			Util.Copy(obj.Code)
			Fx.Ripple(btn, { Alpha = 0.8, Ring = false, Duration = 0.45, Radius = UDim.new(0, 8) })
			Util.SetPart(icon, "Copied", true)
			Icons.Apply(icon, "check", 14, "Success")
			Fx.Pop(icon, 0)
			task.delay(1.4, function()
				if icon.Parent then
					Util.SetPart(icon, "Copied", nil)
					Icons.Apply(icon, "copy", 14, "SubText")
				end
			end)
		end)
	end

	function obj:SetCode(text) obj.Code = tostring(text or ""); render() end
	function obj:GetCode() return obj.Code end
	return Elements.Finish(obj, container, row, "element", copy)
end

-- ─────────────────────────────────────────────────────────────
--  Section (labelled group, optionally collapsible)
--  Returns a container: it has every element method itself.
-- ─────────────────────────────────────────────────────────────
Elements.Create.Section = function(container, opts)
	if type(opts) == "string" then opts = { Title = opts } end
	local frame = New("Frame", {
		Name = "Section", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = Elements.NextOrder(container), Parent = container.Content,
	})
	Util.List(frame, 7)

	local head = New("TextButton", { Name = "Header", Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 0, Parent = frame })
	local x = 4
	local headIcon
	if opts.Icon then
		headIcon = Util.Icon(head, opts.Icon, 14, "SubText", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0) })
		x = 25
	end
	local title = New("TextLabel", { Weight = "SemiBold", TextSize = 12, Position = UDim2.new(0, x, 0, 0), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = head })
	Theme.Bind(title, { TextColor3 = "SubText" })
	Util.SetText(title, opts.Title or "")

	-- the line starts after the title and fades out to the right
	local line = Util.FadeLine(head, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, -60, 0, 1), Style = "Left", Strength = 0.7 })
	local chevron
	if opts.Collapsible then
		chevron = Util.Icon(head, "chevron-down", 14, "Muted", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0) })
	end
	local function layoutLine()
		local startX = x + title.TextBounds.X + 10
		local reserve = chevron and 30 or 6
		line.Position = UDim2.new(0, startX, 0.5, 0)
		line.Size = UDim2.new(1, -(startX + reserve), 0, Lines.Thickness)
	end
	title:GetPropertyChangedSignal("TextBounds"):Connect(layoutLine)
	layoutLine()
	if not (opts.Title and opts.Title ~= "") then line.Visible = false end

	local body = New("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = frame })
	local layout = Util.List(body, 8)

	local section = { Type = "Section", Frame = frame, Title = opts.Title or "", ParentContainer = container, Opened = opts.Opened ~= false, Locked = false }
	Elements.Attach(section, body, container.Window, container.Tab)
	local entry = Elements.Register(container, frame, "section", opts.Title, "", {
		Type = "Section", Icon = opts.Icon, Obj = section, FxTarget = head,
	})
	entry.Entries = section._entries

	local function setOpen(open, instant)
		section.Opened = open
		if chevron then Util.Tween(chevron, 0.25, { Rotation = open and 0 or -90 }, "Back") end
		if instant then
			body.Visible = open
			return
		end
		local scale = container.Window and container.Window.Host:GetScale() or 1
		body.ClipsDescendants = true
		if open then
			body.Visible = true
			body.AutomaticSize = Enum.AutomaticSize.None
			body.Size = UDim2.new(1, 0, 0, 0)
			local tween = Util.Tween(body, 0.32, { Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y / scale) }, "Out")
			if tween then
				tween.Completed:Connect(function()
					if section.Opened then
						body.AutomaticSize = Enum.AutomaticSize.Y
						body.Size = UDim2.new(1, 0, 0, 0)
						body.ClipsDescendants = false
					end
				end)
			end
		else
			body.AutomaticSize = Enum.AutomaticSize.None
			body.Size = UDim2.new(1, 0, 0, body.AbsoluteSize.Y / scale)
			local tween = Util.Tween(body, 0.26, { Size = UDim2.new(1, 0, 0, 0) }, "Out")
			if tween then
				tween.Completed:Connect(function()
					if not section.Opened then body.Visible = false end
				end)
			end
		end
	end

	if opts.Collapsible then
		head.MouseEnter:Connect(function()
			Util.Tween(title, 0.15, { TextColor3 = Theme.Current.Text }, "Quad")
			if chevron then Util.Tween(chevron, 0.15, { ImageColor3 = Theme.Current.Text }, "Quad") end
		end)
		head.MouseLeave:Connect(function()
			Util.Tween(title, 0.2, { TextColor3 = Theme.Current.SubText }, "Quad")
			if chevron then Util.Tween(chevron, 0.2, { ImageColor3 = Theme.Current.Muted }, "Quad") end
		end)
		head.Activated:Connect(function()
			Sound.Play("Click")
			setOpen(not section.Opened)
		end)
		if not section.Opened then
			setOpen(false, true)
			if chevron then chevron.Rotation = -90 end
		end
	else
		head.Active = false
	end

	-- NOTE: never name a section method after an element (Toggle, Button, ...): sections host those as methods
	function section:Open() if not section.Opened then setOpen(true) end end
	function section:Close() if section.Opened then setOpen(false) end end
	function section:SetOpen(open) if section.Opened ~= (open == true) then setOpen(open == true) end end
	function section:ToggleOpen() setOpen(not section.Opened) end
	function section:SetTitle(text)
		section.Title = text
		entry.RawTitle = text
		Util.SetText(title, text)
	end
	function section:SetVisible(v) entry.Hidden = not v; frame.Visible = v end
	function section:Destroy()
		Elements.Unregister(container, entry)
		frame:Destroy()
	end
	return section
end

-- ─────────────────────────────────────────────────────────────
--  Divider / Space
--  Divider() — a fading line.   Divider("Label") / Divider({ Text = "Label" }) — a line, a label, a line.
-- ─────────────────────────────────────────────────────────────
Elements.Create.Divider = function(container, opts)
	if type(opts) == "number" then opts = { Size = opts } elseif type(opts) == "string" then opts = { Text = opts } end
	local frame = New("Frame", {
		Name = "Divider", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, opts.Size or (opts.Text and 22 or 12)),
		LayoutOrder = Elements.NextOrder(container), Parent = container.Content,
	})
	if opts.Text then
		local label = New("TextLabel", {
			Weight = "SemiBold", TextSize = 11, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center, Parent = frame,
		})
		Theme.Bind(label, { TextColor3 = "Muted" })
		Util.SetText(label, opts.Text)
		local left = Util.FadeLine(frame, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.new(0.5, -40, 0, 1), Style = "Right" })
		local right = Util.FadeLine(frame, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0.5, -40, 0, 1), Style = "Left" })
		local function fit()
			local half = label.TextBounds.X / 2 + 14 + 8
			left.Size = UDim2.new(0.5, -half, 0, Lines.Thickness)
			right.Size = UDim2.new(0.5, -half, 0, Lines.Thickness)
		end
		label:GetPropertyChangedSignal("TextBounds"):Connect(fit)
		fit()
	else
		Util.FadeLine(frame, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -16, 0, 1) })
	end
	local obj = { Type = "Divider", Frame = frame }
	obj._entry = Elements.Register(container, frame, "decor")
	function obj:SetVisible(v) obj._entry.Hidden = not v; frame.Visible = v end
	function obj:Destroy() Elements.Unregister(container, obj._entry); frame:Destroy() end
	return obj
end

Elements.Create.Space = function(container, opts)
	local size = type(opts) == "number" and opts or (type(opts) == "table" and opts.Size) or 12
	local frame = New("Frame", {
		Name = "Space", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, size), LayoutOrder = Elements.NextOrder(container), Parent = container.Content,
	})
	local obj = { Type = "Space", Frame = frame }
	obj._entry = Elements.Register(container, frame, "decor")
	function obj:SetSize(s) frame.Size = UDim2.new(1, 0, 0, s) end
	function obj:Destroy() Elements.Unregister(container, obj._entry); frame:Destroy() end
	return obj
end
-- ─────────────────────────────────────────────────────────────
--  Config manager (save / load flagged elements as JSON)
--  Uses the executor filesystem when available, otherwise an
--  in-memory store that lasts for the session.
-- ─────────────────────────────────────────────────────────────
local ConfigManager = {}
ConfigManager.__index = ConfigManager
Config.Memory = {}

function Config.IsPersistent()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
		and type(isfolder) == "function" and type(makefolder) == "function"
end

local function cleanConfigName(name)
	name = tostring(name or "")
	name = string.gsub(name, "[^%w%-_ ]", "")
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	return name
end

function Config.Attach(window)
	local self = setmetatable({ Window = window }, ConfigManager)
	self.Root = window.Folder
	self.Dir = window.Folder .. "/configs"
	window.ConfigManager = self
end

function ConfigManager:_ensure()
	if not Config.IsPersistent() then return end
	pcall(function()
		if not isfolder(self.Root) then makefolder(self.Root) end
		if not isfolder(self.Dir) then makefolder(self.Dir) end
	end)
end
function ConfigManager:_path(name) return self.Dir .. "/" .. name .. ".json" end
function ConfigManager:_memKey(name) return self.Dir .. "/" .. name end

function ConfigManager:Serialize()
	local flags = {}
	for flag, element in self.Window.Flags do
		if element.GetConfig then
			local ok, value = pcall(element.GetConfig)
			if ok then flags[flag] = value end
		end
	end
	return {
		Version = 2, Theme = Theme.Current.Name,
		Appearance = {
			Style = Theme.StyleOverride or "Default",
			Animated = Theme.Animated,
			Click = Fx.Style,
			Lines = { Style = Lines.Style, Thickness = Lines.Thickness, Strength = Lines.Strength, Color = Lines.Color },
			Shadow = { Depth = Shadow.Config.Depth, Strength = Shadow.Config.Strength, Soft = Shadow.Config.Soft },
		},
		Flags = flags,
	}
end

function ConfigManager:Apply(data)
	if type(data) ~= "table" then return false end
	if data.Theme and Theme.Themes[data.Theme] then Theme.Set(data.Theme) end
	local look = data.Appearance
	if type(look) == "table" then
		if look.Style ~= nil then Theme.SetStyle(look.Style) end
		if look.Animated ~= nil then Theme.SetAnimated(look.Animated) end
		if look.Click ~= nil then Fx.SetStyle(look.Click) end
		if type(look.Lines) == "table" then Vesper:SetLines(look.Lines) end
		if type(look.Shadow) == "table" then Vesper:SetShadow(look.Shadow) end
		if self.Window._syncAppearance then pcall(self.Window._syncAppearance) end
	end
	for flag, value in data.Flags or {} do
		local element = self.Window.Flags[flag]
		if element and element.SetConfig then pcall(element.SetConfig, value) end
	end
	return true
end

function ConfigManager:Export()
	local ok, json = pcall(HttpService.JSONEncode, HttpService, self:Serialize())
	return ok and json or nil
end

function ConfigManager:Import(json)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, tostring(json))
	if not ok then return false, "Invalid JSON" end
	return self:Apply(data)
end

function ConfigManager:Save(name)
	name = cleanConfigName(name)
	if name == "" then return false, "A config name is required" end
	local json = self:Export()
	if not json then return false, "Could not serialise the config" end
	if Config.IsPersistent() then
		self:_ensure()
		local ok, err = pcall(writefile, self:_path(name), json)
		if not ok then return false, tostring(err) end
	else
		Config.Memory[self:_memKey(name)] = json
	end
	return true
end

function ConfigManager:Exists(name)
	name = cleanConfigName(name)
	if name == "" then return false end
	if Config.IsPersistent() then
		local ok, found = pcall(isfile, self:_path(name))
		return ok and found == true
	end
	return Config.Memory[self:_memKey(name)] ~= nil
end

function ConfigManager:Load(name)
	name = cleanConfigName(name)
	if not self:Exists(name) then return false, "Config not found" end
	local json
	if Config.IsPersistent() then
		local ok, content = pcall(readfile, self:_path(name))
		if not ok then return false, tostring(content) end
		json = content
	else
		json = Config.Memory[self:_memKey(name)]
	end
	return self:Import(json)
end

function ConfigManager:Delete(name)
	name = cleanConfigName(name)
	if not self:Exists(name) then return false end
	if Config.IsPersistent() then
		if type(delfile) ~= "function" then return false, "delfile is not available" end
		pcall(delfile, self:_path(name))
	else
		Config.Memory[self:_memKey(name)] = nil
	end
	if self:GetAutoload() == name then self:SetAutoload(nil) end
	return true
end

function ConfigManager:List()
	local seen, names = {}, {}
	local function add(n)
		if n and not seen[n] then seen[n] = true; table.insert(names, n) end
	end
	if Config.IsPersistent() and type(listfiles) == "function" then
		self:_ensure()
		local ok, files = pcall(listfiles, self.Dir)
		if ok then
			for _, path in files do add(string.match(path, "([^/\\]+)%.json$")) end
		end
	end
	local prefix = self.Dir .. "/"
	for key in Config.Memory do
		if string.sub(key, 1, #prefix) == prefix then add(string.sub(key, #prefix + 1)) end
	end
	table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
	return names
end

function ConfigManager:SetAutoload(name)
	name = name and cleanConfigName(name) or nil
	local path = self.Root .. "/autoload.txt"
	if Config.IsPersistent() then
		self:_ensure()
		if name and name ~= "" then pcall(writefile, path, name)
		elseif type(delfile) == "function" then pcall(function() if isfile(path) then delfile(path) end end)
		else pcall(writefile, path, "") end
	else
		Config.Memory[path] = name
	end
end

function ConfigManager:GetAutoload()
	local path = self.Root .. "/autoload.txt"
	local value
	if Config.IsPersistent() then
		local ok, content = pcall(function() if isfile(path) then return readfile(path) end end)
		value = ok and content or nil
	else
		value = Config.Memory[path]
	end
	value = value and cleanConfigName(value) or nil
	return (value and value ~= "") and value or nil
end

function ConfigManager:LoadAutoload()
	local name = self:GetAutoload()
	if name and self:Exists(name) then return self:Load(name) end
	return false
end

-- Shortcuts on the window
function Window:SaveConfig(name) return self.ConfigManager:Save(name) end
function Window:LoadConfig(name) return self.ConfigManager:Load(name) end
function Window:LoadAutoload() return self.ConfigManager:LoadAutoload() end


-- ─────────────────────────────────────────────────────────────
--  Key system gate ("Vault")
--  KeySystem = {
--    Key = {"a","b"} | "a",  Validate = function(key) -> bool, message,
--    Title, Note/Subtitle, URL (copied by "Get key"), Buttons = {...}, Links = { {Title, URL | Callback} },
--    SaveKey = true, MaxAttempts = nil, CloseOnFail = true, OnFail = function, Closable = true, Footer, Width, Callback = function(key)
--  }
-- ─────────────────────────────────────────────────────────────
function Vesper._KeyGate(window, ks)
	if type(ks) ~= "table" then ks = {} end
	local keys = ks.Key or ks.Keys
	if type(keys) == "string" then keys = { keys } end
	local keyFile = window.Folder .. "/key.txt"
	local host = window.Host
	local CARD_W = Util.Clamp(ks.Width or 400, 320, 540)
	local persistent = ks.SaveKey ~= false and Config.IsPersistent()

	-- returns ok, message. Validate may yield (HTTP) and may return (bool, message).
	local function validate(input)
		input = Util.Trim(input)
		if input == "" then return false, "Enter your key to continue" end
		if ks.Validate then
			local ok, result, message = pcall(ks.Validate, input)
			if not ok then return false, "Validation failed, try again" end
			if type(result) == "boolean" then return result, message or (result and "Key accepted" or "That key isn't valid") end
			return result ~= nil and result ~= false, message
		end
		if type(keys) == "table" then
			for _, k in keys do
				if k == input then return true, "Key accepted" end
			end
		end
		return false, "That key isn't valid"
	end

	local gate, bg, holder, card, pop
	local unlocked = false

	local function dismiss()
		if not gate then return end
		local g, b, c, p = gate, bg, card, pop
		gate = nil
		Util.FadeCanvas(c, 1, 0.3, "Quad")
		Util.Tween(p, 0.35, { Scale = 1.07 }, "Quad")
		Util.Tween(b, 0.5, { GroupTransparency = 1 }, "Quad")
		task.delay(0.6, function() g:Destroy() end)
	end

	local function unlock(key)
		if unlocked or window.Destroyed then return end
		unlocked = true
		window._locked = false
		if persistent then
			pcall(function()
				if not isfolder(window.Folder) then makefolder(window.Folder) end
				writefile(keyFile, tostring(key))
			end)
		end
		if ks.Callback then Util.Fire(ks.Callback, key) end
		local hadGate = gate ~= nil
		dismiss()
		task.delay(hadGate and 0.25 or 0, function()
			if not window.Destroyed then window:Show() end
		end)
	end

	task.spawn(function()
		-- a remembered key skips the gate
		if persistent then
			local ok, saved = pcall(function() if isfile(keyFile) then return readfile(keyFile) end end)
			if ok and saved and saved ~= "" and (validate(saved)) then
				unlock(Util.Trim(saved))
				return
			end
		end
		if window.Destroyed then return end

		gate = New("Frame", { Name = "KeyGate", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Active = true, Parent = host.Root })

		-- background: deep base + the animated theme backdrop + vignette (one canvas so it fades as one piece)
		bg = New("CanvasGroup", { Name = "Bg", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Parent = gate })
		local base = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.05, Parent = bg })
		Theme.Bind(base, { BackgroundColor3 = function(t) return t.Window3:Lerp(BLACK, 0.5) end })
		Fx.Backdrop(bg, 1)
		local vignette = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, ZIndex = 2, Active = false, Parent = bg })
		New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 0.35), kp(0.5, 0.85), kp(1, 0.3) }), Parent = vignette })

		holder, card = Util.Surface(gate, {
			Name = "KeyCard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, CARD_W, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 5,
		}, 18, true)
		Theme.Bind(card, { BackgroundColor3 = "Window" })
		Theme.WindowGradient(card, 35)
		pop = New("UIScale", { Scale = 0.9, Parent = holder })
		Util.FadeLine(card, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.8, Token = "Accent", ZIndex = 8, Thickness = 1 })

		-- glow behind the logo
		local glow = New("Frame", { Name = "Glow", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 150), Active = false, Parent = card })
		orb(glow, 0.5, 0.42, 200, "Accent", 0.5, Theme.Animated, { 0.03, 0.04 }, 6)

		local content = New("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 3, Parent = card })
		Util.Padding(content, 28, 26, 22, 26)
		Util.List(content, 12, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center)

		-- logo with a spinning ring
		local cluster = New("Frame", { Name = "Cluster", Size = UDim2.fromOffset(76, 76), BackgroundTransparency = 1, LayoutOrder = 1, Parent = content })
		Fx.SpinRing(cluster, { Size = 76, Thickness = 3, Speed = 1.4, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		local tile = Util.MakeLogo(cluster, window.Opts.Icon or "key-round", 50, 15)
		tile.AnchorPoint, tile.Position, tile.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(0, 0)
		local logoIcon = Util.Part(tile, "Icon")

		local title = New("TextLabel", {
			Weight = "SemiBold", TextSize = 20, Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = content,
		})
		Theme.Bind(title, { TextColor3 = "Text" })
		local titleText = Loc.Resolve(ks.Title or "Key System")
		title.Text = titleText
		title.MaxVisibleGraphemes = 0

		local note = New("TextLabel", {
			TextSize = 12, TextWrapped = true, RichText = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, TextTransparency = 1, Parent = content,
		})
		Theme.Bind(note, { TextColor3 = "SubText" })
		Util.SetText(note, ks.Note or ks.Subtitle or "Enter your key to continue.")

		-- input
		local inputWrap = New("Frame", { Name = "Input", Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 4, BackgroundColor3 = WHITE, Parent = content })
		Theme.Bind(inputWrap, { BackgroundColor3 = "Input" })
		Util.Corner(inputWrap, 11)
		Util.Shade(inputWrap, 90, 0.12)
		Shadow.Edge(inputWrap, { Inset = 8, Alpha = 0.75 })
		Util.FadeLine(inputWrap, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.35, ZIndex = 3, Thickness = 1 })
		local keyIcon = Util.Icon(inputWrap, "key-round", 16, "SubText", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0) })
		local input = New("TextBox", {
			Weight = "Medium", TextSize = 13, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -54, 1, 0), Text = "",
			PlaceholderText = "Enter key...", ClearTextOnFocus = false, ClipsDescendants = true, Parent = inputWrap,
		})
		Theme.Bind(input, { TextColor3 = "Text", PlaceholderColor3 = "Muted" })
		local underline = Util.FadeLine(inputWrap, {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(0, 0, 0, 2), Token = "Accent", Strength = 1, Thickness = 2, ZIndex = 5,
		})
		local scan = Util.FadeLine(inputWrap, {
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(-0.4, 0, 1, 0), Size = UDim2.new(0.4, 0, 0, 2), Token = "Accent2", Strength = 1, Thickness = 2, ZIndex = 6,
		})
		scan.Visible = false
		local focused = false
		input.Focused:Connect(function()
			focused = true
			Util.Tween(underline, 0.35, { Size = UDim2.new(1, -10, 0, 2) }, "Out")
			Util.Tween(keyIcon, 0.2, { ImageColor3 = Theme.Current.Accent }, "Quad")
		end)
		input.FocusLost:Connect(function()
			focused = false
			Util.Tween(underline, 0.28, { Size = UDim2.new(0, 0, 0, 2) }, "Quad")
			Util.Tween(keyIcon, 0.2, { ImageColor3 = Theme.Current.SubText }, "Quad")
		end)

		-- status line
		local statusRow = New("Frame", { Name = "Status", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 5, Parent = content })
		Util.List(statusRow, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
		local statusIcon = Util.Icon(statusRow, "info", 14, "Muted", { LayoutOrder = 1, ImageTransparency = 1 })
		local status = New("TextLabel", { TextSize = 12, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Text = "", LayoutOrder = 2, Parent = statusRow })
		Theme.Bind(status, { TextColor3 = "Muted" })
		local function setStatus(text, token, icon)
			status.Text = text or ""
			Theme.Bind(status, { TextColor3 = token or "Muted" })
			if icon and text and text ~= "" then
				Icons.Apply(statusIcon, icon, 14, token or "Muted")
				statusIcon.ImageTransparency = 0
			else
				statusIcon.ImageTransparency = 1
			end
			status.TextTransparency = 1
			Util.Tween(status, 0.25, { TextTransparency = 0 }, "Quad")
		end

		-- attempts
		local dots = {}
		if ks.MaxAttempts then
			local dotRow = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 8), LayoutOrder = 6, Parent = content })
			Util.List(dotRow, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
			for i = 1, ks.MaxAttempts do
				local dot = New("Frame", { Size = UDim2.fromOffset(7, 7), BackgroundColor3 = WHITE, LayoutOrder = i, Parent = dotRow })
				Theme.Bind(dot, { BackgroundColor3 = "Input" })
				Util.Corner(dot, 8)
				dots[i] = dot
			end
		end

		-- buttons
		local busy, attempts, lockedOut = false, 0, false
		local verifyButton

		local function setBusy(on)
			busy = on
			input.TextEditable = not on and not lockedOut
			if on then
				scan.Visible = true
				scan.Position = UDim2.new(-0.4, 0, 1, 0)
				Util.Loop(scan, 0.85, { Position = UDim2.new(1, 0, 1, 0) }, "Sine", false)
			else
				-- a fresh Position replaces the looping tween; hide the bar
				scan.Visible = false
				scan.Position = UDim2.new(-0.4, 0, 1, 0)
			end
			local label = verifyButton and Util.Part(verifyButton, "Label")
			if label then label.Text = on and "Checking..." or "Verify" end
		end

		local function shake()
			for _, dx in { -12, 12, -8, 8, -4, 4, 0 } do
				if not holder or not holder.Parent then return end
				Util.Tween(holder, 0.05, { Position = UDim2.new(0.5, dx, 0.5, 0) }, "Quad")
				task.wait(0.05)
			end
		end

		local function fail(message)
			attempts += 1
			Sound.Play("Error")
			setStatus(message or "That key isn't valid", "Danger", "circle-x")
			Theme.Bind(underline, { BackgroundColor3 = "Danger" })
			Util.Tween(underline, 0.25, { Size = UDim2.new(1, -10, 0, 2) }, "Out")
			Theme.Bind(keyIcon, { ImageColor3 = "Danger" })
			Fx.Flash(inputWrap, { Color = "Danger", Alpha = 0.8, Duration = 0.6, Radius = UDim.new(0, 11) })
			task.spawn(shake)
			Fx.Pop(logoIcon, -14)
			local dot = dots[attempts]
			if dot then
				Theme.Bind(dot, { BackgroundColor3 = "Danger" })
				dot.Size = UDim2.fromOffset(11, 11)
				Util.Tween(dot, 0.4, { Size = UDim2.fromOffset(7, 7) }, "Elastic")
			end
			task.delay(1.1, function()
				if not underline.Parent then return end
				Theme.Bind(underline, { BackgroundColor3 = function(t) return t.Accent end })
				Theme.Bind(keyIcon, { ImageColor3 = focused and "Accent" or "SubText" })
				if not focused then Util.Tween(underline, 0.3, { Size = UDim2.new(0, 0, 0, 2) }, "Quad") end
			end)
			if ks.MaxAttempts and attempts >= ks.MaxAttempts then
				lockedOut = true
				input.TextEditable = false
				setStatus("Too many attempts", "Danger", "lock")
				if ks.OnFail then Util.Fire(ks.OnFail, attempts) end
				if ks.CloseOnFail ~= false then
					task.delay(1.8, function()
						if not window.Destroyed and not unlocked then window:Destroy() end
					end)
				end
			end
		end

		local function succeed(key, message)
			unlocked = true -- stops further attempts while the animation plays
			Sound.Play("Success")
			setStatus(message or "Key accepted", "Success", "circle-check")
			Theme.Bind(underline, { BackgroundColor3 = "Success" })
			Util.Tween(underline, 0.3, { Size = UDim2.new(1, -10, 0, 2) }, "Out")
			if logoIcon then
				Icons.Apply(logoIcon, "check", 24, "AccentText")
				Fx.Pop(logoIcon, 0)
			end
			Util.Tween(tile, 0.35, { Size = UDim2.fromOffset(58, 58) }, "Back")
			Fx.Burst(cluster, { X = 38, Y = 38, Count = 12, Distance = 52, Size = 4.5, Duration = 0.8, ZIndex = 20 })
			Fx.Flash(card, { Color = "Success", Alpha = 0.9, Duration = 0.8, Radius = UDim.new(0, 18) })
			task.delay(0.75, function()
				unlocked = false
				unlock(key)
			end)
		end

		local function verify()
			if busy or unlocked or lockedOut then return end
			local text = Util.Trim(input.Text)
			if text == "" then
				attempts -= 1 -- an empty box is not an attempt
				fail("Enter your key to continue")
				return
			end
			setBusy(true)
			setStatus("Checking...", "Muted", "loader-circle")
			local ok, message = validate(text)
			if not card or not card.Parent then return end
			setBusy(false)
			if ok then succeed(text, message) else fail(message) end
		end
		input.FocusLost:Connect(function(enter) if enter then verify() end end)

		local defs = {}
		if ks.URL then
			table.insert(defs, { Title = "Get key", Icon = "link", Variant = "Secondary", Callback = function()
				local copied = Util.Copy(ks.URL)
				Vesper:Notify({
					Title = copied and "Link copied" or "Key link", Content = copied and "Paste it into your browser to get a key." or tostring(ks.URL), Type = "Info",
				})
			end })
		end
		for _, extra in ks.Buttons or {} do table.insert(defs, extra) end
		table.insert(defs, { Title = "Verify", Icon = "check", Variant = "Primary", Callback = verify, Primary = true })
		local buttonRow = New("Frame", { Name = "Buttons", Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, LayoutOrder = 7, Parent = content })
		Util.List(buttonRow, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
		local width = math.floor((CARD_W - 52 - 8 * (#defs - 1)) / #defs)
		for i, def in defs do
			local btn = Util.MakeButton({ Parent = buttonRow, Text = def.Title, Icon = def.Icon, Variant = def.Variant, Height = 38, Width = width, LayoutOrder = i, Callback = def.Callback })
			if def.Primary then verifyButton = btn end
		end

		-- links
		if ks.Links and #ks.Links > 0 then
			local linkRow = New("Frame", { Name = "Links", Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 8, Parent = content })
			Util.List(linkRow, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
			for i, link in ks.Links do
				Util.MakeButton({
					Parent = linkRow, Text = link.Title, Icon = link.Icon or "link", Variant = "Ghost", Height = 26, TextSize = 12, Radius = 8, LayoutOrder = i,
					Callback = function()
						if link.Callback then Util.Fire(link.Callback) end
						if link.URL then
							local copied = Util.Copy(link.URL)
							Vesper:Notify({ Title = copied and "Link copied" or "Link", Content = copied and tostring(link.URL) or tostring(link.URL), Type = "Info", Duration = 4 })
						end
					end,
				})
			end
		end

		local footer = ks.Footer or (persistent and "Your key is remembered on this device." or nil)
		if footer then
			local foot = New("TextLabel", {
				TextSize = 11, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 9, Parent = content,
			})
			Theme.Bind(foot, { TextColor3 = "Muted" })
			Util.SetText(foot, footer)
		end

		if ks.Closable ~= false then
			local close = Util.IconButton(card, "x", 28, 0)
			close.AnchorPoint, close.Position, close.ZIndex = Vector2.new(1, 0), UDim2.new(1, -12, 0, 12), 10
			close.Activated:Connect(function()
				Sound.Play("Close")
				if ks.OnClose then Util.Fire(ks.OnClose) end
				if not window.Destroyed then window:Destroy() end
			end)
		end

		-- entrance
		Sound.Play("Open")
		Util.Tween(bg, 0.55, { GroupTransparency = 0 }, "Quad")
		Util.FadeCanvas(card, 0, 0.35, "Out")
		Util.Tween(pop, 0.5, { Scale = 1 }, "Back")
		task.delay(0.12, function()
			if tile.Parent then Util.Tween(tile, 0.55, { Size = UDim2.fromOffset(50, 50) }, "Back") end
		end)
		task.delay(0.3, function()
			if note.Parent then Util.Tween(note, 0.5, { TextTransparency = 0 }, "Quad") end
		end)
		task.spawn(function()
			task.wait(0.25)
			local n = #titleText
			for i = 1, n do
				if not title.Parent then return end
				title.MaxVisibleGraphemes = i
				task.wait(math.min(0.45 / math.max(n, 1), 0.04))
			end
			if title.Parent then title.MaxVisibleGraphemes = -1 end
		end)
		task.delay(0.6, function()
			if input.Parent and not Util.IsTouch() and not unlocked and not window.Destroyed then input:CaptureFocus() end
		end)
	end)
end

-- ─────────────────────────────────────────────────────────────
--  Built-in tabs: Themes · Configs · Icons · About
--  They live at the bottom of the sidebar.
-- ─────────────────────────────────────────────────────────────
Util.TypeLabel.ThemePicker, Util.TypeIcon.ThemePicker = "Theme picker", "palette"

function Window:AddBuiltIn(list)
	local set = {}
	if list == true then
		set = { Themes = true, Configs = true }
	elseif type(list) == "table" then
		for k, v in list do
			if type(k) == "number" then set[v] = true else set[k] = v ~= false end
		end
	end
	if set.Themes then self:AddThemesTab() end
	if set.Configs then self:AddConfigsTab() end
	if set.Icons then self:AddIconsTab() end
	if set.About then self:AddAboutTab() end
end

local function builtin(window, key)
	window._builtin = window._builtin or {}
	return window._builtin[key]
end

-- ── Themes ───────────────────────────────────────────────────
function Window:AddThemesTab()
	if builtin(self, "Themes") then return self._builtin.Themes end
	local tab = self:_FooterTab({ Title = "Themes", Icon = "palette" })
	self._builtin.Themes = tab

	-- swatch grid: each swatch shows the window colour with the accent gradient on top
	local card = New("Frame", {
		Name = "ThemePicker", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = Look.Card, BackgroundColor3 = WHITE,
		LayoutOrder = Elements.NextOrder(tab), Parent = tab.Content,
	})
	Theme.Bind(card, { BackgroundColor3 = "Card" })
	Util.Corner(card, 12)
	Util.Shade(card, 90, 0.07)
	Shadow.Edge(card, { Inset = 9, Alpha = 0.84 })
	Util.FadeLine(card, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.26, ZIndex = 4 })
	local pad = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
	Util.Padding(pad, 12, 14, 14, 14)
	Util.List(pad, 12)
	local entry = Elements.Register(tab, card, "element", "Theme colors appearance", "Pick a theme", { Type = "ThemePicker", Icon = "palette" })

	local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = pad })
	local title = New("TextLabel", { Weight = "Medium", TextSize = 14, Size = UDim2.fromScale(1, 1), Parent = header })
	Theme.Bind(title, { TextColor3 = "Text" })
	Util.SetText(title, "Theme")
	local nameLabel = New("TextLabel", { Weight = "Medium", TextSize = 12, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Right, Text = Theme.Current.Name, Parent = header })
	Theme.Bind(nameLabel, { TextColor3 = "SubText" })

	local grid = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = pad })
	local list = Util.List(grid, 6, Enum.FillDirection.Horizontal)
	list.Wraps = true

	local swatches = {}
	local function paint()
		local current = Theme.Current.Name
		nameLabel.Text = current
		for name, s in swatches do
			local on = name == current
			Util.Tween(s.Halo, 0.25, { BackgroundTransparency = on and 0.72 or 1, Size = UDim2.fromOffset(on and 40 or 30, on and 40 or 30) }, "Back")
			Util.Tween(s.Check, 0.2, { ImageTransparency = on and 0 or 1 }, "Quad")
		end
	end

	for i, name in Theme.Order do
		local def = Theme.Themes[name]
		local accent, accent2, windowColor = def.Accent, def.Accent2, def.Window2
		local btn = New("TextButton", { Name = name, Size = UDim2.fromOffset(40, 40), LayoutOrder = i, Parent = grid })
		local halo = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Parent = btn })
		Theme.Bind(halo, { BackgroundColor3 = "Text" })
		Util.Corner(halo, 40)
		local base = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = windowColor, ZIndex = 2, Parent = btn })
		Util.Corner(base, 30)
		Util.Shade(base, 90, 0.18)
		local dot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = WHITE, ZIndex = 3, Parent = btn })
		Util.Corner(dot, 20)
		New("UIGradient", { Rotation = 45, Color = ColorSequence.new(accent, accent2), Parent = dot })
		local check = Util.Icon(dot, "check", 12, WHITE, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ImageTransparency = 1, ZIndex = 4 })
		check.ImageColor3 = (Util.Luminance(accent) + Util.Luminance(accent2)) / 2 > 0.62 and Color3.fromRGB(18, 18, 22) or WHITE
		swatches[name] = { Halo = halo, Check = check }

		btn.MouseEnter:Connect(function()
			nameLabel.Text = name
			Util.Tween(base, 0.18, { Size = UDim2.fromOffset(34, 34) }, "Back")
			Util.Tween(dot, 0.18, { Size = UDim2.fromOffset(23, 23) }, "Back")
		end)
		btn.MouseLeave:Connect(function()
			nameLabel.Text = Theme.Current.Name
			Util.Tween(base, 0.2, { Size = UDim2.fromOffset(30, 30) }, "Quad")
			Util.Tween(dot, 0.2, { Size = UDim2.fromOffset(20, 20) }, "Quad")
		end)
		btn.Activated:Connect(function()
			Sound.Play("Select")
			Fx.Burst(btn, { X = 20, Y = 20, Count = 6, Distance = 24, Size = 3, Duration = 0.5, Color = accent, Color2 = accent2 })
			Theme.Set(name)
		end)
	end
	paint()
	Theme.Watch(card, function() paint() end)

	local controls = {}

	-- Background ---------------------------------------------------
	local look = tab:Section({ Title = "Background", Icon = "layers" })
	local styleValues = { "Default" }
	for _, s in Theme.Styles do table.insert(styleValues, s) end
	controls.style = look:Dropdown({
		Title = "Background style", Desc = "Default follows the theme. Plain, Orbs, Streaks, Aurora, Stars, Grid, Shards or Rings.", Icon = "wand-sparkles",
		Values = styleValues, Default = Theme.StyleOverride or "Default", SearchBar = false,
		Callback = function(v) Theme.SetStyle(v) end,
	})
	controls.animated = look:Toggle({
		Title = "Animated background", Desc = "Let the orbs, streaks and stars drift", Icon = "sparkles", Default = Theme.Animated,
		Callback = function(v) Theme.SetAnimated(v) end,
	})
	controls.opacity = look:Slider({
		Title = "Window opacity", Desc = "Make the window see-through", Icon = "eye", Min = 40, Max = 100, Step = 5, Suffix = "%",
		Default = math.floor((1 - self.Opacity) * 100 + 0.5), ShowDefault = false, Callback = function(v) self:SetOpacity(1 - v / 100) end,
	})

	-- Lines -----------------------------------------------------------
	local lines = tab:Section({ Title = "Lines", Icon = "minus" })
	controls.lineStyle = lines:Dropdown({
		Title = "Line style", Desc = "How dividers and edges fade out", Icon = "git-commit-horizontal", Values = { "Edges", "Left", "Right", "Center", "Solid" },
		Default = Lines.Style, SearchBar = false, Callback = function(v) Vesper:SetLines({ Style = v }) end,
	})
	controls.lineThickness = lines:Slider({
		Title = "Line thickness", Icon = "ruler", Min = 1, Max = 3, Step = 1, Suffix = "px", Default = Lines.Thickness, ShowDefault = false,
		Callback = function(v) Vesper:SetLines({ Thickness = v }) end,
	})
	controls.lineStrength = lines:Slider({
		Title = "Line strength", Desc = "100% is how they were designed", Icon = "contrast", Min = 0, Max = 200, Step = 10, Suffix = "%",
		Default = math.floor(Lines.Strength / 0.5 * 100 + 0.5), Callback = function(v) Vesper:SetLines({ Strength = v / 200 }) end,
	})
	controls.lineColor = lines:Dropdown({
		Title = "Line color", Icon = "paintbrush", Values = { "Stroke", "Accent" }, Default = Lines.Color, SearchBar = false,
		Callback = function(v) Vesper:SetLines({ Color = v }) end,
	})

	-- Depth -------------------------------------------------------------
	local depth = tab:Section({ Title = "Depth", Icon = "box" })
	controls.depth = depth:Slider({
		Title = "Shadow depth", Desc = "The shadow under cards and windows", Icon = "layers-2", Min = 0, Max = 4, Step = 1, Suffix = "px", Default = Shadow.Config.Depth,
		Callback = function(v) Vesper:SetShadow({ Depth = v }) end,
	})
	controls.shadowStrength = depth:Slider({
		Title = "Shadow strength", Icon = "moon", Min = 0, Max = 200, Step = 10, Suffix = "%", Default = math.floor(Shadow.Config.Strength / 0.5 * 100 + 0.5),
		Callback = function(v) Vesper:SetShadow({ Strength = v / 200 }) end,
	})
	controls.soft = depth:Toggle({
		Title = "Soft shadow", Desc = "Adds a wider, softer shadow around floating panels", Icon = "cloud", Default = Shadow.Config.Soft,
		Callback = function(v) Vesper:SetShadow({ Soft = v }) end,
	})

	-- Effects -----------------------------------------------------------
	local fx = tab:Section({ Title = "Effects", Icon = "sparkles" })
	controls.click = fx:Dropdown({
		Title = "Click effect", Desc = "What happens when you press something", Icon = "mouse-pointer-click", Values = Fx.Styles, Default = Fx.Style, SearchBar = false,
		Callback = function(v) Vesper:SetClickEffect(v) end,
	})
	fx:Toggle({
		Title = "Interface sounds", Desc = "Clicks, toggles and notifications", Icon = "bell", Default = Sound.Enabled,
		Callback = function(v) Sound.Enabled = v end,
	})

	-- Notifications -----------------------------------------------------
	local notes = tab:Section({ Title = "Notifications", Icon = "bell-ring", Collapsible = true, Opened = false })
	local no = Layer.Options
	controls.nPosition = notes:Dropdown({
		Title = "Position", Icon = "move", Values = Layer.Positions, Default = no.Position, SearchBar = false,
		Callback = function(v) Vesper:SetNotifyOptions({ Position = v }) end,
	})
	notes:Slider({
		Title = "Width", Icon = "move-horizontal", Min = 220, Max = 480, Step = 10, Suffix = "px", Default = no.Width, ShowDefault = false,
		Callback = function(v) Vesper:SetNotifyOptions({ Width = v }) end,
	})
	notes:Slider({
		Title = "Size", Desc = "Scales everything inside the cards", Icon = "scaling", Min = 60, Max = 160, Step = 10, Suffix = "%", Default = math.floor(no.Scale * 100 + 0.5),
		Callback = function(v) Vesper:SetNotifyOptions({ Scale = v / 100 }) end,
	})
	notes:Dropdown({
		Title = "Animation", Icon = "wand-sparkles", Values = { "Slide", "Pop", "Drop", "Fade" }, Default = no.Animation, SearchBar = false,
		Callback = function(v) Vesper:SetNotifyOptions({ Animation = v }) end,
	})
	notes:Toggle({ Title = "Compact cards", Icon = "minimize-2", Default = no.Compact, Callback = function(v) Vesper:SetNotifyOptions({ Compact = v }) end })
	notes:Toggle({ Title = "Timer bar", Icon = "timer", Default = no.Progress, Callback = function(v) Vesper:SetNotifyOptions({ Progress = v }) end })
	notes:ButtonRow({ Buttons = {
		{ Title = "Preview", Icon = "bell", Variant = "Primary", Callback = function()
			Vesper:Notify({ Title = "Looking good", Content = "This is how your notifications look.", Type = "Success", Duration = 4 })
		end },
	} })

	-- Interface ---------------------------------------------------------
	local ui = tab:Section({ Title = "Interface", Icon = "monitor", Collapsible = true, Opened = false })
	ui:Stepper({
		Title = "Interface scale", Desc = "Resize the whole interface", Icon = "scan-eye", Min = 70, Max = 140, Step = 10, Suffix = "%",
		Default = math.floor(self.UserScale * 100 + 0.5), Callback = function(v) self:SetScale(v / 100) end,
	})
	ui:Segmented({
		Title = "Density", Desc = "Compact makes every control smaller", Icon = "rows-3", Values = { "Auto", "Normal", "Compact" }, Default = self.AutoDensity and "Auto" or self.Density,
		Callback = function(v) self:SetDensity(v) end,
	})
	ui:Keybind({
		Title = "Toggle key", Desc = "Show or hide the window", Icon = "keyboard", Default = self.ToggleKey,
		ChangedCallback = function(key)
			if key and key.EnumType == Enum.KeyCode then self.ToggleKey = key end
		end,
	})
	ui:Toggle({
		Title = "Confirm before closing", Icon = "power", Default = self.ConfirmClose,
		Callback = function(v) self.ConfirmClose = v end,
	})

	-- keeps the controls honest after a config was loaded
	self._syncAppearance = function()
		controls.style:Set(Theme.StyleOverride or "Default", true)
		controls.animated:Set(Theme.Animated, true)
		controls.lineStyle:Set(Lines.Style, true)
		controls.lineThickness:Set(Lines.Thickness, true)
		controls.lineStrength:Set(Lines.Strength / 0.5 * 100, true)
		controls.lineColor:Set(Lines.Color, true)
		controls.depth:Set(Shadow.Config.Depth, true)
		controls.shadowStrength:Set(Shadow.Config.Strength / 0.5 * 100, true)
		controls.soft:Set(Shadow.Config.Soft, true)
		controls.click:Set(Fx.Style, true)
	end
	return tab
end

-- ── Configs ──────────────────────────────────────────────────
function Window:AddConfigsTab()
	if builtin(self, "Configs") then return self._builtin.Configs end
	local tab = self:_FooterTab({ Title = "Configs", Icon = "save" })
	self._builtin.Configs = tab
	local cm = self.ConfigManager

	if not Config.IsPersistent() then
		tab:Paragraph({
			Title = "Session only", Icon = "info",
			Content = "Your executor has no file access, so configs are kept in memory until you leave the game.",
		})
	end

	local section = tab:Section({ Title = "Configs", Icon = "folder" })
	local nameInput = section:Input({ Title = "Config name", Desc = "Type a name to create or overwrite a config", Icon = "pencil", Placeholder = "default", Live = true })
	local dropdown = section:Dropdown({
		Title = "Saved configs", Desc = "Pick one to load or delete", Icon = "folder-open", Values = cm:List(),
		Placeholder = "None", AllowNone = true, Callback = function() end,
	})
	dropdown:Set(cm:GetAutoload(), true)

	local function refresh()
		dropdown:Refresh(cm:List(), true)
	end
	local function selected()
		return dropdown.Value or (nameInput.Value ~= "" and nameInput.Value or nil)
	end

	section:ButtonRow({ Buttons = {
		{ Title = "Save", Icon = "save", Variant = "Primary", Callback = function()
			local name = nameInput.Value ~= "" and nameInput.Value or dropdown.Value
			if not name then
				Vesper:Notify({ Title = "Name needed", Content = "Type a config name first.", Type = "Warning", Duration = 3 })
				return
			end
			local ok, err = cm:Save(name)
			if ok then
				refresh()
				dropdown:Set(name, true)
				Vesper:Notify({ Title = "Config saved", Content = name, Type = "Success", Duration = 3 })
			else
				Vesper:Notify({ Title = "Couldn't save", Content = tostring(err), Type = "Error" })
			end
		end },
		{ Title = "Load", Icon = "download", Variant = "Secondary", Callback = function()
			local name = selected()
			if not name then
				Vesper:Notify({ Title = "Nothing selected", Content = "Pick a saved config first.", Type = "Warning", Duration = 3 })
				return
			end
			local ok, err = cm:Load(name)
			Vesper:Notify({ Title = ok and "Config loaded" or "Couldn't load", Content = ok and name or tostring(err), Type = ok and "Success" or "Error", Duration = 3 })
		end },
		{ Title = "Delete", Icon = "trash-2", Variant = "Ghost", Callback = function()
			local name = dropdown.Value
			if not name then
				Vesper:Notify({ Title = "Nothing selected", Content = "Pick a saved config first.", Type = "Warning", Duration = 3 })
				return
			end
			self:Dialog({
				Title = "Delete config?", Content = "'" .. name .. "' will be removed permanently.", Icon = "trash-2",
				Buttons = {
					{ Title = "Cancel", Variant = "Secondary" },
					{ Title = "Delete", Variant = "Danger", Callback = function()
						local ok, err = cm:Delete(name)
						if ok then dropdown:Set(nil, true); refresh() end
						Vesper:Notify({ Title = ok and "Config deleted" or "Couldn't delete", Content = ok and name or tostring(err or ""), Type = ok and "Success" or "Error", Duration = 3 })
					end },
				},
			})
		end },
		{ Title = "Refresh", Icon = "refresh-cw", Variant = "Ghost", Callback = refresh },
	} })

	section:Toggle({
		Title = "Autoload", Desc = "Load the selected config the next time the script runs", Icon = "rotate-ccw", Default = cm:GetAutoload() ~= nil,
		Callback = function(on)
			if on then
				local name = selected()
				if name then cm:SetAutoload(name) else Vesper:Notify({ Title = "Nothing selected", Content = "Pick a saved config first.", Type = "Warning", Duration = 3 }) end
			else
				cm:SetAutoload(nil)
			end
		end,
	})

	local share = tab:Section({ Title = "Share", Icon = "share-2" })
	share:ButtonRow({ Buttons = {
		{ Title = "Copy current as JSON", Icon = "copy", Variant = "Secondary", Callback = function()
			local json = cm:Export()
			local ok = json and Util.Copy(json)
			Vesper:Notify({ Title = ok and "Copied" or "Couldn't copy", Content = ok and "Config JSON is on your clipboard." or "Clipboard access isn't available.", Type = ok and "Success" or "Warning", Duration = 3 })
		end },
	} })
	share:Input({
		Title = "Import from JSON", Desc = "Paste a config and press Enter", Icon = "clipboard-copy", Placeholder = "Paste JSON",
		Callback = function(text)
			if text == "" then return end
			local ok, err = cm:Import(text)
			Vesper:Notify({ Title = ok and "Config imported" or "Couldn't import", Content = ok and "Applied to this window." or tostring(err), Type = ok and "Success" or "Error", Duration = 3 })
		end,
	})
	return tab
end

-- ── Icons browser ────────────────────────────────────────────
function Window:AddIconsTab()
	if builtin(self, "Icons") then return self._builtin.Icons end
	local tab = self:_FooterTab({ Title = "Icons", Icon = "layout-grid" })
	self._builtin.Icons = tab
	local names = Icons.GetNames()
	local LIMIT = 150

	local show -- assigned below, once the result grid exists
	tab:Input({
		Title = "Search icons", Desc = string.format("%d Lucide icons built in", #names), Icon = "search", Placeholder = "home, sword, heart...",
		Width = 190, Live = true, Callback = function(text) if show then show(text) end end,
	})

	local card = New("Frame", {
		Name = "IconBrowser", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = Look.Card, BackgroundColor3 = WHITE,
		LayoutOrder = Elements.NextOrder(tab), Parent = tab.Content,
	})
	Theme.Bind(card, { BackgroundColor3 = "Card" })
	Util.Corner(card, 12)
	Util.Shade(card, 90, 0.07)
	Shadow.Edge(card, { Inset = 9, Alpha = 0.84 })
	Util.FadeLine(card, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 1), Strength = 0.26, ZIndex = 4 })
	local pad = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
	Util.Padding(pad, 12, 12, 14, 12)
	Util.List(pad, 10)
	Elements.Register(tab, card, "decor")

	local info = New("TextLabel", { TextSize = 11, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Parent = pad })
	Theme.Bind(info, { TextColor3 = "Muted" })
	local grid = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = pad })
	New("UIGridLayout", { CellSize = UDim2.fromOffset(46, 46), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })

	local pool = {}
	for i = 1, LIMIT do
		local btn = New("TextButton", { BackgroundColor3 = WHITE, BackgroundTransparency = 1, LayoutOrder = i, Visible = false, Parent = grid })
		Theme.Bind(btn, { BackgroundColor3 = "Input" })
		Util.Corner(btn, 11)
		local img = Util.Icon(btn, nil, 22, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		pool[i] = { Button = btn, Image = img, Name = nil }
		btn.MouseEnter:Connect(function()
			Util.Tween(btn, 0.12, { BackgroundTransparency = 0 }, "Quad")
			Util.Tween(img, 0.18, { Size = UDim2.fromOffset(26, 26) }, "Back")
			if pool[i].Name then info.Text = pool[i].Name end
		end)
		btn.MouseLeave:Connect(function()
			Util.Tween(btn, 0.15, { BackgroundTransparency = 1 }, "Quad")
			Util.Tween(img, 0.2, { Size = UDim2.fromOffset(22, 22) }, "Quad")
		end)
		btn.Activated:Connect(function()
			local name = pool[i].Name
			if not name then return end
			Sound.Play("Click")
			Fx.Click(btn, { Radius = UDim.new(0, 11) })
			local ok = Util.Copy(name)
			Vesper:Notify({ Title = ok and "Icon name copied" or name, Content = ok and name or "Clipboard access isn't available.", Type = ok and "Success" or "Info", Duration = 2 })
		end)
	end

	show = function(filter)
		filter = string.lower(Util.Trim(filter))
		local shown, total = 0, 0
		for _, name in names do
			if filter == "" or string.find(name, filter, 1, true) then
				total += 1
				if shown < LIMIT then
					shown += 1
					local slot = pool[shown]
					slot.Name = name
					Icons.Apply(slot.Image, name, 22, "Text")
					slot.Button.Visible = true
				end
			end
		end
		for i = shown + 1, LIMIT do
			pool[i].Name = nil
			pool[i].Button.Visible = false
		end
		info.Text = string.format("Showing %d of %d  ·  click an icon to copy its name", shown, total)
	end
	show("")
	return tab
end

-- ── About ────────────────────────────────────────────────────
function Window:AddAboutTab(about)
	if builtin(self, "About") then return self._builtin.About end
	about = about or self.Opts.About or {}
	local tab = self:_FooterTab({ Title = "About", Icon = "info" })
	self._builtin.About = tab
	tab:Paragraph({
		Title = about.Title or self.Opts.Title or "About", Icon = about.Icon or "info",
		Content = about.Content or about.Description or "Built with Vesper UI.", Buttons = about.Buttons,
	})
	tab:Paragraph({
		Title = "Vesper UI", Icon = "sparkles",
		Content = "Version " .. Vesper.Version .. "  ·  Icons by Lucide (ISC license)",
	})
	return tab
end

-- ─────────────────────────────────────────────────────────────
--  Public API
-- ─────────────────────────────────────────────────────────────
Vesper.Icons = {
	Get = function(name, size) return Icons.Resolve(name, size) end,
	Has = Icons.Has,
	GetNames = Icons.GetNames,
	Count = function() return #Icons.GetNames() end,
}

-- Themes ───────────────────────────────────────────────────
function Vesper:SetTheme(name) return Theme.Set(name) end
function Vesper:GetTheme() return Theme.Current.Name end
function Vesper:GetThemes() return table.clone(Theme.Order) end
--- Vesper:AddTheme("Name", { Base = Color3, Accent = Color3, Accent2 = Color3?, Mode = "Dark"|"Light"?, Style = "Orbs"?, Override = {...}? })
function Vesper:AddTheme(name, spec) return Theme.Add(name, spec) end
function Vesper:OnThemeChanged(fn) table.insert(Theme.Listeners, fn) end

-- Backgrounds ──────────────────────────────────────────────
--- Vesper:SetBackground("Orbs") — Plain | Orbs | Streaks | Aurora | Stars | Grid | Shards | Rings, or "Default" to follow the theme
function Vesper:SetBackground(style) return Theme.SetStyle(style) end
function Vesper:GetBackground() return Theme.GetStyle() end
function Vesper:GetBackgrounds() return table.clone(Theme.Styles) end
--- Turn the drifting / twinkling motion of the backgrounds on or off
function Vesper:SetAnimated(on) Theme.SetAnimated(on) end

-- Lines ────────────────────────────────────────────────────
--- Vesper:SetLines({ Style = "Edges"|"Left"|"Right"|"Center"|"Solid", Thickness = 1-4, Strength = 0-1 (0.5 = as designed), Color = "Stroke"|"Accent" })
function Vesper:SetLines(cfg)
	if type(cfg) ~= "table" then return end
	local styles = { Edges = true, Left = true, Right = true, Center = true, Solid = true }
	if cfg.Style ~= nil and styles[cfg.Style] then Lines.Style = cfg.Style end
	if type(cfg.Thickness) == "number" then Lines.Thickness = Util.Clamp(math.floor(cfg.Thickness + 0.5), 1, 4) end
	if type(cfg.Strength) == "number" then Lines.Strength = Util.Clamp(cfg.Strength, 0, 1) end
	local recolor = false
	if cfg.Color ~= nil and Theme.Current[cfg.Color] ~= nil and typeof(Theme.Current[cfg.Color]) == "Color3" then
		recolor = Lines.Color ~= cfg.Color
		Lines.Color = cfg.Color
	end
	Lines.ApplyAll()
	if recolor then Theme.Refresh(true) end
end
function Vesper:GetLines()
	return { Style = Lines.Style, Thickness = Lines.Thickness, Strength = Lines.Strength, Color = Lines.Color }
end

-- Depth shadows ────────────────────────────────────────────
--- Vesper:SetShadow({ Depth = 0-6 (pixels), Strength = 0-1 (0.5 = as designed), Soft = true|false })
function Vesper:SetShadow(cfg)
	if type(cfg) ~= "table" then return end
	if type(cfg.Depth) == "number" then Shadow.Config.Depth = Util.Clamp(cfg.Depth, 0, 6) end
	if type(cfg.Strength) == "number" then Shadow.Config.Strength = Util.Clamp(cfg.Strength, 0, 1) end
	if cfg.Soft ~= nil then Shadow.Config.Soft = cfg.Soft == true end
	Shadow.ApplyAll()
end
function Vesper:GetShadow() return table.clone(Shadow.Config) end

-- Click effects ────────────────────────────────────────────
--- Vesper:SetClickEffect("Ripple" | "Burst" | "Pulse" | "Sheen" | "None")
function Vesper:SetClickEffect(style)
	if style == false then style = "None" end
	return Fx.SetStyle(style)
end
function Vesper:GetClickEffect() return Fx.Style end
function Vesper:GetClickEffects() return table.clone(Fx.Styles) end

-- Sounds ───────────────────────────────────────────────────
--- Vesper:SetSound("Click", "rbxassetid://123") or Vesper:SetSound("Click", { Id = "...", Volume = 0.5, Speed = 1 })
function Vesper:SetSound(name, value)
	if value == nil then Sound.Map[name] = nil; return end
	if type(value) == "number" then value = "rbxassetid://" .. value end
	if type(value) == "string" then
		local old = Sound.Map[name] or {}
		Sound.Map[name] = { Id = value, Volume = old.Volume or 0.4, Speed = old.Speed or 1 }
	else
		Sound.Map[name] = value
	end
end
function Vesper:SetSoundsEnabled(enabled) Sound.Enabled = enabled == true end
function Vesper:SetSoundVolume(volume) Sound.Volume = Util.Clamp(volume, 0, 2) end

-- Localization ─────────────────────────────────────────────
--- Vesper:Localization({ Enabled = true, Prefix = "loc:", DefaultLanguage = "en", Translations = { en = {KEY = "text"}, es = {...} } })
function Vesper:Localization(cfg)
	cfg = cfg or {}
	Loc.Enabled = cfg.Enabled ~= false
	Loc.Prefix = cfg.Prefix or Loc.Prefix
	Loc.Default = cfg.DefaultLanguage or Loc.Default
	Loc.Language = cfg.Language or cfg.DefaultLanguage or Loc.Language
	for lang, translations in cfg.Translations or {} do
		Loc.Tables[lang] = Loc.Tables[lang] or {}
		for key, text in translations do Loc.Tables[lang][key] = text end
	end
	Loc.Refresh()
end
function Vesper:AddTranslations(lang, translations)
	Loc.Tables[lang] = Loc.Tables[lang] or {}
	for key, text in translations do Loc.Tables[lang][key] = text end
	Loc.Refresh()
end
function Vesper:SetLanguage(lang)
	Loc.Language = lang
	Loc.Refresh()
end
function Vesper:GetLanguage() return Loc.Language end
function Vesper:GetLanguages()
	local out = {}
	for lang in Loc.Tables do table.insert(out, lang) end
	table.sort(out)
	return out
end
function Vesper:Translate(text) return Loc.Resolve(text) end

-- Misc ─────────────────────────────────────────────────────
--- Call before creating windows. Example: Vesper:SetFont("rbxasset://fonts/families/Montserrat.json")
function Vesper:SetFont(family)
	Util.FontFamily = family
	table.clear(fontCache)
end

function Vesper:Destroy()
	for i = #Vesper.Windows, 1, -1 do
		local w = Vesper.Windows[i]
		w.Destroyed = true
		pcall(function() w.Maid:Clean(); w.Host:Destroy() end)
	end
	table.clear(Vesper.Windows)
	table.clear(Vesper.Flags)
	-- the notification layer is rebuilt on demand, so it must not keep pointing at destroyed objects
	if Layer.Host then pcall(function() Layer.Host:Destroy() end) end
	Layer.Host, Layer.NotifyHolder, Layer.NotifyList = nil, nil, nil
	table.clear(Layer.Active)
	table.clear(Sound.Pool)
	Sound.Parent = nil
	table.clear(Theme.Listeners)
	Vesper._KeyListening = nil
	local env = (getgenv and getgenv()) or _G
	if env.__VesperLib == Vesper then env.__VesperLib = nil end
end

do
	local env = (getgenv and getgenv()) or _G
	env.__VesperLib = Vesper
end

return Vesper
