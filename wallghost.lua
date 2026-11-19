--[[
========================================================
  WALL GHOST
  repo : supercaptain1233/wallghost
  file : wallghost.lua
  ------------------------------------------------------
  Universal noclip that fights back.
  ------------------------------------------------------
  The red BEST NOCLIP button turns green and you can
  walk through walls. That part is simple.
  ------------------------------------------------------
  The hard part is what comes after. Some games see you
  inside a wall and do one of two things:
    1. shove you back to where you were standing
    2. reset your character
  Both are handled here:
    - a position guard remembers where you were and
      puts you back when the game shoves you
    - a floor holder keeps you on top of the ground so
      you never drop through the map
    - if you do get reset, the character comes back
      and noclip turns itself back on in the same frame
  ------------------------------------------------------
  o   = shrink the box into a little circle
  MOVE = hold and drag the box
  X    = unload and put every part back
========================================================
]]

local RAW = "https://raw.githubusercontent.com/"
  .. "supercaptain1233/wallghost/main/wallghost.lua"

pcall(function()
  local old = getgenv().WallGhost
  if old and old.destroy then old.destroy() end
end)

task.wait(0.2)

local S = {}
getgenv().WallGhost = S

S.alive = true
S.conns = {}
S.on = false
S.ui = {}
S.gui = nil
S.saved = {}
S.char = nil
S.hrp = nil
S.hum = nil
S.lastPos = nil
S.strikes = 0
S.rebaseUntil = 0
S.groundY = nil
S.touched = 0

-- ======================================================
-- services, all wrapped so one failure can't kill boot
-- ======================================================
local function svc(n)
  local ok, s = pcall(function()
    return game:GetService(n)
  end)
  if ok then return s end
  return nil
end

local Players = svc("Players")
local RunService = svc("RunService")
local UIS = svc("UserInputService")
local VirtualUser = svc("VirtualUser")

local LP = Players and Players.LocalPlayer
if not LP then return end

-- ======================================================
-- tiny helpers
-- ======================================================
local function track(c)
  if c then S.conns[#S.conns + 1] = c end
  return c
end

local function safe(fn, ...)
  local ok, a = pcall(fn, ...)
  if ok then return a end
  return nil
end

local function now()
  return os.clock()
end

-- ======================================================
-- colors
-- ======================================================
local C_RED = Color3.fromRGB(196, 62, 72)
local C_GREEN = Color3.fromRGB(38, 190, 150)
local C_TEXT_ON = Color3.fromRGB(8, 24, 18)
local C_TEXT_OFF = Color3.fromRGB(255, 235, 235)

-- ======================================================
-- ray setup for the floor holder
-- ======================================================
local rp = RaycastParams.new()
rp.IgnoreWater = true
safe(function()
  rp.FilterType = Enum.RaycastFilterType.Exclude
end)

local function setFilter()
  local list = {}
  if S.char then
    for _, d in ipairs(S.char:GetDescendants()) do
      if d:IsA("BasePart") then list[#list + 1] = d end
    end
  end
  rp.FilterDescendantsInstances = list
end

-- ======================================================
-- part stripping
-- ======================================================
-- we remember what every part used to be so the game
-- sees the same numbers again when we switch off
local function stripOne(p)
  if not p or not p:IsA("BasePart") then return end
  if S.saved[p] == nil then
    S.saved[p] = p.CanCollide
  end
  if p.CanCollide then
    safe(function() p.CanCollide = false end)
    S.touched = S.touched + 1
  end
end

local function stripAll()
  if not S.char then return end
  S.touched = 0
  for _, d in ipairs(S.char:GetDescendants()) do
    stripOne(d)
  end
end

local function restoreAll()
  for p, v in pairs(S.saved) do
    if p and p.Parent then
      safe(function() p.CanCollide = v end)
    end
  end
  S.saved = {}
  S.touched = 0
end

-- ======================================================
-- character hooking
-- ======================================================
local function hookChar()
  local c = LP.Character
  S.char = c
  if not c then return end

  S.hrp = c:FindFirstChild("HumanoidRootPart")
  S.hum = c:FindFirstChildOfClass("Humanoid")
  S.lastPos = nil
  S.strikes = 0
  S.groundY = nil

  setFilter()

  -- anything new that appears on the body also gets
  -- its collision taken away
  track(c.DescendantAdded:Connect(function(d)
    if not S.on then return end
    if d:IsA("BasePart") then
      stripOne(d)
    end
  end))

  if S.on then
    stripAll()
  end
end

-- ======================================================
-- the floor holder
-- keeps you walking on the ground instead of dropping
-- through it, because collisions are gone
-- ======================================================
local function holdFloor(dt)
  local hrp = S.hrp
  if not hrp or not hrp.Parent then return end

  setFilter()

  local from = hrp.Position + Vector3.new(0, 2, 0)
  local res = safe(function()
    return workspace:Raycast(from, Vector3.new(0, -16, 0), rp)
  end)

  local v = safe(function()
    return hrp.AssemblyLinearVelocity
  end) or Vector3.new(0, 0, 0)

  if res and res.Position then
    local target = res.Position.Y + 3.2
    if S.groundY == nil then S.groundY = target end

    if v.Y <= 1 then
      local diff = target - hrp.Position.Y
      if math.abs(diff) > 0.4 then
        safe(function()
          hrp.CFrame = CFrame.new(
            hrp.Position.X,
            hrp.Position.Y + diff * 0.5,
            hrp.Position.Z
          ) * hrp.CFrame.Rotation
        end)
      end
    end

    S.groundY = target
  else
    -- nothing under us, hang at the last known ground
    if S.groundY and v.Y < -1 and v.Y > -80 then
      safe(function()
        hrp.CFrame = CFrame.new(
          hrp.Position.X,
          S.groundY,
          hrp.Position.Z
        ) * hrp.CFrame.Rotation
      end)
    end
  end
end

-- ======================================================
-- the position guard
-- this is the part that beats "put me back where I was"
-- ======================================================
local function guardPos()
  local hrp = S.hrp
  if not hrp or not hrp.Parent then return end

  local pos = hrp.Position
  local t = now()

  if not S.lastPos then
    S.lastPos = pos
    return
  end

  if t < S.rebaseUntil then
    S.lastPos = pos
    return
  end

  local jump = (pos - S.lastPos).Magnitude

  if jump > 8 then
    S.strikes = S.strikes + 1

    if S.strikes >= 14 then
      -- the game really means it, let it win this one
      S.rebaseUntil = t + 1.0
      S.strikes = 0
      S.lastPos = pos
    else
      -- shove ourselves back
      safe(function()
        hrp.CFrame = CFrame.new(S.lastPos)
          * hrp.CFrame.Rotation
      end)
    end
  else
    if S.strikes > 0 then
      S.strikes = S.strikes - 0.5
    end
    S.lastPos = pos
  end
end

-- ======================================================
-- on / off
-- ======================================================
local function paintMain()
  local b = S.ui.main
  if not b then return end
  if S.on then
    b.BackgroundColor3 = C_GREEN
    b.TextColor3 = C_TEXT_ON
    b.Text = "BEST NOCLIP\nON"
  else
    b.BackgroundColor3 = C_RED
    b.TextColor3 = C_TEXT_OFF
    b.Text = "BEST NOCLIP\nOFF"
  end
end

local function paintStatus()
  local l = S.ui.status
  if not l then return end
  if S.on then
    l.Text = "walls ignored  -  " .. tostring(S.touched)
      .. " parts"
    l.TextColor3 = Color3.fromRGB(150, 235, 200)
  else
    l.Text = "walls solid"
    l.TextColor3 = Color3.fromRGB(140, 150, 165)
  end
end

function setOn(v)
  S.on = v and true or false

  if S.on then
    hookChar()
    stripAll()
    S.lastPos = nil
    S.strikes = 0
    S.rebaseUntil = 0
    -- drop the humanoid into a stable state so the
    -- body does not fight the missing collisions
    if S.hum then
      safe(function()
        S.hum:ChangeState(Enum.HumanoidStateType.Running)
      end)
    end
  else
    restoreAll()
    S.lastPos = nil
    S.strikes = 0
  end

  paintMain()
  paintStatus()
end

-- ======================================================
-- protections
-- ======================================================
function antiAfk()
  track(LP.Idled:Connect(function()
    safe(function()
      VirtualUser:CaptureController()
      VirtualUser:ClickButton2(Vector2.new())
    end)
  end))
end

function antiKick()
  safe(function()
    queue_on_teleport(
      ("loadstring(game:HttpGet('%s'))()"):format(RAW)
    )
  end)
end

-- if the box gets deleted by the game, put it back
function guiWatch()
  if not S.gui then return end
  if S.gui.Parent then return end
  safe(function() S.gui.Parent = getgenv().WallGhostHost end)
end

-- if we get reset, turn noclip straight back on
function watchRespawn()
  track(LP.CharacterAdded:Connect(function()
    task.wait(0.15)
    hookChar()
    if S.on then
      stripAll()
    end
    paintStatus()
  end))

  track(LP.CharacterRemoving:Connect(function()
    S.hrp = nil
    S.hum = nil
  end))
end

-- ======================================================
-- shutdown
-- ======================================================
S.destroy = function()
  if not S.alive then return end
  S.alive = false

  safe(function() if S.on then setOn(false) end end)

  for _, c in ipairs(S.conns) do
    safe(function() c:Disconnect() end)
  end
  S.conns = {}

  safe(function() if S.gui then S.gui:Destroy() end end)
  safe(function()
    if getgenv().WallGhost == S then
      getgenv().WallGhost = nil
    end
  end)
end

-- ======================================================
-- gui helpers
-- ======================================================
local function mk(class, props, parent)
  local i = Instance.new(class)
  for k, v in pairs(props) do
    i[k] = v
  end
  if parent then i.Parent = parent end
  return i
end

local function host()
  local h = nil
  safe(function() h = gethui() end)
  if not h then
    safe(function() h = game:GetService("CoreGui") end)
  end
  if not h then h = LP:FindFirstChild("PlayerGui") end
  return h
end

-- ======================================================
-- gui
-- ======================================================
local function buildGui()
  local gui = mk("ScreenGui", {
    Name = "WallGhostUI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 1200,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
  })

  safe(function()
    if syn and syn.protect_gui then
      syn.protect_gui(gui)
    end
  end)

  local h = host()
  gui.Parent = h
  getgenv().WallGhostHost = h
  S.gui = gui

  -- the box
  local f = mk("Frame", {
    Name = "Box",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(258, 226),
    BackgroundColor3 = Color3.fromRGB(19, 22, 29),
    BorderSizePixel = 0,
  }, gui)

  mk("UICorner", { CornerRadius = UDim.new(0, 12) }, f)
  mk("UIStroke", {
    Color = Color3.fromRGB(60, 70, 88),
    Thickness = 1.5,
  }, f)

  -- title bar
  local bar = mk("Frame", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = Color3.fromRGB(27, 31, 41),
    BorderSizePixel = 0,
  }, f)

  mk("UICorner", { CornerRadius = UDim.new(0, 12) }, bar)
  mk("Frame", {
    Size = UDim2.new(1, 0, 0, 14),
    Position = UDim2.new(0, 0, 1, -14),
    BackgroundColor3 = Color3.fromRGB(27, 31, 41),
    BorderSizePixel = 0,
  }, bar)

  -- the name, top left, lowercase
  mk("TextLabel", {
    Text = "noclip",
    Position = UDim2.new(0, 12, 0, 0),
    Size = UDim2.new(0, 90, 1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(214, 224, 240),
    TextXAlignment = Enum.TextXAlignment.Left,
  }, bar)

  -- shrink to circle
  local circleBtn = mk("TextButton", {
    Text = "o",
    Position = UDim2.new(1, -100, 0, 5),
    Size = UDim2.new(0, 20, 0, 20),
    BackgroundColor3 = Color3.fromRGB(46, 54, 68),
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(190, 202, 220),
  }, bar)
  mk("UICorner", { CornerRadius = UDim.new(1, 0) }, circleBtn)

  -- move
  local moveBtn = mk("TextButton", {
    Text = "MOVE",
    Position = UDim2.new(1, -74, 0, 5),
    Size = UDim2.new(0, 44, 0, 20),
    BackgroundColor3 = Color3.fromRGB(46, 54, 68),
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = Color3.fromRGB(190, 202, 220),
  }, bar)
  mk("UICorner", { CornerRadius = UDim.new(0, 6) }, moveBtn)

  -- close
  local closeBtn = mk("TextButton", {
    Text = "X",
    Position = UDim2.new(1, -26, 0, 5),
    Size = UDim2.new(0, 20, 0, 20),
    BackgroundColor3 = Color3.fromRGB(190, 58, 68),
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(255, 238, 238),
  }, bar)
  mk("UICorner", { CornerRadius = UDim.new(0, 6) }, closeBtn)

  -- the big centre button
  local main = mk("TextButton", {
    Text = "BEST NOCLIP\nOFF",
    Position = UDim2.new(0, 20, 0, 44),
    Size = UDim2.new(1, -40, 0, 110),
    BackgroundColor3 = C_RED,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 17,
    TextColor3 = C_TEXT_OFF,
  }, f)

  mk("UICorner", { CornerRadius = UDim.new(0, 14) }, main)
  mk("UIStroke", {
    Color = Color3.fromRGB(90, 100, 120),
    Thickness = 1,
  }, main)

  -- status
  local status = mk("TextLabel", {
    Text = "walls solid",
    Position = UDim2.new(0, 16, 0, 164),
    Size = UDim2.new(1, -32, 0, 16),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = Color3.fromRGB(140, 150, 165),
    TextXAlignment = Enum.TextXAlignment.Center,
  }, f)

  mk("TextLabel", {
    Text = "hold MOVE to drag  -  o to shrink",
    Position = UDim2.new(0, 16, 0, 184),
    Size = UDim2.new(1, -32, 0, 14),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 9,
    TextColor3 = Color3.fromRGB(104, 114, 130),
    TextXAlignment = Enum.TextXAlignment.Center,
  }, f)

  mk("TextLabel", {
    Text = "green = walls are gone",
    Position = UDim2.new(0, 16, 0, 200),
    Size = UDim2.new(1, -32, 0, 14),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 9,
    TextColor3 = Color3.fromRGB(94, 104, 120),
    TextXAlignment = Enum.TextXAlignment.Center,
  }, f)

  -- the little circle it shrinks into
  local mini = mk("TextButton", {
    Text = "N",
    Position = UDim2.new(0.5, -27, 0.5, -27),
    Size = UDim2.fromOffset(54, 54),
    BackgroundColor3 = C_RED,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Visible = false,
    ZIndex = 5,
  }, gui)

  mk("UICorner", { CornerRadius = UDim.new(1, 0) }, mini)
  mk("UIStroke", {
    Color = Color3.fromRGB(235, 235, 245),
    Thickness = 2,
  }, mini)

  S.ui.box = f
  S.ui.mini = mini
  S.ui.main = main
  S.ui.status = status

  -- shrink / grow
  track(circleBtn.MouseButton1Click:Connect(function()
    f.Visible = false
    mini.Visible = true
    mini.Position = UDim2.new(
      f.Position.X.Scale,
      f.Position.X.Offset - 27,
      f.Position.Y.Scale,
      f.Position.Y.Offset - 27
    )
  end))

  track(mini.MouseButton1Click:Connect(function()
    mini.Visible = false
    f.Visible = true
  end))

  -- the switch
  track(main.MouseButton1Click:Connect(function()
    setOn(not S.on)
    if S.on then
      mini.BackgroundColor3 = C_GREEN
    else
      mini.BackgroundColor3 = C_RED
    end
  end))

  track(closeBtn.MouseButton1Click:Connect(function()
    S.destroy()
  end))

  -- drag
  local dragging = false
  local dragStart = nil
  local startPos = nil

  track(moveBtn.InputBegan:Connect(function(input)
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1
      or t == Enum.UserInputType.Touch then
      dragging = true
      dragStart = input.Position
      startPos = f.Position
      moveBtn.BackgroundColor3 = Color3.fromRGB(70, 84, 104)
    end
  end))

  track(UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseMovement
      or t == Enum.UserInputType.Touch then
      local d = input.Position - dragStart
      f.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + d.X,
        startPos.Y.Scale,
        startPos.Y.Offset + d.Y
      )
    end
  end))

  track(UIS.InputEnded:Connect(function(input)
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1
      or t == Enum.UserInputType.Touch then
      if dragging then
        dragging = false
        moveBtn.BackgroundColor3 = Color3.fromRGB(46, 54, 68)
      end
    end
  end))

  paintMain()
  paintStatus()
end

-- ======================================================
-- main loop
-- ======================================================
function startLoop()
  local tick = 0

  track(RunService.RenderStepped:Connect(function(dt)
    if not S.alive then return end

    if not S.on then return end

    -- bodies that are already there get stripped again
    -- every frame, this is what makes it hold
    if S.char then
      for _, d in ipairs(S.char:GetDescendants()) do
        if d:IsA("BasePart") and d.CanCollide then
          stripOne(d)
        end
      end
    end

    holdFloor(dt)
    guardPos()

    tick = tick + dt
    if tick >= 0.5 then
      tick = 0
      guiWatch()
      paintStatus()
    end
  end))
end

-- ======================================================
-- boot
-- ======================================================
function boot()
  hookChar()
  buildGui()
  antiAfk()
  antiKick()
  watchRespawn()
  startLoop()
  safe(function() setthreadidentity(7) end)
end

local ok, err = xpcall(boot, function(e)
  return tostring(e) .. "\n" .. debug.traceback()
end)

if not ok then
  safe(function() warn("[WallGhost] " .. tostring(err)) end)
  safe(function()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    local box = Instance.new("TextLabel")
    box.Size = UDim2.fromOffset(300, 90)
    box.Position = UDim2.new(0.5, -150, 0, 60)
    box.BackgroundColor3 = Color3.fromRGB(30, 16, 16)
    box.TextColor3 = Color3.fromRGB(255, 190, 190)
    box.Font = Enum.Font.Code
    box.TextSize = 10
    box.TextWrapped = true
    box.Text = "BOOT ERROR\n" .. tostring(err)
    box.Parent = pg
    task.delay(14, function()
      safe(function() box:Destroy() end)
    end)
  end)
end
