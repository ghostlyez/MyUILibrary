--[[
  NOCTURNE - purple/black Roblox UI library (personal use)

  Boot{ Loader -> Access -> Key -> Gui }
    each stage: nil/true = built-in, table = built-in + config, function(ctx) = yours, false = off
  Window -> Tab -> Section -> Card -> Button Toggle Slider Input Textbox Number Dropdown Keybind ColorPicker Label Paragraph

  File map (search the tag):
  [1] utils  [2] assets  [3] sounds  [4] icons  [5] theme  [6] preload  [7] elements
  [8] window  [9] notify  [10] panel  [11] stages  [12] boot
]]

local Players         = game:GetService("Players")
local TweenService    = game:GetService("TweenService")
local UIS             = game:GetService("UserInputService")
local RunService      = game:GetService("RunService")
local SoundService    = game:GetService("SoundService")
local Debris          = game:GetService("Debris")
local HttpService     = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")
local CoreGui         = game:GetService("CoreGui")
local LocalPlayer     = Players.LocalPlayer

local getasset = getcustomasset or getsynasset
local clip     = setclipboard or toclipboard

local Nocturne = { Name = "Nocturne", Version = "1.0.0", Flags = {}, Elements = {}, Stages = {}, Sounds = {}, Icons = {}, Themes = {} }
local Sounds, Icons, Stages, Themes = Nocturne.Sounds, Nocturne.Icons, Nocturne.Stages, Nocturne.Themes

-- [1] utils ---------------------------------------------------------------
-- New(): pass BackgroundColor3 to get a visible background, otherwise it is transparent.
local function New(class, props, kids)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then
		o.BorderSizePixel = 0
		if not (props and props.BackgroundColor3) then o.BackgroundTransparency = 1 end
		if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
			o.Font, o.TextSize, o.TextColor3 = Enum.Font.GothamMedium, 13, Color3.new(1, 1, 1)
			if o:IsA("TextButton") then o.AutoButtonColor, o.Text = false, "" end
			if o:IsA("TextBox") then o.ClearTextOnFocus = false end
		end
	end
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else o[k] = v end
	end
	for _, c in ipairs(kids or {}) do c.Parent = o end
	o.Parent = parent
	return o
end

local function Corner(r) return New("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function Round() return New("UICorner", { CornerRadius = UDim.new(1, 0) }) end
local function Stroke(c, th, tr)
	return New("UIStroke", { Color = c, Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function Pad(x, y)
	y = y or x
	return New("UIPadding", { PaddingLeft = UDim.new(0, x), PaddingRight = UDim.new(0, x), PaddingTop = UDim.new(0, y), PaddingBottom = UDim.new(0, y) })
end
local function List(gap, dir, ha, va)
	return New("UIListLayout", {
		Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = dir or Enum.FillDirection.Vertical,
		HorizontalAlignment = ha or Enum.HorizontalAlignment.Left,
		VerticalAlignment = va or Enum.VerticalAlignment.Top,
	})
end
local function Grad(c0, c1, rot, tr)
	return New("UIGradient", { Color = ColorSequence.new(c0, c1), Rotation = rot or 0, Transparency = tr or NumberSequence.new(0) })
end
local function V2(x, y) return Vector2.new(x, y) end

local function tw(o, props, t, style, dir)
	local tn = TweenService:Create(o, TweenInfo.new(t or .25, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tn:Play()
	return tn
end
local function set(o, props, animate)
	if animate then tw(o, props, .35) else for k, v in pairs(props) do o[k] = v end end
end
local function conn(owner, sig, fn) owner.Conns[#owner.Conns + 1] = sig:Connect(fn) end

local guis = {}
local function mount(gui, ignoreInset)
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = ignoreInset == true
	local parent
	if type(gethui) == "function" then
		local ok, h = pcall(gethui)
		if ok then parent = h end
	end
	if parent then
		gui.Parent = parent
	else
		pcall(function() gui.Parent = CoreGui end)
		if gui.Parent ~= CoreGui then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
	end
	guis[#guis + 1] = gui
	return gui
end

function Nocturne:Unload()
	for _, g in ipairs(guis) do pcall(function() g:Destroy() end) end
	guis = {}
end

-- [2] assets: rbxassetid / rbxasset / github url -> usable content string, urls are cached to disk
local function hash(s)
	local h = 5381
	for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
	return string.format("%08x", h)
end

local function ensureDirs()
	if makefolder and isfolder then
		for _, d in ipairs({ "Nocturne", "Nocturne/cache" }) do
			if not isfolder(d) then pcall(makefolder, d) end
		end
	end
end

local assetCache = {}
local function resolve(src)
	if src == nil then return nil end
	if assetCache[src] ~= nil then return assetCache[src] or nil end
	local out
	if type(src) == "number" or (type(src) == "string" and src:match("^%d+$")) then
		out = "rbxassetid://" .. src
	elseif type(src) == "string" and src:find("^rbxasset") then
		out = src
	elseif type(src) == "string" and src:find("^https?://") and writefile and isfile and getasset then
		ensureDirs()
		local ext = src:match("^[^?#]+"):match("%.(%w+)$") or "png"
		local path = ("Nocturne/cache/%s.%s"):format(hash(src), ext)
		if not isfile(path) then
			local ok, data = pcall(function() return game:HttpGet(src) end)
			if ok and type(data) == "string" and #data > 0 then pcall(writefile, path, data) end
		end
		if isfile(path) then
			local ok, a = pcall(getasset, path)
			if ok then out = a end
		end
	end
	assetCache[src] = out or false
	return out
end

-- lists for keys / whitelist / blacklist: table, or url returning json array / lines
local listCache = {}
local function getList(src)
	if type(src) == "table" then return src end
	if type(src) ~= "string" then return {} end
	if listCache[src] then return listCache[src] end
	local ok, body = pcall(function() return game:HttpGet(src) end)
	if not ok or type(body) ~= "string" then return nil end
	local out = {}
	local ok2, data = pcall(function() return HttpService:JSONDecode(body) end)
	if ok2 and type(data) == "table" then
		if #data > 0 then
			for _, v in ipairs(data) do out[#out + 1] = tostring(v) end
		else
			for k in pairs(data) do out[#out + 1] = tostring(k) end
		end
	else
		for line in body:gmatch("[^\r\n]+") do
			local t = line:match("^%s*(.-)%s*$")
			if t ~= "" then out[#out + 1] = t end
		end
	end
	listCache[src] = out
	return out
end

-- [3] sounds: built-in client sounds by default. Replace any entry with an rbxassetid or a github mp3/ogg url.
Sounds.On = true
Sounds.Volume = 1
Sounds.Ids = {
	Click  = "rbxasset://sounds/clickfast.wav",
	Hover  = "rbxasset://sounds/snap.mp3",
	Toggle = "rbxasset://sounds/switch.wav",
	Tick   = "rbxasset://sounds/electronicpingshort.wav",
	Done   = "rbxasset://sounds/electronicpingshort.wav",
	Error  = "rbxasset://sounds/switch.wav",
	Open   = "rbxasset://sounds/snap.mp3",
}

function Sounds.Play(name, pitch, vol)
	if not Sounds.On then return end
	local id = resolve(Sounds.Ids[name])
	if not id then return end
	local s = New("Sound", { SoundId = id, Volume = (vol or .4) * Sounds.Volume, PlaybackSpeed = pitch or 1, Parent = SoundService })
	s:Play()
	Debris:AddItem(s, 4)
end

function Sounds.Preload(report)
	local names = {}
	for n in pairs(Sounds.Ids) do names[#names + 1] = n end
	for i, n in ipairs(names) do
		local a = resolve(Sounds.Ids[n])
		if a and a:find("^rbxassetid") then pcall(function() ContentProvider:PreloadAsync({ a }) end) end
		report(i / #names, "Loading sounds")
	end
end

-- [4] icons: Lucide through latte-soft/lucide-roblox (spritesheets, so it works with no file functions).
-- Icon names: "home" | "lucide:home" | custom name | rbxassetid | github png url.
Icons.Size = 256                -- 256 = high res. Use 48 if tiny icons look noisy.
Icons.Timeout = 30
Icons.Sources = { "https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau" }
Icons.Custom, Icons.Packs, Icons.Lib = {}, {}, nil
-- Own icon provider: Icons.Lib = { GetAsset = function(name, size) return { Url=, ImageRectSize=, ImageRectOffset= } end, GetAllAssets = optional }

local iconCache = {}

function Icons.Add(name, src) Icons.Custom[name] = src; iconCache[name] = nil end
-- Icons.AddPack("https://raw.githubusercontent.com/USER/REPO/main/png/{name}.png", { "home", "star" })
function Icons.AddPack(url, names) Icons.Packs[#Icons.Packs + 1] = { Url = url, Names = names } end

function Icons.Get(name)
	if not name or name == "" then return nil end
	name = tostring(name)
	if iconCache[name] then return iconCache[name] end
	local out
	if Icons.Custom[name] then
		local img = resolve(Icons.Custom[name])
		if img then out = { Image = img } end
	end
	if not out and Icons.Lib then
		local ok, a = pcall(Icons.Lib.GetAsset, (name:gsub("^lucide:", "")), Icons.Size)
		if ok and type(a) == "table" then out = { Image = a.Url, Size = a.ImageRectSize, Offset = a.ImageRectOffset } end
	end
	if not out and (name:find("^rbxasset") or name:match("^%d+$") or name:find("^https?://")) then
		local img = resolve(name)
		if img then out = { Image = img } end
	end
	if out then iconCache[name] = out end
	return out
end

function Icons.Apply(img, name, color)
	local d = Icons.Get(name)
	if not d then img.Visible = false; return false end
	img.Image, img.ImageRectSize, img.ImageRectOffset = d.Image, d.Size or Vector2.zero, d.Offset or Vector2.zero
	if color then img.ImageColor3 = color end
	img.Visible = true
	return true
end

function Icons.Load(report)
	report(0, "Fetching icon library")
	if not Icons.Lib then
		for _, url in ipairs(Icons.Sources) do
			local ok, lib = pcall(function() return loadstring(game:HttpGet(url))() end)
			if ok and type(lib) == "table" and lib.GetAsset then Icons.Lib = lib; break end
		end
	end
	table.clear(iconCache)
	local jobs = {}
	if Icons.Lib and Icons.Lib.GetAllAssets then
		local ok, all = pcall(Icons.Lib.GetAllAssets, Icons.Size)
		if ok and type(all) == "table" then
			local seen = {}
			for _, a in pairs(all) do
				if a.Url and not seen[a.Url] then seen[a.Url] = true; jobs[#jobs + 1] = a.Url end
			end
		end
	end
	for _, pack in ipairs(Icons.Packs) do
		for _, n in ipairs(pack.Names) do
			jobs[#jobs + 1] = function()
				local url = pack.Url:gsub("{name}", n)
				Icons.Custom[n] = url
				resolve(url)
			end
		end
	end
	local total, done, nxt, running = #jobs, 0, 0, 8
	if total == 0 then report(1, "Icons ready"); return end
	local function worker()
		while true do
			nxt = nxt + 1
			local j = jobs[nxt]
			if not j then return end
			pcall(function()
				if type(j) == "function" then j() else ContentProvider:PreloadAsync({ j }) end
			end)
			done = done + 1
			report(done / total, ("Loading icons  %d/%d"):format(done, total))
		end
	end
	for _ = 1, 8 do task.spawn(function() worker(); running = running - 1 end) end
	local t0 = os.clock()
	while running > 0 and os.clock() - t0 < Icons.Timeout do task.wait() end
	table.clear(iconCache)
end

-- [5] theme: colors are tokens. Elements register painters so SetTheme re-colors everything live.
local function mk(o)
	local t = {
		Bg = Color3.fromRGB(9, 6, 16), Glow = Color3.fromRGB(30, 15, 56), Top = Color3.fromRGB(17, 11, 30),
		Side = Color3.fromRGB(13, 9, 24), Card = Color3.fromRGB(23, 16, 40), Field = Color3.fromRGB(11, 8, 20),
		Text = Color3.fromRGB(238, 232, 252), Sub = Color3.fromRGB(150, 138, 182), Line = Color3.fromRGB(48, 35, 78),
		Accent = Color3.fromRGB(139, 92, 246), Accent2 = Color3.fromRGB(192, 132, 252),
		Idle = Color3.fromRGB(34, 211, 238), -- unpressed accents (cyan); pressed/active elements go black + purple
	}
	for k, v in pairs(o or {}) do t[k] = v end
	return t
end
Themes.Purple = mk()
Themes.Cyan = mk({
	Bg = Color3.fromRGB(5, 10, 14), Glow = Color3.fromRGB(8, 32, 44), Top = Color3.fromRGB(10, 18, 24),
	Side = Color3.fromRGB(7, 13, 19), Card = Color3.fromRGB(13, 23, 31), Field = Color3.fromRGB(6, 12, 17),
	Text = Color3.fromRGB(230, 248, 252), Sub = Color3.fromRGB(130, 165, 178), Line = Color3.fromRGB(28, 54, 68),
	Accent = Color3.fromRGB(34, 211, 238), Accent2 = Color3.fromRGB(125, 235, 252), Idle = Color3.fromRGB(139, 92, 246),
})

local T = mk()
Nocturne.Theme = T
local painters = {}

local function themed(inst, fn)
	fn(false)
	painters[#painters + 1] = { inst, fn }
end

function Nocturne:SetTheme(t)
	if type(t) == "string" then t = Themes[t] end
	if type(t) ~= "table" then return end
	for k, v in pairs(t) do T[k] = v end
	for i = #painters, 1, -1 do
		local p = painters[i]
		if p[1]:IsDescendantOf(game) then pcall(p[2], true) else table.remove(painters, i) end
	end
end

local function Lbl(parent, txt, size, key, font, align, props)
	local l = New("TextLabel", {
		Text = txt or "", TextSize = size, Font = font or Enum.Font.GothamMedium,
		TextXAlignment = align or Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.fromScale(1, 1), Parent = parent,
	})
	for k, v in pairs(props or {}) do l[k] = v end
	themed(l, function(a) set(l, { TextColor3 = T[key or "Text"] }, a) end)
	return l
end

-- [6] preload: everything the UI needs, with real progress. Custom loaders call ctx.Preload(report).
function Nocturne.Preload(cfg, report)
	report = report or function() end
	local jobs = { { "Icons", 8, Icons.Load }, { "Sounds", 1, Sounds.Preload } }
	for _, p in ipairs((cfg and cfg.Preload) or {}) do
		jobs[#jobs + 1] = { "Extra assets", 1, type(p) == "function" and p or function(r)
			local a = resolve(p)
			if a then pcall(function() ContentProvider:PreloadAsync({ a }) end) end
			r(1)
		end }
	end
	local sum = 0
	for _, j in ipairs(jobs) do sum = sum + j[2] end
	local acc = 0
	for _, j in ipairs(jobs) do
		local w = j[2] / sum
		local base = acc
		local ok, err = pcall(j[3], function(f, txt) report(base + w * math.clamp(f or 0, 0, 1), txt or j[1]) end)
		if not ok then warn("[Nocturne] preload '" .. j[1] .. "' failed: " .. tostring(err)) end
		acc = acc + w
		report(acc, j[1])
	end
	report(1, "Ready")
	Nocturne._loaded = true
end

-- [7] elements ----------------------------------------------------------------
local Card = {}
Card.__index = Card

local function makeCard(parent, W, page, order)
	local body = New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Card, LayoutOrder = order or 0, Parent = parent },
		{ Corner(14), Pad(14, 6), List(0), Grad(Color3.new(1, 1, 1), Color3.fromRGB(205, 195, 225), 90) })
	local st = Stroke(T.Line, 1, .3)
	st.Parent = body
	themed(body, function(a) set(body, { BackgroundColor3 = T.Card }, a); set(st, { Color = T.Line }, a) end)
	return setmetatable({ Body = body, W = W, Page = page, _n = 0 }, Card)
end

local function newRow(self, h)
	local n = self._n
	if n > 0 then
		local d = New("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.Line, LayoutOrder = n * 2 - 1, Parent = self.Body })
		themed(d, function(a) set(d, { BackgroundColor3 = T.Line, BackgroundTransparency = .35 }, a) end)
	end
	self._n = n + 1
	return New("Frame", { Size = UDim2.new(1, 0, 0, h or 38), LayoutOrder = self._n * 2, Parent = self.Body })
end

local function commit(o, E, v, silent)
	E.Value = v
	if o.Flag then Nocturne.Flags[o.Flag] = v; Nocturne.Elements[o.Flag] = E end
	if not silent and o.Callback then task.spawn(o.Callback, v) end
end

local function rowLabel(row, o, reserve)
	local r = -(reserve or 0)
	Lbl(row, o.Name or "", 14, "Text", nil, nil, { Size = UDim2.new(1, r, 0, o.Desc and 20 or 38), Position = UDim2.fromOffset(0, o.Desc and 6 or 0) })
	if o.Desc then Lbl(row, o.Desc, 11, "Sub", nil, nil, { Size = UDim2.new(1, r, 0, 14), Position = UDim2.fromOffset(0, 27) }) end
end

local function styleField(box, st)
	local focused = false
	themed(box, function(a)
		set(box, { BackgroundColor3 = T.Field, TextColor3 = T.Text, PlaceholderColor3 = T.Sub }, a)
		set(st, { Color = focused and T.Accent or T.Line }, a)
	end)
	box.Focused:Connect(function() focused = true; set(st, { Color = T.Accent }, true) end)
	box.FocusLost:Connect(function() focused = false; set(st, { Color = T.Line }, true) end)
end

local function fmtDec(step) return #(tostring(step):match("%.(%d+)") or "") end

function Card:Label(text)
	local row = newRow(self, 30)
	local l = Lbl(row, text or "", 13, "Sub", nil, nil, { TextWrapped = true, TextTruncate = Enum.TextTruncate.None })
	local E = {}
	function E:Set(t, color) l.Text = t; if color then l.TextColor3 = color end end
	return E
end

function Card:Paragraph(o)
	local row = newRow(self, 0)
	row.AutomaticSize, row.Size = Enum.AutomaticSize.Y, UDim2.new(1, 0, 0, 0)
	New("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = row })
	List(4).Parent = row
	local wrap = { TextWrapped = true, TextTruncate = Enum.TextTruncate.None, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) }
	local t = Lbl(row, o.Title or "", 14, "Text", Enum.Font.GothamBold, nil, wrap)
	t.LayoutOrder = 1
	local c = Lbl(row, o.Content or "", 12, "Sub", nil, nil, wrap)
	c.LayoutOrder = 2
	local E = {}
	function E:Set(title, content) t.Text = title or t.Text; c.Text = content or c.Text end
	return E
end

function Card:Button(o)
	local row = newRow(self, 40)
	local b = New("TextButton", { Size = UDim2.new(1, 0, 0, 30), AnchorPoint = V2(0, .5), Position = UDim2.fromScale(0, .5), BackgroundColor3 = T.Field, ClipsDescendants = true, Parent = row }, { Corner(10) })
	local sc = New("UIScale", { Parent = b })
	local st = Stroke(T.Line, 1, 0)
	st.Parent = b
	local g = Grad(T.Accent, T.Accent2)
	g.Parent = b
	local inner = New("Frame", { Size = UDim2.fromScale(1, 1), Parent = b }, { List(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local ic = New("ImageLabel", { Size = UDim2.fromOffset(16, 16), Parent = inner })
	local tl = New("TextLabel", { Text = o.Name or "Button", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), Parent = inner })
	local hov, primary = false, o.Primary == true
	local function paint(a)
		set(b, { BackgroundColor3 = primary and Color3.new(1, 1, 1) or (hov and T.Card or T.Field) }, a)
		set(st, { Color = hov and T.Accent or T.Line, Transparency = primary and 1 or 0 }, a)
		g.Enabled, g.Color = primary, ColorSequence.new(T.Accent, T.Accent2)
		set(tl, { TextColor3 = T.Text }, a)
		Icons.Apply(ic, o.Icon, T.Text)
	end
	themed(b, paint)
	b.MouseEnter:Connect(function() hov = true; Sounds.Play("Hover", 1.3, .06); tw(sc, { Scale = 1.02 }, .2); paint(true) end)
	b.MouseLeave:Connect(function() hov = false; tw(sc, { Scale = 1 }, .2); paint(true) end)
	b.MouseButton1Click:Connect(function()
		Sounds.Play("Click", 1, .35)
		sc.Scale = .95
		tw(sc, { Scale = hov and 1.02 or 1 }, .4, Enum.EasingStyle.Back)
		if o.Callback then task.spawn(o.Callback) end
	end)
	local E = {}
	function E:SetText(t) tl.Text = t end
	return E
end

function Card:Toggle(o)
	local row = newRow(self, o.Desc and 50 or 38)
	rowLabel(row, o, 60)
	local btn = New("TextButton", { Size = UDim2.fromOffset(46, 24), AnchorPoint = V2(1, .5), Position = UDim2.fromScale(1, .5), BackgroundColor3 = T.Field, Parent = row }, { Round() })
	local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Parent = btn }, { Round() })
	local g = Grad(T.Accent, T.Accent2)
	g.Parent = fill
	local st = Stroke(T.Idle, 1.5, .5)
	st.Parent = btn
	local knob = New("Frame", { Size = UDim2.fromOffset(18, 18), AnchorPoint = V2(0, .5), Position = UDim2.new(0, 3, .5, 0), BackgroundColor3 = T.Idle, ZIndex = 2, Parent = btn }, { Round() })
	local state, E = o.Default == true, {}
	local function paint(a)
		set(btn, { BackgroundColor3 = T.Field }, a)
		set(fill, { BackgroundTransparency = state and 0 or 1 }, a)
		set(knob, { Position = state and UDim2.new(1, -21, .5, 0) or UDim2.new(0, 3, .5, 0), BackgroundColor3 = state and Color3.new(1, 1, 1) or T.Idle }, a)
		set(st, { Color = state and T.Accent or T.Idle, Transparency = state and .15 or .55 }, a)
		g.Color = ColorSequence.new(T.Accent, T.Accent2)
	end
	themed(btn, paint)
	function E:Set(v, silent)
		state = v and true or false
		paint(true)
		commit(o, E, state, silent)
	end
	function E:Get() return state end
	btn.MouseButton1Click:Connect(function()
		Sounds.Play("Toggle", state and .85 or 1.15, .35)
		E:Set(not state)
	end)
	commit(o, E, state, true)
	if state and o.Callback then task.defer(o.Callback, true) end
	return E
end

function Card:Slider(o)
	local row = newRow(self, 52)
	local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
	local dec, E = fmtDec(step), {}
	Lbl(row, o.Name or "", 14, "Text", nil, nil, { Size = UDim2.new(.6, 0, 0, 24), Position = UDim2.fromOffset(0, 4) })
	local val = Lbl(row, "", 12, "Sub", nil, Enum.TextXAlignment.Right, { Size = UDim2.new(.4, 0, 0, 24), Position = UDim2.new(.6, 0, 0, 4) })
	local hit = New("TextButton", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 28), Parent = row })
	local bar = New("Frame", { Size = UDim2.new(1, 0, 0, 6), AnchorPoint = V2(0, .5), Position = UDim2.fromScale(0, .5), BackgroundColor3 = T.Field, Parent = hit }, { Round() })
	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar }, { Round() })
	local fg = Grad(T.Accent, T.Accent2)
	fg.Parent = fill
	local knob = New("Frame", { Size = UDim2.fromOffset(12, 12), AnchorPoint = V2(.5, .5), Position = UDim2.fromScale(1, .5), BackgroundColor3 = Color3.new(1, 1, 1), Parent = fill }, { Round() })
	local ks = Stroke(T.Accent, 2, .3)
	ks.Parent = knob
	themed(bar, function(a)
		set(bar, { BackgroundColor3 = T.Field }, a)
		set(ks, { Color = T.Accent }, a)
		fg.Color = ColorSequence.new(T.Accent, T.Accent2)
	end)
	local function snap(v)
		v = math.clamp(v, min, max)
		v = min + math.floor((v - min) / step + .5) * step
		return math.clamp(tonumber(("%." .. dec .. "f"):format(v)), min, max)
	end
	local function show(v, anim)
		val.Text = ("%." .. dec .. "f"):format(v) .. (o.Suffix or "")
		local sz = UDim2.fromScale((v - min) / (max - min), 1)
		if anim then tw(fill, { Size = sz }, .12, Enum.EasingStyle.Quad) else fill.Size = sz end
	end
	function E:Set(v, silent)
		v = snap(tonumber(v) or min)
		show(v, true)
		commit(o, E, v, silent)
	end
	function E:Get() return E.Value end
	local drag = false
	local function setDrag(d) drag = d; if self.Page then self.Page.ScrollingEnabled = not d end end
	local function fromInput(i)
		local a = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		local v = snap(min + (max - min) * a)
		if v ~= E.Value then show(v, true); commit(o, E, v) end
	end
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then setDrag(true); fromInput(i) end
	end)
	conn(self.W, UIS.InputChanged, function(i)
		if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromInput(i) end
	end)
	conn(self.W, UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then setDrag(false) end
	end)
	local d = snap(o.Default or min)
	show(d)
	commit(o, E, d, true)
	return E
end

function Card:Input(o)
	local wide = not o.Name or o.Name == ""
	local row = newRow(self, 38)
	if not wide then rowLabel(row, o, 150) end
	local box = New("TextBox", {
		Size = wide and UDim2.new(1, 0, 0, 30) or UDim2.fromOffset(138, 28), AnchorPoint = V2(1, .5), Position = UDim2.fromScale(1, .5),
		BackgroundColor3 = T.Field, PlaceholderText = o.Placeholder or "", Text = tostring(o.Default or ""),
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = o.Clear == true, Parent = row,
	}, { Corner(8), Pad(10, 0) })
	local st = Stroke(T.Line, 1, 0)
	st.Parent = box
	styleField(box, st)
	local E = { Box = box }
	function E:Set(v, silent) box.Text = tostring(v); commit(o, E, box.Text, silent) end
	box.FocusLost:Connect(function(enter)
		if o.Numeric then box.Text = box.Text:gsub("[^%d%.%-]", "") end
		commit(o, E, box.Text)
		if enter and o.OnEnter then task.spawn(o.OnEnter, box.Text) end
	end)
	commit(o, E, box.Text, true)
	return E
end

function Card:Textbox(o)
	local bh = (o.Lines or 4) * 16 + 16
	local row = newRow(self, bh + 36)
	Lbl(row, o.Name or "", 14, "Text", nil, nil, { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 4) })
	local box = New("TextBox", {
		Size = UDim2.new(1, 0, 0, bh), Position = UDim2.fromOffset(0, 32), BackgroundColor3 = T.Field, MultiLine = true, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		PlaceholderText = o.Placeholder or "", Text = tostring(o.Default or ""), Parent = row,
	}, { Corner(8), Pad(10, 8) })
	local st = Stroke(T.Line, 1, 0)
	st.Parent = box
	styleField(box, st)
	local E = { Box = box }
	function E:Set(v, silent) box.Text = tostring(v); commit(o, E, box.Text, silent) end
	box.FocusLost:Connect(function() commit(o, E, box.Text) end)
	commit(o, E, box.Text, true)
	return E
end

function Card:Number(o)
	local row = newRow(self, 38)
	rowLabel(row, o, 126)
	local min, max, step = o.Min or -math.huge, o.Max or math.huge, o.Step or 1
	local dec, E = fmtDec(step), {}
	local holder = New("Frame", { Size = UDim2.fromOffset(118, 28), AnchorPoint = V2(1, .5), Position = UDim2.fromScale(1, .5), Parent = row })
	local function mini(txt, x)
		local b = New("TextButton", { Text = txt, TextSize = 16, Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(x, 0), BackgroundColor3 = T.Field, Parent = holder }, { Corner(8) })
		themed(b, function(a) set(b, { BackgroundColor3 = T.Field, TextColor3 = T.Accent2 }, a) end)
		return b
	end
	local minus, plus = mini("-", 0), mini("+", 90)
	local box = New("TextBox", { Size = UDim2.fromOffset(54, 28), Position = UDim2.fromOffset(32, 0), BackgroundColor3 = T.Field, TextXAlignment = Enum.TextXAlignment.Center, Parent = holder }, { Corner(8) })
	local st = Stroke(T.Line, 1, 0)
	st.Parent = box
	styleField(box, st)
	local function snap(v)
		local base = min == -math.huge and 0 or min
		v = math.clamp(v, min, max)
		v = base + math.floor((v - base) / step + .5) * step
		return math.clamp(tonumber(("%." .. dec .. "f"):format(v)), min, max)
	end
	function E:Set(v, silent)
		v = snap(tonumber(v) or o.Default or 0)
		box.Text = ("%." .. dec .. "f"):format(v)
		commit(o, E, v, silent)
	end
	function E:Get() return E.Value end
	box.FocusLost:Connect(function() E:Set(box.Text) end)
	minus.MouseButton1Click:Connect(function() Sounds.Play("Click", 1.2, .25); E:Set((E.Value or 0) - step) end)
	plus.MouseButton1Click:Connect(function() Sounds.Play("Click", 1.2, .25); E:Set((E.Value or 0) + step) end)
	E:Set(o.Default or 0, true)
	return E
end

function Card:Dropdown(o)
	local row = newRow(self, 38)
	row.ClipsDescendants = true
	local multi, opts, E = o.Multi == true, o.Options or {}, {}
	local sel, single, open, buttons = {}, nil, false, {}
	local head = New("TextButton", { Size = UDim2.new(1, 0, 0, 38), Parent = row })
	Lbl(head, o.Name or "", 14, "Text", nil, nil, { Size = UDim2.new(.5, 0, 1, 0) })
	local cur = Lbl(head, "", 12, "Sub", nil, Enum.TextXAlignment.Right, { Size = UDim2.new(.5, -22, 1, 0), Position = UDim2.fromScale(.5, 0) })
	local chev = New("ImageLabel", { Size = UDim2.fromOffset(16, 16), AnchorPoint = V2(1, .5), Position = UDim2.new(1, 0, .5, 0), Parent = head })
	themed(chev, function() Icons.Apply(chev, "chevron-down", T.Sub) end)
	local list = New("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 0), Position = UDim2.fromOffset(0, 42), BackgroundColor3 = T.Field, ScrollBarThickness = 2,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = row,
	}, { Corner(10), List(2), Pad(4) })

	local function picked()
		local t = {}
		for _, n in ipairs(opts) do if sel[n] then t[#t + 1] = n end end
		return t
	end
	local function refreshText()
		if multi then
			local t = picked()
			cur.Text = #t > 0 and table.concat(t, ", ") or "None"
		else
			cur.Text = single and tostring(single) or "None"
		end
	end
	local function paintOpts(a)
		for n, b in pairs(buttons) do
			local on = multi and sel[n] or (not multi and single == n)
			set(b, { BackgroundColor3 = T.Accent, BackgroundTransparency = on and .8 or 1, TextColor3 = on and T.Text or T.Sub }, a)
		end
	end
	themed(list, function(a) set(list, { BackgroundColor3 = T.Field }, a); paintOpts(a) end)

	local function toggleOpen(state)
		open = state
		local lh = math.min(#opts, 5) * 28 + 8
		tw(row, { Size = UDim2.new(1, 0, 0, open and 38 + 8 + lh or 38) }, .3)
		tw(list, { Size = UDim2.new(1, 0, 0, open and lh or 0) }, .3)
		tw(chev, { Rotation = open and 180 or 0 }, .3)
	end
	function E:Pick(n, silent)
		if multi then sel[n] = not sel[n] or nil else single = n end
		paintOpts(true)
		refreshText()
		commit(o, E, multi and picked() or single, silent)
		if not multi then toggleOpen(false) end
	end
	local function build()
		for _, b in pairs(buttons) do b:Destroy() end
		buttons = {}
		for i, n in ipairs(opts) do
			local b = New("TextButton", { Size = UDim2.new(1, 0, 0, 26), LayoutOrder = i, BackgroundColor3 = T.Accent, BackgroundTransparency = 1, Text = tostring(n), TextColor3 = T.Sub, Parent = list }, { Corner(7) })
			buttons[n] = b
			b.MouseButton1Click:Connect(function() Sounds.Play("Click", 1.1, .25); E:Pick(n) end)
		end
		paintOpts(false)
	end
	function E:Set(v, silent)
		sel, single = {}, nil
		if multi then
			for _, n in ipairs(type(v) == "table" and v or {}) do sel[n] = true end
		else
			single = v
		end
		paintOpts(true)
		refreshText()
		commit(o, E, multi and picked() or single, silent)
	end
	function E:SetOptions(list2)
		opts = list2
		build()
		E:Set(multi and {} or nil, true)
		if open then toggleOpen(true) end
	end
	head.MouseButton1Click:Connect(function() Sounds.Play("Click", .9, .3); toggleOpen(not open) end)
	build()
	if o.Default ~= nil then E:Set(o.Default, true) else refreshText(); commit(o, E, multi and {} or nil, true) end
	return E
end

function Card:Keybind(o)
	local row = newRow(self, 38)
	rowLabel(row, o, 110)
	local btn = New("TextButton", { Size = UDim2.fromOffset(96, 26), AnchorPoint = V2(1, .5), Position = UDim2.fromScale(1, .5), BackgroundColor3 = T.Field, TextSize = 12, Parent = row }, { Corner(8) })
	local st = Stroke(T.Line, 1, 0)
	st.Parent = btn
	local E, key, listening, held = {}, o.Default, false, false
	local function paint(a)
		set(btn, { BackgroundColor3 = T.Field, TextColor3 = listening and T.Accent2 or T.Text }, a)
		set(st, { Color = listening and T.Accent or T.Line }, a)
		btn.Text = listening and "..." or (key and key.Name or "None")
	end
	themed(btn, paint)
	local function fire(v) if o.Callback then task.spawn(o.Callback, v) end end
	function E:Set(k, silent)
		key = k
		paint(true)
		commit({ Flag = o.Flag }, E, k, true)
		if not silent and o.OnChange then task.spawn(o.OnChange, k) end
	end
	btn.MouseButton1Click:Connect(function() listening = true; Sounds.Play("Click", 1, .3); paint(true) end)
	conn(self.W, UIS.InputBegan, function(i, gp)
		if listening then
			if i.UserInputType == Enum.UserInputType.Keyboard then
				listening = false
				local k = i.KeyCode
				if k == Enum.KeyCode.Escape or k == Enum.KeyCode.Backspace then k = nil end
				E:Set(k)
			end
			return
		end
		if gp or not key or i.KeyCode ~= key then return end
		local mode = o.Mode or "Press"
		if mode == "Toggle" then held = not held; fire(held)
		elseif mode == "Hold" then fire(true)
		else fire() end
	end)
	conn(self.W, UIS.InputEnded, function(i)
		if o.Mode == "Hold" and key and i.KeyCode == key then fire(false) end
	end)
	commit({ Flag = o.Flag }, E, key, true)
	return E
end

function Card:ColorPicker(o)
	local row = newRow(self, 38)
	row.ClipsDescendants = true
	rowLabel(row, o, 56)
	local h, s, v = (o.Default or Color3.fromRGB(139, 92, 246)):ToHSV()
	local E, open, dragging = {}, false, nil
	local sw = New("TextButton", { Size = UDim2.fromOffset(40, 20), AnchorPoint = V2(1, 0), Position = UDim2.new(1, 0, 0, 9), BackgroundColor3 = Color3.fromHSV(h, s, v), Parent = row }, { Corner(7), Stroke(Color3.new(1, 1, 1), 1, .75) })
	local sv = New("TextButton", { Size = UDim2.new(1, -26, 0, 96), Position = UDim2.fromOffset(0, 46), BackgroundColor3 = Color3.fromHSV(h, 1, 1), Parent = row }, { Corner(8) })
	New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sv }, { Corner(8), New("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
	New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = sv }, { Corner(8), New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }) })
	local dot = New("Frame", { Size = UDim2.fromOffset(10, 10), AnchorPoint = V2(.5, .5), ZIndex = 3, Parent = sv }, { Round(), Stroke(Color3.new(1, 1, 1), 2, 0) })
	local keys = {}
	for i = 0, 6 do keys[#keys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)) end
	local hue = New("TextButton", { Size = UDim2.fromOffset(16, 96), AnchorPoint = V2(1, 0), Position = UDim2.new(1, 0, 0, 46), BackgroundColor3 = Color3.new(1, 1, 1), Parent = row },
		{ Corner(8), New("UIGradient", { Rotation = 90, Color = ColorSequence.new(keys) }) })
	local hm = New("Frame", { Size = UDim2.new(1, 4, 0, 3), AnchorPoint = V2(.5, .5), BackgroundColor3 = Color3.new(1, 1, 1), Parent = hue }, { Round() })
	local function apply(silent)
		local c = Color3.fromHSV(h, s, v)
		sw.BackgroundColor3, sv.BackgroundColor3 = c, Color3.fromHSV(h, 1, 1)
		dot.Position, hm.Position = UDim2.fromScale(s, 1 - v), UDim2.fromScale(.5, h)
		commit(o, E, c, silent)
	end
	local function move(i)
		if dragging == "sv" then
			s = math.clamp((i.Position.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
			v = 1 - math.clamp((i.Position.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
		elseif dragging == "hue" then
			h = math.clamp((i.Position.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 1)
		else
			return
		end
		apply()
	end
	local function begin(kind, i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = kind
			if self.Page then self.Page.ScrollingEnabled = false end
			move(i)
		end
	end
	sv.InputBegan:Connect(function(i) begin("sv", i) end)
	hue.InputBegan:Connect(function(i) begin("hue", i) end)
	conn(self.W, UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then move(i) end
	end)
	conn(self.W, UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = nil
			if self.Page then self.Page.ScrollingEnabled = true end
		end
	end)
	sw.MouseButton1Click:Connect(function()
		open = not open
		Sounds.Play("Click", 1, .3)
		tw(row, { Size = UDim2.new(1, 0, 0, open and 150 or 38) }, .3)
	end)
	function E:Set(c, silent) h, s, v = c:ToHSV(); apply(silent) end
	apply(true)
	return E
end

-- [8] window -----------------------------------------------------------------
local Tab, Section = {}, {}
Tab.__index, Section.__index = Tab, Section

function Section:Card(c)
	c = c or {}
	local i = c.Column or (self._i % #self.Cols) + 1
	self._i = self._i + 1
	return makeCard(self.Cols[math.min(i, #self.Cols)], self.W, self.Page, self._i)
end
-- elements called straight on a Section go into one shared auto-card
for _, n in ipairs({ "Button", "Toggle", "Slider", "Input", "Textbox", "Number", "Dropdown", "Keybind", "ColorPicker", "Label", "Paragraph" }) do
	Section[n] = function(self, o)
		self._cur = self._cur or self:Card()
		return self._cur[n](self._cur, o)
	end
end

function Tab:Section(s)
	s = type(s) == "string" and { Name = s } or (s or {})
	self._s = self._s + 1
	local frame = New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = self._s, Parent = self.Page }, { List(3) })
	Lbl(frame, s.Name or "", 22, "Text", Enum.Font.GothamBold, nil, { Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 1 })
	if s.Description then Lbl(frame, s.Description, 12, "Sub", nil, nil, { Size = UDim2.new(1, 0, 0, 15), LayoutOrder = 2 }) end
	local cols = New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = frame },
		{ List(12, Enum.FillDirection.Horizontal), New("UIPadding", { PaddingTop = UDim.new(0, 10) }) })
	local n = (s.Columns == 1 or self.W.Narrow) and 1 or 2
	local cl = {}
	for i = 1, n do
		cl[i] = New("Frame", { Size = UDim2.new(1 / n, -12 * (n - 1) / n, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = cols }, { List(12) })
	end
	return setmetatable({ Cols = cl, _i = 0, W = self.W, Page = self.Page }, Section)
end

function Nocturne:Window(o)
	o = o or {}
	local W = { Tabs = {}, Conns = {}, Open = true }
	local title = (o.Title or self.Name):upper()
	local gui = mount(New("ScreenGui", { Name = "NocturneUI", DisplayOrder = 100 }))
	W.Gui = gui
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or V2(1280, 720)
	local sz = o.Size or V2(700, 430)
	local w, h = math.min(sz.X, vp.X - 20), math.min(sz.Y, vp.Y - 70)
	local side = w < 560 and 140 or 184
	W.Narrow = w < 540

	local holder = New("Frame", { AnchorPoint = V2(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(w, h), Parent = gui }, { Corner(18) })
	local scale = New("UIScale", { Scale = .9, Parent = holder })
	local hs = Stroke(Color3.new(1, 1, 1), 1.5, 0)
	hs.Parent = holder
	local hg = New("UIGradient", {
		Color = ColorSequence.new(T.Accent2, T.Accent),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(.5, .85), NumberSequenceKeypoint.new(1, 0) }),
		Parent = hs,
	})
	local spin = TweenService:Create(hg, TweenInfo.new(7, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
	spin:Play()

	local main = New("CanvasGroup", { Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Parent = holder }, { Corner(18) })
	local bg = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = main })
	local bgg = Grad(T.Bg, T.Glow, 45)
	bgg.Parent = bg

	local top = New("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = T.Top, Parent = main })
	local logo = New("Frame", { Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(14, 10), BackgroundColor3 = Color3.new(1, 1, 1), Parent = top }, { Corner(10) })
	local lg = Grad(T.Accent2, T.Accent, 90)
	lg.Parent = logo
	if o.Logo then
		local li = New("ImageLabel", { Size = UDim2.fromOffset(18, 18), AnchorPoint = V2(.5, .5), Position = UDim2.fromScale(.5, .5), Parent = logo })
		Icons.Apply(li, o.Logo, Color3.new(1, 1, 1))
	end
	local tt = Lbl(top, title, 20, "Text", Enum.Font.GothamBlack, nil, { Position = UDim2.fromOffset(54, 0), Size = UDim2.new(1, -150, 1, 0) })
	local tg = Grad(Color3.new(1, 1, 1), T.Accent2)
	tg.Parent = tt
	local sep = New("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 49), BackgroundColor3 = T.Line, Parent = top })

	local function winBtn(i, icon, fb, cb)
		local b = New("TextButton", { Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -44 - 36 * i, 0, 10), BackgroundColor3 = T.Field, Parent = top }, { Corner(9) })
		local im = New("ImageLabel", { Size = UDim2.fromOffset(16, 16), AnchorPoint = V2(.5, .5), Position = UDim2.fromScale(.5, .5), Parent = b })
		local tx = New("TextLabel", { Text = fb, TextSize = 16, Size = UDim2.fromScale(1, 1), Visible = false, Parent = b })
		themed(b, function(a)
			set(b, { BackgroundColor3 = T.Field }, a)
			tx.TextColor3 = T.Sub
			tx.Visible = not Icons.Apply(im, icon, T.Sub)
		end)
		b.MouseEnter:Connect(function() set(b, { BackgroundColor3 = T.Card }, true) end)
		b.MouseLeave:Connect(function() set(b, { BackgroundColor3 = T.Field }, true) end)
		b.MouseButton1Click:Connect(function() Sounds.Play("Click", 1, .3); cb() end)
	end

	local sidebar = New("Frame", { Size = UDim2.new(0, side, 1, -50), Position = UDim2.fromOffset(0, 50), BackgroundColor3 = T.Side, BackgroundTransparency = .25, Parent = main })
	local sline = New("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(1, 0), BackgroundColor3 = T.Line, Parent = sidebar })
	local tabList = New("ScrollingFrame", { Size = UDim2.fromScale(1, 1), ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = sidebar }, { Pad(12, 12), List(6) })
	local content = New("Frame", { Size = UDim2.new(1, -side, 1, -50), Position = UDim2.fromOffset(side, 50), ClipsDescendants = true, Parent = main })

	themed(main, function(a)
		set(top, { BackgroundColor3 = T.Top }, a)
		set(sidebar, { BackgroundColor3 = T.Side }, a)
		set(sep, { BackgroundColor3 = T.Line }, a)
		set(sline, { BackgroundColor3 = T.Line }, a)
		bgg.Color, lg.Color, tg.Color, hg.Color = ColorSequence.new(T.Bg, T.Glow), ColorSequence.new(T.Accent2, T.Accent), ColorSequence.new(Color3.new(1, 1, 1), T.Accent2), ColorSequence.new(T.Accent2, T.Accent)
	end)

	-- drag
	local drag, dstart, pstart
	top.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			drag, dstart, pstart = true, i.Position, holder.Position
		end
	end)
	conn(W, UIS.InputChanged, function(i)
		if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dstart
			holder.Position = UDim2.new(pstart.X.Scale, pstart.X.Offset + d.X, pstart.Y.Scale, pstart.Y.Offset + d.Y)
		end
	end)
	conn(W, UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end
	end)

	function W:Toggle(state)
		if state == nil then state = not W.Open end
		W.Open = state
		if state then holder.Visible = true end
		tw(scale, { Scale = state and 1 or .9 }, .4, state and Enum.EasingStyle.Back or Enum.EasingStyle.Quint)
		tw(main, { GroupTransparency = state and 0 or 1 }, .3)
		tw(hs, { Transparency = state and 0 or 1 }, .3)
		Sounds.Play("Open", state and 1.1 or .8, .25)
		if not state then task.delay(.35, function() if not W.Open then holder.Visible = false end end) end
	end
	function W:Destroy()
		W:Toggle(false)
		task.wait(.4)
		spin:Cancel()
		for _, c in ipairs(W.Conns) do c:Disconnect() end
		gui:Destroy()
	end
	winBtn(0, "x", "x", function() task.spawn(W.Destroy, W) end)
	winBtn(1, "minus", "-", function() W:Toggle(false) end)

	local toggleKey = o.ToggleKey or Enum.KeyCode.RightShift
	conn(W, UIS.InputBegan, function(i, gp)
		if not gp and i.KeyCode == toggleKey then W:Toggle() end
	end)
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then
		local orb = New("TextButton", { Text = title:sub(1, 1), Font = Enum.Font.GothamBlack, TextSize = 18, Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 12, .5, -22), BackgroundColor3 = Color3.new(1, 1, 1), Parent = gui }, { Round(), Grad(T.Accent2, T.Accent, 90) })
		orb.MouseButton1Click:Connect(function() W:Toggle() end)
	end

	function W:Tab(t)
		t = type(t) == "string" and { Name = t } or (t or {})
		local Tb = setmetatable({ W = W, _s = 0 }, Tab)
		local btn = New("TextButton", { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = #W.Tabs + 1, BackgroundColor3 = T.Accent, BackgroundTransparency = 1, Parent = tabList }, { Corner(12) })
		local ic = New("ImageLabel", { Size = UDim2.fromOffset(18, 18), AnchorPoint = V2(0, .5), Position = UDim2.new(0, 12, .5, 0), Parent = btn })
		local lb = New("TextLabel", { Text = t.Name or "Tab", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(t.Icon and 40 or 14, 0), Size = UDim2.new(1, -44, 1, 0), Parent = btn })
		local page = New("ScrollingFrame", { Size = UDim2.fromScale(1, 1), Visible = false, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = content }, { Pad(18, 16), List(22) })
		local hov = false
		local function paint(a)
			local on = W.Current == Tb
			set(btn, { BackgroundColor3 = T.Accent, BackgroundTransparency = on and .82 or (hov and .93 or 1) }, a)
			set(lb, { TextColor3 = on and T.Text or T.Sub }, a)
			Icons.Apply(ic, t.Icon, on and T.Accent2 or T.Sub)
			page.ScrollBarImageColor3 = T.Accent
		end
		themed(btn, paint)
		Tb.Page, Tb.Paint = page, paint
		local function select(quiet)
			if W.Current == Tb then return end
			W.Current = Tb
			for _, x in ipairs(W.Tabs) do x.Paint(true); x.Page.Visible = x == Tb end
			page.Position = UDim2.fromOffset(0, 14)
			tw(page, { Position = UDim2.fromOffset(0, 0) }, .45)
			if not quiet then Sounds.Play("Click", 1.1, .25) end
		end
		btn.MouseButton1Click:Connect(function() select() end)
		btn.MouseEnter:Connect(function() hov = true; paint(true) end)
		btn.MouseLeave:Connect(function() hov = false; paint(true) end)
		W.Tabs[#W.Tabs + 1] = Tb
		if #W.Tabs == 1 then select(true) end
		return Tb
	end

	W:Toggle(true)
	return W
end

-- [9] notify -----------------------------------------------------------------
local notifyGui, notifyHolder
function Nocturne:Notify(o)
	o = type(o) == "string" and { Title = o } or (o or {})
	if not notifyGui or not notifyGui.Parent then
		notifyGui = mount(New("ScreenGui", { Name = "NocturneNotify", DisplayOrder = 2000 }))
		notifyHolder = New("Frame", { Size = UDim2.new(0, 290, 1, -20), AnchorPoint = V2(1, 1), Position = UDim2.new(1, -14, 1, -10), Parent = notifyGui },
			{ List(8, nil, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom) })
	end
	local dur = o.Duration or 4
	local wrap = New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = notifyHolder })
	local card = New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(1.3, 0, 0, 0), BackgroundColor3 = T.Card, Parent = wrap },
		{ Corner(12), Stroke(T.Accent, 1, .55), Pad(14, 11), List(4) })
	Lbl(card, o.Title or "Notice", 14, "Text", Enum.Font.GothamBold, nil, { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1 })
	if o.Content then
		Lbl(card, o.Content, 12, "Sub", nil, nil, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2 })
	end
	local bar = New("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = T.Accent, LayoutOrder = 3, Parent = card }, { Round() })
	Sounds.Play("Tick", 1.3, .2)
	tw(card, { Position = UDim2.new(0, 0, 0, 0) }, .5, Enum.EasingStyle.Back)
	tw(bar, { Size = UDim2.new(0, 0, 0, 2) }, dur, Enum.EasingStyle.Linear)
	task.delay(dur, function()
		tw(card, { Position = UDim2.new(1.3, 0, 0, 0) }, .4, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.wait(.45)
		wrap:Destroy()
	end)
end

-- [10] panel: small centered card used by the key system and access screen -----
local function Panel(o)
	local gui = mount(New("ScreenGui", { Name = "NocturnePanel", DisplayOrder = 900 }))
	local P = { Conns = {}, Gui = gui }
	local dim = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = gui })
	local holder = New("Frame", { AnchorPoint = V2(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.new(0, math.min(o.Width or 340, 400), 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = gui },
		{ Corner(18), Stroke(T.Accent, 1.5, .45) })
	local scale = New("UIScale", { Scale = .9, Parent = holder })
	local main = New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.new(1, 1, 1), Parent = holder },
		{ Corner(18), Pad(18, 18), List(12), Grad(T.Bg, T.Glow, 60) })
	local head = New("Frame", { Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 1, Parent = main })
	New("Frame", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(0, 5), BackgroundColor3 = Color3.new(1, 1, 1), Parent = head }, { Corner(11), Grad(T.Accent2, T.Accent, 90) })
	Lbl(head, o.Title or "", 17, "Text", Enum.Font.GothamBlack, nil, { Position = UDim2.fromOffset(46, 3), Size = UDim2.new(1, -46, 0, 20) })
	Lbl(head, o.Sub or "", 12, "Sub", nil, nil, { Position = UDim2.fromOffset(46, 24), Size = UDim2.new(1, -46, 0, 16) })
	P.Card, P.Holder = makeCard(main, P, nil, 2), holder
	tw(dim, { BackgroundTransparency = .4 }, .5)
	tw(scale, { Scale = 1 }, .5, Enum.EasingStyle.Back)
	function P:Close()
		tw(scale, { Scale = .92 }, .3)
		tw(dim, { BackgroundTransparency = 1 }, .3)
		task.wait(.3)
		for _, c in ipairs(P.Conns) do c:Disconnect() end
		gui:Destroy()
	end
	return P
end

-- [11] stages: default Loader / Access / Key. Replace with Nocturne.Stages.X = function(ctx, cfg) ... end,
-- or pass a function in Boot{ Loader = function(ctx) ... end }. Return false to stop boot.
function Stages.Loader(ctx, c)
	local title = (c.Title or ctx.Config.Title or ctx.Config.Name or Nocturne.Name):upper()
	local gui = mount(New("ScreenGui", { Name = "NocturneLoader", DisplayOrder = 1000 }), true)
	local root = New("CanvasGroup", { Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Parent = gui })
	New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = root }, { Grad(Color3.fromRGB(3, 2, 7), Color3.fromRGB(32, 12, 60), 90) })
	local center = New("Frame", { AnchorPoint = V2(.5, .5), Position = UDim2.fromScale(.5, .44), Size = UDim2.fromOffset(220, 220), Parent = root })

	local tweens = {}
	local function ring(d, th, secs, dir)
		New("Frame", { AnchorPoint = V2(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(d, d), Parent = center }, { Round(), Stroke(T.Accent, th, .86) })
		local sp = New("Frame", { AnchorPoint = V2(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(d, d), Parent = center }, { Round() })
		local st = Stroke(Color3.new(1, 1, 1), th, 0)
		st.Parent = sp
		local g = New("UIGradient", {
			Color = ColorSequence.new(T.Accent2, T.Accent),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(.5, .8), NumberSequenceKeypoint.new(1, 1) }),
			Parent = st,
		})
		local tn = TweenService:Create(g, TweenInfo.new(secs, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 * dir })
		tn:Play()
		tweens[#tweens + 1] = tn
	end
	ring(220, 2, 3.4, 1)
	ring(164, 2, 2.4, -1)
	ring(110, 3, 1.5, 1)

	local logo = New("Frame", { AnchorPoint = V2(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = Color3.new(1, 1, 1), Parent = center }, { Corner(15), Grad(T.Accent2, T.Accent, 90) })
	local ls = New("UIScale", { Parent = logo })
	local pulse = TweenService:Create(ls, TweenInfo.new(.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.15 })
	pulse:Play()
	tweens[#tweens + 1] = pulse

	New("TextLabel", { Text = title, Font = Enum.Font.GothamBlack, TextSize = 24, TextColor3 = T.Text, AnchorPoint = V2(.5, 0), Position = UDim2.new(.5, 0, .44, 138), Size = UDim2.fromOffset(340, 30), Parent = root }, { Grad(Color3.new(1, 1, 1), T.Accent2) })
	local grp = New("Frame", { AnchorPoint = V2(.5, 0), Position = UDim2.new(.5, 0, .44, 178), Size = UDim2.fromOffset(260, 30), Parent = root })
	local status = New("TextLabel", { Text = "Starting", TextSize = 12, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(.75, 0, 0, 16), Parent = grp })
	local pct = New("TextLabel", { Text = "0%", TextSize = 12, TextColor3 = T.Accent2, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(.25, 0, 0, 16), Position = UDim2.fromScale(.75, 0), Parent = grp })
	local track = New("Frame", { Size = UDim2.new(1, 0, 0, 3), Position = UDim2.fromOffset(0, 24), BackgroundColor3 = Color3.fromRGB(36, 25, 58), Parent = grp }, { Round() })
	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track }, { Round(), Grad(T.Accent, T.Accent2) })

	tw(root, { GroupTransparency = 0 }, .6)
	Sounds.Play("Open", .7, .5)
	local target, done = 0, false
	task.spawn(function()
		local ok, err = pcall(ctx.Preload, function(f, txt)
			target = math.max(target, f)
			if txt then status.Text = txt end
		end)
		if not ok then warn("[Nocturne] preload error: " .. tostring(err)) end
		target, done = 1, true
	end)
	local shown, ticks = 0, 0
	while not (done and shown >= .999) do
		local dt = RunService.Heartbeat:Wait()
		shown = math.min(target, shown + math.max((target - shown) * math.min(1, dt * 5), dt * .05))
		fill.Size = UDim2.fromScale(shown, 1)
		pct.Text = math.floor(shown * 100) .. "%"
		local k = math.floor(shown * 24)
		if k > ticks then ticks = k; Sounds.Play("Tick", .8 + shown * .9, .12) end
	end
	status.Text = "Ready"
	Sounds.Play("Done", 1.15, .5)
	task.wait(.25)
	tw(root, { GroupTransparency = 1 }, .6, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	task.wait(.65)
	for _, tn in ipairs(tweens) do tn:Cancel() end
	gui:Destroy()
end

-- Access = { Whitelist = list|url, Blacklist = list|url, Check = function(player) return ok, reason end }
-- entries match UserId or username. A list that cannot be fetched denies access.
function Stages.Access(ctx, a)
	local P = LocalPlayer
	local function deny(msg)
		local pn = Panel({ Title = "ACCESS DENIED", Sub = msg })
		Sounds.Play("Error", .7, .5)
		pn.Card:Label(a.Footer or "Contact the owner if this is a mistake.")
		task.wait(4)
		pn:Close()
		return false
	end
	local function match(list)
		for _, v in ipairs(list) do
			local s = tostring(v):lower()
			if s == tostring(P.UserId) or s == P.Name:lower() then return true end
		end
		return false
	end
	if a.Blacklist ~= nil then
		local bl = getList(a.Blacklist)
		if not bl then return deny("Could not reach the blacklist") end
		if match(bl) then return deny(a.BlacklistMessage or "You are blacklisted") end
	end
	if a.Whitelist ~= nil then
		local wl = getList(a.Whitelist)
		if not wl then return deny("Could not reach the whitelist") end
		if not match(wl) then return deny(a.WhitelistMessage or "You are not whitelisted") end
	end
	if a.Check then
		local ok, res, msg = pcall(a.Check, P)
		if not ok or not res then return deny(msg or "Access denied") end
	end
	return true
end

-- Key = { Keys = list|url, Validate = function(key) return ok, message end, Link = "https://...", Note = "", Save = true }
-- Validate replaces the Keys list (use it for your own API / webhook check).
function Stages.Key(ctx, k)
	local path = ("Nocturne/%s.key"):format(hash(tostring(ctx.Config.Name or Nocturne.Name)))
	local function check(key)
		key = (key or ""):match("^%s*(.-)%s*$")
		if key == "" then return false, "Enter a key" end
		if k.Validate then
			local ok, res, msg = pcall(k.Validate, key)
			if not ok then return false, "Validation error" end
			return res and true or false, msg or (res and "Access granted" or "Invalid key")
		end
		local list = getList(k.Keys)
		if not list then return false, "Could not reach the key server" end
		for _, v in ipairs(list) do
			if v == key then return true, "Access granted" end
		end
		return false, "Invalid key"
	end
	if k.Save ~= false and readfile and isfile then
		local ok, saved = pcall(function() return isfile(path) and readfile(path) or nil end)
		if ok and saved and check(saved) then return true end
	end
	local P = Panel({ Title = k.Title or "KEY SYSTEM", Sub = k.Note or "Enter your key to continue" })
	local status = P.Card:Label("")
	local input = P.Card:Input({ Placeholder = "Paste your key", OnEnter = function() end })
	local result, busy = nil, false
	local function submit()
		if busy then return end
		busy = true
		local text = input.Box.Text
		local ok, msg = check(text)
		if ok then
			status:Set(msg, T.Accent2)
			Sounds.Play("Done", 1.2, .5)
			if k.Save ~= false and writefile then
				pcall(function() ensureDirs(); writefile(path, text:match("^%s*(.-)%s*$")) end)
			end
			task.wait(.6)
			result = true
		else
			status:Set(msg, Color3.fromRGB(255, 90, 110))
			Sounds.Play("Error", .7, .5)
			local p0 = P.Holder.Position
			for _, dx in ipairs({ -10, 10, -6, 6, 0 }) do
				tw(P.Holder, { Position = p0 + UDim2.fromOffset(dx, 0) }, .05, Enum.EasingStyle.Sine)
				task.wait(.05)
			end
			busy = false
		end
	end
	P.Card:Button({ Name = "Get key", Icon = "key-round", Callback = function()
		if k.Link and clip then
			clip(k.Link)
			Nocturne:Notify({ Title = "Link copied", Content = k.Link, Duration = 3 })
		else
			Nocturne:Notify({ Title = "No key link set", Duration = 3 })
		end
	end })
	P.Card:Button({ Name = "Verify", Icon = "check", Primary = true, Callback = submit })
	P.Card:Button({ Name = "Cancel", Callback = function() result = false end })
	input.Box.FocusLost:Connect(function(enter) if enter then submit() end end)
	repeat task.wait(.1) until result ~= nil
	P:Close()
	return result
end

-- [12] boot --------------------------------------------------------------------
-- Nocturne:Boot{ Name, Title, Theme, Preload = {urls/functions}, Loader, Access, Key, Gui = function(Lib, ctx) end }
function Nocturne:Boot(cfg)
	cfg = cfg or {}
	if cfg.Name then self.Name = cfg.Name end
	if cfg.Theme then self:SetTheme(cfg.Theme) end
	local ctx = { Config = cfg, Lib = self, Player = LocalPlayer }
	function ctx.Preload(report) return Nocturne.Preload(cfg, report) end
	for _, name in ipairs({ "Loader", "Access", "Key" }) do
		local v = cfg[name]
		if v ~= false and (name == "Loader" or v ~= nil) then
			local fn = type(v) == "function" and v or Stages[name]
			local ok, res = pcall(fn, ctx, type(v) == "table" and v or {})
			if not ok then
				warn(("[%s] %s stage error: %s"):format(self.Name, name, tostring(res)))
				if name ~= "Loader" then return false end
			elseif res == false then
				return false
			end
		end
	end
	if not self._loaded then pcall(Nocturne.Preload, cfg, function() end) end -- custom/disabled loader: still load icons
	if cfg.Gui then
		local ok, err = xpcall(cfg.Gui, function(e) return debug.traceback(tostring(e), 2) end, self, ctx)
		if not ok then warn(("[%s] Gui error: %s"):format(self.Name, tostring(err))) end
	end
	return true
end

return Nocturne
