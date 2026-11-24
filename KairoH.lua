--[[
 _  __     _               _   _ ___
| |/ /__ _(_)_ __ ___     | | | |_ _|
| ' // _` | | '__/ _ \    | | | || |
| . \ (_| | | | | (_) |   | |_| || |
|_|\_\__,_|_|_|  \___/     \___/|___|

 Kairo UI  -  credits: wheizx
]]
local __F, __K = {}, {}
__F["Util"] = function(...)
local K = ...
local Util = {}

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

Util.TweenService = TweenService
Util.RunService = RunService
Util.UserInputService = UserInputService
Util.HttpService = HttpService
Util.Players = Players

local infoCache = {}
function Util.info(t, style, dir)
	style = style or Enum.EasingStyle.Quint
	dir = dir or Enum.EasingDirection.Out
	local key = t .. style.Name .. dir.Name
	local i = infoCache[key]
	if not i then
		i = TweenInfo.new(t, style, dir)
		infoCache[key] = i
	end
	return i
end

function Util.tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, Util.info(t, style, dir), props)
	tw:Play()
	return tw
end

function Util.clamp(v, a, b)
	if v < a then return a end
	if v > b then return b end
	return v
end

function Util.lerp(a, b, t)
	return a + (b - a) * t
end

function Util.round(v, step)
	step = step or 1
	return math.floor(v / step + 0.5) * step
end

function Util.decimals(step)
	local s = tostring(step)
	local dot = s:find("%.")
	return dot and #s - dot or 0
end

function Util.fmt(v, step)
	local d = Util.decimals(step or 1)
	if d == 0 then return tostring(math.floor(v + 0.5)) end
	return string.format("%." .. d .. "f", v)
end

function Util.rgb(s)
	local r, g, b = s:match("(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
	return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
end

function Util.hex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

function Util.fromHex(s)
	s = s:gsub("#", "")
	if #s == 3 then s = s:sub(1, 1):rep(2) .. s:sub(2, 2):rep(2) .. s:sub(3, 3):rep(2) end
	if #s ~= 6 or s:find("%X") then return nil end
	return Color3.fromRGB(tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16))
end

function Util.mix(a, b, t)
	return a:Lerp(b, t)
end

function Util.luma(c)
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

function Util.copy(t, deep)
	if type(t) ~= "table" then return t end
	local o = {}
	for k, v in t do o[k] = deep and Util.copy(v, true) or v end
	return o
end

function Util.merge(base, over)
	local o = Util.copy(base)
	if over then for k, v in over do o[k] = v end end
	return o
end

function Util.safe(fn, ...)
	if type(fn) ~= "function" then return true end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[Kairo] " .. tostring(err)) end
	return ok, err
end

function Util.uid()
	Util._n = (Util._n or 0) + 1
	return Util._n
end

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({fns = {}, n = 0}, Signal)
end

function Signal:Connect(fn)
	self.n += 1
	local id = self.n
	self.fns[id] = fn
	local sig = self
	return {
		Connected = true,
		Disconnect = function(c)
			c.Connected = false
			sig.fns[id] = nil
		end,
	}
end

function Signal:Fire(...)
	local ids = {}
	for id in self.fns do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ids do
		local fn = self.fns[id]
		if fn then task.spawn(fn, ...) end
	end
end

function Signal:Destroy()
	self.fns = {}
end

Util.Signal = Signal

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({items = {}}, Maid)
end

function Maid:Add(x)
	self.items[#self.items + 1] = x
	return x
end

function Maid:Clean()
	local items = self.items
	self.items = {}
	for i = #items, 1, -1 do
		local x = items[i]
		local t = typeof(x)
		if t == "RBXScriptConnection" then
			x:Disconnect()
		elseif t == "Instance" then
			x:Destroy()
		elseif t == "function" then
			pcall(x)
		elseif t == "table" then
			if x.Disconnect then x:Disconnect() elseif x.Destroy then x:Destroy() end
		end
	end
end

Maid.Destroy = Maid.Clean
Util.Maid = Maid

local function new(class, props, children)
	local o = Instance.new(class)
	if class:find("Button") or class == "TextLabel" or class == "TextBox" or class == "Frame" or class == "ImageLabel" or class == "CanvasGroup" or class == "ScrollingFrame" then
		o.BorderSizePixel = 0
	end
	if class == "TextButton" or class == "ImageButton" then
		o.AutoButtonColor = false
	end
	if class == "Frame" or class == "CanvasGroup" then
		o.BackgroundTransparency = 0
	elseif class == "TextLabel" or class == "ImageLabel" or class == "ImageButton" or class == "TextButton" then
		o.BackgroundTransparency = 1
	end
	local parent
	if props then
		for k, v in props do
			if k == "Parent" then parent = v else o[k] = v end
		end
	end
	if children then
		for _, c in children do c.Parent = o end
	end
	if parent then o.Parent = parent end
	return o
end

Util.new = new

function Util.corner(parent, r)
	return new("UICorner", {CornerRadius = UDim.new(0, r), Parent = parent})
end

function Util.pill(parent)
	return new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = parent})
end

function Util.stroke(parent, color, thickness, transparency)
	return new("UIStroke", {Color = color, Thickness = thickness or 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent})
end

function Util.pad(parent, l, t, r, b)
	t = t or l
	r = r or l
	b = b or t
	return new("UIPadding", {PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b), Parent = parent})
end

function Util.list(parent, gap, dir, ha, va)
	return new("UIListLayout", {
		Padding = UDim.new(0, gap or 0),
		FillDirection = dir or Enum.FillDirection.Vertical,
		HorizontalAlignment = ha or Enum.HorizontalAlignment.Left,
		VerticalAlignment = va or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function Util.fontFace(weight)
	weight = weight or Enum.FontWeight.Medium
	local ok, f = pcall(Font.new, "rbxasset://fonts/families/Inter.json", weight, Enum.FontStyle.Normal)
	if ok then return f end
	return Font.fromEnum(Enum.Font.GothamMedium)
end

local W = {Regular = Enum.FontWeight.Regular, Medium = Enum.FontWeight.Medium, SemiBold = Enum.FontWeight.SemiBold, Bold = Enum.FontWeight.Bold}
local faces = {}
function Util.font(name)
	local f = faces[name]
	if not f then
		f = Util.fontFace(W[name] or W.Medium)
		faces[name] = f
	end
	return f
end

function Util.text(parent, props)
	local p = {
		Size = UDim2.new(1, 0, 1, 0),
		Text = "",
		TextSize = 13,
		FontFace = Util.font(props.Weight or "Medium"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = parent,
	}
	for k, v in props do
		if k ~= "Weight" then p[k] = v end
	end
	return new("TextLabel", p)
end

function Util.measure(text, size, weight, maxw)
	local TextService = game:GetService("TextService")
	local ok, v = pcall(TextService.GetTextSize, TextService, text, size, Enum.Font.GothamMedium, Vector2.new(maxw or 10000, 10000))
	if ok then return v end
	return Vector2.new(#text * size * 0.55, size)
end

function Util.hit(obj, x, y)
	local p, s = obj.AbsolutePosition, obj.AbsoluteSize
	return x >= p.X and x < p.X + s.X and y >= p.Y and y < p.Y + s.Y
end

function Util.mouse()
	return UserInputService:GetMouseLocation()
end

function Util.inset()
	local ok, a = pcall(function() return game:GetService("GuiService"):GetGuiInset() end)
	return ok and a or Vector2.new(0, 36)
end

function Util.inputPos(i)
	local inset = Util.inset()
	return Vector2.new(i.Position.X + inset.X, i.Position.Y + inset.Y)
end

function Util.gui()
	local ok, h = pcall(function() return gethui and gethui() end)
	if ok and h then return h end
	local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok2 and cg then return cg end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

function Util.protect(g)
	pcall(function() if protect_gui then protect_gui(g) elseif syn and syn.protect_gui then syn.protect_gui(g) end end)
end

function Util.viewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

function Util.delay(t, fn)
	return task.delay(t, fn)
end

function Util.ease(t)
	return 1 - (1 - t) ^ 3
end

function Util.tags(list)
	local o = {}
	for _, v in list do o[v] = true end
	return o
end

return Util

end
__F["ThemeData"] = function(...)
local K = ...
local D = {
	{id = "carbon", name = "Carbon", light = false, r = {14, 12, 10, 8},
		bg = "14,14,16", sheet = "22,22,24", tile = "31,31,33", ctl = "43,43,45", ctl2 = "60,60,61", a1 = "236,236,240", a2 = "236,236,240", on = "14,14,16", ink = "236,236,240", pop = "41,41,42"},
	{id = "zinc", name = "Zinc", light = false, r = {14, 12, 10, 8},
		bg = "16,16,16", sheet = "24,24,24", tile = "33,33,33", ctl = "45,45,45", ctl2 = "61,61,61", a1 = "0,145,255", a2 = "0,145,255", on = "255,255,255", ink = "255,255,255", pop = "42,42,42"},
	{id = "daylight", name = "Daylight", light = true, r = {14, 12, 10, 8},
		bg = "233,233,233", sheet = "245,245,245", tile = "255,255,255", ctl = "242,242,242", ctl2 = "210,210,210", a1 = "24,24,27", a2 = "24,24,27", on = "255,255,255", ink = "0,0,0", pop = "255,255,255"},
	{id = "ocean", name = "Ocean", light = false, r = {14, 12, 10, 8},
		bg = "5,26,38", sheet = "14,34,46", tile = "23,42,53", ctl = "35,53,64", ctl2 = "53,70,79", a1 = "0,212,255", a2 = "0,212,255", on = "14,14,16", ink = "230,247,255", pop = "33,51,62"},
	{id = "indigo", name = "Indigo", light = false, r = {14, 12, 10, 8},
		bg = "15,10,46", sheet = "23,19,53", tile = "32,27,61", ctl = "44,39,71", ctl2 = "61,57,86", a1 = "79,70,229", a2 = "79,70,229", on = "255,255,255", ink = "241,245,249", pop = "41,37,69"},
	{id = "violet", name = "Violet", light = false, r = {14, 12, 10, 8},
		bg = "30,10,62", sheet = "38,19,69", tile = "46,27,76", ctl = "57,39,85", ctl2 = "73,57,99", a1 = "124,58,237", a2 = "124,58,237", on = "255,255,255", ink = "250,245,255", pop = "55,37,83"},
	{id = "rose", name = "Rose", light = false, r = {14, 12, 10, 8},
		bg = "31,3,8", sheet = "39,12,17", tile = "47,21,25", ctl = "58,33,38", ctl2 = "74,51,55", a1 = "233,95,116", a2 = "233,95,116", on = "255,255,255", ink = "253,242,248", pop = "56,31,35"},
	{id = "crimson", name = "Crimson", light = false, r = {14, 12, 10, 8},
		bg = "12,4,4", sheet = "21,13,13", tile = "29,22,22", ctl = "41,34,34", ctl2 = "58,52,52", a1 = "185,28,28", a2 = "185,28,28", on = "255,255,255", ink = "254,242,242", pop = "39,32,32"},
	{id = "plant", name = "Plant", light = false, r = {14, 12, 10, 8},
		bg = "10,27,15", sheet = "19,35,23", tile = "27,43,32", ctl = "39,54,44", ctl2 = "57,70,61", a1 = "22,163,74", a2 = "22,163,74", on = "255,255,255", ink = "240,253,244", pop = "37,52,41"},
	{id = "emerald", name = "Emerald", light = false, r = {14, 12, 10, 8},
		bg = "1,20,17", sheet = "10,28,25", tile = "19,36,34", ctl = "31,48,46", ctl2 = "49,65,62", a1 = "5,150,105", a2 = "5,150,105", on = "255,255,255", ink = "236,253,245", pop = "29,46,43"},
	{id = "amber", name = "Amber", light = false, r = {14, 12, 10, 8},
		bg = "28,16,3", sheet = "36,24,12", tile = "44,33,21", ctl = "55,45,33", ctl2 = "71,61,51", a1 = "217,119,6", a2 = "245,158,11", on = "255,255,255", ink = "255,251,235", pop = "53,42,31"},
	{id = "monokai", name = "Monokai", light = false, r = {14, 12, 10, 8},
		bg = "25,22,34", sheet = "33,30,42", tile = "41,38,49", ctl = "53,50,61", ctl2 = "69,66,76", a1 = "252,152,103", a2 = "252,152,103", on = "14,14,16", ink = "252,252,250", pop = "50,48,58"},
	{id = "midnight", name = "Midnight", light = false, r = {14, 12, 10, 8},
		bg = "10,15,30", sheet = "19,23,38", tile = "27,32,46", ctl = "39,44,57", ctl2 = "57,61,73", a1 = "37,99,235", a2 = "37,99,235", on = "255,255,255", ink = "219,234,254", pop = "37,41,55"},
	{id = "tokyo", name = "Tokyo Night", light = false, r = {14, 12, 10, 8},
		bg = "26,27,38", sheet = "34,35,46", tile = "42,43,53", ctl = "53,54,64", ctl2 = "70,70,79", a1 = "122,162,247", a2 = "122,162,247", on = "14,14,16", ink = "192,202,245", pop = "51,52,62"},
	{id = "dracula", name = "Dracula", light = false, r = {14, 12, 10, 8},
		bg = "40,42,54", sheet = "48,49,61", tile = "55,57,68", ctl = "66,68,78", ctl2 = "81,82,92", a1 = "189,147,249", a2 = "189,147,249", on = "14,14,16", ink = "248,248,242", pop = "64,65,76"},
	{id = "nord", name = "Nord", light = false, r = {14, 12, 10, 8},
		bg = "46,52,64", sheet = "53,59,71", tile = "61,66,77", ctl = "71,76,87", ctl2 = "86,91,100", a1 = "136,192,208", a2 = "136,192,208", on = "14,14,16", ink = "236,239,244", pop = "69,74,85"},
	{id = "mocha", name = "Catppuccin", light = false, r = {14, 12, 10, 8},
		bg = "30,30,46", sheet = "38,38,53", tile = "46,46,61", ctl = "57,57,71", ctl2 = "73,73,86", a1 = "203,166,247", a2 = "203,166,247", on = "14,14,16", ink = "205,214,244", pop = "55,55,69"},
	{id = "gruv", name = "Gruvbox", light = false, r = {14, 12, 10, 8},
		bg = "40,40,40", sheet = "48,48,48", tile = "55,55,55", ctl = "66,66,66", ctl2 = "81,81,81", a1 = "250,189,47", a2 = "250,189,47", on = "14,14,16", ink = "235,219,178", pop = "64,64,64"},
	{id = "pine", name = "Rosé Pine", light = false, r = {14, 12, 10, 8},
		bg = "25,23,36", sheet = "33,31,44", tile = "41,39,51", ctl = "53,51,62", ctl2 = "69,67,78", a1 = "235,188,186", a2 = "235,188,186", on = "14,14,16", ink = "224,222,244", pop = "50,49,60"},
	{id = "hollow", name = "Hollow", light = false, r = {14, 12, 10, 8},
		bg = "13,10,16", sheet = "21,19,24", tile = "30,27,33", ctl = "42,39,45", ctl2 = "59,57,61", a1 = "255,140,40", a2 = "168,92,255", on = "14,14,16", ink = "250,238,226", pop = "40,37,42"},
}
return D

end
__F["IconNames"] = function(...)
local K = ...
return {
	"house", "search", "settings", "settings-2", "x", "minus", "plus", "maximize",
	"minimize", "maximize-2", "minimize-2", "chevron-right", "chevron-left", "chevron-down", "chevron-up", "chevrons-up-down",
	"chevrons-right", "chevrons-left", "check", "check-check", "ellipsis", "ellipsis-vertical", "grip-vertical", "grip",
	"arrow-right", "arrow-left", "arrow-up", "arrow-down", "arrow-up-right", "external-link", "copy", "clipboard",
	"clipboard-check", "trash-2", "pencil", "square-pen", "save", "folder", "folder-open", "folder-cog",
	"file", "file-text", "file-code", "download", "upload", "refresh-cw", "rotate-ccw", "undo-2",
	"redo-2", "history", "list", "list-filter", "layout-grid", "layout-dashboard", "panel-left", "panel-left-close",
	"panel-left-open", "panel-top", "menu", "app-window", "crosshair", "target", "eye", "eye-off",
	"globe", "user", "users", "user-round", "user-plus", "shield", "shield-check", "shield-alert",
	"swords", "sword", "zap", "flame", "sparkles", "wand-sparkles", "palette", "paintbrush",
	"brush", "sliders-horizontal", "sliders-vertical", "toggle-left", "toggle-right", "mouse-pointer-click", "mouse-pointer-2", "keyboard",
	"command", "type", "image", "video", "music", "volume-2", "volume-x", "bell",
	"bell-ring", "mail", "message-square", "hash", "at-sign", "link", "key-round", "key",
	"lock", "lock-open", "fingerprint", "badge-check", "award", "crown", "star", "heart",
	"bookmark", "flag", "map-pin", "map", "compass", "navigation", "rocket", "plane",
	"car", "gamepad-2", "dices", "puzzle", "box", "package", "boxes", "cpu",
	"memory-stick", "hard-drive", "server", "database", "wifi", "signal", "activity", "gauge",
	"timer", "clock", "calendar", "trending-up", "trending-down", "chart-line", "chart-column", "chart-pie",
	"chart-no-axes-column", "info", "circle-alert", "triangle-alert", "circle-check", "circle-x", "circle-help", "loader-circle",
	"bug", "terminal", "code", "braces", "wrench", "hammer", "power", "log-out",
	"log-in", "share-2", "send", "play", "pause", "square", "skip-forward", "sun",
	"moon", "monitor", "smartphone", "tablet", "laptop", "hand", "scan", "focus",
	"move", "scissors", "layers", "blend", "droplet", "pipette", "contrast", "circle-dot",
	"circle", "triangle", "hexagon", "gem", "diamond", "atom", "orbit", "infinity",
	"snowflake", "cloud", "cloud-rain", "wind", "leaf", "sprout", "tree-pine", "mountain",
	"waves", "bomb", "skull", "ghost", "bot", "brain", "lightbulb", "megaphone",
	"newspaper", "book-open", "languages", "accessibility", "shuffle", "repeat", "route", "door-open",
	"table", "columns-2", "scroll-text", "text-cursor-input", "footprints", "scaling", "ruler", "dot",
	"spline", "pointer", "wallet", "coins", "gift", "tag", "ticket", "store",
	"shopping-bag", "backpack", "graduation-cap", "cloud-download", "cloud-upload", "hourglass", "radar", "rss",
	"satellite", "shield-off", "smile", "thumbs-up", "user-check", "wand", "zoom-in", "zoom-out",
	"align-left", "align-center", "eraser", "fullscreen", "picture-in-picture-2", "square-dashed-mouse-pointer", "pin", "pin-off",
	"unplug", "plug", "battery-charging", "bluetooth", "cast", "webcam", "mic", "mic-off",
	"headphones", "speaker",
}

end
__F["Theme"] = function(...)
local K = ...
local Util = K.Util
local Data = K.ThemeData

local Theme = {}
Theme.list = {}
Theme.byId = {}
Theme.tokens = {}
Theme.radii = {14, 12, 10, 8}
Theme.changed = Util.Signal.new()
Theme.current = nil
Theme.accentOverride = nil

local bindings = setmetatable({}, {__mode = "k"})
local order = {}

local function build(d)
	local t = {
		id = d.id, name = d.name, light = d.light, r = d.r,
		bg = Util.rgb(d.bg), sheet = Util.rgb(d.sheet), tile = Util.rgb(d.tile),
		ctl = Util.rgb(d.ctl), ctl2 = Util.rgb(d.ctl2),
		a1 = Util.rgb(d.a1), a2 = Util.rgb(d.a2), on = Util.rgb(d.on),
		ink = Util.rgb(d.ink), pop = Util.rgb(d.pop),
	}
	return t
end

local function derive(t)
	t.sub = t.ink:Lerp(t.sheet, 0.42)
	t.mute = t.ink:Lerp(t.sheet, 0.62)
	t.faint = t.ink:Lerp(t.sheet, 0.8)
	t.line = t.ink:Lerp(t.sheet, 0.9)
	t.hover = t.ctl:Lerp(t.ink, 0.06)
	t.press = t.ctl:Lerp(t.ink, 0.12)
	t.tileHover = t.tile:Lerp(t.ink, 0.04)
	t.lock = t.ink:Lerp(t.sheet, 0.55)
	t.shadow = Color3.new(0, 0, 0)
	t.danger = t.light and Color3.fromRGB(196, 54, 54) or Color3.fromRGB(240, 104, 104)
	return t
end

for _, d in Data do
	local t = derive(build(d))
	Theme.list[#Theme.list + 1] = t
	Theme.byId[t.id] = t
end

function Theme.ids()
	local o = {}
	for _, t in Theme.list do o[#o + 1] = t.id end
	return o
end

function Theme.names()
	local o = {}
	for _, t in Theme.list do o[#o + 1] = t.name end
	return o
end

function Theme.resolve(spec)
	local tk = Theme.tokens
	local ty = type(spec)
	if ty == "string" then return tk[spec] end
	if ty == "function" then return spec(tk) end
	if ty == "table" then
		local base = tk[spec[1]]
		if spec[2] then return base:Lerp(tk[spec[2]], spec[3] or 0.5) end
		return base
	end
	return spec
end

function Theme.get(name)
	return Theme.tokens[name]
end

function Theme.bind(obj, map)
	local b = bindings[obj]
	if not b then
		b = {}
		bindings[obj] = b
		order[#order + 1] = obj
		obj.Destroying:Connect(function() bindings[obj] = nil end)
	end
	for prop, spec in map do
		b[prop] = spec
		obj[prop] = Theme.resolve(spec)
	end
	return obj
end

function Theme.unbind(obj, prop)
	local b = bindings[obj]
	if b then
		if prop then b[prop] = nil else bindings[obj] = nil end
	end
end

function Theme.set(id, instant)
	local d = Theme.byId[id]
	if not d then return false end
	local t = {}
	for k, v in d do t[k] = v end
	if Theme.accentOverride then
		t.a1 = Theme.accentOverride
		t.a2 = Theme.accentOverride
		local l = Util.luma(Theme.accentOverride)
		t.on = l > 0.58 and Color3.fromRGB(14, 14, 16) or Color3.new(1, 1, 1)
	end
	Theme.tokens = t
	Theme.current = id
	Theme.radii = d.r
	local live = {}
	for i = 1, #order do
		local o = order[i]
		local b = bindings[o]
		if b and o.Parent ~= nil then
			live[#live + 1] = o
			for prop, spec in b do
				local v = Theme.resolve(spec)
				if instant or not Theme.animate then
					o[prop] = v
				else
					Util.tween(o, 0.28, {[prop] = v}, Enum.EasingStyle.Quad)
				end
			end
		end
	end
	order = live
	Theme.changed:Fire(t, id)
	return true
end

function Theme.setAccent(color, instant)
	Theme.accentOverride = color
	Theme.set(Theme.current or "carbon", instant)
end

function Theme.clearAccent()
	Theme.setAccent(nil)
end

function Theme.register(def)
	local t = derive(build({
		id = def.id, name = def.name or def.id, light = def.light or false, r = def.r or {14, 12, 10, 8},
		bg = def.bg, sheet = def.sheet, tile = def.tile, ctl = def.ctl, ctl2 = def.ctl2,
		a1 = def.a1, a2 = def.a2 or def.a1, on = def.on, ink = def.ink, pop = def.pop or def.tile,
	}))
	if not Theme.byId[t.id] then Theme.list[#Theme.list + 1] = t end
	Theme.byId[t.id] = t
	return t
end

Theme.animate = true
Theme.strokes = false
Theme.gradients = true
local gradList = setmetatable({}, {__mode = "k"})
local strokeList = setmetatable({}, {__mode = "k"})

function Theme.gradient(obj, strength)
	strength = strength or 0.1
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(Color3.new(0, 0, 0), 0), Color3.new(1, 1, 1):Lerp(Color3.new(0, 0, 0), strength))
	g.Enabled = Theme.gradients
	g.Parent = obj
	gradList[g] = true
	return g
end

function Theme.setGradients(on)
	Theme.gradients = on
	for g in gradList do
		if g.Parent then g.Enabled = on end
	end
end

function Theme.stroke(obj, token, transparency, thickness)
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Thickness = thickness or 1
	st.Transparency = transparency or 0.9
	st.Enabled = Theme.strokes
	st.Parent = obj
	Theme.bind(st, {Color = token or "ink"})
	strokeList[st] = true
	return st
end

function Theme.setStrokes(on)
	Theme.strokes = on
	for st in strokeList do
		if st.Parent then st.Enabled = on end
	end
end
Theme.set("carbon", true)

return Theme

end
__F["Icons"] = function(...)
local K = ...
local Util = K.Util
local Theme = K.Theme
local Names = K.IconNames

local Icons = {}
Icons.sheet = ""
Icons.cell = 48
Icons.cols = 16
Icons.index = {}
for i, n in Names do Icons.index[n] = i end

local glyph = {
	x = "×", minus = "–", plus = "+", check = "✓", ["chevron-down"] = "⌄", ["chevron-up"] = "⌃",
	["chevron-right"] = "›", ["chevron-left"] = "‹", search = "⌕", ["circle-alert"] = "!", info = "i",
	["circle-check"] = "✓", ["circle-x"] = "×", ["triangle-alert"] = "!", lock = "•", maximize = "□", ["maximize-2"] = "□",
	["minimize-2"] = "–", ["circle-help"] = "?", ["arrow-right"] = "→", ["arrow-left"] = "←", ["arrow-up"] = "↑", ["arrow-down"] = "↓",
	ellipsis = "…", star = "★", heart = "♥", power = "⏻", ["log-out"] = "↪",
}

function Icons.setSheet(id, cell, cols)
	Icons.sheet = id or ""
	Icons.cell = cell or Icons.cell
	Icons.cols = cols or Icons.cols
	Icons.changed:Fire()
end

Icons.changed = Util.Signal.new()

function Icons.has(name)
	return Icons.index[name] ~= nil
end

function Icons.rect(name)
	local i = Icons.index[name] or Icons.index["circle"]
	local z = i - 1
	local c = Icons.cell
	return Vector2.new((z % Icons.cols) * c, math.floor(z / Icons.cols) * c), Vector2.new(c, c)
end

function Icons.apply(img, name)
	local off, size = Icons.rect(name)
	img.Image = Icons.sheet
	img.ImageRectOffset = off
	img.ImageRectSize = size
end

function Icons.create(parent, name, size, token, props)
	size = size or 16
	token = token or "ink"
	local holder
	if Icons.sheet ~= "" then
		holder = Util.new("ImageLabel", {Name = "Icon", Size = UDim2.fromOffset(size, size), ScaleType = Enum.ScaleType.Fit, Parent = parent})
		Icons.apply(holder, name)
		Theme.bind(holder, {ImageColor3 = token})
	else
		holder = Util.new("TextLabel", {Name = "Icon", Size = UDim2.fromOffset(size, size), Text = glyph[name] or "•", TextSize = math.floor(size * 0.95), FontFace = Util.font("SemiBold"), TextXAlignment = Enum.TextXAlignment.Center, Parent = parent})
		Theme.bind(holder, {TextColor3 = token})
	end
	if props then for k, v in props do holder[k] = v end end
	local conn
	conn = Icons.changed:Connect(function()
		if not holder.Parent then conn:Disconnect() return end
		if holder:IsA("ImageLabel") then Icons.apply(holder, name) end
	end)
	return holder
end

function Icons.set(holder, name)
	if holder:IsA("ImageLabel") then Icons.apply(holder, name) else holder.Text = glyph[name] or "•" end
end

function Icons.tint(holder, token)
	if holder:IsA("ImageLabel") then Theme.bind(holder, {ImageColor3 = token}) else Theme.bind(holder, {TextColor3 = token}) end
end

function Icons.fromUrl(url, file)
	file = file or "Kairo/icons.png"
	local req = request or http_request or (syn and syn.request)
	if not (req and writefile and getcustomasset) then return false end
	local ok = pcall(function()
		if makefolder and isfolder and not isfolder("Kairo") then makefolder("Kairo") end
		if not (isfile and isfile(file)) then
			local res = req({Url = url, Method = "GET"})
			if not res or res.StatusCode ~= 200 then error("download") end
			writefile(file, res.Body)
		end
		Icons.setSheet(getcustomasset(file))
	end)
	return ok
end

return Icons

end
__F["Sound"] = function(...)
local K = ...
local Util = K.Util

local Sound = {}
Sound.enabled = true
Sound.volume = 0.5
Sound.ids = {
	click = "rbxassetid://6895079853",
	hover = "rbxassetid://6895079980",
	toggle = "rbxassetid://6895079853",
	expand = "rbxassetid://6895079980",
	collapse = "rbxassetid://6895079980",
	open = "rbxassetid://6895079853",
	close = "rbxassetid://6895079853",
	notify = "rbxassetid://6895079853",
	success = "rbxassetid://6895079853",
	error = "rbxassetid://6895079853",
	slider = "",
	key = "rbxassetid://6895079853",
}
Sound.pitch = {click = 1, hover = 1.35, toggle = 1.12, expand = 1.2, collapse = 0.9, open = 0.95, close = 0.85, notify = 1.25, success = 1.3, error = 0.7, slider = 1.5, key = 1.1}
Sound.gain = {click = 0.5, hover = 0.18, toggle = 0.5, expand = 0.3, collapse = 0.25, open = 0.5, close = 0.4, notify = 0.6, success = 0.6, error = 0.6, slider = 0.15, key = 0.5}

local host
local pool = {}
local last = {}

local function ensureHost()
	if host and host.Parent then return host end
	host = Util.new("Folder", {Name = "KairoSounds", Parent = Util.gui()})
	return host
end

function Sound.set(name, id)
	Sound.ids[name] = id
end

function Sound.play(name, vol, pitch)
	if not Sound.enabled then return end
	local id = Sound.ids[name]
	if not id or id == "" then return end
	local now = os.clock()
	if last[name] and now - last[name] < 0.04 then return end
	last[name] = now
	local s = table.remove(pool)
	if not s then
		s = Instance.new("Sound")
		s.Parent = ensureHost()
		s.Ended:Connect(function() pool[#pool + 1] = s end)
	end
	s.SoundId = id
	s.Volume = (vol or Sound.gain[name] or 0.4) * Sound.volume * 2
	s.PlaybackSpeed = pitch or Sound.pitch[name] or 1
	s.TimePosition = 0
	s:Play()
end

return Sound

end
__F["Anim"] = function(...)
local K = ...
local Util = K.Util
local Theme = K.Theme

local Anim = {}
Anim.press = "squish"
Anim.speed = 1
Anim.styles = {"squish", "dip", "pop", "sink", "none"}

local function dur(t)
	return t / Anim.speed
end
Anim.dur = dur

local function scaleOf(obj)
	local s = obj:FindFirstChildOfClass("UIScale")
	if not s then
		s = Util.new("UIScale", {Scale = 1, Parent = obj})
	end
	return s
end
Anim.scaleOf = scaleOf

function Anim.hover(obj, restSpec, hoverSpec, prop)
	prop = prop or "BackgroundColor3"
	local on = false
	obj[prop] = Theme.resolve(restSpec)
	local function go(h)
		if on == h then return end
		on = h
		Util.tween(obj, dur(0.14), {[prop] = Theme.resolve(h and hoverSpec or restSpec)}, Enum.EasingStyle.Quad)
	end
	local conn
	conn = Theme.changed:Connect(function()
		if not obj.Parent then conn:Disconnect() return end
		obj[prop] = Theme.resolve(on and hoverSpec or restSpec)
	end)
	obj.MouseEnter:Connect(function() go(true) end)
	obj.MouseLeave:Connect(function() go(false) end)
	return go
end

function Anim.pressable(btn, opts)
	opts = opts or {}
	local style = opts.style or Anim.press
	local target = opts.target or btn
	local depth = opts.depth or 0.96
	local sc
	local function down()
		if style == "none" then return end
		if style == "squish" or style == "pop" then
			sc = sc or scaleOf(target)
			Util.tween(sc, dur(0.09), {Scale = depth}, Enum.EasingStyle.Quad)
		elseif style == "sink" then
			Util.tween(target, dur(0.08), {Position = target.Position + UDim2.fromOffset(0, 1)}, Enum.EasingStyle.Quad)
		elseif style == "dip" and opts.dim then
			Util.tween(target, dur(0.08), {BackgroundTransparency = 0.25}, Enum.EasingStyle.Quad)
		end
	end
	local rest = target.Position
	local function up()
		if style == "none" then return end
		if style == "squish" then
			sc = sc or scaleOf(target)
			Util.tween(sc, dur(0.22), {Scale = 1}, Enum.EasingStyle.Back)
		elseif style == "pop" then
			sc = sc or scaleOf(target)
			sc.Scale = 1.06
			Util.tween(sc, dur(0.24), {Scale = 1}, Enum.EasingStyle.Back)
		elseif style == "sink" then
			Util.tween(target, dur(0.1), {Position = rest}, Enum.EasingStyle.Quad)
		elseif style == "dip" and opts.dim then
			Util.tween(target, dur(0.12), {BackgroundTransparency = 0}, Enum.EasingStyle.Quad)
		end
	end
	local held = false
	btn.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			held = true
			down()
		end
	end)
	btn.InputEnded:Connect(function(i)
		if held and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			held = false
			up()
		end
	end)
	btn.MouseLeave:Connect(function()
		if held then
			held = false
			up()
		end
	end)
end

function Anim.fadeIn(obj, props, t, delay)
	local goal = {}
	for k, v in props do
		goal[k] = obj[k]
		obj[k] = v
	end
	if delay and delay > 0 then
		task.delay(delay, function()
			if obj.Parent then Util.tween(obj, dur(t or 0.25), goal) end
		end)
	else
		Util.tween(obj, dur(t or 0.25), goal)
	end
end

function Anim.spring(obj, prop, to, t)
	return Util.tween(obj, dur(t or 0.3), {[prop] = to}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

function Anim.setPress(name)
	Anim.press = name
end

return Anim

end
__F["Notify"] = function(...)
local K = ...
local Util = K.Util
local Theme = K.Theme
local Icons = K.Icons
local Sound = K.Sound
local Anim = K.Anim

local UIS = Util.UserInputService

local Notify = {}
Notify.position = "TR"
Notify.style = "card"
Notify.size = "big"
Notify.speed = "fast"
Notify.duration = 4
Notify.max = 4
Notify.dismiss = {tap = true, swipe = true}
Notify.hoverPause = true
Notify.sound = "notify"
Notify.tint = true
Notify.animation = "slip"
Notify.enabled = true

local TYPE_ICON = {success = "check", info = "info", warn = "triangle-alert", error = "x", join = "users"}
local DIM = {
	big = {w = 360, h = 72, icon = 40, title = 14, sub = 12, pad = 14},
	compact = {w = 300, h = 56, icon = 30, title = 13, sub = 11, pad = 12},
}
local ANIM_T = {slip = 0.24, drift = 0.36, snap = 0.32, blur = 0.52}

local gui, holder, list
local active = {}
local live = {}
Notify.history = {}

local function ensure()
	if gui and gui.Parent then return end
	gui = Util.new("ScreenGui", {Name = "KairoNotify", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = Util.gui()})
	Util.protect(gui)
	holder = Util.new("Frame", {Name = "Holder", BackgroundTransparency = 1, Size = UDim2.new(1, -24, 1, -24), Position = UDim2.fromOffset(12, 12), Parent = gui})
	list = Util.list(holder, 8)
	Notify.layout()
end

function Notify.layout()
	if not holder then return end
	local p = Notify.position
	local right = p:sub(2, 2) == "R"
	local bottom = p:sub(1, 1) == "B"
	list.HorizontalAlignment = right and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
	list.VerticalAlignment = bottom and Enum.VerticalAlignment.Bottom or Enum.VerticalAlignment.Top
	list.SortOrder = bottom and Enum.SortOrder.LayoutOrder or Enum.SortOrder.LayoutOrder
end

function Notify.setPosition(p)
	Notify.position = p
	Notify.layout()
end

local function remove(item, instant)
	if item.gone then return end
	item.gone = true
	for i, v in active do
		if v == item then table.remove(active, i) break end
	end
	if item.maid then item.maid:Clean() end
	local card, wrap = item.card, item.wrap
	if instant or not wrap.Parent then
		wrap:Destroy()
		return
	end
	local right = Notify.position:sub(2, 2) == "R"
	local dx = (right and 1 or -1) * (item.w + 24)
	local t = Anim.dur(0.2)
	Util.tween(card, t, {Position = UDim2.new(0, dx, 0, 0), GroupTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(t * 0.6, function()
		if wrap.Parent then Util.tween(wrap, Anim.dur(0.16), {Size = UDim2.fromOffset(item.w, 0)}, Enum.EasingStyle.Quad) end
	end)
	task.delay(t + 0.2, function() wrap:Destroy() end)
	if item.onClose then Util.safe(item.onClose) end
end

local function buildIcon(parent, kind, d)
	local tile = Util.new("Frame", {Name = "IconTile", Size = UDim2.fromOffset(d.icon, d.icon), Position = UDim2.new(0, d.pad, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = parent})
	Util.corner(tile, Theme.radii[3])
	local accent = Notify.tint and (kind == "success" or kind == "info")
	Theme.bind(tile, {BackgroundColor3 = accent and {"ctl2", "a1", 0.35} or "ctl2"})
	local ic = Icons.create(tile, TYPE_ICON[kind] or "info", math.floor(d.icon * 0.5), "ink")
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)
	return tile
end

local function buildCard(item, cfg, d)
	local card = Util.new("Frame", {Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, item.bodyH), Parent = item.card})
	local textX = d.pad * 2 + d.icon
	buildIcon(card, cfg.Type or "info", d)
	local title = Util.text(card, {Name = "Title", Text = cfg.Title or "", TextSize = d.title, Weight = "SemiBold", Size = UDim2.new(1, -textX - d.pad - 40, 0, d.title + 4), Position = UDim2.new(0, textX, 0.5, cfg.Text and cfg.Text ~= "" and -(d.title + 2) or -(d.title + 4) / 2)})
	Theme.bind(title, {TextColor3 = "ink"})
	if cfg.Text and cfg.Text ~= "" then
		local sub = Util.text(card, {Name = "Sub", Text = cfg.Text, TextSize = d.sub, Weight = "Medium", Size = UDim2.new(1, -textX - d.pad, 0, d.sub + 4), Position = UDim2.new(0, textX, 0.5, 2)})
		Theme.bind(sub, {TextColor3 = "sub"})
	end
	local stamp = Util.text(card, {Name = "Stamp", Text = "now", TextSize = 10, Weight = "Medium", Size = UDim2.fromOffset(40, 12), Position = UDim2.new(1, -d.pad - 40, 0, d.pad - 2), TextXAlignment = Enum.TextXAlignment.Right})
	Theme.bind(stamp, {TextColor3 = "mute"})
	local bar = Util.new("Frame", {Name = "Grip", Size = UDim2.fromOffset(28, 3), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Parent = card})
	Util.pill(bar)
	Theme.bind(bar, {BackgroundColor3 = "faint"})
	return title
end

local function buildPill(item, cfg, d)
	local card = item.card
	buildIcon(card, cfg.Type or "info", {icon = 28, pad = 8})
	local label = Util.text(card, {Name = "Title", Text = cfg.Title or "", TextSize = 13, Weight = "SemiBold", Size = UDim2.new(1, -52, 1, 0), Position = UDim2.fromOffset(44, 0)})
	Theme.bind(label, {TextColor3 = "ink"})
end

local function buildIsland(item, cfg)
	local card = item.card
	local ic = Icons.create(card, TYPE_ICON[cfg.Type or "success"] or "check", 14, "ink")
	ic.AnchorPoint = Vector2.new(0, 0.5)
	ic.Position = UDim2.new(0, 22, 0.5, 0)
	local label = Util.text(card, {Name = "Title", Text = cfg.Title or "", TextSize = 13, Weight = "SemiBold", Size = UDim2.new(1, -52, 1, 0), Position = UDim2.fromOffset(44, 0)})
	Theme.bind(label, {TextColor3 = "ink"})
end

local function buildActions(item, cfg, d)
	local row = Util.new("Frame", {Name = "Actions", BackgroundTransparency = 1, Size = UDim2.new(1, -d.pad * 2, 0, 30), Position = UDim2.new(0, d.pad, 1, -d.pad - 30), Parent = item.card})
	local n = #cfg.Actions
	for i, a in cfg.Actions do
		local primary = a.Primary or i == n
		local b = Util.new("TextButton", {Name = "Action" .. i, Size = UDim2.new(1 / n, -4, 1, 0), Position = UDim2.new((i - 1) / n, i == 1 and 0 or 4, 0, 0), Text = a.Text or a.Name or "OK", TextSize = 12, BackgroundTransparency = 0, FontFace = Util.font("SemiBold"), Parent = row})
		Util.corner(b, Theme.radii[4])
		Theme.bind(b, {BackgroundColor3 = primary and "a1" or "ctl", TextColor3 = primary and "on" or "sub"})
		Anim.pressable(b)
		b.Activated:Connect(function()
			Sound.play("click")
			if a.Callback then Util.safe(a.Callback) end
			remove(item)
		end)
	end
end

function Notify.new(cfg)
	if type(cfg) == "string" then cfg = {Title = cfg} end
	local hist = Notify.history
	hist[#hist + 1] = {Title = cfg.Title, Text = cfg.Text, Type = cfg.Type}
	if #hist > 30 then table.remove(hist, 1) end
	if not Notify.enabled then return end
	ensure()
	local style = cfg.Style or Notify.style
	local d = DIM[cfg.Size or Notify.size] or DIM.big
	local vw = Util.viewport().X
	local w, h = d.w, d.h
	if style == "pill" then w, h = 0, 44
	elseif style == "island" then w, h = 180, 40 end
	local hasActions = cfg.Actions and #cfg.Actions > 0
	if hasActions then h = d.h + 46 end
	if style == "pill" then
		w = math.clamp(Util.measure(cfg.Title or "", 13).X + 84, 150, 360)
	end
	w = math.min(w, vw - 24)
	local item = {w = w, maid = Util.Maid.new(), onClose = cfg.OnClose}
	local wrap = Util.new("Frame", {Name = "Item", BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h), LayoutOrder = Util.uid(), ClipsDescendants = false, Parent = holder})
	if Notify.position:sub(1, 1) == "B" then wrap.LayoutOrder = -Util.uid() end
	local card = Util.new("CanvasGroup", {Name = "Card", Size = UDim2.fromOffset(w, h), Parent = wrap})
	Util.corner(card, style == "card" and Theme.radii[2] + 2 or (style == "pill" and 22 or 20))
	Theme.bind(card, {BackgroundColor3 = "pop"})
	item.card, item.wrap = card, wrap
	item.bodyH = d.h
	local stroke = Theme.stroke(card, "ink", 0.92)
	Theme.bind(stroke, {Color = "ink"})
	if style == "pill" then buildPill(item, cfg, d)
	elseif style == "island" then buildIsland(item, cfg)
	else buildCard(item, cfg, d) end
	if hasActions then buildActions(item, cfg, d) end

	local hit = Util.new("TextButton", {Name = "Hit", Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 0, Parent = card})
	if hasActions then hit.Size = UDim2.new(1, 0, 0, d.h) end
	active[#active + 1] = item
	while #active > Notify.max do remove(active[1], false) end

	local right = Notify.position:sub(2, 2) == "R"
	local kind = Notify.animation
	local t = Anim.dur(ANIM_T[kind] * (Notify.speed == "fast" and 0.5 or 1))
	card.GroupTransparency = 1
	if kind == "slip" then
		card.Position = UDim2.fromOffset((right and 1 or -1) * (w + 24), 0)
		Util.tween(card, t, {Position = UDim2.fromOffset(0, 0), GroupTransparency = 0}, Enum.EasingStyle.Back)
	elseif kind == "drift" then
		card.Position = UDim2.fromOffset(0, Notify.position:sub(1, 1) == "B" and 18 or -18)
		Util.tween(card, t, {Position = UDim2.fromOffset(0, 0), GroupTransparency = 0}, Enum.EasingStyle.Quint)
	elseif kind == "snap" then
		local sc = Util.new("UIScale", {Scale = 0.9, Parent = card})
		Util.tween(sc, t, {Scale = 1}, Enum.EasingStyle.Back)
		Util.tween(card, t, {GroupTransparency = 0}, Enum.EasingStyle.Quad)
	else
		Util.tween(card, t, {GroupTransparency = 0}, Enum.EasingStyle.Sine)
	end
	if cfg.Sound ~= false then Sound.play(cfg.SoundName or Notify.sound) end

	local hovering, dragging = false, false
	local remaining = cfg.Duration or Notify.duration
	local dismissOn = Util.merge(Notify.dismiss, cfg.Dismiss)
	local hasTimer = remaining > 0 and not hasActions
	hit.MouseEnter:Connect(function() hovering = true end)
	hit.MouseLeave:Connect(function() hovering = false end)
	hit.Activated:Connect(function()
		if dismissOn.tap and not dragging then
			if cfg.Callback then Util.safe(cfg.Callback) end
			remove(item)
		end
	end)
	if dismissOn.swipe then
		local startX, base
		item.maid:Add(hit.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				startX = i.Position.X
				base = card.Position.X.Offset
				dragging = false
			end
		end))
		item.maid:Add(UIS.InputChanged:Connect(function(i)
			if startX and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				local dx = i.Position.X - startX
				if math.abs(dx) > 6 then dragging = true end
				if dragging then card.Position = UDim2.fromOffset(base + dx, 0) end
			end
		end))
		item.maid:Add(UIS.InputEnded:Connect(function(i)
			if startX and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
				local dx = card.Position.X.Offset
				startX = nil
				if dragging and math.abs(dx) > w * 0.3 then
					remove(item)
				else
					Util.tween(card, Anim.dur(0.2), {Position = UDim2.fromOffset(0, 0)}, Enum.EasingStyle.Quint)
				end
				task.delay(0.05, function() dragging = false end)
			end
		end))
	end
	if hasTimer then
		task.spawn(function()
			while remaining > 0 and not item.gone do
				task.wait(0.1)
				if not (Notify.hoverPause and hovering) and not dragging then remaining -= 0.1 end
			end
			remove(item)
		end)
	end
	live[#live + 1] = item
	local handle = {}
	function handle.Close() remove(item) end
	function handle.Update(c)
		local t1 = card:FindFirstChild("Title")
		if t1 and c.Title then t1.Text = c.Title end
		local s1 = card:FindFirstChild("Sub")
		if s1 and c.Text then s1.Text = c.Text end
	end
	return handle
end

function Notify.clear()
	for i = #active, 1, -1 do remove(active[i], false) end
end

function Notify.success(t, s) return Notify.new({Title = t, Text = s, Type = "success"}) end
function Notify.info(t, s) return Notify.new({Title = t, Text = s, Type = "info"}) end
function Notify.warn(t, s) return Notify.new({Title = t, Text = s, Type = "warn"}) end
function Notify.error(t, s) return Notify.new({Title = t, Text = s, Type = "error"}) end

function Notify.destroy()
	if gui then gui:Destroy() gui = nil end
	active = {}
end

return Notify

end
__F["Pop"] = function(...)
local K = ...
local Util = K.Util
local Theme = K.Theme
local Icons = K.Icons
local Anim = K.Anim
local Sound = K.Sound

local Pop = {}

local function state(win)
	if not win._pop then win._pop = {} end
	return win._pop
end

function Pop.scale(win)
	return win.fitScale or 1
end

function Pop.toLocal(win, absPos)
	local base = win.popLayer.AbsolutePosition
	local s = Pop.scale(win)
	return Vector2.new((absPos.X - base.X) / s, (absPos.Y - base.Y) / s)
end

function Pop.bounds(win)
	local s = Pop.scale(win)
	local a = win.popLayer.AbsoluteSize
	return Vector2.new(a.X / s, a.Y / s)
end

function Pop.place(win, popup, anchor, w, h, opts)
	opts = opts or {}
	local s = Pop.scale(win)
	local ap = Pop.toLocal(win, anchor.AbsolutePosition)
	local asz = Vector2.new(anchor.AbsoluteSize.X / s, anchor.AbsoluteSize.Y / s)
	local vb = Pop.bounds(win)
	local gap = opts.gap or 4
	local x = opts.alignRight and (ap.X + asz.X - w) or (opts.centerX and (ap.X + asz.X / 2 - w / 2) or ap.X)
	local y = ap.Y + asz.Y + gap
	if y + h > vb.Y - 6 then
		local above = ap.Y - gap - h
		if above >= 6 then y = above else y = math.max(6, vb.Y - 6 - h) end
	end
	x = Util.clamp(x, 6, math.max(6, vb.X - w - 6))
	popup.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
	return x, y
end

function Pop.close(win, instant)
	local st = state(win)
	local cur = st.current
	if not cur then return end
	st.current = nil
	if cur.onClose then Util.safe(cur.onClose) end
	if cur.catcher then cur.catcher:Destroy() end
	local f = cur.frame
	if not f or not f.Parent then return end
	if instant then f:Destroy() return end
	local sc = f:FindFirstChildOfClass("UIScale")
	if sc then Util.tween(sc, Anim.dur(0.1), {Scale = 0.96}, Enum.EasingStyle.Quad) end
	if f:IsA("CanvasGroup") then Util.tween(f, Anim.dur(0.1), {GroupTransparency = 1}, Enum.EasingStyle.Quad) end
	task.delay(Anim.dur(0.12), function() if f.Parent then f:Destroy() end end)
end

function Pop.open(win, frame, opts)
	opts = opts or {}
	Pop.close(win, true)
	local st = state(win)
	local catcher = Util.new("TextButton", {Name = "Catcher", Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 1, Parent = win.popLayer})
	if opts.dim then
		catcher.BackgroundTransparency = 1
		catcher.BackgroundColor3 = Color3.new(0, 0, 0)
		catcher.BackgroundTransparency = 1
		Util.tween(catcher, Anim.dur(0.18), {BackgroundTransparency = opts.dim}, Enum.EasingStyle.Quad)
	end
	catcher.Activated:Connect(function() if not opts.modal then Pop.close(win) end end)
	local rc = Util.new("TextButton", {Name = "RightCatcher", Visible = false, Parent = catcher})
	frame.ZIndex = 2
	frame.Parent = win.popLayer
	for _, d in frame:GetDescendants() do
		if d:IsA("GuiObject") then d.ZIndex = math.max(d.ZIndex, 2) end
	end
	st.current = {frame = frame, catcher = catcher, onClose = opts.onClose, key = opts.key}
	local sc = frame:FindFirstChildOfClass("UIScale") or Util.new("UIScale", {Scale = 1, Parent = frame})
	sc.Scale = 0.96
	Util.tween(sc, Anim.dur(0.16), {Scale = 1}, Enum.EasingStyle.Back)
	if frame:IsA("CanvasGroup") then
		frame.GroupTransparency = 1
		Util.tween(frame, Anim.dur(0.12), {GroupTransparency = 0}, Enum.EasingStyle.Quad)
	end
	rc:Destroy()
	return st.current
end

function Pop.isOpen(win, key)
	local c = state(win).current
	return c ~= nil and (key == nil or c.key == key)
end

function Pop.panel(win, w, h, name)
	local f = Util.new("CanvasGroup", {Name = name or "Popup", Size = UDim2.fromOffset(w, h)})
	f.AnchorPoint = Vector2.new(0, 0)
	Util.corner(f, Theme.radii[3] + 2)
	Theme.bind(f, {BackgroundColor3 = "pop"})
	local st = Theme.stroke(f, "ink", 0.9)
	Theme.bind(st, {Color = "ink"})
	return f
end

function Pop.menu(win, anchor, items, opts)
	opts = opts or {}
	local w = opts.width or 160
	local rowH = 32
	local h = #items * rowH + 8
	local f = Pop.panel(win, w, h, "Menu")
	local lay = Util.list(f, 0)
	Util.pad(f, 4, 4, 4, 4)
	for i, it in items do
		local b = Util.new("TextButton", {Name = it.Name, Size = UDim2.new(1, 0, 0, rowH), BackgroundTransparency = 1, Text = "", LayoutOrder = i, Parent = f})
		Util.corner(b, Theme.radii[4] + 1)
		local ic = Icons.create(b, it.Icon or "dot", 14, it.Danger and "ink" or "sub")
		ic.Position = UDim2.fromOffset(10, 9)
		local lab = Util.text(b, {Text = it.Name, TextSize = 12, Weight = "Medium", Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(34, 0)})
		Theme.bind(lab, {TextColor3 = "ink"})
		Theme.bind(b, {BackgroundColor3 = "ctl2"})
		b.MouseEnter:Connect(function() Util.tween(b, 0.1, {BackgroundTransparency = 0.5}) Sound.play("hover") end)
		b.MouseLeave:Connect(function() Util.tween(b, 0.12, {BackgroundTransparency = 1}) end)
		b.Activated:Connect(function()
			Sound.play("click")
			Pop.close(win)
			if it.Callback then Util.safe(it.Callback) end
		end)
	end
	local _ = lay
	Pop.place(win, f, anchor, w, h, {alignRight = true, gap = 6})
	Pop.open(win, f, {key = opts.key or "menu"})
	return f
end

function Pop.tip(win, anchor, text, title)
	local w = 220
	local lines = math.max(1, math.ceil(Util.measure(text, 12, "Medium", w - 24).Y / 15))
	local h = 24 + lines * 15 + (title and 20 or 0)
	local f = Pop.panel(win, w, h, "Tip")
	local y = 12
	if title then
		local t = Util.text(f, {Text = title, TextSize = 12, Weight = "SemiBold", Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 10)})
		Theme.bind(t, {TextColor3 = "ink"})
		y = 30
	end
	local body = Util.text(f, {Text = text, TextSize = 12, Weight = "Medium", TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Size = UDim2.new(1, -24, 0, lines * 15), Position = UDim2.fromOffset(12, y), TextYAlignment = Enum.TextYAlignment.Top})
	Theme.bind(body, {TextColor3 = "sub"})
	Pop.place(win, f, anchor, w, h, {centerX = true, gap = 6})
	local c = Pop.open(win, f, {key = "tip"})
	c.catcher.Active = false
	c.catcher.Visible = true
	return f
end

function Pop.dialog(win, cfg)
	local w = cfg.Width or 280
	local f = Util.new("CanvasGroup", {Name = "Dialog", Size = UDim2.fromOffset(w, 0), AutomaticSize = Enum.AutomaticSize.Y})
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	Util.corner(f, Theme.radii[2])
	Theme.bind(f, {BackgroundColor3 = "pop"})
	local st = Theme.stroke(f, "ink", 0.9)
	Theme.bind(st, {Color = "ink"})
	Util.pad(f, 16, 16, 16, 14)
	local lay = Util.list(f, 6)
	local t = Util.text(f, {Text = cfg.Title or "", TextSize = 14, Weight = "SemiBold", Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1})
	Theme.bind(t, {TextColor3 = "ink"})
	if cfg.Text then
		local lines = math.max(1, math.ceil(Util.measure(cfg.Text, 12, "Medium", w - 32).Y / 15))
		local b = Util.text(f, {Text = cfg.Text, TextSize = 12, Weight = "Medium", TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Size = UDim2.new(1, 0, 0, lines * 15), TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2})
		Theme.bind(b, {TextColor3 = "sub"})
	end
	local row = Util.new("Frame", {Name = "Buttons", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 3, Parent = f})
	local sp = Util.new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 6), LayoutOrder = 2, Parent = f})
	local _ = sp
	local n = #cfg.Buttons
	for i, bt in cfg.Buttons do
		local primary = bt.Primary
		local b = Util.new("TextButton", {Name = bt.Text, BackgroundTransparency = 0, Size = UDim2.new(1 / n, i == n and 0 or -4, 1, 0), Position = UDim2.new((i - 1) / n, i == 1 and 0 or 0, 0, 0), Text = bt.Text, TextSize = 12, FontFace = Util.font("SemiBold"), Parent = row})
		if i > 1 then b.Position = UDim2.new((i - 1) / n, 4, 0, 0) end
		Util.corner(b, Theme.radii[3])
		Theme.bind(b, {BackgroundColor3 = primary and "a1" or "ctl", TextColor3 = primary and "on" or "ink"})
		Anim.pressable(b)
		b.Activated:Connect(function()
			Sound.play("click")
			Pop.close(win)
			if bt.Callback then Util.safe(bt.Callback) end
		end)
	end
	local _l = lay
	f.Position = UDim2.fromScale(0.5, 0.5)
	Pop.open(win, f, {dim = 0.55, modal = cfg.Modal, key = "dialog"})
	return f
end

return Pop

end
__F["Lighting"] = function(...)
local K = ...
local Util = K.Util
local Theme = K.Theme

local Lighting = {}
Lighting.enabled = true
Lighting.intensity = 0.5
Lighting.corner = "random"
Lighting.shadow = true
Lighting.shadowStrength = 0.5
Lighting.corners = {"TL", "TR", "BR", "BL"}

local ROT = {TL = 45, TR = 135, BR = 225, BL = 315}
local rng = Random.new()
local attached = setmetatable({}, {__mode = "k"})

local function paintLight(win)
	local st = attached[win]
	if not st then return end
	local f = st.light
	f.Visible = Lighting.enabled
	local corner = Lighting.corner == "random" and st.corner or Lighting.corner
	st.g.Rotation = ROT[corner] or 45
	local a = 1 - 0.16 * Lighting.intensity
	st.g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1)})
end

local function paintShadow(win)
	local st = attached[win]
	if not st then return end
	for i, l in st.layers do
		l.Visible = Lighting.shadow
		l.BackgroundTransparency = 1 - (0.05 + 0.02 * (#st.layers - i)) * Lighting.shadowStrength * 2
	end
end

function Lighting.attach(win)
	if attached[win] then return end
	local st = {corner = Lighting.corners[rng:NextInteger(1, 4)], layers = {}}
	local light = Util.new("Frame", {Name = "Light", Size = UDim2.fromScale(1, 1), ZIndex = 40, Active = false, Parent = win.root})
	Theme.bind(light, {BackgroundColor3 = "a1"})
	st.light = light
	st.g = Util.new("UIGradient", {Parent = light})
	Util.corner(light, Theme.radii[1])
	for i = 1, 6 do
		local pad = i * 5
		local l = Util.new("Frame", {Name = "Layer" .. i, Size = UDim2.new(1, pad * 2, 1, pad * 2), Position = UDim2.fromOffset(-pad, -pad + 6), ZIndex = 0, Parent = win.shadow})
		Util.corner(l, Theme.radii[1] + pad)
		l.BackgroundColor3 = Color3.new(0, 0, 0)
		st.layers[i] = l
	end
	attached[win] = st
	paintLight(win)
	paintShadow(win)
	win.OnVisible:Connect(function(on)
		if on and Lighting.corner == "random" then
			st.corner = Lighting.corners[rng:NextInteger(1, 4)]
			paintLight(win)
		end
	end)
	win.maid:Add(Theme.changed:Connect(function() paintLight(win) end))
end

function Lighting.refresh()
	for win in attached do
		if win.gui and win.gui.Parent then
			paintLight(win)
			paintShadow(win)
		end
	end
end

function Lighting.set(opts)
	for k, v in opts do Lighting[k] = v end
	Lighting.refresh()
end

return Lighting

end
__F["Window"] = function(...)
local K = ...
local Util = K.Util
local Theme = K.Theme
local Icons = K.Icons
local Anim = K.Anim
local Sound = K.Sound
local Pop = K.Pop

local UIS = Util.UserInputService
local Players = Util.Players

local Window = {}
Window.__index = Window
Window.list = {}

local HEADER = 44
local RAIL_W = 132
local RAIL_C = 36
local GAP = 8

local Tab = {}
Tab.__index = Tab
Window.Tab = Tab

local function mkLabel(parent, props, token)
	local l = Util.text(parent, props)
	Theme.bind(l, {TextColor3 = token or "ink"})
	return l
end

function Window.new(cfg)
	cfg = Util.merge({
		Name = "Kairo", Sub = "", Version = "", Logo = "K", Theme = "carbon",
		Size = Vector2.new(600, 384), MinSize = Vector2.new(560, 360), MaxSize = Vector2.new(720, 456),
		Key = Enum.KeyCode.RightShift, Rail = "full", Indicator = false, Draggable = true,
	}, cfg)
	if cfg.Theme then Theme.set(cfg.Theme, true) end
	local self = setmetatable({}, Window)
	self.cfg = cfg
	self.maid = Util.Maid.new()
	self.tabs = {}
	self.groups = {}
	self.groupOrder = {}
	self.flags = {}
	self.options = {}
	self.registry = {}
	self.hbuttons = {}
	self.visible = true
	self.minimized = false
	self.expanded = false
	self.baseSize = cfg.Size
	self.size = cfg.Size
	self.railMode = cfg.Rail
	self.railHover = false
	self.fitScale = 1
	self.OnUnload = Util.Signal.new()
	self.OnTab = Util.Signal.new()
	self.OnVisible = Util.Signal.new()

	local gui = Util.new("ScreenGui", {
		Name = "Kairo" .. Util.uid(), ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 500,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = Util.gui(),
	})
	Util.protect(gui)
	self.gui = gui

	local fit = Util.new("Frame", {Name = "Fit", BackgroundTransparency = 1, Size = UDim2.fromOffset(self.size.X, self.size.Y), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = gui})
	self.frame = fit
	self.fitUI = Util.new("UIScale", {Parent = fit})

	local shadow = Util.new("Frame", {Name = "Shadow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = fit})
	self.shadow = shadow

	local root = Util.new("CanvasGroup", {Name = "Root", Size = UDim2.fromScale(1, 1), Parent = fit})
	Util.corner(root, Theme.radii[1])
	Theme.bind(root, {BackgroundColor3 = "bg"})
	self.root = root
	self.animUI = Util.new("UIScale", {Scale = 0.94, Parent = root})
	root.GroupTransparency = 1

	self.popLayer = Util.new("Frame", {Name = "Pop", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = gui})
	self.popUI = Util.new("UIScale", {Parent = self.popLayer})
	self.popLayer.AnchorPoint = Vector2.new(0, 0)

	self:_header()
	self:_rail()
	self:_sheet()
	self:_input()
	self:_fit()

	self.maid:Add(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() self:_fit() end))
	Window.list[#Window.list + 1] = self
	if K.Lighting then K.Lighting.attach(self) end

	Util.tween(self.animUI, Anim.dur(0.32), {Scale = 1}, Enum.EasingStyle.Back)
	Util.tween(root, Anim.dur(0.22), {GroupTransparency = 0}, Enum.EasingStyle.Quad)
	Sound.play("open")
	return self
end

function Window:_fit()
	local vp = Util.viewport()
	local s = math.min(1, (vp.X - 16) / self.size.X, (vp.Y - 16) / self.size.Y)
	s = math.max(0.5, s)
	self.fitScale = s
	self.fitUI.Scale = s
	self.popUI.Scale = s
	self.popLayer.Size = UDim2.fromScale(1 / s, 1 / s)
	self:_relayoutHeader()
end

function Window:_header()
	local cfg = self.cfg
	local root = self.root
	local header = Util.new("Frame", {Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, HEADER), Parent = root})
	self.header = header
	local dragBtn = Util.new("TextButton", {Name = "Drag", Size = UDim2.fromScale(1, 1), Text = "", Parent = header})
	self.dragBtn = dragBtn

	local mark = Util.new("Frame", {Name = "Mark", Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(12, 10), Parent = header})
	Util.corner(mark, 8)
	Theme.bind(mark, {BackgroundColor3 = "ink"})
	self.mark = mark
	if cfg.Logo and cfg.Logo:find("rbxassetid") then
		mark.BackgroundTransparency = 1
		Util.new("ImageLabel", {Size = UDim2.fromScale(1, 1), Image = cfg.Logo, Parent = mark})
	else
		local l = Util.text(mark, {Text = cfg.Logo or "K", TextSize = 14, Weight = "Bold", TextXAlignment = Enum.TextXAlignment.Center})
		Theme.bind(l, {TextColor3 = "bg"})
	end

	local nameL = mkLabel(header, {Name = "Name", Text = cfg.Name, TextSize = 13, Weight = "SemiBold", Size = UDim2.fromOffset(110, 16), Position = UDim2.fromOffset(46, 7)})
	local nameW = Util.measure(cfg.Name, 13).X
	self.nameLabel = nameL
	if cfg.Version ~= "" then
		local v = mkLabel(header, {Name = "Version", Text = cfg.Version, TextSize = 10, Weight = "SemiBold", Size = UDim2.fromOffset(40, 16), Position = UDim2.fromOffset(46 + math.ceil(nameW) + 6, 7)}, "mute")
		self.versionLabel = v
	end
	mkLabel(header, {Name = "Sub", Text = cfg.Sub, TextSize = 11, Weight = "Medium", Size = UDim2.fromOffset(130, 14), Position = UDim2.fromOffset(46, 23)}, "sub")

	local dots = Util.new("Frame", {Name = "Dots", BackgroundTransparency = 1, Size = UDim2.fromOffset(14, 6), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Parent = header})
	for r = 0, 1 do
		for c = 0, 3 do
			local d = Util.new("Frame", {Size = UDim2.fromOffset(2, 2), Position = UDim2.fromOffset(c * 4, r * 4), Parent = dots})
			Theme.bind(d, {BackgroundColor3 = "faint"})
		end
	end

	local search = Util.new("TextButton", {Name = "Search", Size = UDim2.fromOffset(184, 28), Text = "", BackgroundTransparency = 0, Parent = header})
	Util.corner(search, 8)
	Theme.bind(search, {BackgroundColor3 = "tile"})
	local sic = Icons.create(search, "search", 14, "mute")
	sic.Position = UDim2.fromOffset(10, 7)
	self.searchIcon = sic
	self.searchText = mkLabel(search, {Text = "Search", TextSize = 12, Weight = "Medium", Size = UDim2.new(1, -36, 1, 0), Position = UDim2.fromOffset(32, 0)}, "mute")
	Anim.hover(search, "tile", "ctl")
	Anim.pressable(search, {depth = 0.985})
	search.Activated:Connect(function()
		Sound.play("click")
		self:OpenSearch()
	end)
	self.search = search

	self:HeaderButton({Name = "Notifications", Icon = "bell", Callback = function(btn) self:_bell(btn) end, Order = 10})
	self:HeaderButton({Name = "Sidebar", Icon = "panel-left-close", Callback = function() self:ToggleRail() end, Order = 20})
	self.railBtn = self.hbuttons[#self.hbuttons]
	self:HeaderButton({Name = "Window", Icon = "app-window", Callback = function(btn) self:_menu(btn) end, Order = 90})
end

function Window:HeaderButton(cfg)
	local b = Util.new("TextButton", {Name = cfg.Name or "Btn", Size = UDim2.fromOffset(28, 28), Text = "", BackgroundTransparency = 1, Parent = self.header})
	Util.corner(b, 8)
	Theme.bind(b, {BackgroundColor3 = "ctl"})
	local ic = Icons.create(b, cfg.Icon or "dot", 15, "sub")
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)
	b.MouseEnter:Connect(function()
		Util.tween(b, 0.12, {BackgroundTransparency = 0.35})
		Icons.tint(ic, "ink")
		Sound.play("hover")
	end)
	b.MouseLeave:Connect(function()
		Util.tween(b, 0.14, {BackgroundTransparency = 1})
		Icons.tint(ic, "sub")
	end)
	Anim.pressable(b, {depth = 0.92})
	b.Activated:Connect(function()
		Sound.play("click")
		if cfg.Callback then Util.safe(cfg.Callback, b) end
	end)
	local item = {btn = b, icon = ic, order = cfg.Order or 50, name = cfg.Name}
	self.hbuttons[#self.hbuttons + 1] = item
	table.sort(self.hbuttons, function(a, c) return a.order < c.order end)
	if self.railBtn then self.railBtn = nil end
	for _, h in self.hbuttons do if h.name == "Sidebar" then self.railBtn = h end end
	self:_relayoutHeader()
	return item
end

function Window:_relayoutHeader()
	if not self.header then return end
	local w = self.size.X
	local n = #self.hbuttons
	local x = w - 12
	for i = n, 1, -1 do
		local b = self.hbuttons[i].btn
		x -= 28
		b.Position = UDim2.fromOffset(x, 8)
		x -= 2
	end
	local startBtn = x + 2
	local reserve = 46 + math.ceil(Util.measure(self.cfg.Name, 13).X) + (self.cfg.Version ~= "" and 52 or 8)
	reserve = math.max(reserve, 46 + 130)
	local avail = startBtn - 16 - (reserve + 12)
	local sw = math.clamp(avail, 28, 184)
	local icon = sw < 110
	if icon then sw = 28 end
	self.searchIsIcon = icon
	self.search.Size = UDim2.fromOffset(sw, 28)
	self.search.Position = UDim2.fromOffset(startBtn - 16 - sw, 8)
	self.searchText.Visible = not icon
	self.searchIcon.Position = icon and UDim2.fromOffset(7, 7) or UDim2.fromOffset(10, 7)
	self.search.BackgroundTransparency = icon and 1 or 0
end

function Window:_menu(anchor)
	Sound.play("click")
	Pop.menu(self, anchor, {
		{Name = "Minimize", Icon = "minus", Callback = function() self:Minimize() end},
		{Name = self.expanded and "Restore" or "Expand", Icon = self.expanded and "minimize-2" or "maximize-2", Callback = function() self:SetExpanded(not self.expanded) end},
		{Name = "Unload", Icon = "power", Callback = function() self:ConfirmUnload() end},
	}, {width = 164})
end

function Window:_bell(anchor)
	local hist = K.Notify.history
	local rows = math.max(1, math.min(#hist, 5))
	local w, h = 260, 44 + rows * 44
	local f = Pop.panel(self, w, h, "Inbox")
	local t = mkLabel(f, {Text = "Notifications", TextSize = 12, Weight = "SemiBold", Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 4)})
	local _ = t
	if #hist == 0 then
		mkLabel(f, {Text = "Nothing yet", TextSize = 12, Weight = "Medium", Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 40)}, "mute")
	end
	for i = 1, rows do
		local e = hist[#hist - i + 1]
		if e then
			local row = Util.new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 36 + (i - 1) * 44), Parent = f})
			local ic = Icons.create(row, ({success = "check", info = "info", warn = "triangle-alert", error = "x", join = "users"})[e.Type or "info"] or "info", 14, "sub")
			ic.Position = UDim2.fromOffset(6, 13)
			mkLabel(row, {Text = e.Title or "", TextSize = 12, Weight = "SemiBold", Size = UDim2.new(1, -36, 0, 16), Position = UDim2.fromOffset(30, 4)})
			mkLabel(row, {Text = e.Text or "", TextSize = 11, Weight = "Medium", Size = UDim2.new(1, -36, 0, 14), Position = UDim2.fromOffset(30, 21)}, "sub")
		end
	end
	Pop.place(self, f, anchor, w, h, {alignRight = true, gap = 6})
	Pop.open(self, f, {key = "inbox"})
end

function Window:_rail()
	local root = self.root
	local rail = Util.new("Frame", {Name = "Rail", BackgroundTransparency = 1, Size = UDim2.new(0, RAIL_W, 1, -(HEADER + GAP)), Position = UDim2.fromOffset(GAP, HEADER), ZIndex = 5, Parent = root})
	self.rail = rail
	local bg = Util.new("Frame", {Name = "Bg", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = rail})
	Util.corner(bg, Theme.radii[2])
	Theme.bind(bg, {BackgroundColor3 = "pop"})
	self.railBg = bg
	local scroll = Util.new("ScrollingFrame", {Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -42), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 6, Parent = rail})
	Util.list(scroll, 2)
	self.tabScroll = scroll

	local user = Util.new("TextButton", {Name = "User", Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 1, -36), Text = "", BackgroundTransparency = 1, ZIndex = 6, Parent = rail})
	Util.corner(user, Theme.radii[3])
	Theme.bind(user, {BackgroundColor3 = "tile"})
	self.userRow = user
	local lp = Players.LocalPlayer
	local u = self.cfg.User or {}
	local name = u.Name or (lp and lp.DisplayName) or "Player"
	local role = u.Role or "Member"
	local av = Util.new("Frame", {Name = "Avatar", Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(6, 6), ZIndex = 7, Parent = user})
	Util.pill(av)
	Theme.bind(av, {BackgroundColor3 = "ctl2"})
	av.ClipsDescendants = true
	local img = Util.new("ImageLabel", {Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = av})
	Util.pill(img)
	local ok, thumb = pcall(function() return Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48) end)
	if u.Avatar then img.Image = u.Avatar elseif ok and thumb then img.Image = thumb end
	self.userName = mkLabel(user, {Text = name, TextSize = 12, Weight = "SemiBold", Size = UDim2.new(1, -66, 0, 14), Position = UDim2.fromOffset(36, 4), ZIndex = 7})
	self.userRole = mkLabel(user, {Text = role, TextSize = 10, Weight = "Medium", Size = UDim2.new(1, -66, 0, 12), Position = UDim2.fromOffset(36, 19), ZIndex = 7}, "sub")
	local pw = Icons.create(user, "power", 13, "mute")
	pw.Position = UDim2.new(1, -24, 0.5, -6.5)
	pw.ZIndex = 7
	self.userPower = pw
	user.MouseEnter:Connect(function() Util.tween(user, 0.12, {BackgroundTransparency = 0}) Icons.tint(pw, "ink") end)
	user.MouseLeave:Connect(function() Util.tween(user, 0.14, {BackgroundTransparency = 1}) Icons.tint(pw, "mute") end)
	user.Activated:Connect(function() Sound.play("click") self:ConfirmUnload() end)

	if self.cfg.Indicator then
		self.indicator = Util.new("Frame", {Name = "Indicator", Size = UDim2.fromOffset(3, 14), ZIndex = 8, Parent = rail})
		Util.pill(self.indicator)
		Theme.bind(self.indicator, {BackgroundColor3 = "ink"})
	end
end

function Window:_railWidth(expandedNow)
	if self.railMode == "full" or expandedNow then return RAIL_W end
	return RAIL_C
end

function Window:_applyRail(instant)
	local collapsed = self.railMode == "icons"
	local w = collapsed and RAIL_C or RAIL_W
	local sx = GAP + w + GAP
	local t = instant and 0 or Anim.dur(0.26)
	self.railWidth = w
	local function go(o, props)
		if t == 0 then for k, v in props do o[k] = v end else Util.tween(o, t, props, Enum.EasingStyle.Quint) end
	end
	if not self.railHover then go(self.rail, {Size = UDim2.new(0, w, 1, -(HEADER + GAP))}) end
	go(self.sheet, {Position = UDim2.fromOffset(sx, HEADER), Size = UDim2.new(1, -(sx + GAP), 1, -(HEADER + GAP))})
	self:_labels(not collapsed, instant)
	if self.railBtn then Icons.set(self.railBtn.icon, collapsed and "panel-left-open" or "panel-left-close") end
end

function Window:_labels(show, instant)
	local t = instant and 0 or Anim.dur(0.18)
	local function fade(o, v)
		local prop = o:IsA("ImageLabel") and "ImageTransparency" or "TextTransparency"
		if t == 0 then o[prop] = v else Util.tween(o, t, {[prop] = v}) end
	end
	for _, tab in self.tabs do
		fade(tab.label, show and 0 or 1)
		if tab.lockIcon then fade(tab.lockIcon, show and 0 or 1) end
	end
	for _, g in self.groups do
		fade(g.label, show and 0 or 1)
		fade(g.chev, show and 0 or 1)
		g.dash.Visible = not show
	end
	fade(self.userName, show and 0 or 1)
	fade(self.userRole, show and 0 or 1)
	fade(self.userPower, show and 0 or 1)
end

function Window:SetRail(mode, instant)
	if mode == self.railMode then return end
	self.railMode = mode
	self.railHover = false
	self.railBg.BackgroundTransparency = 1
	self:_applyRail(instant)
	Sound.play(mode == "icons" and "collapse" or "expand")
end

function Window:ToggleRail()
	self:SetRail(self.railMode == "full" and "icons" or "full")
end

function Window:_hoverRail(on)
	if self.railMode ~= "icons" or self.railHover == on then return end
	self.railHover = on
	local t = Anim.dur(on and 0.24 or 0.2)
	Util.tween(self.rail, t, {Size = UDim2.new(0, on and RAIL_W or RAIL_C, 1, -(HEADER + GAP))}, Enum.EasingStyle.Quint)
	Util.tween(self.railBg, t, {BackgroundTransparency = on and 0 or 1}, Enum.EasingStyle.Quad)
	self:_labels(on, false)
	Sound.play(on and "expand" or "collapse")
end

function Window:_sheet()
	local sx = GAP + RAIL_W + GAP
	local sheet = Util.new("Frame", {Name = "Sheet", Size = UDim2.new(1, -(sx + GAP), 1, -(HEADER + GAP)), Position = UDim2.fromOffset(sx, HEADER), Parent = self.root})
	Util.corner(sheet, Theme.radii[2])
	Theme.bind(sheet, {BackgroundColor3 = "sheet"})
	self.sheet = sheet
	self:_applyRail(true)
end

function Window:_input()
	local maid = self.maid
	local dragging, start, origin = false, nil, nil
	maid:Add(self.dragBtn.InputBegan:Connect(function(i)
		if not self.cfg.Draggable then return end
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			start = Vector2.new(i.Position.X, i.Position.Y)
			origin = self.frame.Position
		end
	end))
	maid:Add(UIS.InputChanged:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				local d = Vector2.new(i.Position.X, i.Position.Y) - start
				self.frame.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y)
			end
			local m = Util.mouse()
			local rail = self.rail
			if self.railMode == "icons" and self.visible then
				local p, s = rail.AbsolutePosition, rail.AbsoluteSize
				local sc = self.fitScale
				local w = (self.railHover and RAIL_W or RAIL_C) * sc + 2
				local inside = m.X >= p.X - 2 and m.X <= p.X + w and m.Y >= p.Y and m.Y <= p.Y + s.Y
				if inside and not self.railHover then
					self._rt = nil
					self:_hoverRail(true)
				elseif not inside and self.railHover then
					local token = {}
					self._rt = token
					task.delay(0.12, function()
						if self._rt == token then self:_hoverRail(false) end
					end)
				end
			end
		end
	end))
	maid:Add(UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				dragging = false
				self:_clampPosition()
			end
		end
	end))
	maid:Add(UIS.InputBegan:Connect(function(i, gp)
		if gp then return end
		if self.cfg.Key and i.KeyCode == self.cfg.Key and not UIS:GetFocusedTextBox() then
			self:Toggle()
		elseif self.visible and not UIS:GetFocusedTextBox() and (i.KeyCode == Enum.KeyCode.Slash or (i.KeyCode == Enum.KeyCode.K and (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)))) then
			self:OpenSearch()
		end
	end))
end

function Window:_clampPosition()
	local vp = Util.viewport()
	local f = self.frame
	local p, s = f.AbsolutePosition, f.AbsoluteSize
	local dx, dy = 0, 0
	local margin = 24
	if p.X + s.X < margin + 80 then dx = margin + 80 - (p.X + s.X) end
	if p.X > vp.X - margin - 80 then dx = vp.X - margin - 80 - p.X end
	if p.Y < 0 then dy = -p.Y end
	if p.Y > vp.Y - 60 then dy = vp.Y - 60 - p.Y end
	if dx ~= 0 or dy ~= 0 then
		Util.tween(f, Anim.dur(0.2), {Position = f.Position + UDim2.fromOffset(dx, dy)}, Enum.EasingStyle.Quint)
	end
end

function Window:SetSize(v, animate)
	v = Vector2.new(math.clamp(v.X, self.cfg.MinSize.X, self.cfg.MaxSize.X), math.clamp(v.Y, self.cfg.MinSize.Y, self.cfg.MaxSize.Y))
	self.size = v
	if animate then
		Util.tween(self.frame, Anim.dur(0.3), {Size = UDim2.fromOffset(v.X, v.Y)}, Enum.EasingStyle.Quint)
	else
		self.frame.Size = UDim2.fromOffset(v.X, v.Y)
	end
	self:_fit()
end

function Window:SetExpanded(on)
	self.expanded = on
	self:SetSize(on and self.cfg.MaxSize or self.baseSize, true)
end

local function groupFor(self, name)
	if not name then return nil end
	local g = self.groups[name]
	if g then return g end
	local idx = #self.groupOrder + 1
	self.groupOrder[idx] = name
	local f = Util.new("TextButton", {Name = "Group_" .. name, Size = UDim2.new(1, 0, 0, 26), Text = "", BackgroundTransparency = 1, LayoutOrder = idx * 1000, ZIndex = 6, Parent = self.tabScroll})
	local lab = mkLabel(f, {Text = name:upper(), TextSize = 10, Weight = "SemiBold", Size = UDim2.new(1, -36, 1, 0), Position = UDim2.fromOffset(12, 2), ZIndex = 7}, "mute")
	lab.AnchorPoint = Vector2.new(0, 0)
	local chev = Icons.create(f, "chevron-down", 10, "mute")
	chev.Position = UDim2.new(1, -22, 0.5, -4)
	chev.ZIndex = 7
	local dash = Util.new("Frame", {Size = UDim2.fromOffset(12, 1), Position = UDim2.new(0.5, -6, 0.5, 2), Visible = false, ZIndex = 7, Parent = f})
	Theme.bind(dash, {BackgroundColor3 = "faint"})
	g = {name = name, frame = f, label = lab, chev = chev, dash = dash, tabs = {}, open = true, index = idx}
	f.Activated:Connect(function()
		if self.railMode == "icons" and not self.railHover then return end
		g.open = not g.open
		Sound.play("click")
		Util.tween(chev, 0.18, {Rotation = g.open and 0 or -90})
		for _, t in g.tabs do t.button.Visible = g.open and not t.hidden end
	end)
	self.groups[name] = g
	return g
end

function Window:Tab(cfg)
	cfg = Util.merge({Name = "Tab", Icon = "circle", Columns = 2}, cfg)
	local tab = setmetatable({win = self, cfg = cfg, name = cfg.Name, sections = {}, locked = false}, Tab)
	local g = groupFor(self, cfg.Group)
	local gi = g and g.index or 0
	tab.group = g
	local order = gi * 1000 + (g and #g.tabs or #self.tabs) + 1
	if not g then order = #self.tabs + 1 end

	local btn = Util.new("TextButton", {Name = "Tab_" .. cfg.Name, Size = UDim2.new(1, 0, 0, 30), Text = "", BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 6, Parent = self.tabScroll})
	Util.corner(btn, Theme.radii[3])
	Theme.bind(btn, {BackgroundColor3 = "ctl"})
	local ic = Icons.create(btn, cfg.Icon, 16, "sub")
	ic.Position = UDim2.fromOffset(10, 7)
	ic.ZIndex = 7
	local label = mkLabel(btn, {Text = cfg.Name, TextSize = 13, Weight = "Medium", Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(36, 0), ZIndex = 7}, "sub")
	tab.button, tab.icon, tab.label = btn, ic, label
	if self.railMode == "icons" then label.TextTransparency = 1 end
	btn.MouseEnter:Connect(function()
		tab.hover = true
		if self.current ~= tab then Util.tween(btn, 0.12, {BackgroundTransparency = 0.55}) end
		Sound.play("hover")
	end)
	btn.MouseLeave:Connect(function()
		tab.hover = false
		if self.current ~= tab then Util.tween(btn, 0.16, {BackgroundTransparency = 1}) end
	end)
	Anim.pressable(btn, {depth = 0.97})
	btn.Activated:Connect(function()
		Sound.play("click")
		tab:Select()
	end)

	local page = Util.new("CanvasGroup", {Name = "Page_" .. cfg.Name, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Visible = false, Parent = self.sheet})
	tab.page = page
	Util.pad(page, 12, 12, 12, 0)
	self:_pageHeader(tab)
	local body
	if cfg.Raw then
		body = Util.new("ScrollingFrame", {Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -48), Position = UDim2.fromOffset(0, 48), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = page})
		tab.body = body
	else
		body = Util.new("ScrollingFrame", {Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -48), Position = UDim2.fromOffset(0, 48), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = page})
		Theme.bind(body, {ScrollBarImageColor3 = "ctl2"})
		body.ScrollBarImageTransparency = 0.2
		Util.pad(body, 0, 0, 0, 12)
		tab.body = body
		tab.cols = {}
		local n = cfg.Columns
		local w = cfg.Weights or {}
		local total, acc = 0, 0
		for c = 1, n do total += w[c] or 1 end
		for c = 1, n do
			local frac = (w[c] or 1) / total
			local col = Util.new("Frame", {Name = "Col" .. c, BackgroundTransparency = 1, Size = UDim2.new(frac, c == n and (n == 1 and 0 or -4) or -4, 0, 0), Position = UDim2.new(acc, c == 1 and 0 or 4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = body})
			acc += frac
			Util.list(col, 8)
			tab.cols[c] = col
		end
	end

	self.tabs[#self.tabs + 1] = tab
	if g then g.tabs[#g.tabs + 1] = tab end
	tab.index = #self.tabs
	self:Register({Name = cfg.Name, Kind = "Tab", Tab = tab, Icon = cfg.Icon, Keywords = cfg.Keywords, Run = function() tab:Select() end})
	if not self.current then tab:Select(true) end
	if cfg.Locked then tab:SetLocked(true, cfg.LockReason) end
	return tab
end

function Window:_pageHeader(tab)
	local cfg = tab.cfg
	local h = Util.new("Frame", {Name = "PageHeader", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = tab.page})
	tab.header = h
	tab.title = mkLabel(h, {Text = cfg.Title or cfg.Name, TextSize = 16, Weight = "SemiBold", Size = UDim2.new(1, -140, 0, 20), Position = UDim2.fromOffset(0, 0)})
	tab.subtitle = mkLabel(h, {Text = cfg.Description or "", TextSize = 12, Weight = "Medium", Size = UDim2.new(1, -140, 0, 16), Position = UDim2.fromOffset(0, 21)}, "sub")
	local tools = Util.new("Frame", {Name = "Tools", BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Parent = h})
	Util.list(tools, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	tab.tools = tools
	tab.toolOrder = 0
end

function Tab:Select(instant)
	local win = self.win
	if win.current == self then return end
	if self.locked and self.cfg.LockHard then return end
	local prev = win.current
	win.current = self
	for _, t in win.tabs do
		local on = t == self
		Util.tween(t.button, instant and 0 or 0.16, {BackgroundTransparency = on and 0 or 1}, Enum.EasingStyle.Quad)
		Icons.tint(t.icon, on and "ink" or "sub")
		Theme.bind(t.label, {TextColor3 = on and "ink" or "sub"})
		t.label.FontFace = Util.font(on and "SemiBold" or "Medium")
	end
	if win.indicator then
		local y = self.button.AbsolutePosition.Y - win.rail.AbsolutePosition.Y + 8
		Util.tween(win.indicator, 0.2, {Position = UDim2.fromOffset(-6, y)}, Enum.EasingStyle.Quint)
	end
	if prev and not instant then
		local pg = prev.page
		Util.tween(pg, Anim.dur(0.1), {GroupTransparency = 1}, Enum.EasingStyle.Quad)
		task.delay(Anim.dur(0.1), function()
			if win.current ~= prev then pg.Visible = false end
		end)
		local np = self.page
		np.Visible = true
		np.GroupTransparency = 1
		np.Position = UDim2.fromOffset(0, 6)
		task.delay(Anim.dur(0.06), function()
			Util.tween(np, Anim.dur(0.22), {GroupTransparency = 0, Position = UDim2.fromOffset(0, 0)}, Enum.EasingStyle.Quint)
		end)
	else
		self.page.Visible = true
		self.page.GroupTransparency = 0
	end
	if self.body then self.body.CanvasPosition = Vector2.new() end
	win.OnTab:Fire(self)
end

function Tab:SetTitle(t, d)
	self.title.Text = t
	if d then self.subtitle.Text = d end
end

function Tab:SetLocked(on, reason)
	self.locked = on
	if on then
		if not self.lockIcon then
			local li = Icons.create(self.button, "lock", 12, "mute")
			li.Position = UDim2.new(1, -22, 0.5, -6)
			li.ZIndex = 7
			self.lockIcon = li
		end
		self.lockIcon.Visible = true
		self.label.TextTransparency = self.win.railMode == "icons" and 1 or 0.35
		self.icon.ImageTransparency = 0.45
		if self.icon:IsA("TextLabel") then self.icon.TextTransparency = 0.45 end
		if K.Lock then self.lockCover = K.Lock.cover(self.page, {Reason = reason or self.cfg.LockReason or "Premium", Effect = self.win.lockEffect, Win = self.win, Top = 48}) end
	else
		if self.lockIcon then self.lockIcon.Visible = false end
		self.label.TextTransparency = 0
		self.icon.ImageTransparency = 0
		if self.icon:IsA("TextLabel") then self.icon.TextTransparency = 0 end
		if self.lockCover then self.lockCover:Destroy() self.lockCover = nil end
	end
end

function Tab:Segmented(cfg)
	return K.Elements.headerSegmented(self, cfg)
end

function Tab:IconButton(cfg)
	return K.Elements.headerIcon(self, cfg)
end

function Tab:Section(cfg)
	return K.Elements.section(self, cfg)
end

function Window:SelectTab(name)
	for _, t in self.tabs do
		if t.cfg.Name == name or t.name == name then t:Select() return t end
	end
end

function Window:Register(e)
	e.Win = self
	self.registry[#self.registry + 1] = e
	return e
end

function Window:OpenSearch()
	if K.Search then K.Search.open(self) end
end

function Window:Notify(cfg)
	return K.Notify.new(cfg)
end

function Window:SetVisible(on)
	if self.visible == on or self.minimized then return end
	self.visible = on
	if on then
		self.frame.Visible = true
		Util.tween(self.animUI, Anim.dur(0.3), {Scale = 1}, Enum.EasingStyle.Back)
		Util.tween(self.root, Anim.dur(0.2), {GroupTransparency = 0}, Enum.EasingStyle.Quad)
	else
		Pop.close(self, true)
		Util.tween(self.animUI, Anim.dur(0.18), {Scale = 0.94}, Enum.EasingStyle.Quad)
		Util.tween(self.root, Anim.dur(0.16), {GroupTransparency = 1}, Enum.EasingStyle.Quad)
		task.delay(Anim.dur(0.18), function()
			if not self.visible and self.frame.Parent then self.frame.Visible = false end
		end)
	end
	Sound.play(on and "open" or "close")
	self.OnVisible:Fire(on)
end

function Window:Toggle()
	if self.minimized then self:Restore() else self:SetVisible(not self.visible) end
end

function Window:Minimize()
	if self.minimized then return end
	self.minimized = true
	self.visible = false
	Pop.close(self, true)
	Util.tween(self.animUI, Anim.dur(0.2), {Scale = 0.9}, Enum.EasingStyle.Quad)
	Util.tween(self.root, Anim.dur(0.16), {GroupTransparency = 1}, Enum.EasingStyle.Quad)
	task.delay(Anim.dur(0.2), function()
		if self.minimized then self.frame.Visible = false end
	end)
	self:_chip(true)
	Sound.play("collapse")
end

function Window:Restore()
	if not self.minimized then return end
	self.minimized = false
	self.visible = true
	self.frame.Visible = true
	self:_chip(false)
	Util.tween(self.animUI, Anim.dur(0.3), {Scale = 1}, Enum.EasingStyle.Back)
	Util.tween(self.root, Anim.dur(0.2), {GroupTransparency = 0}, Enum.EasingStyle.Quad)
	Sound.play("expand")
end

function Window:_chip(show)
	if not self.chip then
		local w = math.ceil(Util.measure(self.cfg.Name, 12).X) + 80
		local chip = Util.new("TextButton", {Name = "Chip", Size = UDim2.fromOffset(w, 36), Text = "", BackgroundTransparency = 0, AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(16, 16), Visible = false, Parent = self.gui})
		Util.pill(chip)
		Theme.bind(chip, {BackgroundColor3 = "bg"})
		local st = Theme.stroke(chip, "ink", 0.88)
		Theme.bind(st, {Color = "ink"})
		local mk = Util.new("Frame", {Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(6, 6), Parent = chip})
		Util.corner(mk, 8)
		Theme.bind(mk, {BackgroundColor3 = "ink"})
		local l = Util.text(mk, {Text = self.cfg.Logo:find("rbxassetid") and "K" or self.cfg.Logo, TextSize = 13, Weight = "Bold", TextXAlignment = Enum.TextXAlignment.Center})
		Theme.bind(l, {TextColor3 = "bg"})
		mkLabel(chip, {Text = self.cfg.Name, TextSize = 12, Weight = "SemiBold", Size = UDim2.new(1, -76, 1, 0), Position = UDim2.fromOffset(38, 0)})
		local ex = Icons.create(chip, "maximize-2", 13, "sub")
		ex.Position = UDim2.new(1, -26, 0.5, -6.5)
		Anim.pressable(chip, {depth = 0.95})
		local dragging, moved, start, origin = false, false, nil, nil
		chip.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging, moved = true, false
				start = Vector2.new(i.Position.X, i.Position.Y)
				origin = chip.Position
			end
		end)
		self.maid:Add(UIS.InputChanged:Connect(function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				local d = Vector2.new(i.Position.X, i.Position.Y) - start
				if d.Magnitude > 5 then moved = true end
				if moved then chip.Position = UDim2.fromOffset(origin.X.Offset + d.X, origin.Y.Offset + d.Y) end
			end
		end))
		self.maid:Add(UIS.InputEnded:Connect(function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
				dragging = false
				if moved then
					local vp = Util.viewport()
					local p = chip.AbsolutePosition
					local sz = chip.AbsoluteSize
					local x = p.X + sz.X / 2 < vp.X / 2 and 12 or vp.X - sz.X - 12
					local y = math.clamp(p.Y, 12, vp.Y - sz.Y - 12)
					Util.tween(chip, Anim.dur(0.28), {Position = UDim2.fromOffset(x, y)}, Enum.EasingStyle.Back)
				end
			end
		end))
		chip.Activated:Connect(function()
			if not moved then self:Restore() end
		end)
		self.chip = chip
	end
	local chip = self.chip
	if show then
		chip.Visible = true
		local sc = chip:FindFirstChildOfClass("UIScale") or Util.new("UIScale", {Parent = chip})
		sc.Scale = 0.7
		Util.tween(sc, Anim.dur(0.3), {Scale = 1}, Enum.EasingStyle.Back)
	else
		chip.Visible = false
	end
end

function Window:ConfirmUnload()
	Pop.dialog(self, {
		Title = "Unload " .. self.cfg.Name .. "?",
		Text = "The hub closes and every feature stops running.",
		Buttons = {
			{Text = "Cancel"},
			{Text = "Unload", Primary = true, Callback = function() self:Destroy() end},
		},
	})
end

function Window:Destroy()
	if self.destroyed then return end
	self.destroyed = true
	self.OnUnload:Fire()
	for i, w in Window.list do if w == self then table.remove(Window.list, i) break end end
	Util.tween(self.animUI, Anim.dur(0.2), {Scale = 0.92}, Enum.EasingStyle.Quad)
	Util.tween(self.root, Anim.dur(0.18), {GroupTransparency = 1}, Enum.EasingStyle.Quad)
	task.delay(Anim.dur(0.22), function()
		self.maid:Clean()
		self.gui:Destroy()
	end)
end

Window.Unload = Window.Destroy

return Window

end
__F["Elements"] = function(...)
local K = ...
local Util = K.Util
local Theme = K.Theme
local Icons = K.Icons
local Anim = K.Anim
local Sound = K.Sound
local Pop = K.Pop


local Elements = {}
Elements.types = {}
Elements.H = 34
Elements.C = 24

local Section = {}
Section.__index = function(self, k)
	local v = rawget(Section, k)
	if v ~= nil then return v end
	local t = Elements.types[k]
	if t then
		return function(s, cfg) return Elements.make(s, k, t, cfg) end
	end
	return nil
end
Elements.Section = Section

local Elem = {}
Elem.__index = Elem
Elements.Elem = Elem

function Elements.section(tab, cfg)
	cfg = type(cfg) == "string" and {Name = cfg} or (cfg or {})
	local col = tab.cols and tab.cols[cfg.Column or 1] or tab.body
	local wrap = Util.new("Frame", {Name = "Section_" .. (cfg.Name or ""), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = #tab.sections + 1, Parent = col})
	Util.list(wrap, 4)
	local sec = setmetatable({tab = tab, win = tab.win, cfg = cfg, wrap = wrap, n = 0, elems = {}}, Section)
	if cfg.Name and cfg.Name ~= "" then
		local head = Util.new("Frame", {Name = "Head", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0, Parent = wrap})
		local t = Util.text(head, {Text = cfg.Name, TextSize = 12, Weight = "SemiBold", Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -8, 1, 0)})
		Theme.bind(t, {TextColor3 = "sub"})
		sec.head = head
		sec.title = t
	end
	local tile = Util.new("Frame", {Name = "Tile", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = wrap})
	Util.corner(tile, Theme.radii[3] + 2)
	Theme.bind(tile, {BackgroundColor3 = "tile"})
	Theme.stroke(tile, "ink", 0.93)
	Util.list(tile, 0)
	sec.tile = tile
	tab.sections[#tab.sections + 1] = sec
	if cfg.Mode then sec.wrap.Visible = (tab.mode == nil or tab.mode == cfg.Mode) end
	return sec
end

function Section:SetVisible(v)
	self.wrap.Visible = v
end

function Section:SetName(n)
	if self.title then self.title.Text = n end
end

function Elements.flash(row)
	local f = Util.new("Frame", {Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20, Parent = row})
	Util.corner(f, Theme.radii[3])
	Theme.bind(f, {BackgroundColor3 = "ink"})
	task.spawn(function()
		for _ = 1, 2 do
			Util.tween(f, 0.18, {BackgroundTransparency = 0.82}, Enum.EasingStyle.Sine)
			task.wait(0.22)
			Util.tween(f, 0.3, {BackgroundTransparency = 1}, Enum.EasingStyle.Sine)
			task.wait(0.34)
		end
		f:Destroy()
	end)
end

function Elements.ctlFrame(parent, props)
	props.Parent = parent
	local f = Util.new("Frame", props)
	Util.corner(f, Theme.radii[4] - 1)
	Theme.bind(f, {BackgroundColor3 = "ctl"})
	Theme.gradient(f, 0.12)
	return f
end

function Elements.hoverCtl(btn, target, rest, over)
	rest = rest or "ctl"
	over = over or "hover"
	local on = false
	target = target or btn
	local conn
	conn = Theme.changed:Connect(function()
		if not target.Parent then conn:Disconnect() return end
		target.BackgroundColor3 = Theme.resolve(on and over or rest)
	end)
	btn.MouseEnter:Connect(function()
		on = true
		Util.tween(target, Anim.dur(0.12), {BackgroundColor3 = Theme.resolve(over)}, Enum.EasingStyle.Quad)
	end)
	btn.MouseLeave:Connect(function()
		on = false
		Util.tween(target, Anim.dur(0.14), {BackgroundColor3 = Theme.resolve(rest)}, Enum.EasingStyle.Quad)
	end)
end

function Elements.newRow(sec, cfg, height)
	sec.n += 1
	local row = Util.new("Frame", {Name = cfg.Name or "Row", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height or Elements.H), LayoutOrder = sec.n, Parent = sec.tile})
	local left = Util.new("Frame", {Name = "Left", BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.fromOffset(12, 0), Parent = row})
	Util.list(left, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local label
	if cfg.Name and not cfg.NoLabel then
		label = Util.text(left, {Name = "Label", Text = cfg.Name, TextSize = 13, Weight = "Medium", Size = UDim2.new(0, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None})
		Theme.bind(label, {TextColor3 = "ink"})
	end
	local right = Util.new("Frame", {Name = "Right", BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, Elements.C), AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Parent = row})
	Util.list(right, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local e = setmetatable({row = row, label = label, left = left, right = right, sec = sec, win = sec.win, cfg = cfg, name = cfg.Name, Changed = Util.Signal.new(), maid = Util.Maid.new()}, Elem)
	if cfg.Info then e:_info(cfg.Info) end
	sec.elems[#sec.elems + 1] = e
	return e
end

function Elem:_info(text)
	local b = Util.new("TextButton", {Name = "Info", Size = UDim2.fromOffset(14, 14), Text = "", Parent = self.left, LayoutOrder = 5})
	local ic = Icons.create(b, "info", 13, "mute")
	ic.Position = UDim2.fromOffset(0, 0)
	b.MouseEnter:Connect(function()
		Icons.tint(ic, "ink")
		Pop.tip(self.win, b, text, self.name)
	end)
	b.MouseLeave:Connect(function()
		Icons.tint(ic, "mute")
		if Pop.isOpen(self.win, "tip") then Pop.close(self.win) end
	end)
	b.Activated:Connect(function() Pop.tip(self.win, b, text, self.name) end)
	self.infoBtn = b
end

function Elem:SetName(n)
	self.name = n
	if self.label then self.label.Text = n end
end

function Elem:SetVisible(v)
	self.row.Visible = v
end

function Elem:Highlight()
	if self.win.current ~= self.sec.tab then self.sec.tab:Select() end
	task.delay(0.15, function() Elements.flash(self.row) end)
	local body = self.sec.tab.body
	if body and body:IsA("ScrollingFrame") then
		local y = self.row.AbsolutePosition.Y - body.AbsolutePosition.Y + body.CanvasPosition.Y - 40
		Util.tween(body, 0.3, {CanvasPosition = Vector2.new(0, math.max(0, y))}, Enum.EasingStyle.Quint)
	end
end

function Elem:Lock(reason)
	self.locked = true
	self.lockReason = reason or "Premium"
	if not self.lockCover then
		local cover = Util.new("TextButton", {Name = "LockCover", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 15, Parent = self.row})
		local ic = Icons.create(cover, "lock", 13, "sub")
		ic.AnchorPoint = Vector2.new(1, 0.5)
		ic.Position = UDim2.new(1, -12, 0.5, 0)
		ic.ZIndex = 16
		cover.Activated:Connect(function()
			Sound.play("error")
			K.Notify.new({Title = self.name .. " is locked", Text = self.lockReason .. " required", Type = "warn", Duration = 2.5})
		end)
		self.lockCover = cover
	end
	self.lockCover.Visible = true
	for _, o in self.row:GetChildren() do
		if o.Name == "Left" or o.Name == "Right" then
			for _, d in o:GetDescendants() do
				if d:IsA("TextLabel") or d:IsA("TextButton") then d.TextTransparency = 0.55 end
				if d:IsA("ImageLabel") then d.ImageTransparency = 0.55 end
			end
			if o.Name == "Right" then o.Visible = false end
		end
	end
end

function Elem:Unlock()
	self.locked = false
	if self.lockCover then self.lockCover.Visible = false end
	for _, o in self.row:GetChildren() do
		if o.Name == "Left" or o.Name == "Right" then
			for _, d in o:GetDescendants() do
				if d:IsA("TextLabel") or d:IsA("TextButton") then d.TextTransparency = 0 end
				if d:IsA("ImageLabel") then d.ImageTransparency = 0 end
			end
			o.Visible = true
		end
	end
end

function Elem:Destroy()
	self.maid:Clean()
	self.row:Destroy()
	if self.flag then self.win.options[self.flag] = nil end
end

function Elem:Fire(value)
	if self.flag then self.win.flags[self.flag] = value end
	self.Changed:Fire(value)
	if self.cfg.Callback and not self._silent then Util.safe(self.cfg.Callback, value) end
	if K.Config then K.Config.dirty(self.win) end
end

function Elements.make(sec, kind, builder, cfg)
	cfg = type(cfg) == "string" and {Name = cfg} or (cfg or {})
	local e = builder(sec, cfg)
	if not e then return nil end
	e.kind = kind
	if cfg.Flag then
		e.flag = cfg.Flag
		sec.win.options[cfg.Flag] = e
		if e.Get then sec.win.flags[cfg.Flag] = e:Get() end
	end
	if cfg.Locked then e:Lock(cfg.LockReason) end
	if e.row and cfg.Name and not cfg.Inline then
		sec.win:Register({Name = cfg.Name, Kind = (kind == "Button" or kind == "Action") and "Action" or "Setting", Type = kind, Tab = sec.tab, Section = sec, Elem = e, Keywords = cfg.Keywords, Info = cfg.Info, Run = function() e:Highlight() end})
	end
	return e
end

function Elements.headerSegmented(tab, cfg)
	local opts = cfg.Options or {}
	local holder = Util.new("Frame", {Name = "Segments", BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = (tab.toolOrder or 0) + 1, Parent = tab.tools})
	tab.toolOrder = (tab.toolOrder or 0) + 1
	Util.list(holder, 2, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local seg = {buttons = {}, Changed = Util.Signal.new()}
	local value = cfg.Default or opts[1]
	local function paint(animate)
		for name, b in seg.buttons do
			local on = name == value
			local t = animate and 0.16 or 0
			Theme.bind(b, {BackgroundColor3 = "ink", TextColor3 = on and "bg" or "sub"})
			Util.tween(b, t, {BackgroundTransparency = on and 0 or 1}, Enum.EasingStyle.Quad)
		end
	end
	for i, name in opts do
		local b = Util.new("TextButton", {Name = name, Size = UDim2.new(0, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.X, Text = name, TextSize = 12, FontFace = Util.font("Medium"), LayoutOrder = i, Parent = holder})
		Util.pad(b, 12, 0, 12, 0)
		Util.corner(b, 8)
		Theme.bind(b, {BackgroundColor3 = "ctl"})
		Theme.gradient(b, 0.1)
		Anim.pressable(b, {depth = 0.95})
		seg.buttons[name] = b
		b.Activated:Connect(function()
			if value == name then return end
			value = name
			Sound.play("click")
			paint(true)
			tab.mode = name
			for _, s in tab.sections do
				if s.cfg.Mode then s.wrap.Visible = s.cfg.Mode == name end
			end
			seg.Changed:Fire(name)
			if cfg.Callback then Util.safe(cfg.Callback, name) end
		end)
	end
	paint(false)
	tab.mode = value
	for _, s in tab.sections do if s.cfg.Mode then s.wrap.Visible = s.cfg.Mode == value end end
	function seg.Set(_, v) value = v paint(true) tab.mode = v for _, s in tab.sections do if s.cfg.Mode then s.wrap.Visible = s.cfg.Mode == v end end end
	function seg.Get() return value end
	return seg
end

function Elements.headerIcon(tab, cfg)
	tab.toolOrder = (tab.toolOrder or 0) + 1
	local b = Util.new("TextButton", {Name = cfg.Name or "Tool", Size = UDim2.fromOffset(28, 28), Text = "", BackgroundTransparency = 0, LayoutOrder = tab.toolOrder + 50, Parent = tab.tools})
	Util.corner(b, 8)
	Theme.bind(b, {BackgroundColor3 = "ctl"})
	Theme.gradient(b, 0.12)
	local ic = Icons.create(b, cfg.Icon or "refresh-cw", 14, "sub")
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)
	Elements.hoverCtl(b, b, "ctl", "hover")
	Anim.pressable(b, {depth = 0.92})
	b.Activated:Connect(function()
		Sound.play("click")
		if cfg.Spin ~= false then
			ic.Rotation = 0
			Util.tween(ic, 0.45, {Rotation = 360}, Enum.EasingStyle.Quint)
		end
		if cfg.Callback then Util.safe(cfg.Callback) end
	end)
	return b
end

K.Elements = Elements
return Elements

end
__F["Controls"] = function(...)
local K = ...
local Util = K.Util
local Theme = K.Theme
local Icons = K.Icons
local Anim = K.Anim
local Sound = K.Sound
local E = K.Elements
local T = E.types
local UIS = Util.UserInputService

local C = E.C

local function ctlButton(parent, cfg)
	local b = Util.new("TextButton", {Name = cfg.Name or "Btn", Size = cfg.Size or UDim2.new(0, 0, 0, C), AutomaticSize = cfg.Size and Enum.AutomaticSize.None or Enum.AutomaticSize.X, Text = cfg.Text or "", TextSize = 12, FontFace = Util.font(cfg.Weight or "SemiBold"), BackgroundTransparency = 0, LayoutOrder = cfg.Order or 0, Parent = parent})
	Util.corner(b, Theme.radii[4] - 1)
	local style = cfg.Style or "secondary"
	local rest, over, txt = "ctl", "hover", "ink"
	if style == "primary" then rest, over, txt = "a1", {"a1", "ink", 0.12}, "on"
	elseif style == "danger" then rest, over, txt = "ctl", "hover", "danger"
	elseif style == "ghost" then rest, over, txt = "tile", "ctl", "sub"
	elseif style == "soft" then rest, over, txt = "ctl", "hover", "sub" end
	Theme.bind(b, {TextColor3 = txt})
	b.BackgroundColor3 = Theme.resolve(rest)
	if style ~= "ghost" then Theme.gradient(b, style == "primary" and 0.16 or 0.12) end
	if cfg.Padding ~= false then Util.pad(b, cfg.Pad or 12, 0, cfg.Pad or 12, 0) end
	E.hoverCtl(b, b, rest, over)
	Anim.pressable(b, {depth = 0.95})
	if style == "primary" then
		local shadow = Util.new("Frame", {Name = "Glow", Size = UDim2.new(1, 4, 1, 4), Position = UDim2.fromOffset(-2, 1), BackgroundTransparency = 0.9, ZIndex = 0, Parent = b})
		Util.corner(shadow, Theme.radii[4] + 1)
		Theme.bind(shadow, {BackgroundColor3 = "a1"})
		shadow.Visible = false
	end
	return b
end
E.ctlButton = ctlButton

T.Label = function(sec, cfg)
	local e = E.newRow(sec, cfg)
	if cfg.Text then
		local v = Util.text(e.right, {Text = cfg.Text, TextSize = 12, Weight = "Medium", Size = UDim2.new(0, 0, 0, 16), AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None})
		Theme.bind(v, {TextColor3 = "sub"})
		e.value = v
	end
	function e:Set(t) if self.value then self.value.Text = t end end
	function e:Get() return self.value and self.value.Text or "" end
	return e
end

T.Paragraph = function(sec, cfg)
	sec.n += 1
	local row = Util.new("Frame", {Name = cfg.Name or "Paragraph", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = sec.n, Parent = sec.tile})
	Util.pad(row, 12, 9, 12, 9)
	Util.list(row, 3)
	local e = setmetatable({row = row, sec = sec, win = sec.win, cfg = cfg, name = cfg.Name, Changed = Util.Signal.new(), maid = Util.Maid.new()}, E.Elem)
	if cfg.Name then
		local t = Util.text(row, {Text = cfg.Name, TextSize = 13, Weight = "SemiBold", Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1})
		Theme.bind(t, {TextColor3 = "ink"})
		e.label = t
	end
	local body = Util.text(row, {Text = cfg.Text or "", TextSize = 12, Weight = "Medium", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2})
	Theme.bind(body, {TextColor3 = "sub"})
	e.body = body
	function e:Set(t) body.Text = t end
	function e:Get() return body.Text end
	sec.elems[#sec.elems + 1] = e
	return e
end

T.Divider = function(sec, cfg)
	sec.n += 1
	local row = Util.new("Frame", {Name = "Divider", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 9), LayoutOrder = sec.n, Parent = sec.tile})
	local l = Util.new("Frame", {Size = UDim2.new(1, -24, 0, 1), Position = UDim2.new(0, 12, 0.5, 0), Parent = row})
	Theme.bind(l, {BackgroundColor3 = "line"})
	local e = setmetatable({row = row, sec = sec, win = sec.win, cfg = cfg, Changed = Util.Signal.new(), maid = Util.Maid.new()}, E.Elem)
	return e
end

T.Button = function(sec, cfg)
	local e = E.newRow(sec, cfg)
	local text = cfg.Text or cfg.ButtonText or "Run"
	if cfg.Icon then
		local b = ctlButton(e.right, {Text = text, Style = cfg.Style, Pad = 10})
		b.Text = ""
		local row = Util.new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = b})
		Util.list(row, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
		local ic = Icons.create(row, cfg.Icon, 13, cfg.Style == "primary" and "on" or (cfg.Style == "danger" and "danger" or "ink"))
		ic.LayoutOrder = 1
		local t = Util.text(row, {Text = text, TextSize = 12, Weight = "SemiBold", Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2})
		Theme.bind(t, {TextColor3 = cfg.Style == "primary" and "on" or (cfg.Style == "danger" and "danger" or "ink")})
		e.btn = b
		e.btnLabel = t
	else
		e.btn = ctlButton(e.right, {Text = text, Style = cfg.Style})
	end
	e.btn.Activated:Connect(function()
		if e.locked then return end
		Sound.play("click")
		if cfg.Callback then Util.safe(cfg.Callback) end
		e.Changed:Fire()
	end)
	function e:SetText(t) if self.btnLabel then self.btnLabel.Text = t else self.btn.Text = t end end
	function e:Click() self.btn.Activated:Fire() end
	return e
end

T.Buttons = function(sec, cfg)
	local e = E.newRow(sec, cfg)
	for i, b in cfg.Buttons do
		local btn = ctlButton(e.right, {Text = b.Text, Style = b.Style or (i == 1 and "primary" or "secondary"), Order = i, Pad = 14})
		btn.Activated:Connect(function()
			Sound.play("click")
			if b.Callback then Util.safe(b.Callback) end
		end)
	end
	return e
end

T.Action = function(sec, cfg)
	sec.n += 1
	local row = Util.new("Frame", {Name = cfg.Name or "Action", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = sec.n, Parent = sec.tile})
	local e = setmetatable({row = row, sec = sec, win = sec.win, cfg = cfg, name = cfg.Name, Changed = Util.Signal.new(), maid = Util.Maid.new()}, E.Elem)
	local b = ctlButton(row, {Text = "", Style = cfg.Style or "primary", Size = UDim2.new(1, -16, 0, 32), Padding = false})
	b.Position = UDim2.fromOffset(8, 6)
	local inner = Util.new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = b})
	Util.list(inner, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local tok = (cfg.Style or "primary") == "primary" and "on" or ((cfg.Style == "danger") and "danger" or "ink")
	if cfg.Icon then
		local ic = Icons.create(inner, cfg.Icon, 14, tok)
		ic.LayoutOrder = 1
	end
	local t = Util.text(inner, {Text = cfg.Name or "Run", TextSize = 13, Weight = "SemiBold", Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2})
	Theme.bind(t, {TextColor3 = tok})
	b.Activated:Connect(function()
		if e.locked then return end
		Sound.play("click")
		if cfg.Callback then Util.safe(cfg.Callback) end
	end)
	e.btn = b
	sec.elems[#sec.elems + 1] = e
	return e
end

local function knobAndTrack(parent, w, h)
	local track = Util.new("TextButton", {Name = "Toggle", Size = UDim2.fromOffset(w, h), Text = "", BackgroundTransparency = 0, Parent = parent})
	Util.pill(track)
	local pad = 3
	local ks = h - pad * 2
	local knob = Util.new("Frame", {Name = "Knob", Size = UDim2.fromOffset(ks, ks), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, pad, 0.5, 0), Parent = track})
	Util.pill(knob)
	local check = Icons.create(knob, "check", math.floor(ks * 0.62), "a1")
	check.AnchorPoint = Vector2.new(0.5, 0.5)
	check.Position = UDim2.fromScale(0.5, 0.5)
	return track, knob, check, pad, ks
end

local function paintToggle(track, knob, check, on, pad, ks, w, animate, stretch)
	local t = animate and Anim.dur(0.18) or 0
	local x = on and (w - ks - pad) or pad
	local kw = stretch and ks + 4 or ks
	if on and stretch then x -= 4 end
	local function go(o, props, style)
		if t == 0 then for k, v in props do o[k] = v end else Util.tween(o, t, props, style or Enum.EasingStyle.Quint) end
	end
	go(track, {BackgroundColor3 = Theme.resolve(on and "a1" or "ctl")})
	go(knob, {Position = UDim2.new(0, x, 0.5, 0), Size = UDim2.fromOffset(kw, ks), BackgroundColor3 = Theme.resolve(on and "on" or "mute")})
	if check:IsA("ImageLabel") then go(check, {ImageTransparency = on and 0 or 1}) else go(check, {TextTransparency = on and 0 or 1}) end
end

function E.toggleWidget(parent, default, onChange, size)
	local w, h = 44, C
	if size == "S" then w, h = 36, 20 elseif size == "L" then w, h = 48, 26 end
	local track, knob, check, pad, ks = knobAndTrack(parent, w, h)
	local on = default and true or false
	local w0 = {track = track}
	local conn = Theme.changed:Connect(function() paintToggle(track, knob, check, on, pad, ks, w, false) end)
	paintToggle(track, knob, check, on, pad, ks, w, false)
	local pressed = false
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			pressed = true
			paintToggle(track, knob, check, on, pad, ks, w, true, true)
		end
	end)
	track.MouseLeave:Connect(function()
		if pressed then
			pressed = false
			paintToggle(track, knob, check, on, pad, ks, w, true)
		end
	end)
	track.Activated:Connect(function()
		pressed = false
		on = not on
		Sound.play("toggle", nil, on and 1.15 or 0.95)
		paintToggle(track, knob, check, on, pad, ks, w, true)
		onChange(on)
	end)
	function w0.Set(v, silent)
		v = v and true or false
		if v == on then return end
		on = v
		paintToggle(track, knob, check, on, pad, ks, w, true)
		if not silent then onChange(on) end
	end
	function w0.Get() return on end
	w0.conn = conn
	return w0
end

T.Toggle = function(sec, cfg)
	local e = E.newRow(sec, cfg)
	local acc = cfg.Keybind
	if acc then
		if type(acc) ~= "table" then acc = {} end
		e.keybind = E.make(sec, "Keybind", T.Keybind, Util.merge(acc, {Parent = e.right, Inline = true, Name = cfg.Name .. " key"}))
	end
	if cfg.Color then
		local cc = cfg.Color
		if typeof(cc) == "Color3" then cc = {Default = cc} end
		e.color = E.make(sec, "ColorPicker", T.ColorPicker, Util.merge(cc, {Parent = e.right, Inline = true, Name = cfg.Name .. " color"}))
	end
	local w = E.toggleWidget(e.right, cfg.Default, function(v)
		e:Fire(v)
	end, cfg.Size)
	w.track.LayoutOrder = 100
	e.widget = w
	function e:Set(v, silent)
		self._silent = silent
		w.Set(v, false)
		self._silent = false
	end
	function e:Get() return w.Get() end
	if cfg.Default then
		task.defer(function() if e.flag then sec.win.flags[e.flag] = w.Get() end end)
	end
	return e
end

T.Checkbox = function(sec, cfg)
	local e = E.newRow(sec, cfg)
	local box = Util.new("TextButton", {Name = "Check", Size = UDim2.fromOffset(C, C), Text = "", BackgroundTransparency = 0, Parent = e.right})
	Util.corner(box, Theme.radii[4] - 1)
	Theme.gradient(box, 0.12)
	local ic = Icons.create(box, "check", 14, "on")
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)
	local on = cfg.Default and true or false
	local function paint(animate)
		local t = animate and Anim.dur(0.14) or 0
		local goal = {BackgroundColor3 = Theme.resolve(on and "a1" or "ctl")}
		if t == 0 then box.BackgroundColor3 = goal.BackgroundColor3 else Util.tween(box, t, goal) end
		local prop = ic:IsA("ImageLabel") and "ImageTransparency" or "TextTransparency"
		if t == 0 then ic[prop] = on and 0 or 1 else Util.tween(ic, t, {[prop] = on and 0 or 1}) end
	end
	paint(false)
	local conn = Theme.changed:Connect(function() paint(false) end)
	e.maid:Add(conn)
	Anim.pressable(box, {depth = 0.9})
	box.Activated:Connect(function()
		on = not on
		Sound.play("toggle")
		paint(true)
		e:Fire(on)
	end)
	function e:Set(v, silent) on = v and true or false paint(true) if not silent then self:Fire(on) end end
	function e:Get() return on end
	return e
end

T.Slider = function(sec, cfg)
	local e = E.newRow(sec, cfg)
	local min, max, step = cfg.Min or 0, cfg.Max or 100, cfg.Step or 1
	local value = Util.clamp(cfg.Default or min, min, max)
	local width = cfg.Width or 76
	local holder = Util.new("TextButton", {Name = "Slider", Size = UDim2.fromOffset(width, C), Text = "", BackgroundTransparency = 1, Parent = e.right, LayoutOrder = 10})
	local track = Util.new("Frame", {Name = "Track", Size = UDim2.new(1, -6, 0, 4), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Parent = holder})
	Util.pill(track)
	Theme.bind(track, {BackgroundColor3 = "ctl2"})
	local fill = Util.new("Frame", {Name = "Fill", Size = UDim2.fromScale(0, 1), Parent = track})
	Util.pill(fill)
	Theme.bind(fill, {BackgroundColor3 = "a1"})
	local thumb = Util.new("Frame", {Name = "Thumb", Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), ZIndex = 3, Parent = track})
	Util.pill(thumb)
	Theme.bind(thumb, {BackgroundColor3 = "ink"})
	local scale = Util.new("UIScale", {Parent = thumb})
	local vbox = Util.new("TextBox", {Name = "Value", Size = UDim2.new(0, 0, 0, C), AutomaticSize = Enum.AutomaticSize.X, Text = "", TextSize = 12, FontFace = Util.font("SemiBold"), BackgroundTransparency = 1, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Right, LayoutOrder = 20, Parent = e.right})
	Theme.bind(vbox, {TextColor3 = "ink"})
	local suffix = cfg.Suffix or ""
	local function show()
		vbox.Text = Util.fmt(value, step) .. suffix
		local frac = (value - min) / math.max(max - min, 1e-9)
		fill.Size = UDim2.fromScale(frac, 1)
		thumb.Position = UDim2.fromScale(frac, 0.5)
	end
	local function setValue(v, silent, animate)
		v = Util.clamp(Util.round(v - min, step) + min, min, max)
		v = tonumber(Util.fmt(v, step))
		if v == value then return end
		value = v
		local frac = (value - min) / math.max(max - min, 1e-9)
		vbox.Text = Util.fmt(value, step) .. suffix
		if animate then
			Util.tween(fill, 0.12, {Size = UDim2.fromScale(frac, 1)}, Enum.EasingStyle.Quad)
			Util.tween(thumb, 0.12, {Position = UDim2.fromScale(frac, 0.5)}, Enum.EasingStyle.Quad)
		else
			fill.Size = UDim2.fromScale(frac, 1)
			thumb.Position = UDim2.fromScale(frac, 0.5)
		end
		if not silent then e:Fire(value) end
	end
	local dragging = false
	local function fromInput(x)
		local ap, asz = track.AbsolutePosition, track.AbsoluteSize
		local f = Util.clamp((x - ap.X) / math.max(asz.X, 1), 0, 1)
		setValue(min + (max - min) * f)
	end
	holder.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			Util.tween(scale, 0.1, {Scale = 1.25}, Enum.EasingStyle.Quad)
			fromInput(Util.inputPos(i).X)
		end
	end)
	e.maid:Add(UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			fromInput(Util.inputPos(i).X)
		end
	end))
	e.maid:Add(UIS.InputEnded:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			Util.tween(scale, 0.18, {Scale = 1}, Enum.EasingStyle.Back)
		end
	end))
	vbox.FocusLost:Connect(function()
		local n = tonumber((vbox.Text:gsub("[^%d%.%-]", "")))
		if n then setValue(n, false, true) end
		vbox.Text = Util.fmt(value, step) .. suffix
	end)
	show()
	function e:Set(v, silent) setValue(v, silent, true) end
	function e:Get() return value end
	function e:SetRange(a, b) min, max = a, b value = Util.clamp(value, a, b) show() end
	return e
end

T.TextBox = function(sec, cfg)
	local e = E.newRow(sec, cfg)
	local wide = cfg.Wide
	local w = cfg.Width or 92
	local box = E.ctlFrame(e.right, {Name = "Field", Size = UDim2.fromOffset(w, C), LayoutOrder = 10})
	if wide then box.Size = UDim2.fromOffset(cfg.Width or 150, C) end
	local tb = Util.new("TextBox", {Name = "Input", Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Text = cfg.Default or "", PlaceholderText = cfg.Placeholder or "", TextSize = 12, FontFace = Util.font("Medium"), ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd, Parent = box})
	Theme.bind(tb, {TextColor3 = "ink", PlaceholderColor3 = "mute"})
	if cfg.Mask then
		tb.Text = cfg.Default or ""
	end
	local value = cfg.Default or ""
	tb.Focused:Connect(function() Util.tween(box, 0.12, {BackgroundColor3 = Theme.resolve("hover")}) end)
	tb.FocusLost:Connect(function(enter)
		Util.tween(box, 0.14, {BackgroundColor3 = Theme.resolve("ctl")})
		local t = tb.Text
		if cfg.Numeric then
			local n = tonumber(t)
			if not n then tb.Text = value return end
			if cfg.Min then n = math.max(cfg.Min, n) end
			if cfg.Max then n = math.min(cfg.Max, n) end
			t = tostring(n)
			tb.Text = t
		end
		if cfg.Finished and not enter then return end
		value = t
		e:Fire(value)
	end)
	function e:Set(v, silent) tb.Text = tostring(v) value = tostring(v) if not silent then self:Fire(value) end end
	function e:Get() return value end
	e.input = tb
	return e
end

T.Number = function(sec, cfg)
	cfg = Util.merge(cfg, {Numeric = true})
	local e = E.newRow(sec, cfg)
	local min, max, step = cfg.Min or -math.huge, cfg.Max or math.huge, cfg.Step or 1
	local value = cfg.Default or 0
	local suffix = cfg.Suffix or ""
	local box = E.ctlFrame(e.right, {Name = "Field", Size = UDim2.fromOffset(cfg.Width or 92, C), LayoutOrder = 10})
	local tb = Util.new("TextBox", {Name = "Input", Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Text = "", TextSize = 12, FontFace = Util.font("Medium"), ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Parent = box})
	Theme.bind(tb, {TextColor3 = "ink"})
	local function show() tb.Text = Util.fmt(value, step) .. (suffix ~= "" and " " .. suffix or "") end
	local function set(v, silent)
		v = Util.clamp(v, min, max)
		v = tonumber(Util.fmt(Util.round(v, step), step))
		value = v
		show()
		if not silent then e:Fire(value) end
	end
	tb.Focused:Connect(function() tb.Text = Util.fmt(value, step) end)
	tb.FocusLost:Connect(function()
		local n = tonumber((tb.Text:gsub("[^%d%.%-]", "")))
		if n then set(n) else show() end
	end)
	show()
	function e:Set(v, silent) set(v, silent) end
	function e:Get() return value end
	return e
end

T.Segmented = function(sec, cfg)
	sec.n += 1
	local row = Util.new("Frame", {Name = cfg.Name or "Segmented", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = sec.n, Parent = sec.tile})
	local e = setmetatable({row = row, sec = sec, win = sec.win, cfg = cfg, name = cfg.Name, Changed = Util.Signal.new(), maid = Util.Maid.new()}, E.Elem)
	sec.elems[#sec.elems + 1] = e
	local list = Util.new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 7), Parent = row})
	Util.list(list, 4, Enum.FillDirection.Horizontal)
	local opts = cfg.Options
	local value = cfg.Default or opts[1]
	local buttons = {}
	local function paint(animate)
		for name, b in buttons do
			local on = name == value
			Util.tween(b, animate and Anim.dur(0.16) or 0, {BackgroundColor3 = Theme.resolve(on and "ink" or "ctl")}, Enum.EasingStyle.Quad)
			Theme.bind(b, {TextColor3 = on and "bg" or "sub"})
		end
	end
	for i, name in opts do
		local b = Util.new("TextButton", {Name = name, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Text = name, TextSize = 12, FontFace = Util.font("SemiBold"), BackgroundTransparency = 0, LayoutOrder = i, Parent = list})
		Util.pad(b, 12, 0, 12, 0)
		Util.corner(b, Theme.radii[4])
		Theme.gradient(b, 0.12)
		Anim.pressable(b, {depth = 0.95})
		buttons[name] = b
		b.Activated:Connect(function()
			if value == name then return end
			value = name
			Sound.play("click")
			paint(true)
			e:Fire(value)
		end)
	end
	paint(false)
	e.maid:Add(Theme.changed:Connect(function() paint(false) end))
	function e:Set(v, silent) value = v paint(true) if not silent then self:Fire(v) end end
	function e:Get() return value end
	return e
end

T.Feature = function(sec, cfg)
	sec.n += 1
	local row = Util.new("TextButton", {Name = cfg.Name, BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = sec.n, Parent = sec.tile})
	local e = setmetatable({row = row, sec = sec, win = sec.win, cfg = cfg, name = cfg.Name, Changed = Util.Signal.new(), maid = Util.Maid.new()}, E.Elem)
	sec.elems[#sec.elems + 1] = e
	local hl = Util.new("Frame", {Name = "Hover", Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3), BackgroundTransparency = 1, Parent = row})
	Util.corner(hl, Theme.radii[3])
	Theme.bind(hl, {BackgroundColor3 = "ctl"})
	local tile = Util.new("Frame", {Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(12, 7), Parent = row})
	Util.corner(tile, 8)
	Theme.bind(tile, {BackgroundColor3 = {"ctl2", "a1", 0.25}})
	local ic = Icons.create(tile, cfg.Icon or "zap", 14, "ink")
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)
	local l = Util.text(row, {Text = cfg.Name, TextSize = 13, Weight = "Medium", Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(46, 0)})
	Theme.bind(l, {TextColor3 = "ink"})
	local ch = Icons.create(row, "chevron-right", 14, "mute")
	ch.Position = UDim2.new(1, -28, 0.5, -7)
	row.MouseEnter:Connect(function()
		Util.tween(hl, 0.12, {BackgroundTransparency = 0.4}, Enum.EasingStyle.Quad)
		Util.tween(ch, 0.14, {Position = UDim2.new(1, -24, 0.5, -7)}, Enum.EasingStyle.Quad)
		Icons.tint(ch, "ink")
		Sound.play("hover")
	end)
	row.MouseLeave:Connect(function()
		Util.tween(hl, 0.14, {BackgroundTransparency = 1}, Enum.EasingStyle.Quad)
		Util.tween(ch, 0.16, {Position = UDim2.new(1, -28, 0.5, -7)}, Enum.EasingStyle.Quad)
		Icons.tint(ch, "mute")
	end)
	row.Activated:Connect(function()
		Sound.play("click")
		if cfg.Callback then Util.safe(cfg.Callback) end
	end)
	return e
end

T.Progress = function(sec, cfg)
	sec.n += 1
	local row = Util.new("Frame", {Name = cfg.Name or "Progress", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = sec.n, Parent = sec.tile})
	local e = setmetatable({row = row, sec = sec, win = sec.win, cfg = cfg, name = cfg.Name, Changed = Util.Signal.new(), maid = Util.Maid.new()}, E.Elem)
	sec.elems[#sec.elems + 1] = e
	local l = Util.text(row, {Text = cfg.Name or "", TextSize = 12, Weight = "Medium", Size = UDim2.new(1, -80, 0, 16), Position = UDim2.fromOffset(12, 8)})
	Theme.bind(l, {TextColor3 = "ink"})
	local v = Util.text(row, {Text = "", TextSize = 12, Weight = "SemiBold", Size = UDim2.new(0, 60, 0, 16), Position = UDim2.new(1, -72, 0, 8), TextXAlignment = Enum.TextXAlignment.Right})
	Theme.bind(v, {TextColor3 = "sub"})
	local track = Util.new("Frame", {Size = UDim2.new(1, -24, 0, 6), Position = UDim2.fromOffset(12, 28), Parent = row})
	Util.pill(track)
	Theme.bind(track, {BackgroundColor3 = "ctl"})
	local fill = Util.new("Frame", {Size = UDim2.fromScale(0, 1), Parent = track})
	Util.pill(fill)
	Theme.bind(fill, {BackgroundColor3 = "a1"})
	Theme.gradient(fill, 0.1)
	local value = cfg.Default or 0
	local min, max = cfg.Min or 0, cfg.Max or 100
	local function show(animate)
		local f = Util.clamp((value - min) / math.max(max - min, 1e-9), 0, 1)
		Util.tween(fill, animate and 0.3 or 0, {Size = UDim2.fromScale(f, 1)}, Enum.EasingStyle.Quint)
		v.Text = cfg.Format and cfg.Format(value) or (math.floor(f * 100 + 0.5) .. "%")
	end
	show(false)
	function e:Set(x) value = x show(true) end
	function e:Get() return value end
	return e
end

T.Keybind = function(sec, cfg)
	local e
	if cfg.Inline then
		e = setmetatable({row = cfg.Parent, sec = sec, win = sec.win, cfg = cfg, name = cfg.Name, Changed = Util.Signal.new(), maid = Util.Maid.new()}, E.Elem)
	else
		e = E.newRow(sec, cfg)
	end
	local parent = cfg.Inline and cfg.Parent or e.right
	local btn = Util.new("TextButton", {Name = "Key", Size = UDim2.new(0, 0, 0, C), AutomaticSize = Enum.AutomaticSize.X, Text = "", BackgroundTransparency = 0, LayoutOrder = 50, Parent = parent})
	Util.corner(btn, Theme.radii[4] - 1)
	Theme.bind(btn, {BackgroundColor3 = "ctl"})
	Theme.gradient(btn, 0.12)
	local lab = Util.text(btn, {Text = "None", TextSize = 12, Weight = "SemiBold", Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.None})
	Theme.bind(lab, {TextColor3 = "ink"})
	local constraint = Util.new("UISizeConstraint", {MinSize = Vector2.new(30, C), Parent = btn})
	local _ = constraint
	Util.pad(btn, 9, 0, 9, 0)
	lab.TextXAlignment = Enum.TextXAlignment.Center
	E.hoverCtl(btn, btn, "ctl", "hover")
	local key = cfg.Default
	local listening = false
	local mode = cfg.Mode or "Toggle"
	local function name(k)
		if not k then return "None" end
		if typeof(k) == "EnumItem" then
			if k.EnumType == Enum.UserInputType then
				local m = {MouseButton1 = "M1", MouseButton2 = "M2", MouseButton3 = "M3"}
				return m[k.Name] or k.Name
			end
			local n = k.Name
			local map = {LeftControl = "LCtrl", RightControl = "RCtrl", LeftShift = "LShift", RightShift = "RShift", LeftAlt = "LAlt", RightAlt = "RAlt", Return = "Enter", Backspace = "Back", Escape = "Esc", Zero = "0", One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9"}
			return map[n] or n
		end
		return tostring(k)
	end
	local function show()
		lab.Text = listening and "..." or name(key)
		Theme.bind(lab, {TextColor3 = (key or listening) and "ink" or "sub"})
	end
	show()
	local function set(k, silent)
		key = k
		listening = false
		show()
		if not silent then e:Fire(k and k.Name or nil) end
	end
	Anim.pressable(btn, {depth = 0.94})
	btn.Activated:Connect(function()
		if listening then return end
		listening = true
		Sound.play("click")
		show()
		task.delay(0.05, function() e._arm = true end)
	end)
	e.maid:Add(UIS.InputBegan:Connect(function(i, gp)
		if listening and e._arm then
			if i.UserInputType == Enum.UserInputType.Keyboard then
				e._arm = false
				if i.KeyCode == Enum.KeyCode.Escape then listening = false show() return end
				if i.KeyCode == Enum.KeyCode.Backspace or i.KeyCode == Enum.KeyCode.Delete then set(nil) return end
				set(i.KeyCode)
			elseif i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.MouseButton2 or i.UserInputType == Enum.UserInputType.MouseButton3 then
				if i.UserInputType == Enum.UserInputType.MouseButton1 then
					local m = Util.mouse()
					if Util.hit(btn, m.X, m.Y) then return end
				end
				e._arm = false
				set(i.UserInputType)
			end
			return
		end
		if gp or listening or not key then return end
		if UIS:GetFocusedTextBox() then return end
		local hit = (i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode == key) or (i.UserInputType == key)
		if hit then
			e.held = true
			if cfg.Pressed then Util.safe(cfg.Pressed, mode == "Hold" and true or nil) end
			e.Pressed:Fire(true)
		end
	end))
	e.maid:Add(UIS.InputEnded:Connect(function(i)
		if not key or not e.held then return end
		local hit = (i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode == key) or (i.UserInputType == key)
		if hit then
			e.held = false
			if mode == "Hold" and cfg.Pressed then Util.safe(cfg.Pressed, false) end
			e.Pressed:Fire(false)
		end
	end))
	e.Pressed = Util.Signal.new()
	function e:Set(k, silent)
		if type(k) == "string" then
			local ok, v = pcall(function() return Enum.KeyCode[k] end)
			k = ok and v or nil
		end
		set(k, silent)
	end
	function e:Get() return key end
	function e:GetName() return name(key) end
	return e
end

return E

end
__F["Controls2"] = function(...)
local K = ...
local Util = K.Util
local Theme = K.Theme
local Icons = K.Icons
local Anim = K.Anim
local Sound = K.Sound
local Pop = K.Pop
local E = K.Elements
local T = E.types
local UIS = Util.UserInputService

local C = E.C

local function optName(o) return type(o) == "table" and (o.Name or o.Text) or tostring(o) end
local function optValue(o) return type(o) == "table" and (o.Value ~= nil and o.Value or (o.Name or o.Text)) or o end

T.Dropdown = function(sec, cfg)
	local e = E.newRow(sec, cfg)
	local multi = cfg.Multi
	local options = cfg.Options or {}
	local w = cfg.Width or 96
	local selected = {}
	local single
	local function initDefault()
		if multi then
			selected = {}
			if type(cfg.Default) == "table" then for _, v in cfg.Default do selected[v] = true end end
		else
			single = cfg.Default
			if single == nil and options[1] ~= nil and not cfg.AllowNone then single = optValue(options[1]) end
		end
	end
	initDefault()
	local btn = Util.new("TextButton", {Name = "Dropdown", Size = UDim2.fromOffset(w, C), Text = "", BackgroundTransparency = 0, LayoutOrder = 10, Parent = e.right})
	Util.corner(btn, Theme.radii[4] - 1)
	Theme.bind(btn, {BackgroundColor3 = "ctl"})
	Theme.gradient(btn, 0.12)
	local text = Util.text(btn, {Text = "", TextSize = 12, Weight = "Medium", Size = UDim2.new(1, -28, 1, 0), Position = UDim2.fromOffset(8, 0)})
	Theme.bind(text, {TextColor3 = "ink"})
	local chev = Icons.create(btn, "chevron-down", 14, "sub")
	chev.Position = UDim2.new(1, -20, 0.5, -7)
	E.hoverCtl(btn, btn, "ctl", "hover")
	Anim.pressable(btn, {depth = 0.97})
	local function label()
		if multi then
			local names, n = nil, 0
			for _, o in options do
				if selected[optValue(o)] then
					n += 1
					names = names or optName(o)
				end
			end
			if n == 0 then return cfg.Placeholder or "None" end
			return n == 1 and names or (names .. " +" .. (n - 1))
		end
		for _, o in options do
			if optValue(o) == single then return optName(o) end
		end
		return cfg.Placeholder or "Select"
	end
	local function show() text.Text = label() end
	show()
	local function value()
		if multi then
			local o = {}
			for _, opt in options do if selected[optValue(opt)] then o[#o + 1] = optValue(opt) end end
			return o
		end
		return single
	end
	local function open()
		Sound.play("click")
		if Pop.isOpen(sec.win, "dd" .. tostring(e)) then Pop.close(sec.win) return end
		local count = #options
		local searchable = cfg.Search or count > 7
		local rows = math.min(count, 7)
		local pw = math.max(w + 16, cfg.PopupWidth or 132)
		local ph = rows * 28 + 8 + (searchable and 34 or 0)
		local f = Pop.panel(sec.win, pw, ph, "Options")
		local query = ""
		local top = 4
		local scroll = Util.new("ScrollingFrame", {Name = "List", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, rows * 28), Position = UDim2.fromOffset(4, 4 + (searchable and 34 or 0)), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, Parent = f})
		Theme.bind(scroll, {ScrollBarImageColor3 = "ctl2"})
		Util.list(scroll, 0)
		local rowsMap = {}
		local function paintRow(o, r)
			local on = multi and selected[optValue(o)] or (not multi and single == optValue(o))
			r.check.Visible = on and true or false
			Theme.bind(r.lab, {TextColor3 = on and "ink" or "sub"})
		end
		for i, o in options do
			local r = Util.new("TextButton", {Name = optName(o), Size = UDim2.new(1, 0, 0, 28), Text = "", BackgroundTransparency = 1, LayoutOrder = i, Parent = scroll})
			Util.corner(r, Theme.radii[4] - 1)
			Theme.bind(r, {BackgroundColor3 = "ctl2"})
			local lab = Util.text(r, {Text = optName(o), TextSize = 12, Weight = "Medium", Size = UDim2.new(1, -34, 1, 0), Position = UDim2.fromOffset(10, 0)})
			local ck = Icons.create(r, "check", 13, "ink")
			ck.Position = UDim2.new(1, -23, 0.5, -6.5)
			local rec = {row = r, lab = lab, check = ck, name = optName(o):lower()}
			rowsMap[i] = rec
			paintRow(o, rec)
			r.MouseEnter:Connect(function() Util.tween(r, 0.08, {BackgroundTransparency = 0.5}) Sound.play("hover") end)
			r.MouseLeave:Connect(function() Util.tween(r, 0.1, {BackgroundTransparency = 1}) end)
			r.Activated:Connect(function()
				Sound.play("click")
				local v = optValue(o)
				if multi then
					selected[v] = not selected[v] or nil
					paintRow(o, rec)
					show()
					e:Fire(value())
				else
					single = v
					show()
					Pop.close(sec.win)
					e:Fire(v)
				end
			end)
		end
		if searchable then
			local sb = Util.new("Frame", {Name = "SearchBox", Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, top), Parent = f})
			Util.corner(sb, Theme.radii[4] - 1)
			Theme.bind(sb, {BackgroundColor3 = "ctl"})
			local si = Icons.create(sb, "search", 12, "mute")
			si.Position = UDim2.fromOffset(8, 7)
			local tb = Util.new("TextBox", {Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(26, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "Search", TextSize = 12, FontFace = Util.font("Medium"), ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = sb})
			Theme.bind(tb, {TextColor3 = "ink", PlaceholderColor3 = "mute"})
			tb:GetPropertyChangedSignal("Text"):Connect(function()
				query = tb.Text:lower()
				local shown = 0
				for _, rec in rowsMap do
					local v = query == "" or rec.name:find(query, 1, true) ~= nil
					rec.row.Visible = v
					if v then shown += 1 end
				end
				scroll.Size = UDim2.new(1, -8, 0, math.min(shown, 7) * 28)
			end)
		end
		Pop.place(sec.win, f, btn, pw, ph, {alignRight = true})
		Pop.open(sec.win, f, {key = "dd" .. tostring(e)})
		Util.tween(chev, 0.16, {Rotation = 180})
		local cur = sec.win._pop.current
		cur.onClose = function() Util.tween(chev, 0.16, {Rotation = 0}) end
	end
	btn.Activated:Connect(open)
	function e:Set(v, silent)
		if multi then
			selected = {}
			for _, x in v or {} do selected[x] = true end
		else
			single = v
		end
		show()
		if not silent then self:Fire(value()) end
	end
	function e:Get() return value() end
	function e:Refresh(list, keep)
		options = list
		if not keep then initDefault() end
		show()
	end
	return e
end

local function toHSV(c)
	local h, s, v = c:ToHSV()
	return h, s, v
end

T.ColorPicker = function(sec, cfg)
	local e
	if cfg.Inline then
		e = setmetatable({row = cfg.Parent, sec = sec, win = sec.win, cfg = cfg, name = cfg.Name, Changed = Util.Signal.new(), maid = Util.Maid.new()}, E.Elem)
	else
		e = E.newRow(sec, cfg)
	end
	local parent = cfg.Inline and cfg.Parent or e.right
	local color = cfg.Default or Color3.fromRGB(120, 120, 126)
	local h, s, v = toHSV(color)
	local sw = Util.new("TextButton", {Name = "Swatch", Size = UDim2.fromOffset(C, C), Text = "", BackgroundTransparency = 0, LayoutOrder = 40, Parent = parent})
	Util.corner(sw, Theme.radii[4] - 1)
	sw.BackgroundColor3 = color
	Anim.pressable(sw, {depth = 0.92})
	local ring = Theme.stroke(sw, "ink", 0.85)
	ring.Enabled = true
	local function apply(silent)
		color = Color3.fromHSV(h, s, v)
		sw.BackgroundColor3 = color
		if not silent then e:Fire(color) end
	end
	local pickerParts
	local function sync()
		if not pickerParts then return end
		pickerParts.sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		pickerParts.cursor.Position = UDim2.fromScale(s, 1 - v)
		pickerParts.hueCursor.Position = UDim2.fromScale(h, 0.5)
		pickerParts.hex.Text = Util.hex(color)
		pickerParts.preview.BackgroundColor3 = color
	end
	local drag
	local function open()
		Sound.play("click")
		local win = sec.win
		if Pop.isOpen(win, "color" .. tostring(e)) then Pop.close(win) return end
		local pw, ph = 190, 218
		local f = Pop.panel(win, pw, ph, "ColorPicker")
		local sv = Util.new("Frame", {Name = "SV", Size = UDim2.fromOffset(166, 110), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.fromHSV(h, 1, 1), ClipsDescendants = true, Parent = f})
		Util.corner(sv, 8)
		local white = Util.new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sv})
		Util.new("UIGradient", {Transparency = NumberSequence.new(0, 1), Parent = white})
		local black = Util.new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = sv})
		Util.new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black})
		local cursor = Util.new("Frame", {Name = "Cursor", Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = sv})
		Util.pill(cursor)
		Util.stroke(cursor, Color3.new(0, 0, 0), 1, 0.4)
		local svHit = Util.new("TextButton", {Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 4, Parent = sv})
		local hue = Util.new("Frame", {Name = "Hue", Size = UDim2.fromOffset(166, 10), Position = UDim2.fromOffset(12, 130), BackgroundColor3 = Color3.new(1, 1, 1), Parent = f})
		Util.pill(hue)
		local stops = {}
		for i = 0, 6 do stops[#stops + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1, 1, 1)) end
		stops[#stops] = ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1))
		Util.new("UIGradient", {Color = ColorSequence.new(stops), Parent = hue})
		local hueCursor = Util.new("Frame", {Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(h, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = hue})
		Util.pill(hueCursor)
		Util.stroke(hueCursor, Color3.new(0, 0, 0), 1, 0.4)
		local hueHit = Util.new("TextButton", {Size = UDim2.new(1, 0, 1, 8), Position = UDim2.fromOffset(0, -4), Text = "", ZIndex = 4, Parent = hue})
		local row = Util.new("Frame", {Name = "HexRow", BackgroundTransparency = 1, Size = UDim2.fromOffset(166, 24), Position = UDim2.fromOffset(12, 152), Parent = f})
		local preview = Util.new("Frame", {Name = "Preview", Size = UDim2.fromOffset(24, 24), BackgroundColor3 = color, Parent = row})
		Util.corner(preview, 7)
		local hexBox = E.ctlFrame(row, {Name = "Hex", Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(30, 0)})
		local hex = Util.new("TextBox", {Size = UDim2.new(1, -34, 1, 0), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1, Text = Util.hex(color), TextSize = 12, FontFace = Util.font("Medium"), ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = hexBox})
		Theme.bind(hex, {TextColor3 = "ink"})
		local cp = Util.new("TextButton", {Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -24, 0, 1), Text = "", BackgroundTransparency = 1, Parent = hexBox})
		local cpi = Icons.create(cp, "copy", 12, "mute")
		cpi.Position = UDim2.fromOffset(5, 5)
		cp.Activated:Connect(function()
			if setclipboard then setclipboard(Util.hex(color)) end
			K.Notify.new({Title = "Copied", Text = Util.hex(color), Type = "success", Duration = 1.6, Style = "island"})
		end)
		hex.FocusLost:Connect(function()
			local c = Util.fromHex(hex.Text)
			if c then
				h, s, v = toHSV(c)
				apply()
				sync()
			else
				hex.Text = Util.hex(color)
			end
		end)
		local presets = cfg.Presets or {}
		local py = 184
		for i, pc in presets do
			if i > 8 then break end
			local p = Util.new("TextButton", {Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(12 + (i - 1) * 21, py), Text = "", BackgroundColor3 = pc, Parent = f})
			Util.corner(p, 5)
			p.Activated:Connect(function() h, s, v = toHSV(pc) apply() sync() end)
		end
		pickerParts = {sv = sv, cursor = cursor, hueCursor = hueCursor, hex = hex, preview = preview}
		svHit.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = "sv" end
		end)
		hueHit.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = "hue" end
		end)
		local function update(pos)
			if drag == "sv" then
				local ap, asz = sv.AbsolutePosition, sv.AbsoluteSize
				s = Util.clamp((pos.X - ap.X) / asz.X, 0, 1)
				v = 1 - Util.clamp((pos.Y - ap.Y) / asz.Y, 0, 1)
			elseif drag == "hue" then
				local ap, asz = hue.AbsolutePosition, hue.AbsoluteSize
				h = Util.clamp((pos.X - ap.X) / asz.X, 0, 0.999)
			else
				return
			end
			apply()
			sync()
		end
		local m1 = UIS.InputChanged:Connect(function(i)
			if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(Util.inputPos(i)) end
		end)
		local m2 = UIS.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = nil end
		end)
		svHit.InputBegan:Connect(function(i) if drag then update(Util.inputPos(i)) end end)
		hueHit.InputBegan:Connect(function(i) if drag then update(Util.inputPos(i)) end end)
		Pop.place(win, f, sw, pw, ph, {alignRight = true})
		Pop.open(win, f, {key = "color" .. tostring(e)})
		win._pop.current.onClose = function() m1:Disconnect() m2:Disconnect() pickerParts = nil drag = nil end
		sync()
	end
	sw.Activated:Connect(open)
	function e:Set(c, silent)
		h, s, v = toHSV(c)
		apply(true)
		sync()
		if not silent then self:Fire(color) end
	end
	function e:Get() return color end
	if cfg.Inline then
		e.Get = function() return color end
	end
	return e
end

return E

end
__F["Controls3"] = function(...)
local K = ...
local Util = K.Util
local Theme = K.Theme
local Icons = K.Icons
local Anim = K.Anim
local Sound = K.Sound
local E = K.Elements
local T = E.types

local function elem(sec, cfg, row)
	local e = setmetatable({row = row, sec = sec, win = sec.win, cfg = cfg, name = cfg.Name, Changed = Util.Signal.new(), maid = Util.Maid.new()}, E.Elem)
	sec.elems[#sec.elems + 1] = e
	return e
end

local function header(row, cfg)
	if not cfg.Name then return 0 end
	local l = Util.text(row, {Text = cfg.Name, TextSize = 13, Weight = "Medium", Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18)})
	Theme.bind(l, {TextColor3 = "ink"})
	return 28
end

T.Radio = function(sec, cfg)
	sec.n += 1
	local opts = cfg.Options or {}
	local row = Util.new("Frame", {Name = cfg.Name or "Radio", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = sec.n, Parent = sec.tile})
	local e = elem(sec, cfg, row)
	Util.list(row, 0)
	if cfg.Name then
		local h = Util.new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 0, Parent = row})
		local l = Util.text(h, {Text = cfg.Name, TextSize = 13, Weight = "Medium", Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 18)})
		Theme.bind(l, {TextColor3 = "ink"})
	end
	local value = cfg.Default or opts[1]
	local dots = {}
	local function paint(animate)
		for name, d in dots do
			local on = name == value
			Util.tween(d.ring, animate and 0.16 or 0, {BackgroundColor3 = Theme.resolve(on and "a1" or "ctl")}, Enum.EasingStyle.Quad)
			Util.tween(d.dot, animate and 0.2 or 0, {Size = on and UDim2.fromOffset(8, 8) or UDim2.fromOffset(0, 0)}, Enum.EasingStyle.Back)
			Theme.bind(d.label, {TextColor3 = on and "ink" or "sub"})
		end
	end
	for i, name in opts do
		local b = Util.new("TextButton", {Name = name, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", LayoutOrder = i, Parent = row})
		local ring = Util.new("Frame", {Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(14, 7), Parent = b})
		Util.pill(ring)
		local dot = Util.new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0), Parent = ring})
		Util.pill(dot)
		Theme.bind(dot, {BackgroundColor3 = "on"})
		local label = Util.text(b, {Text = name, TextSize = 12, Weight = "Medium", Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -52, 1, 0)})
		dots[name] = {ring = ring, dot = dot, label = label}
		Anim.pressable(b, {depth = 0.98})
		b.Activated:Connect(function()
			if value == name then return end
			value = name
			Sound.play("click")
			paint(true)
			e:Fire(value)
		end)
	end
	paint(false)
	e.maid:Add(Theme.changed:Connect(function() paint(false) end))
	function e:Set(v, silent) value = v paint(true) if not silent then self:Fire(v) end end
	function e:Get() return value end
	return e
end

T.Chips = function(sec, cfg)
	sec.n += 1
	local opts = cfg.Options or {}
	local row = Util.new("Frame", {Name = cfg.Name or "Chips", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = sec.n, Parent = sec.tile})
	local e = elem(sec, cfg, row)
	Util.list(row, 0)
	if cfg.Name then
		local h = Util.new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 0, Parent = row})
		local l = Util.text(h, {Text = cfg.Name, TextSize = 13, Weight = "Medium", Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 18)})
		Theme.bind(l, {TextColor3 = "ink"})
	end
	local wrap = Util.new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = row})
	Util.pad(wrap, 12, 2, 12, 10)
	local lay = Util.list(wrap, 6, Enum.FillDirection.Horizontal)
	lay.Wraps = true
	local multi = cfg.Multi
	local value = {}
	if multi then
		for _, v in cfg.Default or {} do value[v] = true end
	else
		value[cfg.Default or opts[1]] = true
	end
	local chips = {}
	local function paint(animate)
		for name, c in chips do
			local on = value[name] == true
			Util.tween(c, animate and 0.16 or 0, {BackgroundColor3 = Theme.resolve(on and "ink" or "ctl")}, Enum.EasingStyle.Quad)
			Theme.bind(c, {TextColor3 = on and "bg" or "sub"})
		end
	end
	local function list()
		local out = {}
		for _, name in opts do if value[name] then out[#out + 1] = name end end
		return out
	end
	for i, name in opts do
		local c = Util.new("TextButton", {Name = name, Size = UDim2.new(0, 0, 0, 24), AutomaticSize = Enum.AutomaticSize.X, Text = name, TextSize = 11, FontFace = Util.font("SemiBold"), BackgroundTransparency = 0, LayoutOrder = i, Parent = wrap})
		Util.pad(c, 10, 0, 10, 0)
		Util.pill(c)
		chips[name] = c
		Anim.pressable(c, {depth = 0.94})
		c.Activated:Connect(function()
			Sound.play("click")
			if multi then
				value[name] = not value[name] or nil
			else
				value = {[name] = true}
			end
			paint(true)
			e:Fire(multi and list() or name)
		end)
	end
	paint(false)
	e.maid:Add(Theme.changed:Connect(function() paint(false) end))
	function e:Get() return multi and list() or list()[1] end
	function e:Set(v, silent)
		value = {}
		if multi then for _, x in v do value[x] = true end else value[v] = true end
		paint(true)
		if not silent then self:Fire(self:Get()) end
	end
	return e
end

T.Stepper = function(sec, cfg)
	local e = E.newRow(sec, cfg)
	local min, max, step = cfg.Min or 0, cfg.Max or 10, cfg.Step or 1
	local value = Util.clamp(cfg.Default or min, min, max)
	local box = E.ctlFrame(e.right, {Size = UDim2.fromOffset(92, E.C), Name = "Stepper"})
	local function btn(txt, x)
		local b = Util.new("TextButton", {Size = UDim2.fromOffset(24, E.C), Position = UDim2.fromOffset(x, 0), BackgroundTransparency = 1, Text = "", Parent = box})
		local ic = Icons.create(b, txt, 13, "sub")
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.5)
		b.MouseEnter:Connect(function() Icons.tint(ic, "ink") end)
		b.MouseLeave:Connect(function() Icons.tint(ic, "sub") end)
		Anim.pressable(b, {depth = 0.9})
		return b
	end
	local minus, plus = btn("minus", 0), btn("plus", 68)
	local readout = Util.text(box, {Text = "", TextSize = 12, Weight = "SemiBold", Position = UDim2.fromOffset(24, 0), Size = UDim2.fromOffset(44, E.C), TextXAlignment = Enum.TextXAlignment.Center})
	Theme.bind(readout, {TextColor3 = "ink"})
	local function show() readout.Text = Util.fmt(value, step) .. (cfg.Suffix or "") end
	local function set(v, silent)
		v = Util.clamp(Util.round(v, step), min, max)
		if v == value then return end
		value = v
		show()
		if not silent then e:Fire(value) end
	end
	minus.Activated:Connect(function() Sound.play("click") set(value - step) end)
	plus.Activated:Connect(function() Sound.play("click") set(value + step) end)
	show()
	function e:Set(v, silent) set(v, silent) end
	function e:Get() return value end
	return e
end

T.List = function(sec, cfg)
	sec.n += 1
	local row = Util.new("Frame", {Name = cfg.Name or "List", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = sec.n, Parent = sec.tile})
	local e = elem(sec, cfg, row)
	Util.list(row, 0)
	local items = {}
	local selected
	local function paint(animate)
		for _, it in items do
			local on = it.key == selected
			Util.tween(it.hl, animate and 0.14 or 0, {BackgroundTransparency = on and 0.3 or 1}, Enum.EasingStyle.Quad)
			Icons.tint(it.tick, on and "ink" or "faint")
			it.tick.Visible = on
		end
	end
	function e:Add(entry)
		local key = entry.Key or entry.Name
		local b = Util.new("TextButton", {Name = key, Size = UDim2.new(1, 0, 0, entry.Text and 40 or 32), BackgroundTransparency = 1, Text = "", LayoutOrder = #items + 1, Parent = row})
		local hl = Util.new("Frame", {Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), BackgroundTransparency = 1, Parent = b})
		Util.corner(hl, Theme.radii[3])
		Theme.bind(hl, {BackgroundColor3 = "ctl"})
		local ic = Icons.create(b, entry.Icon or "circle", 14, "sub")
		ic.Position = UDim2.new(0, 14, 0.5, -7)
		local n = Util.text(b, {Text = entry.Name, TextSize = 12, Weight = "Medium", Position = UDim2.new(0, 38, 0, entry.Text and 6 or 0), Size = UDim2.new(1, -90, 0, entry.Text and 16 or 32)})
		Theme.bind(n, {TextColor3 = "ink"})
		if entry.Text then
			local d = Util.text(b, {Text = entry.Text, TextSize = 10, Weight = "Medium", Position = UDim2.fromOffset(38, 22), Size = UDim2.new(1, -90, 0, 12)})
			Theme.bind(d, {TextColor3 = "mute"})
		end
		local tick = Icons.create(b, "check", 13, "ink")
		tick.Position = UDim2.new(1, -28, 0.5, -6.5)
		tick.Visible = false
		Anim.pressable(b, {depth = 0.985})
		b.MouseEnter:Connect(function() if selected ~= key then Util.tween(hl, 0.1, {BackgroundTransparency = 0.6}) end end)
		b.MouseLeave:Connect(function() if selected ~= key then Util.tween(hl, 0.14, {BackgroundTransparency = 1}) end end)
		b.Activated:Connect(function()
			Sound.play("click")
			if cfg.Select ~= false then selected = key paint(true) end
			e:Fire(key)
			if entry.Callback then Util.safe(entry.Callback, key) end
		end)
		items[#items + 1] = {key = key, hl = hl, tick = tick, button = b}
		return b
	end
	for _, entry in cfg.Items or {} do
		e:Add(type(entry) == "string" and {Name = entry} or entry)
	end
	selected = cfg.Default
	paint(false)
	function e:Set(k, silent) selected = k paint(true) if not silent then self:Fire(k) end end
	function e:Get() return selected end
	return e
end

T.Console = function(sec, cfg)
	sec.n += 1
	local h = cfg.Height or 120
	local row = Util.new("Frame", {Name = cfg.Name or "Console", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h + 16), LayoutOrder = sec.n, Parent = sec.tile})
	local e = elem(sec, cfg, row)
	local box = Util.new("ScrollingFrame", {Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8), BackgroundTransparency = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, Parent = row})
	Util.corner(box, Theme.radii[4])
	Theme.bind(box, {BackgroundColor3 = "ctl", ScrollBarImageColor3 = "ctl2"})
	Util.pad(box, 8, 6, 8, 6)
	Util.list(box, 2)
	local colors = {info = "sub", ok = "ink", warn = "ink", error = "danger"}
	local count = 0
	local limit = cfg.Limit or 80
	function e:Log(text, level)
		count += 1
		local line = Util.text(box, {Text = os.date("%H:%M:%S") .. "  " .. text, TextSize = 11, Weight = "Medium", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = count, TextWrapped = true})
		Theme.bind(line, {TextColor3 = colors[level or "info"] or "sub"})
		local kids = {}
		for _, c in box:GetChildren() do if c:IsA("TextLabel") then kids[#kids + 1] = c end end
		if #kids > limit then kids[1]:Destroy() end
		box.CanvasPosition = Vector2.new(0, 1e6)
	end
	function e:Clear()
		for _, c in box:GetChildren() do if c:IsA("TextLabel") then c:Destroy() end end
	end
	function e:Get() return count end
	return e
end

T.Picker = function(sec, cfg)
	sec.n += 1
	local items = cfg.Items or {}
	local cols = cfg.Columns or 2
	local row = Util.new("Frame", {Name = cfg.Name or "Picker", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = sec.n, Parent = sec.tile})
	local e = elem(sec, cfg, row)
	local top = header(row, cfg)
	local grid = Util.new("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = row})
	Util.pad(grid, 8, 4, 8, 8)
	local lay = Util.new("UIGridLayout", {CellSize = UDim2.new(1 / cols, -6, 0, cfg.CardHeight or 58), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid})
	local _ = lay
	local value = cfg.Default
	local cards = {}
	local function paint(animate)
		for name, c in cards do
			local on = name == value
			Util.tween(c.bg, animate and 0.16 or 0, {BackgroundColor3 = Theme.resolve(on and "ink" or "ctl")}, Enum.EasingStyle.Quad)
			Theme.bind(c.name, {TextColor3 = on and "bg" or "ink"})
			Icons.tint(c.icon, on and "bg" or "sub")
		end
	end
	for i, it in items do
		it = type(it) == "string" and {Name = it} or it
		local b = Util.new("TextButton", {Name = it.Name, BackgroundTransparency = 1, Text = "", LayoutOrder = i, Parent = grid})
		local bg = Util.new("Frame", {Size = UDim2.fromScale(1, 1), Parent = b})
		Util.corner(bg, Theme.radii[3])
		local ic = Icons.create(b, it.Icon or "swords", 18, "sub")
		ic.Position = UDim2.fromOffset(12, 10)
		local n = Util.text(b, {Text = it.Name, TextSize = 12, Weight = "SemiBold", Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 16)})
		cards[it.Name] = {bg = bg, name = n, icon = ic}
		if it.Locked then
			local lk = Icons.create(b, "lock", 12, "mute")
			lk.AnchorPoint = Vector2.new(1, 0)
			lk.Position = UDim2.new(1, -10, 0, 10)
		end
		Anim.pressable(b, {depth = 0.95})
		b.Activated:Connect(function()
			if it.Locked then
				Sound.play("error")
				if sec.win then sec.win:Notify({Title = "Locked", Text = it.LockReason or "Not available on your plan", Type = "warn", Duration = 2.4}) end
				return
			end
			if value == it.Name then return end
			value = it.Name
			Sound.play("click")
			paint(true)
			e:Fire(value)
		end)
	end
	paint(false)
	e.maid:Add(Theme.changed:Connect(function() paint(false) end))
	function e:Set(v, silent) value = v paint(true) if not silent then self:Fire(v) end end
	function e:Get() return value end
	return e
end

return E

end
__F["Lock"] = function(...)
local K = ...
local Util = K.Util
local Theme = K.Theme
local Icons = K.Icons
local Anim = K.Anim
local Sound = K.Sound

local Lock = {}
Lock.effects = {"Frost", "Dim", "Stripes", "Blur"}

local function stripes(parent)
	local f = Util.new("Frame", {Name = "Stripes", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = parent})
	local pts = {}
	local n = 16
	for i = 0, n do
		pts[#pts + 1] = ColorSequenceKeypoint.new(i / n, (i % 2 == 0) and Color3.new(1, 1, 1) or Color3.new(0.78, 0.78, 0.78))
	end
	Util.new("UIGradient", {Rotation = 45, Color = ColorSequence.new(pts), Parent = f})
	return f
end

function Lock.cover(parent, cfg)
	cfg = cfg or {}
	local effect = cfg.Effect or "Frost"
	local top = cfg.Top or 0
	local cover = Util.new("TextButton", {Name = "LockCover", Size = UDim2.new(1, 0, 1, -top), Position = UDim2.fromOffset(0, top), Text = "", ZIndex = 30, BackgroundTransparency = 1, Parent = parent})
	local fill = Util.new("Frame", {Name = "Fill", Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = cover})
	Util.corner(fill, Theme.radii[3] + 2)
	Theme.bind(fill, {BackgroundColor3 = "sheet"})
	if effect == "Dim" then
		fill.BackgroundTransparency = 0.18
	elseif effect == "Stripes" then
		fill.BackgroundTransparency = 0.05
		local s = stripes(fill)
		s.ZIndex = 31
		s.BackgroundTransparency = 0.94
		Util.corner(s, Theme.radii[3] + 2)
	elseif effect == "Blur" then
		fill.BackgroundTransparency = 0.04
	else
		fill.BackgroundTransparency = 0.08
		local g = Util.new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.1)}), Parent = fill})
		local _ = g
	end
	local box = Util.new("Frame", {Name = "Box", BackgroundTransparency = 1, Size = UDim2.fromOffset(250, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), ZIndex = 32, Parent = cover})
	Util.list(box, 6, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center)
	local ring = Util.new("Frame", {Name = "Ring", Size = UDim2.fromOffset(36, 36), LayoutOrder = 1, ZIndex = 32, Parent = box})
	Util.pill(ring)
	Theme.bind(ring, {BackgroundColor3 = "ctl"})
	local ic = Icons.create(ring, "lock", 16, "ink")
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)
	ic.ZIndex = 33
	local title = Util.text(box, {Text = (cfg.Reason or "Premium") .. " feature", TextSize = 13, Weight = "SemiBold", Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, ZIndex = 32})
	Theme.bind(title, {TextColor3 = "ink"})
	local body = Util.text(box, {Text = cfg.Text or ("Unlock this with a " .. (cfg.Reason or "Premium") .. " key.\nEverything behind this is hidden."), TextSize = 11, Weight = "Medium", Size = UDim2.new(1, 0, 0, 28), TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 3, ZIndex = 32})
	Theme.bind(body, {TextColor3 = "sub"})
	local btn = Util.new("TextButton", {Name = "Get", Size = UDim2.new(0, 0, 0, 24), AutomaticSize = Enum.AutomaticSize.X, Text = cfg.Button or ("Get " .. (cfg.Reason or "Premium")), TextSize = 11, FontFace = Util.font("SemiBold"), BackgroundTransparency = 0, LayoutOrder = 4, ZIndex = 32, Parent = box})
	Util.pad(btn, 12, 0, 12, 0)
	Util.corner(btn, Theme.radii[4] - 1)
	Theme.bind(btn, {BackgroundColor3 = "a1", TextColor3 = "on"})
	Anim.pressable(btn, {depth = 0.94})
	btn.Activated:Connect(function()
		Sound.play("click")
		if cfg.Action then Util.safe(cfg.Action) else K.Notify.new({Title = "Premium required", Text = "Enter a premium key to unlock this", Type = "warn", Duration = 2.5}) end
	end)
	cover.Destroying:Connect(function() end)
	return cover
end

function Lock.setEffect(win, name)
	win.lockEffect = name
end

return Lock

end
__F["Config"] = function(...)
local K = ...
local Util = K.Util

local Config = {}
Config.folder = "Kairo"
Config.autosave = true
Config.delay = 1.2
local pending = {}

local function enc(v)
	local t = typeof(v)
	if t == "Color3" then return {__t = "c3", v.R, v.G, v.B} end
	if t == "EnumItem" then return {__t = "enum", v.EnumType and tostring(v.EnumType) or "", v.Name} end
	if t == "table" then
		local o = {}
		for k, x in v do o[k] = enc(x) end
		return o
	end
	return v
end

local function dec(v)
	if type(v) == "table" then
		if v.__t == "c3" then return Color3.new(v[1], v[2], v[3]) end
		if v.__t == "enum" then
			local ok, r = pcall(function() return Enum[v[1]:gsub("^Enum%.", "")][v[2]] end)
			return ok and r or nil
		end
		local o = {}
		for k, x in v do o[k] = dec(x) end
		return o
	end
	return v
end

function Config.path(win, name)
	return Config.folder .. "/" .. (win.cfg.ConfigId or win.cfg.Name or "hub"):gsub("[^%w_%-]", "") .. "_" .. name .. ".json"
end

function Config.supported()
	return writefile ~= nil and readfile ~= nil and isfile ~= nil
end

function Config.collect(win)
	local out = {}
	for flag, e in win.options do
		if e.Get and not e.noSave then out[flag] = enc(e:Get()) end
	end
	return out
end

function Config.apply(win, data)
	for flag, v in data do
		local e = win.options[flag]
		if e and e.Set then
			local ok = pcall(function() e:Set(dec(v), false) end)
			local _ = ok
		end
	end
end

function Config.save(win, name)
	if not Config.supported() then return false, "no file access" end
	name = name or "default"
	pcall(function() if makefolder and not isfolder(Config.folder) then makefolder(Config.folder) end end)
	local ok, err = pcall(function() writefile(Config.path(win, name), Util.HttpService:JSONEncode(Config.collect(win))) end)
	return ok, err
end

function Config.load(win, name)
	if not Config.supported() then return false, "no file access" end
	name = name or "default"
	local p = Config.path(win, name)
	if not isfile(p) then return false, "missing" end
	local ok, data = pcall(function() return Util.HttpService:JSONDecode(readfile(p)) end)
	if not ok then return false, "corrupt" end
	Config.apply(win, data)
	return true
end

function Config.list(win)
	local o = {}
	if not (listfiles and isfolder and isfolder(Config.folder)) then return o end
	local prefix = Config.path(win, ""):gsub("%.json$", "")
	for _, f in listfiles(Config.folder) do
		f = f:gsub("\\", "/")
		local n = f:match("([^/]+)_([^/_]+)%.json$")
		if n and f:find(prefix:gsub("%-", "%%-"), 1, false) then o[#o + 1] = f:match("_([^/_]+)%.json$") end
	end
	return o
end

function Config.delete(win, name)
	if delfile and isfile(Config.path(win, name)) then delfile(Config.path(win, name)) return true end
	return false
end

function Config.dirty(win)
	if not Config.autosave or not Config.supported() or win._loading then return end
	pending[win] = os.clock()
	task.delay(Config.delay, function()
		if pending[win] and os.clock() - pending[win] >= Config.delay - 0.05 then
			pending[win] = nil
			Config.save(win, "auto")
		end
	end)
end

function Config.autoload(win)
	win._loading = true
	local ok = Config.load(win, "auto")
	win._loading = false
	return ok
end

return Config

end
__F["Search"] = function(...)
local K = ...
local Util = K.Util
local Theme = K.Theme
local Icons = K.Icons
local Anim = K.Anim
local Sound = K.Sound
local Pop = K.Pop

local UIS = Util.UserInputService

local Search = {}

local function score(entry, q)
	if q == "" then return 1 end
	local name = entry.Name:lower()
	if name == q then return 100 end
	if name:sub(1, #q) == q then return 80 end
	for w in name:gmatch("%S+") do
		if w:sub(1, #q) == q then return 65 end
	end
	if name:find(q, 1, true) then return 50 end
	local extra = ((entry.Keywords and table.concat(entry.Keywords, " ") or "") .. " " .. (entry.Tab and entry.Tab.name or "") .. " " .. (entry.Section and entry.Section.cfg.Name or "")):lower()
	if extra:find(q, 1, true) then return 30 end
	local i = 1
	for c in q:gmatch(".") do
		local f = name:find(c, i, true)
		if not f then return 0 end
		i = f + 1
	end
	return 12
end

local KIND = {Tab = "Tabs", Setting = "Settings", Action = "Actions"}
local TYPEHINT = {Toggle = "Toggle", Slider = "Slider", Dropdown = "Dropdown", Keybind = "Keybind", ColorPicker = "Color", Checkbox = "Checkbox", TextBox = "Input", Number = "Number", Segmented = "Options", Button = "Action", Action = "Action", Buttons = "Action", Label = "Info", Paragraph = "Info", Feature = "Page"}

local function highlight(name, q)
	if q == "" then return name end
	local s, e = name:lower():find(q, 1, true)
	if not s then return name end
	return name:sub(1, s - 1) .. "<b>" .. name:sub(s, e) .. "</b>" .. name:sub(e + 1)
end

function Search.open(win)
	if Pop.isOpen(win, "search") then Pop.close(win) return end
	Sound.play("open")
	local vb = Pop.bounds(win)
	local pw = math.min(380, vb.X - 24)
	local maxRows = 7
	local f = Util.new("CanvasGroup", {Name = "Search", Size = UDim2.fromOffset(pw, 52), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, math.max(30, vb.Y * 0.2))})
	Util.corner(f, Theme.radii[2])
	Theme.bind(f, {BackgroundColor3 = "pop"})
	Theme.stroke(f, "ink", 0.9)
	local bar = Util.new("Frame", {Name = "Bar", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = f})
	local sic = Icons.create(bar, "search", 15, "sub")
	sic.Position = UDim2.fromOffset(14, 14)
	local tb = Util.new("TextBox", {Name = "Query", BackgroundTransparency = 1, Size = UDim2.new(1, -92, 1, 0), Position = UDim2.fromOffset(38, 0), Text = "", PlaceholderText = "Search tabs, settings and actions", TextSize = 13, FontFace = Util.font("Medium"), ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = bar})
	Theme.bind(tb, {TextColor3 = "ink", PlaceholderColor3 = "mute"})
	local x = Util.new("TextButton", {Name = "Clear", Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -34, 0, 11), Text = "", BackgroundTransparency = 0, Parent = bar})
	Util.corner(x, 7)
	Theme.bind(x, {BackgroundColor3 = "ctl"})
	local xi = Icons.create(x, "x", 12, "sub")
	xi.Position = UDim2.fromOffset(5, 5)
	local filters = Util.new("Frame", {Name = "Filters", BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 46), Visible = false, Parent = f})
	Util.list(filters, 4, Enum.FillDirection.Horizontal)
	local list = Util.new("ScrollingFrame", {Name = "Results", BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 0), Position = UDim2.fromOffset(8, 46), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, Parent = f})
	Theme.bind(list, {ScrollBarImageColor3 = "ctl2"})
	Util.list(list, 0)
	local foot = Util.text(f, {Name = "Hints", Text = "↑↓ move    ↵ open    Tab filter    Esc close", TextSize = 10, Weight = "Medium", Size = UDim2.new(1, -24, 0, 22), Position = UDim2.new(0, 12, 1, -24), Visible = false})
	Theme.bind(foot, {TextColor3 = "mute"})
	f.Position = UDim2.new(0.5, 0, 0, math.max(36, vb.Y * 0.3))
	f.AnchorPoint = Vector2.new(0.5, 0)
	Pop.open(win, f, {key = "search", dim = 0.5})

	local filter = "All"
	local results = {}
	local sel = 1
	local rowFrames = {}
	local conns = {}
	local function clearRows()
		for _, r in rowFrames do r:Destroy() end
		rowFrames = {}
	end
	local function run(entry)
		Pop.close(win)
		task.delay(0.12, function()
			Sound.play("click")
			if entry.Run then Util.safe(entry.Run) end
		end)
	end
	local function paintSel()
		for i, r in rowFrames do
			local on = r:GetAttribute("idx") == sel
			if r:GetAttribute("idx") then
				Util.tween(r, 0.08, {BackgroundTransparency = on and 0.35 or 1}, Enum.EasingStyle.Quad)
			end
		end
	end
	local function render()
		clearRows()
		local q = tb.Text:lower()
		local pool = {}
		local counts = {All = 0, Tabs = 0, Settings = 0, Actions = 0}
		for _, e in win.registry do
			local s = score(e, q)
			if s > 0 and (q ~= "" or e.Kind ~= "Setting" or true) then
				counts.All += 1
				counts[KIND[e.Kind]] += 1
				if filter == "All" or KIND[e.Kind] == filter then pool[#pool + 1] = {e = e, s = s} end
			end
		end
		table.sort(pool, function(a, b)
			if a.s ~= b.s then return a.s > b.s end
			return a.e.Name < b.e.Name
		end)
		results = {}
		local order = {"Tab", "Setting", "Action"}
		local y = 0
		local nrows = 0
		local idx = 0
		for _, kind in order do
			local group = {}
			for _, p in pool do if p.e.Kind == kind then group[#group + 1] = p.e end end
			if #group > 0 then
				local h = Util.text(list, {Text = KIND[kind]:upper(), TextSize = 10, Weight = "SemiBold", Size = UDim2.new(1, 0, 0, 22), LayoutOrder = y, TextTransparency = 0})
				h.Position = UDim2.fromOffset(0, 0)
				Util.pad(h, 8, 0, 0, 0)
				Theme.bind(h, {TextColor3 = "mute"})
				rowFrames[#rowFrames + 1] = h
				y += 1
				for _, e in group do
					idx += 1
					nrows += 1
					results[idx] = e
					local r = Util.new("TextButton", {Name = "Result", Size = UDim2.new(1, 0, 0, 34), Text = "", BackgroundTransparency = idx == 1 and 0.35 or 1, LayoutOrder = y, Parent = list})
					r:SetAttribute("idx", idx)
					Util.corner(r, Theme.radii[3])
					Theme.bind(r, {BackgroundColor3 = "ctl"})
					local ico = Icons.create(r, e.Icon or (e.Kind == "Action" and "zap" or (e.Kind == "Tab" and "layout-grid" or "sliders-horizontal")), 14, "sub")
					ico.Position = UDim2.fromOffset(10, 10)
					local nm = Util.text(r, {Text = highlight(e.Name, q), RichText = true, TextSize = 13, Weight = "Medium", Size = UDim2.new(1, -150, 1, 0), Position = UDim2.fromOffset(34, 0)})
					Theme.bind(nm, {TextColor3 = "ink"})
					local hint = e.Kind == "Tab" and "Tab" or (e.Tab and e.Tab.name or "")
					if e.Kind ~= "Tab" and TYPEHINT[e.Type] then hint = hint .. " · " .. TYPEHINT[e.Type] end
					local hl = Util.text(r, {Text = hint, TextSize = 11, Weight = "Medium", Size = UDim2.fromOffset(110, 34), Position = UDim2.new(1, -120, 0, 0), TextXAlignment = Enum.TextXAlignment.Right})
					Theme.bind(hl, {TextColor3 = "mute"})
					r.MouseEnter:Connect(function() sel = r:GetAttribute("idx") paintSel() end)
					r.Activated:Connect(function() run(e) end)
					rowFrames[#rowFrames + 1] = r
					y += 1
				end
			end
		end
		sel = 1
		local hasQuery = q ~= ""
		filters.Visible = hasQuery
		foot.Visible = true
		local top = hasQuery and 74 or 46
		list.Position = UDim2.fromOffset(8, top)
		local rowsH = 0
		for _, r in rowFrames do rowsH += r.Size.Y.Offset end
		local lh = math.min(rowsH, maxRows * 34 + 22 * 2)
		list.Size = UDim2.new(1, -16, 0, lh)
		local total = top + lh + 30
		if #pool == 0 then
			local none = Util.text(list, {Text = hasQuery and "No results" or "Nothing to show", TextSize = 12, Weight = "Medium", Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Center})
			Theme.bind(none, {TextColor3 = "mute"})
			rowFrames[#rowFrames + 1] = none
			list.Size = UDim2.new(1, -16, 0, 34)
			total = top + 34 + 30
		end
		for _, b in filters:GetChildren() do if b:IsA("TextButton") then b:Destroy() end end
		for i, name in {"All", "Tabs", "Settings", "Actions"} do
			local b = Util.new("TextButton", {Name = name, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Text = name .. " " .. counts[name], TextSize = 11, FontFace = Util.font("SemiBold"), BackgroundTransparency = 0, LayoutOrder = i, Parent = filters})
			Util.pad(b, 10, 0, 10, 0)
			Util.corner(b, 7)
			local on = filter == name
			Theme.bind(b, {BackgroundColor3 = on and "ink" or "ctl", TextColor3 = on and "bg" or "sub"})
			b.Activated:Connect(function() filter = name Sound.play("click") render() end)
		end
		Util.tween(f, Anim.dur(0.18), {Size = UDim2.fromOffset(pw, total)}, Enum.EasingStyle.Quint)
		paintSel()
	end
	tb:GetPropertyChangedSignal("Text"):Connect(render)
	x.Activated:Connect(function()
		if tb.Text ~= "" then tb.Text = "" else Pop.close(win) end
	end)
	tb.FocusLost:Connect(function(enter)
		if enter and results[sel] then run(results[sel]) end
	end)
	conns[#conns + 1] = UIS.InputBegan:Connect(function(i)
		if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if i.KeyCode == Enum.KeyCode.Down then
			sel = math.min(#results, sel + 1)
			paintSel()
			local r = rowFrames[1] and nil
			local _ = r
		elseif i.KeyCode == Enum.KeyCode.Up then
			sel = math.max(1, sel - 1)
			paintSel()
		elseif i.KeyCode == Enum.KeyCode.Tab then
			local names = {"All", "Tabs", "Settings", "Actions"}
			local at = table.find(names, filter) or 1
			filter = names[at % #names + 1]
			render()
		elseif i.KeyCode == Enum.KeyCode.Escape then
			Pop.close(win)
		end
	end)
	win._pop.current.onClose = function()
		for _, c in conns do c:Disconnect() end
	end
	render()
	task.defer(function() if tb.Parent then tb:CaptureFocus() end end)
end

return Search

end
__F["Cards"] = function(...)
local K = ...
local Util = K.Util
local Theme = K.Theme
local Icons = K.Icons
local Anim = K.Anim
local Sound = K.Sound
local E = K.Elements

local Cards = {}

local sampler
function Cards.stats()
	if sampler then return sampler end
	local s = {fps = 60, ping = 0, fpsHist = {}, pingHist = {}, changed = Util.Signal.new()}
	local frames, acc = 0, 0
	local Stats = game:GetService("Stats")
	s.conn = Util.RunService.RenderStepped:Connect(function(dt)
		frames += 1
		acc += dt
		if acc >= 0.5 then
			s.fps = math.floor(frames / acc + 0.5)
			frames, acc = 0, 0
			local ok, p = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
			s.ping = ok and math.floor(p + 0.5) or s.ping
			local fh, ph = s.fpsHist, s.pingHist
			fh[#fh + 1] = s.fps
			ph[#ph + 1] = s.ping
			if #fh > 14 then table.remove(fh, 1) end
			if #ph > 14 then table.remove(ph, 1) end
			s.changed:Fire(s)
		end
	end)
	sampler = s
	return s
end

function Cards.card(parent, props)
	local f = Util.new("Frame", Util.merge({Name = "Card", Parent = parent}, props))
	Util.corner(f, Theme.radii[3] + 2)
	Theme.bind(f, {BackgroundColor3 = props and props.Color or "tile"})
	Theme.stroke(f, "ink", 0.93)
	return f
end

local function spark(parent, bars, w, h)
	local f = Util.new("Frame", {Name = "Spark", BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h), Parent = parent})
	local items = {}
	local bw = (w - (bars - 1) * 2) / bars
	for i = 1, bars do
		local b = Util.new("Frame", {Size = UDim2.fromOffset(bw, 4), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset((i - 1) * (bw + 2), h), Parent = f})
		Util.corner(b, 1)
		Theme.bind(b, {BackgroundColor3 = i == bars and "ink" or "faint"})
		items[i] = b
	end
	local self = {frame = f}
	function self.set(hist, lo, hi)
		lo, hi = lo or 0, hi or 1
		for i = 1, bars do
			local v = hist[#hist - bars + i]
			local fr = v and Util.clamp((v - lo) / math.max(hi - lo, 1e-6), 0.08, 1) or 0.08
			Util.tween(items[i], 0.25, {Size = UDim2.fromOffset(bw, math.max(2, h * fr))}, Enum.EasingStyle.Quint)
		end
	end
	return self
end

function Cards.stat(parent, cfg)
	local card = Cards.card(parent, {Size = cfg.Size or UDim2.new(0.5, -4, 0, cfg.Height or 56)})
	local l = Util.text(card, {Text = cfg.Label:upper(), TextSize = 9, Weight = "SemiBold", Position = UDim2.fromOffset(12, 9), Size = UDim2.new(1, -24, 0, 12)})
	Theme.bind(l, {TextColor3 = "mute"})
	local v = Util.text(card, {Text = "0", TextSize = cfg.ValueSize or 22, Weight = "Bold", Position = UDim2.fromOffset(12, 21), Size = UDim2.new(0, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None})
	Theme.bind(v, {TextColor3 = "ink"})
	local u = Util.text(card, {Text = cfg.Unit or "", TextSize = 11, Weight = "Medium", Size = UDim2.fromOffset(30, 14), Position = UDim2.fromOffset(12, 32)})
	Theme.bind(u, {TextColor3 = "mute"})
	local sp = cfg.Spark and spark(card, 9, 34, 22)
	if sp then sp.frame.AnchorPoint = Vector2.new(1, 1) sp.frame.Position = UDim2.new(1, -12, 1, -10) end
	local self = {frame = card}
	function self.Set(val, hist, lo, hi)
		v.Text = tostring(val)
		u.Position = UDim2.fromOffset(12 + #tostring(val) * (cfg.ValueSize or 22) * 0.56 + 4, (cfg.ValueSize or 22) > 18 and 32 or 24)
		if sp and hist then sp.set(hist, lo, hi) end
	end
	return self
end

function Cards.quickGrid(parent, items, cols)
	cols = cols or #items
	local g = Util.new("Frame", {Name = "Quick", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Parent = parent})
	for i, it in items do
		local b = Util.new("TextButton", {Name = it.Name, Size = UDim2.new(1 / cols, -6, 1, 0), Position = UDim2.new((i - 1) / cols, (i - 1) * 6 / cols * 0 + (i == 1 and 0 or 3), 0, 0), Text = "", BackgroundTransparency = 0, Parent = g})
		Util.corner(b, Theme.radii[3])
		Theme.bind(b, {BackgroundColor3 = "tile"})
		Theme.gradient(b, 0.08)
		Theme.stroke(b, "ink", 0.93)
		E.hoverCtl(b, b, "tile", "ctl")
		Anim.pressable(b, {depth = 0.95})
		local ic = Icons.create(b, it.Icon, 16, "sub")
		ic.AnchorPoint = Vector2.new(0.5, 0)
		ic.Position = UDim2.new(0.5, 0, 0, 8)
		local t = Util.text(b, {Text = it.Name, TextSize = 10, Weight = "SemiBold", Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -17), TextXAlignment = Enum.TextXAlignment.Center})
		Theme.bind(t, {TextColor3 = "sub"})
		b.Activated:Connect(function()
			Sound.play("click")
			if it.Callback then Util.safe(it.Callback, b, t) end
		end)
		it.button, it.label = b, t
	end
	return g
end

function Cards.listCard(parent, cfg)
	local card = Cards.card(parent, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y})
	Util.list(card, 0)
	local head = Util.new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 0, Parent = card})
	local t = Util.text(head, {Text = cfg.Title, TextSize = 12, Weight = "SemiBold", Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -60, 1, 0)})
	Theme.bind(t, {TextColor3 = "ink"})
	if cfg.Action then
		local a = Util.new("TextButton", {Text = cfg.Action, TextSize = 11, FontFace = Util.font("SemiBold"), Size = UDim2.fromOffset(40, 28), Position = UDim2.new(1, -48, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = head})
		Theme.bind(a, {TextColor3 = "sub"})
		a.Activated:Connect(function() Sound.play("click") if cfg.OnAction then Util.safe(cfg.OnAction) end end)
	end
	for i, r in cfg.Rows do
		local row = Util.new("TextButton", {Name = r.Name, Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Text = "", LayoutOrder = i, Parent = card})
		local hl = Util.new("Frame", {Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), BackgroundTransparency = 1, Parent = row})
		Util.corner(hl, 8)
		Theme.bind(hl, {BackgroundColor3 = "ctl"})
		local ic = Icons.create(row, r.Icon or "zap", 14, "sub")
		ic.Position = UDim2.fromOffset(12, 9)
		local n = Util.text(row, {Text = r.Name, TextSize = 12, Weight = "Medium", Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -80, 1, 0)})
		Theme.bind(n, {TextColor3 = "ink"})
		local tail = Icons.create(row, r.Dismiss and "x" or "chevron-right", 13, "mute")
		tail.Position = UDim2.new(1, -26, 0.5, -6.5)
		row.MouseEnter:Connect(function() Util.tween(hl, 0.1, {BackgroundTransparency = 0.45}) Icons.tint(tail, "ink") end)
		row.MouseLeave:Connect(function() Util.tween(hl, 0.14, {BackgroundTransparency = 1}) Icons.tint(tail, "mute") end)
		row.Activated:Connect(function()
			Sound.play("click")
			if r.Dismiss then
				Util.tween(row, 0.18, {Size = UDim2.new(1, 0, 0, 0)})
				task.delay(0.2, function() row:Destroy() end)
			end
			if r.Callback then Util.safe(r.Callback) end
		end)
	end
	return card
end

local function silhouette(parent)
	local skin = Color3.fromRGB(226, 190, 150)
	local function part(sz, pos, col)
		local p = Util.new("Frame", {Size = UDim2.fromOffset(sz[1], sz[2]), Position = UDim2.fromOffset(pos[1], pos[2]), Parent = parent})
		p.BackgroundColor3 = col
		Util.corner(p, 3)
		return p
	end
	local cx = 0
	local hd = part({22, 22}, {cx - 11, 0}, skin)
	local _ = hd
	part({34, 38}, {cx - 17, 24}, Color3.fromRGB(70, 74, 86))
	part({10, 36}, {cx - 29, 24}, skin)
	part({10, 36}, {cx + 19, 24}, skin)
	part({16, 40}, {cx - 17, 64}, Color3.fromRGB(46, 49, 58))
	part({16, 40}, {cx + 1, 64}, Color3.fromRGB(46, 49, 58))
end

function Cards.profile(parent, cfg)
	local card = Cards.card(parent, {Size = cfg.Size or UDim2.new(1, 0, 1, 0)})
	local stage = Util.new("Frame", {Name = "Stage", BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 120), Position = UDim2.fromOffset(8, 8), Parent = card})
	local ok = false
	local lp = Util.Players.LocalPlayer
	if cfg.Viewport ~= false and lp and lp.Character then
		ok = pcall(function()
			local vp = Util.new("ViewportFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = stage})
			local char = lp.Character
			char.Archivable = true
			local clone = char:Clone()
			if not clone then error("no clone") end
			clone.Parent = vp
			local cam = Instance.new("Camera")
			cam.Parent = vp
			vp.CurrentCamera = cam
			local cf, size = clone:GetBoundingBox()
			local dist = math.max(size.X, size.Y) * 1.7 + 2
			cam.CFrame = CFrame.new(cf.Position + Vector3.new(0, 0.3, dist), cf.Position)
		end)
	end
	if not ok then
		local holder = Util.new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(60, 104), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = stage})
		local inner = Util.new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(30, 0), Parent = holder})
		silhouette(inner)
	end
	local n = Util.text(card, {Text = cfg.Name or "Player", TextSize = 13, Weight = "SemiBold", Position = UDim2.fromOffset(0, 136), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center})
	Theme.bind(n, {TextColor3 = "ink"})
	local h = Util.text(card, {Text = cfg.Handle or "", TextSize = 10, Weight = "Medium", Position = UDim2.fromOffset(0, 153), Size = UDim2.new(1, 0, 0, 12), TextXAlignment = Enum.TextXAlignment.Center})
	Theme.bind(h, {TextColor3 = "sub"})
	local lv = Util.text(card, {Text = cfg.Level or "", TextSize = 10, Weight = "Medium", Position = UDim2.fromOffset(0, 166), Size = UDim2.new(1, 0, 0, 12), TextXAlignment = Enum.TextXAlignment.Center})
	Theme.bind(lv, {TextColor3 = "mute"})
	if cfg.Button then
		local b = E.ctlButton(card, {Text = cfg.Button, Style = "secondary", Size = UDim2.new(1, -16, 0, 26), Padding = false})
		b.AnchorPoint = Vector2.new(0, 1)
		b.Position = UDim2.new(0, 8, 1, -8)
		b.Activated:Connect(function() Sound.play("click") if cfg.Callback then Util.safe(cfg.Callback) end end)
	end
	return card
end

function Cards.welcome(parent, cfg)
	local card = Cards.card(parent, {Size = UDim2.new(1, 0, 0, 76)})
	local hello = Util.text(card, {Text = cfg.Greeting or "GOOD EVENING", TextSize = 9, Weight = "SemiBold", Position = UDim2.fromOffset(12, 9), Size = UDim2.new(0.5, 0, 0, 12)})
	Theme.bind(hello, {TextColor3 = "mute"})
	local name = Util.text(card, {Text = cfg.Name or "Player", TextSize = 18, Weight = "Bold", Position = UDim2.fromOffset(12, 21), Size = UDim2.new(0.5, 0, 0, 24)})
	Theme.bind(name, {TextColor3 = "ink"})
	local meta = Util.new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(0.5, 0, 0, 16), Position = UDim2.fromOffset(12, 50), Parent = card})
	Util.list(meta, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local timeL, tier
	do
		local c1 = Util.new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Parent = meta})
		Util.list(c1, 4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		local ic = Icons.create(c1, "clock", 11, "sub")
		ic.LayoutOrder = 1
		timeL = Util.text(c1, {Text = "00:00", TextSize = 11, Weight = "Medium", Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2})
		Theme.bind(timeL, {TextColor3 = "sub"})
		local c2 = Util.new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = meta})
		Util.list(c2, 4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		local ic2 = Icons.create(c2, "key-round", 11, "sub")
		ic2.LayoutOrder = 1
		tier = Util.text(c2, {Text = cfg.Tier or "Free", TextSize = 11, Weight = "Medium", Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2})
		Theme.bind(tier, {TextColor3 = "sub"})
	end
	local st = Cards.stats()
	local fpsV = Util.text(card, {Text = "0", TextSize = 15, Weight = "Bold", Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(40, 20), TextXAlignment = Enum.TextXAlignment.Right})
	Theme.bind(fpsV, {TextColor3 = "ink"})
	local fpsU = Util.text(card, {Text = "fps", TextSize = 10, Weight = "Medium", Position = UDim2.new(0.5, 42, 0, 14), Size = UDim2.fromOffset(20, 14)})
	Theme.bind(fpsU, {TextColor3 = "mute"})
	local pingV = Util.text(card, {Text = "0", TextSize = 15, Weight = "Bold", Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(40, 20), TextXAlignment = Enum.TextXAlignment.Right})
	Theme.bind(pingV, {TextColor3 = "ink"})
	local pingU = Util.text(card, {Text = "ms", TextSize = 10, Weight = "Medium", Position = UDim2.new(0.5, 42, 0, 44), Size = UDim2.fromOffset(20, 14)})
	Theme.bind(pingU, {TextColor3 = "mute"})
	local sp1 = spark(card, 8, 36, 16)
	sp1.frame.Position = UDim2.new(1, -48, 0, 12)
	local sp2 = spark(card, 8, 36, 16)
	sp2.frame.Position = UDim2.new(1, -48, 0, 42)
	local t0 = os.clock()
	local function refresh()
		fpsV.Text = tostring(st.fps)
		pingV.Text = tostring(st.ping)
		sp1.set(st.fpsHist, 0, 144)
		sp2.set(st.pingHist, 0, 200)
	end
	refresh()
	card.Destroying:Connect(function() end)
	local c = st.changed:Connect(function()
		if not card.Parent then return end
		refresh()
	end)
	local clock = task.spawn(function()
		while card.Parent do
			local s = math.floor(os.clock() - t0)
			timeL.Text = string.format("%02d:%02d", math.floor(s / 60) % 100, s % 60)
			task.wait(1)
		end
	end)
	local self = {frame = card, SetTier = function(t) tier.Text = t end, SetName = function(n) name.Text = n end}
	card.Destroying:Connect(function() c:Disconnect() task.cancel(clock) end)
	return self
end

function Cards.brand(parent, cfg)
	local card = Cards.card(parent, {Size = cfg.Size or UDim2.new(1, 0, 0, 64)})
	local icon = Util.new("Frame", {Name = "Icon", Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(12, 12), Parent = card})
	Util.corner(icon, Theme.radii[3])
	Theme.bind(icon, {BackgroundColor3 = {"ctl2", "a1", 0.3}})
	if cfg.Image then
		Util.new("ImageLabel", {Size = UDim2.fromScale(1, 1), Image = cfg.Image, Parent = icon})
	else
		local ic = Icons.create(icon, cfg.Icon or "message-square", 20, "ink")
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.5)
	end
	local t = Util.text(card, {Text = cfg.Title or "", TextSize = 13, Weight = "SemiBold", Position = UDim2.fromOffset(62, 13), Size = UDim2.new(1, -124, 0, 16)})
	Theme.bind(t, {TextColor3 = "ink"})
	local d = Util.text(card, {Text = cfg.Text or "", TextSize = 11, Weight = "Medium", Position = UDim2.fromOffset(62, 31), Size = UDim2.new(1, -124, 0, 14)})
	Theme.bind(d, {TextColor3 = "sub"})
	local btn = E.ctlButton(card, {Text = cfg.Button or "Open", Style = cfg.Style or "primary", Pad = 14})
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -12, 0.5, 0)
	btn.Activated:Connect(function()
		Sound.play("click")
		if cfg.Copy and setclipboard then
			setclipboard(cfg.Copy)
			K.Notify.new({Title = "Link copied", Text = cfg.Copy, Type = "success", Duration = 2})
		end
		if cfg.Callback then Util.safe(cfg.Callback) end
	end)
	return card
end

function Cards.chart(parent, cfg)
	local h = cfg.Height or 96
	local card = Cards.card(parent, {Size = UDim2.new(1, 0, 0, h)})
	local t = Util.text(card, {Text = cfg.Title or "", TextSize = 12, Weight = "SemiBold", Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 16)})
	Theme.bind(t, {TextColor3 = "ink"})
	local area = Util.new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -24, 1, -38), Position = UDim2.fromOffset(12, 28), Parent = card})
	local bars = {}
	local self = {frame = card}
	function self.Set(data)
		for _, b in bars do b:Destroy() end
		bars = {}
		local n = #data
		if n == 0 then return end
		local mx = 1e-9
		for _, v in data do mx = math.max(mx, v) end
		local gap = 3
		for i, v in data do
			local b = Util.new("Frame", {AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(1 / n, -gap, 0, 2), Position = UDim2.new((i - 1) / n, gap / 2, 1, 0), Parent = area})
			Util.corner(b, 3)
			Theme.bind(b, {BackgroundColor3 = i == n and "a1" or "ctl2"})
			Util.tween(b, 0.4, {Size = UDim2.new(1 / n, -gap, v / mx, 0)}, Enum.EasingStyle.Quint)
			bars[#bars + 1] = b
		end
	end
	if cfg.Data then self.Set(cfg.Data) end
	return self
end

return Cards

end
__F["KeySystem"] = function(...)
local K = ...
local Util = K.Util
local Theme = K.Theme
local Icons = K.Icons
local Anim = K.Anim
local Sound = K.Sound

local KeySystem = {}

local function hwid()
	local ok, id = pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
	return ok and id or "unknown"
end

local function http(url)
	local req = request or http_request or (syn and syn.request)
	if req then
		local ok, res = pcall(req, {Url = url, Method = "GET"})
		if ok and res then return res.StatusCode, res.Body end
		return 0, tostring(res)
	end
	local ok, body = pcall(function() return game:HttpGet(url) end)
	return ok and 200 or 0, ok and body or ""
end

function KeySystem.check(cfg, key, provider)
	if cfg.Validate then
		local ok, a, b = pcall(cfg.Validate, key, provider)
		if not ok then return false, "Validation failed", true end
		return a and true or false, b
	end
	local api = cfg.Api
	if not api then return false, "No key service configured", true end
	local url = (provider and provider.Check or api.Url):gsub("{key}", Util.HttpService:UrlEncode(key)):gsub("{hwid}", hwid())
	local status, body = http(url)
	if status == 0 then return false, "Could not reach the key server", true end
	if api.Check then
		local ok, r, m = pcall(api.Check, status, body, key)
		return ok and r and true or false, m
	end
	local pass = api.Ok or "true"
	return status == 200 and tostring(body):lower():find(pass:lower(), 1, true) ~= nil, nil
end

local function savePath(cfg)
	return "Kairo/" .. (cfg.Name or "hub"):gsub("[^%w]", "") .. ".key"
end

function KeySystem.new(cfg, onSuccess)
	cfg = Util.merge({Name = "Kairo", Sub = "Enter your key", KeyLength = 16, Remember = true, Providers = {{Name = "Linkvertise", Url = ""}}, Theme = nil}, cfg)
	if cfg.Theme then Theme.set(cfg.Theme, true) end
	local gui = Util.new("ScreenGui", {Name = "KairoKey", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 900, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = Util.gui()})
	Util.protect(gui)
	local dim = Util.new("Frame", {Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = gui})
	Util.tween(dim, 0.4, {BackgroundTransparency = cfg.Dim or 0.45}, Enum.EasingStyle.Quad)
	local fitScale = math.min(1, (Util.viewport().X - 24) / 360, (Util.viewport().Y - 24) / 196)
	local root = Util.new("CanvasGroup", {Name = "Popup", Size = UDim2.fromOffset(360, 196), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), GroupTransparency = 1, Parent = gui})
	Util.corner(root, Theme.radii[1])
	Theme.bind(root, {BackgroundColor3 = "bg"})
	Theme.stroke(root, "ink", 0.92)
	local sc = Util.new("UIScale", {Scale = 0.9 * fitScale, Parent = root})
	Util.tween(sc, 0.45, {Scale = fitScale}, Enum.EasingStyle.Back)
	Util.tween(root, 0.3, {GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5)}, Enum.EasingStyle.Quint)
	Sound.play("open")

	local mark = Util.new("Frame", {Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(10, 8), Parent = root})
	Util.corner(mark, 9)
	Theme.bind(mark, {BackgroundColor3 = "ink"})
	local mi = Icons.create(mark, "key-round", 15, "bg")
	mi.AnchorPoint = Vector2.new(0.5, 0.5)
	mi.Position = UDim2.fromScale(0.5, 0.5)
	local t1 = Util.text(root, {Text = cfg.Name, TextSize = 13, Weight = "SemiBold", Position = UDim2.fromOffset(46, 9), Size = UDim2.new(1, -100, 0, 16)})
	Theme.bind(t1, {TextColor3 = "ink"})
	local t2 = Util.text(root, {Text = cfg.Sub, TextSize = 11, Weight = "Medium", Position = UDim2.fromOffset(46, 25), Size = UDim2.new(1, -100, 0, 14)})
	Theme.bind(t2, {TextColor3 = "sub"})
	local help = Util.new("TextButton", {Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -34, 0, 10), Text = "", BackgroundTransparency = 0, Parent = root})
	Util.pill(help)
	Theme.bind(help, {BackgroundColor3 = "ctl"})
	local hi = Icons.create(help, "circle-help", 13, "sub")
	hi.Position = UDim2.fromOffset(5.5, 5.5)
	Anim.pressable(help, {depth = 0.92})

	local card = Util.new("Frame", {Name = "Card", Size = UDim2.new(1, -16, 1, -52), Position = UDim2.fromOffset(8, 44), Parent = root})
	Util.corner(card, Theme.radii[2])
	Theme.bind(card, {BackgroundColor3 = "tile"})
	local lab = Util.text(card, {Text = "License key", TextSize = 10, Weight = "SemiBold", Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -24, 0, 12)})
	Theme.bind(lab, {TextColor3 = "mute"})
	local box = Util.new("Frame", {Name = "Box", Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 22), Parent = card})
	Util.corner(box, Theme.radii[4])
	Theme.bind(box, {BackgroundColor3 = "ctl"})
	local boxStroke = Util.stroke(box, Theme.tokens.danger, 1, 1)
	Theme.bind(boxStroke, {Color = "danger"})
	local kic = Icons.create(box, "key-round", 13, "mute")
	kic.Position = UDim2.fromOffset(9, 6.5)
	local tb = Util.new("TextBox", {Name = "Key", BackgroundTransparency = 1, Size = UDim2.new(1, -66, 1, 0), Position = UDim2.fromOffset(30, 0), Text = "", PlaceholderText = "Paste or type your key", TextSize = 12, FontFace = Util.font("Medium"), ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = box})
	Theme.bind(tb, {TextColor3 = "ink", PlaceholderColor3 = "mute"})
	local mask = Util.text(box, {Name = "Mask", Text = "", TextSize = 12, Weight = "Medium", Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -66, 1, 0), Visible = false})
	Theme.bind(mask, {TextColor3 = "ink"})
	local eye = Util.new("TextButton", {Name = "Eye", Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -26, 0, 2), Text = "", BackgroundTransparency = 1, Visible = false, Parent = box})
	local eyeIc = Icons.create(eye, "eye", 13, "sub")
	eyeIc.Position = UDim2.fromOffset(4.5, 4.5)
	local status = Util.new("Frame", {Name = "Status", BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 52), Parent = card})
	local sIc = Icons.create(status, "info", 12, "mute")
	sIc.Position = UDim2.fromOffset(0, 2)
	local sTx = Util.text(status, {Text = "Paste the key you got from the provider", TextSize = 11, Weight = "Medium", Position = UDim2.fromOffset(17, 0), Size = UDim2.new(1, -17, 1, 0)})
	Theme.bind(sTx, {TextColor3 = "mute"})
	local rem = Util.new("TextButton", {Name = "Remember", BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 70), Parent = card})
	local cb = Util.new("Frame", {Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(0, 2), Parent = rem})
	Util.corner(cb, 6)
	local cbi = Icons.create(cb, "check", 12, "on")
	cbi.AnchorPoint = Vector2.new(0.5, 0.5)
	cbi.Position = UDim2.fromScale(0.5, 0.5)
	local rt = Util.text(rem, {Text = "Remember me for this account", TextSize = 12, Weight = "Medium", Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -28, 1, 0)})
	Theme.bind(rt, {TextColor3 = "ink"})
	local row = Util.new("Frame", {Name = "Actions", BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 24), Position = UDim2.new(0, 12, 1, -36), Parent = card})

	local providers = cfg.Providers
	local provIdx = 1
	local pbtn = Util.new("TextButton", {Name = "Provider", Size = UDim2.fromOffset(100, 24), Text = "", BackgroundTransparency = 0, Parent = row})
	Util.corner(pbtn, Theme.radii[4] - 1)
	Theme.bind(pbtn, {BackgroundColor3 = "ctl"})
	Theme.gradient(pbtn, 0.12)
	local ptx = Util.text(pbtn, {Text = providers[1].Name, TextSize = 12, Weight = "Medium", Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -26, 1, 0)})
	Theme.bind(ptx, {TextColor3 = "ink"})
	local pch = Icons.create(pbtn, "chevron-down", 13, "sub")
	pch.Position = UDim2.new(1, -19, 0.5, -6.5)
	local get = Util.new("TextButton", {Name = "Get", Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(104, 0), Text = "", BackgroundTransparency = 0, Parent = row})
	Util.corner(get, Theme.radii[4] - 1)
	Theme.bind(get, {BackgroundColor3 = "ctl"})
	local gi = Icons.create(get, "message-square", 13, "sub")
	gi.Position = UDim2.fromOffset(5.5, 5.5)
	local go = Util.new("TextButton", {Name = "Continue", Size = UDim2.new(1, -134, 1, 0), Position = UDim2.fromOffset(134, 0), Text = "", BackgroundTransparency = 0, Parent = row})
	Util.corner(go, Theme.radii[4] - 1)
	Theme.gradient(go, 0.16)
	local goRow = Util.new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = go})
	Util.list(goRow, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local goIc = Icons.create(goRow, "arrow-right", 13, "on")
	goIc.LayoutOrder = 1
	local goTx = Util.text(goRow, {Text = "Continue", TextSize = 12, Weight = "SemiBold", Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2})
	Theme.bind(goTx, {TextColor3 = "on"})
	Anim.pressable(go, {depth = 0.96})
	Anim.pressable(get, {depth = 0.92})

	local self = {gui = gui, state = "idle", remember = cfg.Remember, hidden = false}
	local ready = false
	local busy = false

	local function paintCheck(animate)
		local on = self.remember
		Util.tween(cb, animate and 0.16 or 0, {BackgroundColor3 = Theme.resolve(on and "a1" or "ctl")}, Enum.EasingStyle.Quad)
		local p = cbi:IsA("ImageLabel") and "ImageTransparency" or "TextTransparency"
		Util.tween(cbi, animate and 0.16 or 0, {[p] = on and 0 or 1}, Enum.EasingStyle.Quad)
		if animate and on then
			local s = cb:FindFirstChildOfClass("UIScale") or Util.new("UIScale", {Parent = cb})
			s.Scale = 0.8
			Util.tween(s, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
		end
	end
	paintCheck(false)
	local function paintGo()
		local active = ready and not busy
		Theme.bind(go, {BackgroundColor3 = active and "a1" or {"ctl2", "tile", 0.2}})
		Theme.bind(goTx, {TextColor3 = active and "on" or "sub"})
		Icons.tint(goIc, active and "on" or "sub")
	end
	local function setStatus(icon, text, tok)
		Icons.set(sIc, icon)
		Icons.tint(sIc, tok)
		sTx.Text = text
		Theme.bind(sTx, {TextColor3 = tok})
	end
	local function setState(s, msg)
		self.state = s
		local key = tb.Text
		if s == "idle" then
			ready = false
			setStatus("info", "Paste the key you got from the provider", "mute")
		elseif s == "typing" then
			ready = false
			setStatus("info", "Keep typing, " .. #key .. " characters", "mute")
		elseif s == "complete" then
			ready = true
			setStatus("circle-check", "Looks right", "sub")
		elseif s == "checking" then
			ready = false
			setStatus("loader-circle", "Checking with the key server", "sub")
		elseif s == "wrong" then
			ready = #key >= 1
			setStatus("triangle-alert", msg or "That key is not valid", "danger")
			Util.tween(boxStroke, 0.15, {Transparency = 0.1})
		elseif s == "ok" then
			ready = false
			setStatus("circle-check", "Key accepted", "sub")
		end
		if s ~= "wrong" then Util.tween(boxStroke, 0.15, {Transparency = 1}) end
		paintGo()
	end
	local function refreshMask()
		mask.Visible = self.hidden and tb.Text ~= ""
		tb.TextTransparency = (self.hidden and tb.Text ~= "") and 1 or 0
		mask.Text = string.rep("•", #tb.Text)
		Icons.set(eyeIc, self.hidden and "eye-off" or "eye")
	end
	tb:GetPropertyChangedSignal("Text"):Connect(function()
		if busy then return end
		local n = #tb.Text
		eye.Visible = n > 0
		refreshMask()
		if n == 0 then setState("idle")
		elseif n >= cfg.KeyLength then setState("complete")
		else setState("typing") end
	end)
	eye.Activated:Connect(function()
		self.hidden = not self.hidden
		Sound.play("click")
		refreshMask()
	end)
	rem.Activated:Connect(function()
		self.remember = not self.remember
		Sound.play("toggle")
		paintCheck(true)
	end)
	pbtn.Activated:Connect(function()
		Sound.play("click")
		provIdx = provIdx % #providers + 1
		ptx.Text = providers[provIdx].Name
	end)
	get.Activated:Connect(function()
		Sound.play("click")
		local p = providers[provIdx]
		if p.Url and p.Url ~= "" and setclipboard then
			setclipboard(p.Url)
			K.Notify.new({Title = "Link copied", Text = p.Name .. " key link", Type = "success", Duration = 2.2, Style = "pill"})
		else
			K.Notify.new({Title = "No link set", Text = "Add a provider Url in the script", Type = "info", Duration = 2.2, Style = "pill"})
		end
	end)
	help.Activated:Connect(function()
		K.Notify.new({Title = "Need a key?", Text = "Use the link button, finish the steps and paste the key here", Type = "info", Duration = 4})
	end)

	local function shake()
		for i = 1, 5 do
			local dx = (i % 2 == 0 and 1 or -1) * (8 - i)
			Util.tween(root, 0.05, {Position = UDim2.new(0.5, dx, 0.5, 0)}, Enum.EasingStyle.Quad)
			task.wait(0.05)
		end
		Util.tween(root, 0.08, {Position = UDim2.fromScale(0.5, 0.5)}, Enum.EasingStyle.Quad)
	end

	local function spin()
		task.spawn(function()
			local a = 0
			while self.state == "checking" and sIc.Parent do
				a = (a + 24) % 360
				sIc.Rotation = a
				task.wait(0.03)
			end
			sIc.Rotation = 0
		end)
	end

	function self.close()
		Util.tween(root, 0.25, {GroupTransparency = 1, Position = UDim2.fromScale(0.5, 0.53)}, Enum.EasingStyle.Quad)
		Util.tween(sc, 0.25, {Scale = fitScale * 0.94}, Enum.EasingStyle.Quad)
		Util.tween(dim, 0.35, {BackgroundTransparency = 1}, Enum.EasingStyle.Quad)
		task.delay(0.4, function() gui:Destroy() end)
	end

	function self.submit(key)
		if busy then return end
		key = key or tb.Text
		if key == "" then return end
		if tb.Text ~= key then tb.Text = key end
		busy = true
		setState("checking")
		spin()
		Icons.set(goIc, "loader-circle")
		goTx.Text = "Checking"
		task.spawn(function()
			local minWait = os.clock() + 0.7
			local ok, msg = KeySystem.check(cfg, key, providers[provIdx])
			local left = minWait - os.clock()
			if left > 0 then task.wait(left) end
			busy = false
			self.state = ok and "ok" or "wrong"
			if ok then
				setState("ok")
				Icons.set(goIc, "lock-open")
				goTx.Text = "Unlocked"
				Sound.play("success")
				if self.remember and writefile then
					pcall(function()
						if makefolder and not isfolder("Kairo") then makefolder("Kairo") end
						writefile(savePath(cfg), key)
					end)
				elseif delfile and isfile and isfile(savePath(cfg)) then
					pcall(delfile, savePath(cfg))
				end
				local flash = Util.new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, ZIndex = 20, Parent = go})
				Util.corner(flash, Theme.radii[4] - 1)
				Util.tween(flash, 0.5, {BackgroundTransparency = 1}, Enum.EasingStyle.Quad)
				task.wait(0.55)
				self.close()
				K.Notify.new({Title = "Key verified", Text = cfg.SuccessText or "Welcome back", Type = "success", Duration = 3.5})
				if onSuccess then Util.safe(onSuccess, key) end
			else
				setState("wrong", msg)
				Icons.set(goIc, "arrow-right")
				goTx.Text = "Continue"
				Sound.play("error")
				shake()
			end
		end)
	end
	go.Activated:Connect(function()
		Sound.play("click")
		if ready then self.submit() end
	end)
	tb.FocusLost:Connect(function(enter)
		if enter and ready then self.submit() end
	end)
	self.input = tb
	if cfg.Remember and readfile and isfile and isfile(savePath(cfg)) then
		local ok, saved = pcall(readfile, savePath(cfg))
		if ok and saved and saved ~= "" then
			tb.Text = saved
			if cfg.AutoSubmit ~= false then task.delay(0.6, function() self.submit(saved) end) end
		end
	end
	paintGo()
	return self
end

return KeySystem

end
__F["Boot"] = function(...)
local K = ...
local Util = K.Util
local Theme = K.Theme
local Sound = K.Sound

local Boot = {}
Boot.styles = {"Letters", "Fade", "Typewriter", "Slide", "Zoom", "Glitch", "Pulse", "Wipe", "Logo"}

local function letterWidth(ch, size)
	return math.max(size * 0.5, Util.measure(ch, size).X + size * 0.12)
end

local function progressBar(root, y)
	local track = Util.new("Frame", {Name = "Progress", Size = UDim2.fromOffset(180, 3), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, y, 0), BackgroundTransparency = 0, Parent = root})
	Util.pill(track)
	Theme.bind(track, {BackgroundColor3 = "ctl"})
	local fill = Util.new("Frame", {Size = UDim2.fromScale(0, 1), Parent = track})
	Util.pill(fill)
	Theme.bind(fill, {BackgroundColor3 = "ink"})
	local pct = Util.text(root, {Text = "0%", TextSize = 10, Weight = "Medium", Size = UDim2.fromOffset(180, 12), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, y, 8), TextXAlignment = Enum.TextXAlignment.Right})
	Theme.bind(pct, {TextColor3 = "mute"})
	local label = Util.text(root, {Text = "Warming up", TextSize = 10, Weight = "Medium", Size = UDim2.fromOffset(180, 12), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, y, 8), TextXAlignment = Enum.TextXAlignment.Left})
	Theme.bind(label, {TextColor3 = "mute"})
	local self = {track = track, label = label, pct = pct}
	function self.set(f, text)
		Util.tween(fill, 0.2, {Size = UDim2.fromScale(Util.clamp(f, 0, 1), 1)}, Enum.EasingStyle.Quad)
		pct.Text = math.floor(f * 100 + 0.5) .. "%"
		if text then label.Text = text end
	end
	function self.hide()
		Util.tween(track, 0.3, {BackgroundTransparency = 1})
		Util.tween(fill, 0.3, {BackgroundTransparency = 1})
		Util.tween(pct, 0.3, {TextTransparency = 1})
		Util.tween(label, 0.3, {TextTransparency = 1})
	end
	return self
end

local function wordRow(parent, text, size)
	local row = Util.new("Frame", {Name = "Word", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, size + 8), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Parent = parent})
	local x = 0
	local letters = {}
	for ch in text:gmatch(".") do
		local w = letterWidth(ch, size)
		local l = Util.new("TextLabel", {Name = ch, Size = UDim2.fromOffset(w, size + 8), Position = UDim2.fromOffset(x, 0), BackgroundTransparency = 1, Text = ch, TextSize = size, FontFace = Util.font("Bold"), TextXAlignment = Enum.TextXAlignment.Center, Parent = row})
		Theme.bind(l, {TextColor3 = "ink"})
		letters[#letters + 1] = l
		x += w + size * 0.08
	end
	row.Size = UDim2.fromOffset(x, size + 8)
	return row, letters
end

local function logoTile(parent, cfg, size)
	local t = Util.new("Frame", {Name = "Logo", Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Parent = parent})
	Util.corner(t, size * 0.28)
	Theme.bind(t, {BackgroundColor3 = "ink"})
	if cfg.Logo and tostring(cfg.Logo):find("rbxassetid") then
		t.BackgroundTransparency = 1
		Util.new("ImageLabel", {Size = UDim2.fromScale(1, 1), Image = cfg.Logo, Parent = t})
	else
		local l = Util.text(t, {Text = cfg.Letter or "K", TextSize = size * 0.5, Weight = "Bold", TextXAlignment = Enum.TextXAlignment.Center})
		Theme.bind(l, {TextColor3 = "bg"})
	end
	return t
end

local styles = {}

styles.letters = function(root, cfg, bar, finish)
	local size = 46
	local row, letters = wordRow(root, cfg.Name:upper(), size)
	for i, l in letters do
		l.TextTransparency = 1
		l.Position = UDim2.fromOffset(l.Position.X.Offset, -26)
		task.delay(0.1 + i * 0.09, function()
			Sound.play("key", 0.25, 1 + i * 0.03)
			Util.tween(l, 0.5, {Position = UDim2.fromOffset(l.Position.X.Offset, 0), TextTransparency = 0}, Enum.EasingStyle.Back)
		end)
	end
	local streak = Util.new("Frame", {Name = "Streak", Size = UDim2.fromOffset(34, size + 20), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, -30, 0.5, 0), Rotation = 14, BackgroundTransparency = 0.8, Parent = row})
	Theme.bind(streak, {BackgroundColor3 = "ink"})
	Util.new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1)}), Parent = streak})
	task.delay(1.2 + #letters * 0.09, function()
		Util.tween(streak, 0.9, {Position = UDim2.new(1, 30, 0.5, 0)}, Enum.EasingStyle.Quad)
	end)
	task.wait(1.8 + #letters * 0.09)
	finish.wait(bar)
	local rng = Random.new(7)
	for _, l in letters do
		local dx, dy = rng:NextInteger(-160, 160), rng:NextInteger(-110, 110)
		Util.tween(l, 0.7, {Position = UDim2.fromOffset(l.Position.X.Offset + dx, dy), Rotation = rng:NextInteger(-50, 50), TextTransparency = 1}, Enum.EasingStyle.Quint)
	end
	task.wait(0.35)
	local lg = logoTile(root, cfg, 56)
	local sc = Util.new("UIScale", {Scale = 0.2, Parent = lg})
	lg.BackgroundTransparency = 1
	Util.tween(lg, 0.3, {BackgroundTransparency = 0})
	Util.tween(sc, 0.6, {Scale = 1}, Enum.EasingStyle.Back)
	Sound.play("success")
	task.wait(0.9)
	Util.tween(sc, 0.35, {Scale = 1.4}, Enum.EasingStyle.Quad)
	Util.tween(lg, 0.35, {BackgroundTransparency = 1})
end

styles.fade = function(root, cfg, bar, finish)
	local lg = logoTile(root, cfg, 54)
	local name = Util.text(root, {Text = cfg.Name, TextSize = 16, Weight = "SemiBold", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.46, 44), Size = UDim2.fromOffset(240, 22), TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1})
	Theme.bind(name, {TextColor3 = "ink"})
	lg.BackgroundTransparency = 1
	Util.tween(lg, 0.7, {BackgroundTransparency = 0}, Enum.EasingStyle.Sine)
	Util.tween(name, 0.9, {TextTransparency = 0}, Enum.EasingStyle.Sine)
	task.wait(1.2)
	finish.wait(bar)
	Util.tween(lg, 0.5, {BackgroundTransparency = 1})
	Util.tween(name, 0.5, {TextTransparency = 1})
	task.wait(0.4)
end

styles.typewriter = function(root, cfg, bar, finish)
	local l = Util.text(root, {Text = "", TextSize = 30, Weight = "SemiBold", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(340, 40), TextXAlignment = Enum.TextXAlignment.Center})
	Theme.bind(l, {TextColor3 = "ink"})
	local name = cfg.Name
	for i = 1, #name do
		l.Text = name:sub(1, i) .. "|"
		Sound.play("key", 0.2, 1 + (i % 4) * 0.05)
		task.wait(0.07)
	end
	l.Text = name
	task.wait(0.4)
	finish.wait(bar)
	Util.tween(l, 0.4, {TextTransparency = 1})
	task.wait(0.4)
end

styles.slide = function(root, cfg, bar, finish)
	local row, letters = wordRow(root, cfg.Name, 40)
	local _ = row
	for i, l in letters do
		l.TextTransparency = 1
		local x = l.Position.X.Offset
		l.Position = UDim2.fromOffset(x - 60, 0)
		task.delay(i * 0.06, function() Util.tween(l, 0.6, {Position = UDim2.fromOffset(x, 0), TextTransparency = 0}, Enum.EasingStyle.Quint) end)
	end
	task.wait(0.8 + #letters * 0.06)
	finish.wait(bar)
	for i, l in letters do
		task.delay(i * 0.04, function() Util.tween(l, 0.4, {Position = UDim2.fromOffset(l.Position.X.Offset + 60, 0), TextTransparency = 1}, Enum.EasingStyle.Quint) end)
	end
	task.wait(0.6)
end

styles.zoom = function(root, cfg, bar, finish)
	local lg = logoTile(root, cfg, 60)
	local sc = Util.new("UIScale", {Scale = 3, Parent = lg})
	lg.BackgroundTransparency = 1
	Util.tween(sc, 0.8, {Scale = 1}, Enum.EasingStyle.Quint)
	Util.tween(lg, 0.5, {BackgroundTransparency = 0})
	task.wait(1.1)
	finish.wait(bar)
	Util.tween(sc, 0.4, {Scale = 0.1}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	Util.tween(lg, 0.4, {BackgroundTransparency = 1})
	task.wait(0.45)
end

styles.glitch = function(root, cfg, bar, finish)
	local layers = {}
	for i = 1, 3 do
		local l = Util.text(root, {Text = cfg.Name:upper(), TextSize = 40, Weight = "Bold", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(360, 50), TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = i == 1 and 0 or 0.7})
		Theme.bind(l, {TextColor3 = i == 1 and "ink" or (i == 2 and "a1" or "sub")})
		layers[i] = l
	end
	local rng = Random.new(3)
	for _ = 1, 10 do
		layers[2].Position = UDim2.new(0.5, rng:NextInteger(-6, 6), 0.46, rng:NextInteger(-3, 3))
		layers[3].Position = UDim2.new(0.5, rng:NextInteger(-6, 6), 0.46, rng:NextInteger(-3, 3))
		task.wait(0.06)
	end
	layers[2].Position = UDim2.fromScale(0.5, 0.46)
	layers[3].Position = UDim2.fromScale(0.5, 0.46)
	finish.wait(bar)
	for _, l in layers do Util.tween(l, 0.4, {TextTransparency = 1}) end
	task.wait(0.4)
end

styles.pulse = function(root, cfg, bar, finish)
	local lg = logoTile(root, cfg, 50)
	local sc = Util.new("UIScale", {Parent = lg})
	local alive = true
	task.spawn(function()
		while alive and lg.Parent do
			Util.tween(sc, 0.5, {Scale = 1.12}, Enum.EasingStyle.Sine)
			task.wait(0.5)
			Util.tween(sc, 0.5, {Scale = 1}, Enum.EasingStyle.Sine)
			task.wait(0.5)
		end
	end)
	task.wait(1)
	finish.wait(bar)
	alive = false
	Util.tween(lg, 0.4, {BackgroundTransparency = 1})
	task.wait(0.4)
end

styles.wipe = function(root, cfg, bar, finish)
	local l = Util.text(root, {Text = cfg.Name, TextSize = 34, Weight = "Bold", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(300, 44), TextXAlignment = Enum.TextXAlignment.Center})
	Theme.bind(l, {TextColor3 = "ink"})
	local g = Util.new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.51, 1), NumberSequenceKeypoint.new(1, 1)}), Parent = l})
	g.Offset = Vector2.new(-1, 0)
	Util.tween(g, 0.9, {Offset = Vector2.new(0, 0)}, Enum.EasingStyle.Quint)
	task.wait(1.4)
	finish.wait(bar)
	Util.tween(g, 0.6, {Offset = Vector2.new(1, 0)}, Enum.EasingStyle.Quint)
	task.wait(0.7)
end

styles.logo = styles.fade

function Boot.play(cfg, done)
	cfg = Util.merge({Name = "Kairo", Style = "Letters", Background = {Type = "none"}, Skip = true, Sound = false, Preload = {}}, cfg)
	local style = styles[tostring(cfg.Style):lower()] or styles.fade
	local gui = Util.new("ScreenGui", {Name = "KairoBoot", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 950, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = Util.gui()})
	Util.protect(gui)
	local bgc = cfg.Background or {Type = "none"}
	local bg = Util.new("Frame", {Name = "Bg", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = true, Parent = gui})
	if bgc.Type == "color" then
		bg.BackgroundColor3 = bgc.Color or Color3.new(0, 0, 0)
		bg.BackgroundTransparency = bgc.Transparency or 0
	elseif bgc.Type == "image" and bgc.Image then
		bg.BackgroundColor3 = Color3.new(0, 0, 0)
		bg.BackgroundTransparency = 0
		Util.new("ImageLabel", {Size = UDim2.fromScale(1, 1), Image = bgc.Image, ScaleType = Enum.ScaleType.Crop, ImageTransparency = bgc.Transparency or 0.15, Parent = bg})
	else
		bg.BackgroundColor3 = Color3.new(0, 0, 0)
		Util.tween(bg, 0.4, {BackgroundTransparency = bgc.Dim or 0.35}, Enum.EasingStyle.Quad)
	end
	local root = Util.new("Frame", {Name = "Stage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = bg})
	local bar = progressBar(root, 0.46)
	bar.track.Position = UDim2.new(0.5, 0, 0.46, 52)
	bar.pct.Position = UDim2.new(0.5, 0, 0.46, 60)
	bar.label.Position = UDim2.new(0.5, 0, 0.46, 60)
	local progress = 0
	local loaded = false
	local skipped = false
	local items = cfg.Preload
	task.spawn(function()
		local total = #items
		if total == 0 then
			for i = 1, 20 do
				progress = i / 20
				bar.set(progress, i < 14 and "Warming up" or "Almost there")
				task.wait(0.05)
			end
		else
			local CP = game:GetService("ContentProvider")
			local n = 0
			for _, a in items do
				pcall(function() CP:PreloadAsync({a}) end)
				n += 1
				progress = n / total
				bar.set(progress, "Loading assets")
			end
		end
		loaded = true
	end)
	local finish = {}
	function finish.wait(b)
		while not loaded and not skipped do task.wait(0.05) end
		b.set(1, "Ready")
		task.wait(0.25)
		b.hide()
	end
	local skip = Util.new("TextButton", {Name = "Skip", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 20, Visible = cfg.Skip, Parent = gui})
	skip.Activated:Connect(function() skipped = true end)
	task.spawn(function()
		local ok, err = pcall(style, root, cfg, bar, finish)
		if not ok then warn("[Kairo] boot: " .. tostring(err)) end
		Util.tween(bg, 0.45, {BackgroundTransparency = 1}, Enum.EasingStyle.Quad)
		task.wait(0.5)
		gui:Destroy()
		if done then Util.safe(done) end
	end)
	return gui
end

return Boot

end
__F["Hub"] = function(...)
local K = ...
local Util = K.Util
local Theme = K.Theme
local Cards = K.Cards
local Notify = K.Notify
local Lighting = K.Lighting
local Anim = K.Anim
local Sound = K.Sound

local Hub = {}

local function greeting()
	local h = tonumber(os.date("%H")) or 12
	if h < 5 then return "LATE NIGHT" end
	if h < 12 then return "GOOD MORNING" end
	if h < 18 then return "GOOD AFTERNOON" end
	return "GOOD EVENING"
end

local function home(win, tab, user)
	local left, right = tab.cols[1], tab.cols[2]
	local stats = Cards.stats()
	Cards.welcome(left, {Greeting = greeting(), Name = user.Name, Tier = user.Tier or "Free", Stats = stats})
	Cards.quickGrid(left, {
		{Name = "Farm", Icon = "zap", Callback = function() win:Notify({Title = "Auto farm", Text = "Switched on", Type = "success", Duration = 2.4}) end},
		{Name = "Aim", Icon = "crosshair", Callback = function() win:Notify({Title = "Targeting", Text = "Smart mode ready", Type = "info", Duration = 2.4}) end},
		{Name = "ESP", Icon = "eye", Callback = function() win:Notify({Title = "Overlay", Text = "Players highlighted", Type = "info", Duration = 2.4}) end},
		{Name = "Save", Icon = "save", Callback = function() K.Config.save(win, "quick") win:Notify({Title = "Config saved", Text = "quick", Type = "success", Duration = 2.4}) end},
	}, 4)
	Cards.listCard(left, {Title = "Suggested", Action = "See all", OnAction = function() win:Tab("Automation") end, Rows = {
		{Name = "Turn on auto collect", Icon = "package", Callback = function() win:SelectTab("Automation") end},
		{Name = "Pick a theme", Icon = "palette", Callback = function() win:SelectTab("Appearance") end},
		{Name = "Bind a toggle key", Icon = "keyboard", Callback = function() win:SelectTab("Hotkeys") end},
	}})
	Cards.profile(right, {Size = UDim2.new(1, 0, 0, 258), Name = user.Name, Handle = "@" .. (user.Handle or user.Name:lower()), Level = user.Level or "Level 1", Button = "Customize", Callback = function() win:SelectTab("Appearance") end})
	tab:Segmented({Options = {"Overview", "Session"}, Default = "Overview"})
	tab:IconButton({Icon = "layout-grid", Callback = function() win:OpenSearch() end})
end

local function automation(win, tab)
	tab:Segmented({Options = {"Basic", "Advanced"}, Default = "Basic"})
	tab:IconButton({Icon = "rotate-ccw", Callback = function() win:Notify({Title = "Defaults restored", Type = "info", Duration = 2}) end})
	local a = tab:Section({Name = "Auto collect", Column = 1})
	a:Toggle({Name = "Enabled", Default = true, Info = "Collect nearby items", Flag = "collect"})
	a:Slider({Name = "Radius", Min = 0, Max = 50, Default = 24, Info = "Studs around you", Flag = "radius"})
	a:Dropdown({Name = "Priority", Options = {"Closest", "Weakest", "Strongest"}, Default = "Closest", Info = "Order", Flag = "priority"})
	a:ColorPicker({Name = "Highlight", Default = Color3.fromRGB(160, 160, 170), Info = "Item colour", Flag = "hl"})
	a:Number({Name = "Delay", Default = 0.4, Min = 0, Max = 5, Step = 0.1, Suffix = "s", Info = "Between pickups", Flag = "delay"})
	a:Keybind({Name = "Toggle key", Info = "Hold or press", Flag = "ckey"})
	local b = tab:Section({Name = "Rewards", Column = 2})
	b:Toggle({Name = "Auto claim", Default = true, Info = "Daily and timed rewards", Flag = "claim"})
	b:Toggle({Name = "Auto sell", Default = false, Info = "Sell when full", Flag = "sell"})
	b:Number({Name = "Sell above", Default = 80, Min = 10, Max = 100, Step = 5, Suffix = "%", Flag = "sellat"})
	b:Progress({Name = "Session value", Default = 36, Format = function(v) return math.floor(v) .. " / 100" end})
	b:Buttons({Buttons = {{Text = "Run once", Callback = function() win:Notify({Title = "Done", Text = "Ran one cycle", Type = "success", Duration = 2}) end}, {Text = "Reset", Style = "secondary"}}})
	local c = tab:Section({Name = "Advanced", Column = 1, Mode = "Advanced"})
	c:Toggle({Name = "Humanise timing", Default = true, Info = "Small random gaps", Flag = "human"})
	c:Slider({Name = "Jitter", Min = 0, Max = 100, Default = 20, Suffix = "%", Flag = "jitter"})
	c:Dropdown({Name = "Path", Options = {"Direct", "Smooth", "Cautious"}, Default = "Smooth", Flag = "path"})
	local d = tab:Section({Name = "Safety", Column = 2, Mode = "Advanced"})
	d:Toggle({Name = "Pause on danger", Default = true, Info = "Stop near threats", Flag = "pause"})
	d:Toggle({Name = "Leave if reported", Default = false, Flag = "leave"})
	d:Slider({Name = "Health floor", Min = 5, Max = 95, Default = 35, Suffix = "%", Flag = "hpfloor"})
end

local function targeting(win, tab)
	local a = tab:Section({Name = "Aim", Column = 1})
	a:Segmented({Name = "Mode", Options = {"Smart", "Manual", "Off"}, Default = "Smart", NoLabel = true, Flag = "aim"})
	a:Dropdown({Name = "Parts", Options = {"Head", "Torso", "Legs"}, Multi = true, Default = {"Head", "Torso"}, Info = "Preferred parts", Flag = "parts"})
	a:Slider({Name = "Field of view", Min = 10, Max = 180, Default = 90, Suffix = "°", Flag = "fov"})
	a:Slider({Name = "Smoothing", Min = 0, Max = 100, Default = 40, Flag = "smooth"})
	a:Toggle({Name = "Visible only", Default = true, Info = "Skip hidden targets", Flag = "vis"})
	a:Toggle({Name = "Team check", Default = true, Flag = "team"})
	local b = tab:Section({Name = "Filter", Column = 2})
	b:TextBox({Name = "Name filter", Placeholder = "Filter name", NoLabel = true, Wide = true, Flag = "namef"})
	b:Checkbox({Name = "Range ring", Default = true, Info = "Draw the radius", Flag = "ring"})
	b:Toggle({Name = "Hide names", Default = false, Flag = "hide"})
	local lk = b:Toggle({Name = "Prediction", Default = false, Info = "Premium feature", Flag = "predict"})
	lk:Lock("Premium only")
	local c = tab:Section({Name = "Keys", Column = 2})
	c:Keybind({Name = "Aim key", Info = "Hold to aim", Flag = "aimkey"})
	c:Keybind({Name = "Switch target", Flag = "switchkey"})
end

local function weapons(win, tab)
	local a = tab:Section({Name = "Loadout", Column = 1})
	a:Picker({Items = {{Name = "Katana", Icon = "swords"}, {Name = "Bow", Icon = "target"}, {Name = "Staff", Icon = "wand-sparkles"}, {Name = "Dagger", Icon = "sword"}, {Name = "Scythe", Icon = "skull", Locked = true, LockReason = "Premium weapon"}, {Name = "Fists", Icon = "hand"}}, Default = "Katana", Columns = 2, Flag = "weapon", Callback = function(v) win:Notify({Title = v, Text = "Equipped", Type = "success", Duration = 2}) end})
	local b = tab:Section({Name = "Behaviour", Column = 2})
	b:Toggle({Name = "Auto equip", Default = true, Flag = "equip"})
	b:Toggle({Name = "Auto reload", Default = true, Flag = "reload"})
	b:Slider({Name = "Swing rate", Min = 1, Max = 20, Default = 8, Suffix = "/s", Flag = "rate"})
	b:Dropdown({Name = "Combo", Options = {"Light", "Heavy", "Mixed"}, Default = "Mixed", Flag = "combo"})
	b:Stepper({Name = "Chain length", Min = 1, Max = 9, Default = 3, Flag = "chain"})
	b:Radio({Name = "Finisher", Options = {"Always", "Low health", "Never"}, Default = "Low health", Flag = "finisher"})
end

local function stats(win, tab)
	local s = Cards.stats()
	local left, right = tab.cols[1], tab.cols[2]
	local fps = Cards.stat(left, {Label = "Frame rate", Unit = "fps", Spark = true, Size = UDim2.new(1, 0, 0, 62)})
	local ping = Cards.stat(right, {Label = "Latency", Unit = "ms", Spark = true, Size = UDim2.new(1, 0, 0, 62)})
	fps.Set(s.fps)
	ping.Set(s.ping)
	s.changed:Connect(function(st)
		fps.Set(st.fps, st.fpsHist, 0, 144)
		ping.Set(st.ping, st.pingHist, 0, 300)
	end)
	local a = tab:Section({Name = "Session", Column = 1})
	a:Label({Name = "Time in game", Text = "00:00"})
	a:Label({Name = "Server players", Text = tostring(#Util.Players:GetPlayers())})
	a:Label({Name = "Executor", Text = (identifyexecutor and select(1, identifyexecutor())) or "Unknown"})
	local t0 = os.clock()
	task.spawn(function()
		while tab.page and tab.page.Parent do
			local e = math.floor(os.clock() - t0)
			a.elems[1]:Set(string.format("%02d:%02d", math.floor(e / 60), e % 60))
			task.wait(1)
		end
	end)
	local b = tab:Section({Name = "Monitor", Column = 2})
	b:Toggle({Name = "Show FPS overlay", Default = false, Flag = "fpsov"})
	b:Toggle({Name = "Warn on low FPS", Default = true, Flag = "fpswarn"})
	local log = tab:Section({Name = "Activity", Column = 1})
	local con = log:Console({Height = 96})
	con:Log("Hub ready", "ok")
	con:Log("Waiting for the game to load")
	s.changed:Connect(function(st)
		if st.fps < 25 then con:Log("Low frame rate: " .. st.fps, "warn") end
	end)
	win.Console = con
end

local function overlay(win, tab)
	local a = tab:Section({Name = "Players", Column = 1})
	a:Toggle({Name = "Highlight", Default = true, Flag = "esp"})
	a:ColorPicker({Name = "Colour", Default = Color3.fromRGB(255, 255, 255), Flag = "espc"})
	a:Slider({Name = "Opacity", Min = 0, Max = 100, Default = 60, Suffix = "%", Flag = "espo"})
	local b = tab:Section({Name = "World", Column = 2})
	b:Chips({Name = "Show", Options = {"Name", "Distance", "Health", "Tool", "Team"}, Multi = true, Default = {"Name", "Distance"}, Flag = "chips"})
	b:Toggle({Name = "Full bright", Default = false, Flag = "fb"})
	b:Slider({Name = "Field of view", Min = 40, Max = 120, Default = 70, Flag = "wfov"})
	b:Toggle({Name = "No fog", Default = false, Flag = "nofog"})
end

local function appearance(win, tab)
	local ids, names = Theme.ids(), Theme.names()
	local a = tab:Section({Name = "Theme", Column = 1})
	a:Dropdown({Name = "Palette", Options = names, Default = names[1], Info = "Whole interface", Flag = "theme", Callback = function(v)
		for i, n in names do if n == v then Theme.set(ids[i]) end end
	end})
	a:ColorPicker({Name = "Accent", Default = Color3.fromRGB(235, 235, 240), Info = "Overrides the palette accent", Flag = "accent", Callback = function(c) Theme.setAccent(c) end})
	a:Toggle({Name = "Soft gradients", Default = true, Flag = "grad", Callback = function(v) Theme.setGradients(v) end})
	a:Toggle({Name = "Outlines", Default = false, Info = "Thin strokes on cards", Flag = "strokes", Callback = function(v) Theme.setStrokes(v) end})
	local b = tab:Section({Name = "Light", Column = 2})
	b:Toggle({Name = "Corner light", Default = true, Info = "Soft glow from a random corner", Flag = "light", Callback = function(v) Lighting.set({enabled = v}) end})
	b:Slider({Name = "Intensity", Min = 0, Max = 100, Default = 50, Suffix = "%", Flag = "lint", Callback = function(v) Lighting.set({intensity = v / 100}) end})
	b:Toggle({Name = "Shadow", Default = true, Flag = "shadow", Callback = function(v) Lighting.set({shadow = v}) end})
	local c = tab:Section({Name = "Window", Column = 1})
	c:Segmented({Name = "Sidebar", Options = {"Full", "Icons", "Hover"}, Default = "Full", NoLabel = true, Flag = "rail", Callback = function(v) win:SetRail(v:lower()) end})
	c:Dropdown({Name = "Press style", Options = {"squish", "dip", "pop", "sink", "none"}, Default = "squish", Flag = "press", Callback = function(v) Anim.setPress(v) end})
	c:Toggle({Name = "Sounds", Default = false, Flag = "sfx", Callback = function(v) Sound.enabled = v end})
	local d = tab:Section({Name = "Alerts", Column = 2})
	d:Dropdown({Name = "Position", Options = {"top-right", "top-left", "bottom-right", "bottom-left", "top", "bottom"}, Default = "bottom-right", Width = 120, Flag = "npos", Callback = function(v) Notify.setPosition(v) end})
	d:Button({Name = "Preview", Text = "Show", Callback = function() win:Notify({Title = "Looks good", Text = "Tap to dismiss", Type = "success", Duration = 3}) end})
end

local function hotkeys(win, tab)
	local a = tab:Section({Name = "Window", Column = 1})
	a:Keybind({Name = "Show or hide", Default = win.cfg.Key, Info = "Toggles the window", Flag = "togglekey", Callback = function(k) win.cfg.Key = k end})
	a:Label({Name = "Search", Text = "Ctrl + K"})
	local b = tab:Section({Name = "Actions", Column = 2})
	b:Keybind({Name = "Panic", Info = "Hide and stop everything", Flag = "panic", Callback = function() win:SetVisible(false) end})
end

local function configs(win, tab)
	local name = "default"
	local a = tab:Section({Name = "Save and load", Column = 1})
	a:TextBox({Name = "Config name", Default = "default", Placeholder = "Name", Flag = "cfgname", NoSave = true, Callback = function(v) name = v end})
	a:Buttons({Buttons = {
		{Text = "Save", Callback = function() local ok = K.Config.save(win, name) win:Notify({Title = ok and "Saved" or "Could not save", Text = name, Type = ok and "success" or "error", Duration = 2.4}) end},
		{Text = "Load", Style = "secondary", Callback = function() local ok = K.Config.load(win, name) win:Notify({Title = ok and "Loaded" or "Not found", Text = name, Type = ok and "success" or "warn", Duration = 2.4}) end},
	}})
	a:Toggle({Name = "Auto save", Default = false, Flag = "autosave", NoSave = true})
	local b = tab:Section({Name = "Saved", Column = 2})
	b:Dropdown({Name = "Files", Options = K.Config.list(win), Default = nil, Placeholder = "None yet", NoSave = true, Callback = function(v) name = v end})
	b:Button({Name = "Delete", Text = "Delete", Style = "danger", Callback = function() K.Config.delete(win, name) win:Notify({Title = "Deleted", Text = name, Type = "info", Duration = 2}) end})
end

local function about(win, tab, cfg)
	local left, right = tab.cols[1], tab.cols[2]
	Cards.brand(left, {Title = cfg.Name, Text = "Version " .. cfg.Version, Icon = "sparkles", Button = "Open", Callback = function() win:Notify({Title = cfg.Name, Text = "You are on the latest build", Type = "success", Duration = 2.6}) end})
	Cards.brand(left, {Title = "Community", Text = "Get support", Icon = "message-square", Button = "Join", Copy = cfg.Discord, Callback = function()
		if cfg.Discord and setclipboard then setclipboard(cfg.Discord) end
		win:Notify({Title = "Invite copied", Text = "Paste it in your browser", Type = "success", Duration = 2.6})
	end})
	local a = tab:Section({Name = "Build", Column = 2})
	a:Label({Name = "Version", Text = cfg.Version})
	a:Label({Name = "Library", Text = "Kairo UI"})
	a:Label({Name = "Credits", Text = "wheizx"})
	a:Button({Name = "Unload", Text = "Unload", Style = "danger", Callback = function() win:ConfirmUnload() end})
end

function Hub.build(cfg)
	cfg = Util.merge({Name = "Vanta", Sub = "Blox Fruits", Version = "v1.0", Theme = "carbon", User = {Name = "Player", Role = "Member"}, Discord = ""}, cfg)
	local lp = Util.Players.LocalPlayer
	if lp and cfg.User.Name == "Player" then cfg.User = {Name = lp.DisplayName, Handle = lp.Name, Role = "Member", Tier = "Free"} end
	local win = K.Window.new({Name = cfg.Name, Sub = cfg.Sub, Version = cfg.Version, Theme = cfg.Theme, User = cfg.User, Key = cfg.Key or Enum.KeyCode.RightShift})
	local tabs = {
		{"Home", "house", nil, function(_, t) home(win, t, cfg.User) end, {Weights = {282, 128}}},
		{"Automation", "zap", "Gameplay", automation, {Description = "Collect, farm and manage rewards"}},
		{"Targeting", "crosshair", "Gameplay", targeting, {}},
		{"Weapons", "swords", "Gameplay", weapons, {}},
		{"Stats", "chart-line", "Visuals", stats, {}},
		{"Overlay", "eye", "Visuals", overlay, {}},
		{"Appearance", "palette", "System", appearance, {}},
		{"Hotkeys", "keyboard", "System", hotkeys, {}},
		{"Config", "save", "System", configs, {}},
		{"About", "info", "System", function(_, t) about(win, t, cfg) end, {}},
	}
	for _, d in tabs do
		local t = win:Tab(Util.merge({Name = d[1], Icon = d[2], Group = d[3]}, d[5]))
		d[4](win, t)
	end
	win:SelectTab("Home")
	return win
end

return Hub

end
__F["Loader"] = function(...)
local K = ...
local Util = K.Util
local Boot = K.Boot

local Loader = {}

function Loader.run(cfg)
	cfg = Util.merge({
		Name = "Vanta",
		Sub = "Blox Fruits",
		Version = "v1.0",
		Theme = "carbon",
		Boot = {Style = "Letters", Background = {Type = "none"}},
		Key = nil,
		Discord = "",
	}, cfg)
	if cfg.IconSheet then K.Icons.setSheet(cfg.IconSheet) elseif cfg.IconUrl then K.Icons.fromUrl(cfg.IconUrl) end
	local started = false
	local function open()
		if started then return end
		started = true
		local win = K.Hub.build({Name = cfg.Name, Sub = cfg.Sub, Version = cfg.Version, Theme = cfg.Theme, Discord = cfg.Discord, User = cfg.User})
		if cfg.OnReady then Util.safe(cfg.OnReady, win) end
		return win
	end
	local function gate()
		if cfg.Key then
			K.KeySystem.new(cfg.Key, function() open() end)
		else
			open()
		end
	end
	if cfg.Boot == false then
		gate()
	else
		Boot.play(Util.merge({Name = cfg.Name}, cfg.Boot), gate)
	end
end

return Loader

end
local __O = {"Util", "ThemeData", "IconNames", "Theme", "Icons", "Sound", "Anim", "Notify", "Pop", "Lighting", "Window", "Elements", "Controls", "Controls2", "Controls3", "Lock", "Config", "Search", "Cards", "KeySystem", "Boot", "Hub", "Loader"}
for _, n in ipairs(__O) do
  local r = __F[n](__K)
  if r ~= nil then __K[n] = r end
end
local Kairo = __K
Kairo.CreateWindow = Kairo.Window.new
Kairo.Version = "1.0.0"
return Kairo
