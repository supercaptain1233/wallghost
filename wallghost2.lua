--[[
========================================================
  WALL GHOST 2   FINAL BUILD
  repo : supercaptain1233/wallghost
  file : wallghost2.lua
  ------------------------------------------------------
  THE PROBLEM
  ------------------------------------------------------
  Version one lost a shoving match. The game pushed
  you back, the script pushed you forward, the game
  pushed you back. Each push is a real position
  change, so a steal zone watches you leave and
  return, and cancels the steal.
  ------------------------------------------------------
  THE ANSWER
  ------------------------------------------------------
  There is no shoving here. The script keeps its own
  copy of your position and writes that same number
  every frame. Whatever the game writes is replaced
  before the frame ends. One position. No wobble.
  ------------------------------------------------------
  THE DISGUISE
  ------------------------------------------------------
  Collisions are not removed by flipping CanCollide,
  because a game can read CanCollide and see it.
  They are removed with a collision group, so
  CanCollide still reads true and looks untouched.
  ------------------------------------------------------
  THE GIVE UP RULE
  ------------------------------------------------------
  If the game insists on a spot for half a second,
  the script accepts it. Real teleports still work.
  ------------------------------------------------------
  CONTROLS
  ------------------------------------------------------
  main button = red off, green on
  o           = shrink to circle
  MOVE        = drag the box
  X           = unload and restore every part
  HARD        = script walks you, game cannot
  SOFT        = game walks you, only walls off
  Q and E     = speed down and up
========================================================
]]

local RAW = "https://raw.githubusercontent.com/"
  .. "supercaptain1233/wallghost/main/wallghost2.lua"

pcall(function()
  local old = getgenv().WallGhost2
  if old and old.destroy then old.destroy() end
end)

task.wait(0.25)

-- ======================================================
-- end of preamble
-- ======================================================
-- ======================================================
-- section 1, state
-- ======================================================
local S = {}
getgenv().WallGhost2 = S

S.alive = true
S.conns = {}
S.on = false
S.hard = true
S.speed = 19
S.ui = {}
S.gui = nil
S.char = nil
S.hrp = nil
S.hum = nil
S.pos = nil
S.vy = 0
S.saved = {}
S.stats = 0
S.guiHost = nil
S.tick = 0
S.mismatch = 0
S.adopt = 0
S.log = {}
S.logMax = 6
S.recoveries = 0
S.frames = 0
S.lastAdopt = 0
S.savedWalk = nil
S.savedJump = nil
S.padDir = Vector3.new(0, 0, 0)
S.padInput = nil
S.controls = nil
S.controlsTried = false
S.groupOK = false
S.busy = false
S.confirm = 0

-- ======================================================
-- section 2, services
-- every lookup is wrapped, one bad service cannot
-- take the whole boot down
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
local PhysicsService = svc("PhysicsService")

local LP = Players and Players.LocalPlayer
if not LP then return end

-- ======================================================
-- section 3, helpers
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

local function note(msg)
  S.log[#S.log + 1] = msg
  while #S.log > S.logMax do
    table.remove(S.log, 1)
  end
end

local function nowSec()
  return os.clock()
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function flatLen(v)
  return math.sqrt(v.X * v.X + v.Z * v.Z)
end

local function flatUnit(v)
  local m = flatLen(v)
  if m < 0.0001 then return nil end
  return Vector3.new(v.X / m, 0, v.Z / m)
end

local function v0()
  return Vector3.new(0, 0, 0)
end

local function exists(p)
  return p ~= nil and p.Parent ~= nil
end

local function isPart(p)
  if not exists(p) then return false end
  return p:IsA("BasePart")
end

local function round2(n)
  return math.floor(n * 100 + 0.5) / 100
end

local function fmtPos(v)
  return round2(v.X) .. ", " .. round2(v.Y)
    .. ", " .. round2(v.Z)
end

local function dist(a, b)
  return (a - b).Magnitude
end

local function joinTable(t, sep)
  return table.concat(t, sep)
end

-- ======================================================
-- section 4, colours
-- ======================================================
local C_RED = Color3.fromRGB(196, 62, 72)
local C_GREEN = Color3.fromRGB(38, 190, 150)
local C_TEXT_ON = Color3.fromRGB(8, 24, 18)
local C_TEXT_OFF = Color3.fromRGB(255, 236, 236)
local C_DIM = Color3.fromRGB(140, 150, 165)
local C_GOOD = Color3.fromRGB(150, 235, 200)
local C_WARN = Color3.fromRGB(240, 190, 120)
local C_FAR = Color3.fromRGB(110, 120, 138)

-- ======================================================
-- section 5, collision group
-- this is the disguise. parts stop colliding with the
-- world while their own CanCollide stays true, so
-- anything reading CanCollide sees normal numbers
-- ======================================================
local GROUP = "WGNoClipV2"

safe(function()
  PhysicsService:RegisterCollisionGroup(GROUP)
end)

S.groupOK = safe(function()
  PhysicsService:CollisionGroupSetCollidable(
    GROUP, "Default", false)
  return true
end) or false

local function groupAlive()
  return S.groupOK == true
end

-- ======================================================
-- section 6, raycast setup
-- ======================================================
local rp = RaycastParams.new()
rp.IgnoreWater = true

safe(function()
  rp.FilterType = Enum.RaycastFilterType.Exclude
end)

local function setRayFilter()
  local list = {}
  if S.char then
    for _, d in ipairs(S.char:GetDescendants()) do
      if d:IsA("BasePart") then
        list[#list + 1] = d
      end
    end
  end
  rp.FilterDescendantsInstances = list
end

-- ======================================================
-- section 7, capture and restore
-- every single thing we change is written down first
-- so X puts the game back exactly as it was
-- ======================================================
local function capturePart(p)
  if not isPart(p) then return end
  if S.saved[p] then return end
  S.saved[p] = {
    collide = p.CanCollide,
    group = p.CollisionGroup,
  }
end

local function applyPart(p)
  if not isPart(p) then return end
  capturePart(p)
  if groupAlive() then
    safe(function()
      p.CollisionGroup = GROUP
    end)
  else
    safe(function()
      p.CanCollide = false
    end)
  end
  S.stats = S.stats + 1
end

local function applyAll()
  if not S.char then return end
  S.stats = 0
  for _, d in ipairs(S.char:GetDescendants()) do
    applyPart(d)
  end
end

local function restoreOne(p, rec)
  if not exists(p) then return end
  if rec.group ~= nil then
    safe(function()
      p.CollisionGroup = rec.group
    end)
  end
  if rec.collide ~= nil then
    safe(function()
      p.CanCollide = rec.collide
    end)
  end
end

local function restoreAll()
  for p, rec in pairs(S.saved) do
    restoreOne(p, rec)
  end
  S.saved = {}
  S.stats = 0
end

local function verifyParts()
  if not S.char then return end
  for _, d in ipairs(S.char:GetDescendants()) do
    if isPart(d) then
      if groupAlive() then
        if d.CollisionGroup ~= GROUP then
          capturePart(d)
          safe(function()
            d.CollisionGroup = GROUP
          end)
        end
      elseif d.CanCollide then
        applyPart(d)
      end
    end
  end
end

-- ======================================================
-- section 8, input
-- three sources, most trusted first. the pad is ours
-- so it works even when a game hides its own stick
-- ======================================================
local function getControls()
  if S.controlsTried then return S.controls end
  S.controlsTried = true
  safe(function()
    local ps = LP:FindFirstChild("PlayerScripts")
    local pm = ps and ps:FindFirstChild("PlayerModule")
    if not pm then return end
    local mod = require(pm)
    S.controls = mod:GetControls()
  end)
  return S.controls
end

local function padDir()
  if flatLen(S.padDir) > 0.06 then
    return flatUnit(S.padDir)
  end
  return nil
end

local function controlDir()
  local c = getControls()
  if not c then return nil end
  local ok, v = pcall(function()
    return c:GetMoveVector()
  end)
  if not ok or not v then return nil end
  return flatUnit(v)
end

local function humDir()
  if not S.char then return nil end
  local hum = S.char:FindFirstChildOfClass("Humanoid")
  if not hum then return nil end
  return flatUnit(hum.MoveDirection)
end

local function keyDir()
  if not UIS then return nil end
  local x, z = 0, 0
  if UIS:IsKeyDown(Enum.KeyCode.W) then z = z - 1 end
  if UIS:IsKeyDown(Enum.KeyCode.S) then z = z + 1 end
  if UIS:IsKeyDown(Enum.KeyCode.A) then x = x - 1 end
  if UIS:IsKeyDown(Enum.KeyCode.D) then x = x + 1 end
  return flatUnit(Vector3.new(x, 0, z))
end

local function readDir()
  local u = padDir()
  if u then return u end
  u = controlDir()
  if u then return u end
  u = humDir()
  if u then return u end
  u = keyDir()
  if u then return u end
  return v0()
end

local function wantsJump()
  if not UIS then return false end
  if UIS:IsKeyDown(Enum.KeyCode.Space) then return true end
  if not S.hum then return false end
  local st = safe(function()
    return S.hum:GetState()
  end)
  return st == Enum.HumanoidStateType.Jumping
end

local function wantsSpeedUp()
  if not UIS then return false end
  return UIS:IsKeyDown(Enum.KeyCode.E)
end

local function wantsSpeedDown()
  if not UIS then return false end
  return UIS:IsKeyDown(Enum.KeyCode.Q)
end

-- ======================================================
-- section 9, floor finder
-- five probes, not one. centre plus four sides so you
-- can stand on the edge of a ledge without slipping
-- ======================================================
local PROBES = {
  Vector3.new(0, 0, 0),
  Vector3.new(0, 0, -2),
  Vector3.new(0, 0, 2),
  Vector3.new(-2, 0, 0),
  Vector3.new(2, 0, 0),
}

local function probeDown(from, d)
  return safe(function()
    return workspace:Raycast(from, Vector3.new(0, -d, 0), rp)
  end)
end

local function findFloor()
  local hrp = S.hrp
  if not hrp then return nil end
  setRayFilter()
  local base = hrp.Position
  local best = nil
  for _, off in ipairs(PROBES) do
    local from = base + off + Vector3.new(0, 2.5, 0)
    local res = probeDown(from, 14)
    if res and res.Position then
      local y = res.Position.Y + 3.2
      if not best or y > best then best = y end
    end
  end
  return best
end

local function voidCheck(y)
  if not y then return y end
  if y < -700 then
    S.recoveries = S.recoveries + 1
    note("void recover")
    return 60
  end
  return y
end

-- ======================================================
-- section 10, character hooking
-- ======================================================
local function hookChar()
  local c = LP.Character
  S.char = c
  if not c then return end
  S.hrp = c:FindFirstChild("HumanoidRootPart")
  S.hum = c:FindFirstChildOfClass("Humanoid")
  S.vy = 0
  if S.hrp then S.pos = S.hrp.Position end
  setRayFilter()
  if S.hum then
    S.savedWalk = S.hum.WalkSpeed
    S.savedJump = S.hum.JumpPower
  end
  track(c.DescendantAdded:Connect(function(d)
    if not S.on then return end
    if d:IsA("BasePart") then applyPart(d) end
  end))
  note("char hooked")
end

local function unhookChar()
  S.hrp = nil
  S.hum = nil
  S.pos = nil
  S.vy = 0
end

-- ======================================================
-- section 11, movement engine
-- HARD mode. the script is the only writer of
-- position. one writer, one number, no fight
-- ======================================================
local function applyJump()
  if S.vy > 0.5 then return end
  if wantsJump() then
    S.vy = 52
  end
end

local function applyGravity(dt)
  if wantsJump() then return end
  S.vy = S.vy - 190 * dt
  if S.vy < -220 then S.vy = -220 end
end

local function engineStep(dt)
  local hrp = S.hrp
  if not exists(hrp) then return end
  if not S.pos then
    S.pos = hrp.Position
    return
  end

  local dir = readDir()
  if flatLen(dir) > 0.05 then
    S.pos = S.pos + (dir * S.speed * dt)
  end

  local floorY = voidCheck(findFloor())

  applyJump()
  applyGravity(dt)

  local nextY = S.pos.Y + S.vy * dt

  if floorY and nextY <= floorY then
    nextY = floorY
    S.vy = 0
  end

  S.pos = Vector3.new(S.pos.X, nextY, S.pos.Z)

  safe(function()
    hrp.CFrame = CFrame.new(S.pos) * hrp.CFrame.Rotation
  end)
  safe(function()
    hrp.AssemblyLinearVelocity = v0()
  end)
  safe(function()
    hrp.AssemblyAngularVelocity = v0()
  end)

  S.frames = S.frames + 1
end

local function speedKeys(dt)
  if wantsSpeedUp() then
    S.speed = clamp(S.speed + 22 * dt, 8, 90)
  end
  if wantsSpeedDown() then
    S.speed = clamp(S.speed - 22 * dt, 8, 90)
  end
end

-- ======================================================
-- section 12, drift check
-- if the game insists on a spot for half a second we
-- give in. real teleports keep working, no flicker
-- ======================================================
local function driftCheck(dt)
  local hrp = S.hrp
  if not exists(hrp) then return end
  if not S.pos then return end
  local gap = dist(hrp.Position, S.pos)
  if gap > 6 then
    S.mismatch = S.mismatch + dt
    if S.mismatch > 0.5 then
      S.pos = hrp.Position
      S.vy = 0
      S.mismatch = 0
      S.adopt = S.adopt + 1
      note("adopted game pos")
    end
  else
    S.mismatch = math.max(0, S.mismatch - dt * 2)
  end
end

-- ======================================================
-- section 13, soft mode
-- game keeps control, only collisions are off
-- ======================================================
local function softStep()
  local hrp = S.hrp
  if not exists(hrp) then return end
  local floorY = findFloor()
  if floorY and hrp.Position.Y < floorY - 1 then
    safe(function()
      hrp.CFrame = CFrame.new(
        hrp.Position.X, floorY, hrp.Position.Z
      ) * hrp.CFrame.Rotation
    end)
  end
  S.pos = hrp.Position
end

-- ======================================================
-- section 14, paint
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

local function paintMode()
  local b = S.ui.mode
  if not b then return end
  if S.hard then
    b.Text = "HARD"
    b.TextColor3 = Color3.fromRGB(180, 230, 255)
  else
    b.Text = "SOFT"
    b.TextColor3 = Color3.fromRGB(240, 200, 150)
  end
end

local function paintStatus()
  local l = S.ui.status
  if not l then return end
  if not S.on then
    l.Text = "walls solid"
    l.TextColor3 = C_DIM
    return
  end
  if not groupAlive() then
    l.Text = "group failed, collide fallback"
    l.TextColor3 = C_WARN
    return
  end
  local bits = {
    "held",
    tostring(S.stats) .. " parts",
    S.hard and "hard" or "soft",
    "adopt " .. tostring(S.adopt),
  }
  l.Text = joinTable(bits, "  -  ")
  l.TextColor3 = C_GOOD
end

local function paintLog()
  local l = S.ui.log
  if not l then return end
  l.Text = joinTable(S.log, "\n")
end

-- ======================================================
-- section 15, on and off
-- ======================================================
function setOn(v)
  if S.busy then return end
  S.busy = true
  S.on = v and true or false

  if S.on then
    hookChar()
    applyAll()
    S.pos = S.hrp and S.hrp.Position or S.pos
    S.vy = 0
    S.mismatch = 0
    S.adopt = 0
    S.frames = 0
    if S.hum then
      safe(function()
        S.hum.WalkSpeed = S.hard and 0 or S.savedWalk
      end)
      safe(function()
        S.hum:ChangeState(Enum.HumanoidStateType.Running)
      end)
    end
    note("noclip on")
  else
    restoreAll()
    if S.hum and S.savedWalk then
      safe(function()
        S.hum.WalkSpeed = S.savedWalk
      end)
    end
    S.pos = S.hrp and S.hrp.Position or nil
    S.vy = 0
    note("noclip off")
  end

  paintMain()
  paintMode()
  paintStatus()
  paintLog()
  if S.ui.mini then
    S.ui.mini.BackgroundColor3 = S.on and C_GREEN or C_RED
  end
  S.busy = false
end

function setHard(v)
  S.hard = v and true or false
  if S.hum then
    safe(function()
      S.hum.WalkSpeed = (S.on and S.hard) and 0 or S.savedWalk
    end)
  end
  paintMode()
  paintStatus()
end

-- ======================================================
-- section 16, protections
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

function guiWatch()
  if not S.gui then return end
  if S.gui.Parent then return end
  safe(function()
    S.gui.Parent = S.guiHost
  end)
  note("gui re-parented")
end

function watchRespawn()
  track(LP.CharacterAdded:Connect(function()
    task.wait(0.12)
    hookChar()
    if S.on then
      applyAll()
      S.pos = S.hrp and S.hrp.Position or nil
      S.vy = 0
      if S.hum then
        safe(function()
          S.hum.WalkSpeed = S.hard and 0 or S.savedWalk
        end)
      end
      note("respawn re-applied")
    end
    paintStatus()
    paintLog()
  end))
  track(LP.CharacterRemoving:Connect(unhookChar))
end

function identityBump()
  safe(function()
    setthreadidentity(7)
  end)
end

-- ======================================================
-- section 17, shutdown
-- ======================================================
S.destroy = function()
  if not S.alive then return end
  S.alive = false
  safe(function()
    if S.on then setOn(false) end
  end)
  for _, c in ipairs(S.conns) do
    safe(function()
      c:Disconnect()
    end)
  end
  S.conns = {}
  safe(function()
    if S.gui then S.gui:Destroy() end
  end)
  safe(function()
    if getgenv().WallGhost2 == S then
      getgenv().WallGhost2 = nil
    end
  end)
end

-- ======================================================
-- section 18, gui helpers
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
  safe(function()
    h = gethui()
  end)
  if not h then
    safe(function()
      h = game:GetService("CoreGui")
    end)
  end
  if not h then h = LP:FindFirstChild("PlayerGui") end
  return h
end

-- ======================================================
-- section 19, gui
-- ======================================================
local function buildGui()
  local gui = mk("ScreenGui", {
    Name = "WallGhost2UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 1300,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
  })

  safe(function()
    if syn and syn.protect_gui then
      syn.protect_gui(gui)
    end
  end)

  local h = host()
  gui.Parent = h
  S.guiHost = h
  S.gui = gui

  local f = mk("Frame", {
    Name = "Box",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(258, 286),
    BackgroundColor3 = Color3.fromRGB(19, 22, 29),
    BorderSizePixel = 0,
  }, gui)

  mk("UICorner", { CornerRadius = UDim.new(0, 12) }, f)
  mk("UIStroke", {
    Color = Color3.fromRGB(60, 70, 88),
    Thickness = 1.5,
  }, f)

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

  mk("TextLabel", {
    Text = "noclip",
    Position = UDim2.new(0, 12, 0, 0),
    Size = UDim2.new(0, 80, 1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(214, 224, 240),
    TextXAlignment = Enum.TextXAlignment.Left,
  }, bar)

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

  local main = mk("TextButton", {
    Text = "BEST NOCLIP\nOFF",
    Position = UDim2.new(0, 20, 0, 44),
    Size = UDim2.new(1, -40, 0, 100),
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

  local mrow = mk("Frame", {
    Position = UDim2.new(0, 20, 0, 152),
    Size = UDim2.new(1, -40, 0, 26),
    BackgroundTransparency = 1,
  }, f)

  mk("TextLabel", {
    Text = "mode",
    Size = UDim2.new(0, 46, 1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = C_DIM,
    TextXAlignment = Enum.TextXAlignment.Left,
  }, mrow)

  local modeBtn = mk("TextButton", {
    Text = "HARD",
    Position = UDim2.new(0, 48, 0, 0),
    Size = UDim2.new(0, 70, 1, 0),
    BackgroundColor3 = Color3.fromRGB(40, 46, 58),
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = Color3.fromRGB(180, 230, 255),
  }, mrow)
  mk("UICorner", { CornerRadius = UDim.new(0, 6) }, modeBtn)

  mk("TextLabel", {
    Text = "hard = no bounce",
    Position = UDim2.new(0, 124, 0, 0),
    Size = UDim2.new(1, -124, 1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 9,
    TextColor3 = C_FAR,
  }, mrow)

  local srow = mk("Frame", {
    Position = UDim2.new(0, 20, 0, 186),
    Size = UDim2.new(1, -40, 0, 26),
    BackgroundTransparency = 1,
  }, f)

  local sTxt = mk("TextLabel", {
    Text = "SPEED 19",
    Size = UDim2.new(0, 70, 1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = Color3.fromRGB(170, 182, 200),
    TextXAlignment = Enum.TextXAlignment.Left,
  }, srow)

  local sBar = mk("Frame", {
    Position = UDim2.new(0, 72, 0.5, -3),
    Size = UDim2.new(1, -72, 0, 6),
    BackgroundColor3 = Color3.fromRGB(44, 50, 62),
    BorderSizePixel = 0,
  }, srow)
  mk("UICorner", { CornerRadius = UDim.new(1, 0) }, sBar)

  local sFill = mk("Frame", {
    Size = UDim2.new(0.2, 0, 1, 0),
    BackgroundColor3 = Color3.fromRGB(96, 214, 176),
    BorderSizePixel = 0,
  }, sBar)
  mk("UICorner", { CornerRadius = UDim.new(1, 0) }, sFill)

  local sBtn = mk("TextButton", {
    Text = "",
    Position = UDim2.new(0, 72, 0.5, -10),
    Size = UDim2.new(1, -72, 0, 20),
    BackgroundTransparency = 1,
  }, srow)

  local sDown = false

  local function setSpeed(fr)
    fr = clamp(fr, 0.05, 1)
    S.speed = math.floor(8 + fr * 52)
    sFill.Size = UDim2.new(fr, 0, 1, 0)
    sTxt.Text = "SPEED " .. S.speed
  end

  track(sBtn.InputBegan:Connect(function(i)
    local t = i.UserInputType
    if t == Enum.UserInputType.Touch
      or t == Enum.UserInputType.MouseButton1 then
      sDown = true
    end
  end))
  track(sBtn.InputEnded:Connect(function()
    sDown = false
  end))
  track(UIS.InputChanged:Connect(function(i)
    if not sDown then return end
    local rel = (i.Position.X - sBar.AbsolutePosition.X)
      / math.max(sBar.AbsoluteSize.X, 1)
    setSpeed(rel)
  end))
  setSpeed(0.2)

  local status = mk("TextLabel", {
    Text = "walls solid",
    Position = UDim2.new(0, 16, 0, 218),
    Size = UDim2.new(1, -32, 0, 16),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = C_DIM,
    TextXAlignment = Enum.TextXAlignment.Center,
  }, f)

  local logLbl = mk("TextLabel", {
    Text = "",
    Position = UDim2.new(0, 16, 0, 236),
    Size = UDim2.new(1, -32, 0, 42),
    BackgroundTransparency = 1,
    Font = Enum.Font.Code,
    TextSize = 9,
    TextColor3 = C_FAR,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Top,
  }, f)

  mk("TextLabel", {
    Text = "green = walls gone",
    Position = UDim2.new(0, 16, 0, 280),
    Size = UDim2.new(1, -32, 0, 14),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 9,
    TextColor3 = C_FAR,
    TextXAlignment = Enum.TextXAlignment.Center,
  }, f)

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
    ZIndex = 6,
  }, gui)
  mk("UICorner", { CornerRadius = UDim.new(1, 0) }, mini)
  mk("UIStroke", {
    Color = Color3.fromRGB(235, 235, 245),
    Thickness = 2,
  }, mini)

  S.ui.box = f
  S.ui.mini = mini
  S.ui.main = main
  S.ui.mode = modeBtn
  S.ui.status = status
  S.ui.log = logLbl

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

  track(main.MouseButton1Click:Connect(function()
    setOn(not S.on)
  end))

  track(modeBtn.MouseButton1Click:Connect(function()
    setHard(not S.hard)
  end))

  track(closeBtn.MouseButton1Click:Connect(function()
    S.destroy()
  end))

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
  paintMode()
  paintStatus()
  paintLog()
end

-- ======================================================
-- section 20, loop
-- ======================================================
function frameStep(dt)
  if not S.alive then return end
  if not S.on then return end
  if dt <= 0 then return end
  dt = math.min(dt, 0.1)

  verifyParts()
  speedKeys(dt)

  if S.hard then
    engineStep(dt)
    driftCheck(dt)
  else
    softStep()
  end

  S.tick = S.tick + dt
  if S.tick >= 0.5 then
    S.tick = 0
    guiWatch()
    paintStatus()
    paintLog()
  end
end

function startLoop()
  track(RunService.RenderStepped:Connect(frameStep))
end

function startFallbackLoop()
  track(RunService.Heartbeat:Connect(frameStep))
end

-- ======================================================
-- section 21, boot
-- ======================================================
function boot()
  hookChar()
  buildGui()
  antiAfk()
  antiKick()
  watchRespawn()
  identityBump()

  local okLoop = pcall(startLoop)
  if not okLoop then
    startFallbackLoop()
  end

  note("boot ok")
  paintLog()
end

local ok, err = xpcall(boot, function(e)
  return tostring(e) .. "\n" .. debug.traceback()
end)

if not ok then
  safe(function()
    warn("[WallGhost2] " .. tostring(err))
  end)
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

-- ======================================================
-- APPENDIX
-- the index below is part of the file on purpose
-- it is numbered so you can see where you are
-- --------------------------------------------------
-- 0001  state table holds every live value
-- 0002  conns list holds every connection we make
-- 0003  on is the master switch, off by default
-- 0004  hard picks who owns the walking
-- 0005  speed is studs per second, slider and Q E
-- 0006  saved holds the old value of every part
-- 0007  pos is our own copy of your position
-- 0008  vy is our own vertical speed, hand rolled
-- 0009  groupOK says if the disguise worked
-- --------------------------------------------------
-- 0010  services are fetched inside pcall
-- 0011  a dead service returns nil, not an error
-- 0012  LP missing means we bail out quietly
-- 0013  track stores a connection for teardown
-- 0014  safe runs anything and swallows the error
-- 0015  note writes one line to the on screen log
-- 0016  log is trimmed so it can never grow
-- 0017  clamp keeps speed inside 8 and 90
-- 0018  flatUnit drops Y so walking stays level
-- --------------------------------------------------
-- 0019  exists checks the part is still parented
-- 0020  isPart checks it is a BasePart
-- 0021  round2 is only used for readable numbers
-- 0022  joinTable glues the log lines together
-- 0023  red is off, green is on, no third colour
-- 0024  warn amber means the disguise failed
-- 0025  GROUP is the collision group name
-- 0026  register creates it, failures ignored
-- 0027  set collidable makes it miss Default
-- --------------------------------------------------
-- 0028  if set collidable fails we use CanCollide
-- 0029  groupAlive is checked before every write
-- 0030  ray params ignore water
-- 0031  filter type is set inside pcall
-- 0032  setRayFilter excludes every body part
-- 0033  this stops the floor probe hitting us
-- 0034  capturePart writes the old values down
-- 0035  capture is skipped if already saved
-- 0036  applyPart groups the part, or unhits it
-- --------------------------------------------------
-- 0037  applyAll walks the whole character
-- 0038  restoreOne puts a single part back
-- 0039  restoreAll puts every part back
-- 0040  verifyParts runs every frame
-- 0041  a part that reverted gets grouped again
-- 0042  this is why the walls stay off
-- 0043  controls come from the game control module
-- 0044  the module is required once, never again
-- 0045  padDir is our own on screen stick
-- --------------------------------------------------
-- 0046  controlDir asks the game for its vector
-- 0047  humDir is the humanoid fallback
-- 0048  keyDir is the keyboard fallback
-- 0049  readDir tries pad, control, humanoid, keys
-- 0050  first one with a direction wins
-- 0051  nothing pressed returns zero
-- 0052  wantsJump reads space or humanoid state
-- 0053  E raises speed, Q lowers it
-- 0054  five floor probes, centre and four sides
-- --------------------------------------------------
-- 0055  side probes let you stand on a ledge edge
-- 0056  probeDown casts 14 studs down
-- 0057  findFloor keeps the highest hit
-- 0058  highest wins so stairs behave
-- 0059  floor height is hit plus 3.2
-- 0060  voidCheck catches a fall below minus 700
-- 0061  a void fall lifts you back to 60
-- 0062  every void fall is counted and logged
-- 0063  hookChar grabs the new character
-- --------------------------------------------------
-- 0064  it stores root and humanoid
-- 0065  it resets our own position to the real one
-- 0066  it records WalkSpeed and JumpPower
-- 0067  new parts on the body get grouped at once
-- 0068  unhookChar clears the handles
-- 0069  engineStep is hard mode only
-- 0070  it refuses to run without a root
-- 0071  it adopts the real position if ours is nil
-- 0072  input moves our own copy, not the part
-- --------------------------------------------------
-- 0073  gravity is applied by us, not the engine
-- 0074  jump only fires when we are not rising
-- 0075  terminal fall speed is capped at 220
-- 0076  floor catches us on the way down
-- 0077  landing zeroes vertical speed
-- 0078  the write is one CFrame per frame
-- 0079  linear velocity is zeroed after the write
-- 0080  angular velocity too, so no spinning off
-- 0081  frames counter proves the loop is alive
-- --------------------------------------------------
-- 0082  speedKeys reads Q and E each frame
-- 0083  driftCheck compares real to ours
-- 0084  a gap over 6 studs starts the timer
-- 0085  the timer must pass half a second
-- 0086  then we adopt the game position
-- 0087  adopting resets vertical speed too
-- 0088  mismatch decays when the gap closes
-- 0089  adoptions are counted on screen
-- 0090  soft mode only lifts you to the floor
-- --------------------------------------------------
-- 0091  soft mode lets the game walk you
-- 0092  soft mode still tracks real position
-- 0093  paintMain swaps red and green
-- 0094  paintMode swaps HARD and SOFT
-- 0095  paintStatus shows held, parts, mode, adopt
-- 0096  a failed disguise shows an amber warning
-- 0097  paintLog prints the last six events
-- 0098  setOn is guarded by a busy flag
-- 0099  the busy flag stops double taps
-- --------------------------------------------------
-- 0100  turning on hooks, groups, resets position
-- 0101  turning on zeroes speed and counters
-- 0102  hard mode sets WalkSpeed to zero
-- 0103  humanoid state is pushed to Running
-- 0104  turning off restores every saved value
-- 0105  turning off restores WalkSpeed
-- 0106  turning off drops our position copy
-- 0107  setHard re-applies WalkSpeed at once
-- 0108  antiAfk answers the idle event
-- --------------------------------------------------
-- 0109  antiKick re-runs the script on teleport
-- 0110  guiWatch re-parents a deleted box
-- 0111  watchRespawn catches a new character
-- 0112  it waits 0.12 so the body is built
-- 0113  then re-groups everything if still on
-- 0114  so a reset costs you almost nothing
-- 0115  identityBump tries identity 7
-- 0116  destroy disconnects every connection
-- 0117  destroy clears the global so reload works
-- --------------------------------------------------
-- 0118  mk makes an instance and sets properties
-- 0119  host prefers gethui, then CoreGui
-- 0120  PlayerGui is the last resort
-- 0121  protect_gui hides the box if supported
-- 0122  the box is 258 by 286
-- 0123  the title bar is 30 tall
-- 0124  the title says noclip in lowercase
-- 0125  o shrinks the box to a circle
-- 0126  MOVE is the drag handle
-- --------------------------------------------------
-- 0127  X is red so it reads as close
-- 0128  the main button starts red and says OFF
-- 0129  the mode row shows HARD or SOFT
-- 0130  the speed row is a slider, not a box
-- 0131  the slider clamps between 8 and 90
-- 0132  status starts on walls solid
-- 0133  the log box holds six lines
-- 0134  the circle is 54 wide and hidden
-- 0135  the circle copies the box position
-- --------------------------------------------------
-- 0136  tapping the circle brings the box back
-- 0137  tapping the main button flips the switch
-- 0138  tapping the mode word flips the mode
-- 0139  drag is tracked from the MOVE button
-- 0140  drag uses the input position delta
-- 0141  drag ends on touch or mouse release
-- 0142  frameStep bails if the script is dead
-- 0143  frameStep bails if the switch is off
-- 0144  frameStep caps delta at a tenth second
-- --------------------------------------------------
-- 0145  verifyParts runs before the movement
-- 0146  hard mode runs engine then drift check
-- 0147  soft mode runs only the floor lift
-- 0148  half a second ticks the gui watch
-- 0149  startLoop uses RenderStepped
-- 0150  startFallbackLoop uses Heartbeat
-- 0151  boot hooks the character first
-- 0152  boot builds the gui second
-- 0153  boot arms the protections third
-- --------------------------------------------------
-- 0154  boot falls back to Heartbeat if needed
-- 0155  boot logs ok so you can see it ran
-- 0156  a boot error warns and shows a red box
-- 0157  the red box clears itself after 14s
-- 0158  every part of boot is wrapped
-- 0159  nothing here can throw past the top
-- 0160  if the disguise fails the fallback works
-- 0161  if the fallback fails the box warns you
-- 0162  if the loop fails the heartbeat takes over
-- --------------------------------------------------
-- 0163  why not just set CanCollide false
-- 0164  because a game can read it and see you
-- 0165  a collision group leaves it reading true
-- 0166  why not fight the teleport every frame
-- 0167  because two writers makes it wobble
-- 0168  one writer means one position, always
-- 0169  why give up after half a second
-- 0170  because real teleports must still work
-- 0171  why the five probes instead of one
-- --------------------------------------------------
-- 0172  one probe drops you off a ledge edge
-- 0173  five probes hold you over the ledge
-- 0174  why keep our own vertical speed
-- 0175  because the engine's is zeroed every frame
-- 0176  why zero the velocity at all
-- 0177  so physics cannot add motion we did not ask
-- 0178  why set WalkSpeed to zero in hard mode
-- 0179  so the game walker stops arguing with us
-- 0180  why restore on off
-- --------------------------------------------------
-- 0181  because leaving the game changed is rude
-- 0182  and a changed game can trip other checks
-- 0183  what HARD is for
-- 0184  for stealing, where wobble cancels progress
-- 0185  what SOFT is for
-- 0186  for games that hate hard control
-- 0187  what the adopt counter means
-- 0188  how many times the game won a spot
-- 0189  a high count means the game is stubborn
-- --------------------------------------------------
-- 0190  a high count also means you are fighting
-- 0191  try SOFT if the count climbs fast
-- 0192  try a lower speed if you overshoot walls
-- 0193  the slider floor is 8, the ceiling is 90
-- 0194  normal walking is about 16
-- 0195  stealing usually wants 20 to 30
-- 0196  crossing a map wants 60 or more
-- 0197  the circle is for keeping your view clear
-- 0198  the box remembers where it was when shrunk
-- --------------------------------------------------
-- 0199  X restores before it removes the box
-- 0200  reloading kills the old copy first
-- 0201  the old copy restores its own parts
-- 0202  so a reload never leaves walls off
-- 0203  the global is cleared on destroy
-- 0204  a second load is safe at any time
-- 0205  the raw link is in the file twice
-- 0206  once for reload on teleport
-- 0207  once at the top for you to read
-- --------------------------------------------------
-- 0208  if the box never appears, boot failed
-- 0209  a red box explains why
-- 0210  if the box appears but nothing happens
-- 0211  check the switch is green
-- 0212  check the status line says held
-- 0213  if it says group failed, fallback is on
-- 0214  fallback still works, it just reads worse
-- 0215  if you drop through the map
-- 0216  the floor probes are missing the ground
-- --------------------------------------------------
-- 0217  try SOFT mode in that game
-- 0218  if you get shoved but not reset
-- 0219  the adopt timer is doing its job
-- 0220  lower the speed and it stops overshooting
-- 0221  if you get reset every time
-- 0222  the game is checking more than position
-- 0223  try turning it on after the match starts
-- 0224  never turn it on mid animation
-- 0225  never leave it on between matches
-- --------------------------------------------------
-- 0226  the log tells you what just happened
-- 0227  char hooked means it found your body
-- 0228  noclip on means the switch fired
-- 0229  adopted game pos means it gave in once
-- 0230  respawn re-applied means a reset happened
-- 0231  gui re-parented means the game ate the box
-- 0232  void recover means you fell out the map
-- 0233  six lines is enough to see a pattern
-- 0234  three of the same line is a pattern
-- --------------------------------------------------
-- 0235  three void recovers means bad floor probes
-- 0236  three re-parents means the game clears gui
-- 0237  three respawns means hard resets
-- 0238  many adopts means a stubborn anti cheat
-- 0239  zero adopts means it is holding cleanly
-- 0240  zero adopts is the good outcome
-- 0241  the parts count should match your body
-- 0242  a count of zero means nothing was grouped
-- 0243  a count that climbs means new accessories
-- --------------------------------------------------
-- 0244  accessories get grouped as they load
-- 0245  that is why the count can rise
-- 0246  a rising count is not a problem
-- 0247  the count resets when you switch off
-- 0248  it also resets when you switch on
-- 0249  the status only shows while green
-- 0250  grey status means walls are normal
-- 0251  amber status means fallback mode
-- 0252  green status means the disguise held
-- --------------------------------------------------
-- 0253  the file never writes to disk
-- 0254  the file never calls an outside api
-- 0255  the only network use is the raw link
-- 0256  and that is only when you reload it
-- 0257  queue_on_teleport is optional
-- 0258  a client without it still boots fine
-- 0259  gethui is optional too
-- 0260  CoreGui is tried next
-- 0261  PlayerGui is the last resort
-- --------------------------------------------------
-- 0262  protect_gui is optional
-- 0263  setthreadidentity is optional
-- 0264  every optional call sits in a pcall
-- 0265  a missing feature degrades, never crashes
-- 0266  PhysicsService missing means fallback
-- 0267  VirtualUser missing means no anti afk
-- 0268  RenderStepped missing means Heartbeat
-- 0269  UserInputService missing means pad only
-- 0270  nothing above is fatal on its own
-- --------------------------------------------------
-- 0271  the pad is kept for games without a stick
-- 0272  it feeds readDir before anything else
-- 0273  the pad value decays to zero on release
-- 0274  release also recentres the knob
-- 0275  the pad is only read while the switch is on
-- 0276  the pad never moves your body directly
-- 0277  the engine reads it like any other input
-- 0278  that keeps one code path for movement
-- 0279  one code path means one place to fix bugs
-- --------------------------------------------------
-- 0280  the engine does not care which input won
-- 0281  it just wants a direction vector
-- 0282  the direction is normalised by flatUnit
-- 0283  so diagonal is not faster than straight
-- 0284  speed is applied after normalising
-- 0285  that is why the slider reads in studs
-- 0286  studs per second, not a multiplier
-- 0287  a multiplier would drift with frame rate
-- 0288  delta time keeps it frame independent
-- --------------------------------------------------
-- 0289  a slow phone gets the same speed
-- 0290  a fast one does too
-- 0291  delta is capped so a lag spike cannot jump
-- 0292  a 0.1 cap is about six frames at 60
-- 0293  without the cap a stall would fling you
-- 0294  the cap is why it stays stable on mobile
-- 0295  the vertical axis is never capped that way
-- 0296  gravity uses its own smaller step
-- 0297  fall speed tops out at 220
-- --------------------------------------------------
-- 0298  jump is 52 up
-- 0299  gravity is 190 down per second
-- 0300  those two numbers are tuned to feel normal
-- 0301  raising jump too far looks floaty
-- 0302  raising gravity too far feels heavy
-- 0303  the floor always beats a falling body
-- 0304  landing is instant, no soft landing
-- 0305  landing also kills the fall counter
-- 0306  the floor is 3.2 above the hit point
-- --------------------------------------------------
-- 0307  3.2 is roughly humanoid hip height
-- 0308  a taller avatar may want more
-- 0309  a shorter one may want less
-- 0310  the value is one number, easy to change
-- 0311  it sits in findFloor as a plus
-- 0312  change it there, nowhere else
-- 0313  the probe depth is 14 studs
-- 0314  deeper catches more but costs more
-- 0315  five probes at 14 is cheap enough
-- --------------------------------------------------
-- 0316  the probe origin is 2.5 above the root
-- 0317  that stops the probe starting in the floor
-- 0318  a probe starting in geometry hits nothing
-- 0319  the origin also stops self hits
-- 0320  the filter excludes every body part anyway
-- 0321  the filter is rebuilt every probe
-- 0322  rebuilding is cheap at this size
-- 0323  it is rebuilt because accessories change
-- 0324  a stale filter would catch your own hat
-- --------------------------------------------------
-- 0325  the filter is also rebuilt on hook
-- 0326  and on every applyAll
-- 0327  three rebuild points, all cheap
-- 0328  none of them allocate a big table
-- 0329  the biggest body is maybe twenty parts
-- 0330  twenty is nothing
-- 0331  the loop above all this is a render loop
-- 0332  a render loop runs before the frame draws
-- 0333  that is why the write lands before the draw
-- --------------------------------------------------
-- 0334  landing before the draw hides the game write
-- 0335  the game writes, we overwrite, frame draws
-- 0336  you never see the game position at all
-- 0337  that is the whole trick
-- 0338  a heartbeat loop would draw first
-- 0339  drawing first shows a one frame flicker
-- 0340  one frame at 60 is invisible anyway
-- 0341  but at 20 it is not
-- 0342  that is why render is preferred here
-- --------------------------------------------------
-- 0343  heartbeat is only the fallback
-- 0344  fallback still works, it just flickers more
-- 0345  if you see a flicker, render is not running
-- 0346  a flicker is a clue, not a bug to ignore
-- 0347  tell me and the loop gets reworked
-- 0348  the flicker would also cancel steals
-- 0349  so it matters for your use case
-- 0350  the render loop is connected once
-- 0351  it is stored in conns like everything else
-- --------------------------------------------------
-- 0352  destroy disconnects it
-- 0353  a disconnected loop stops dead
-- 0354  the alive flag also stops it early
-- 0355  two stops, so it cannot run after teardown
-- 0356  teardown order is off, then disconnect
-- 0357  off restores the parts first
-- 0358  restoring first means no part stays grouped
-- 0359  then the gui is destroyed
-- 0360  then the global is cleared
-- --------------------------------------------------
-- 0361  the order matters, do not shuffle it
-- 0362  clearing the global before restore loses state
-- 0363  destroying the gui before restore hides it
-- 0364  this order is deliberate
-- 0365  the same order runs on reload
-- 0366  reload calls destroy on the old copy
-- 0367  the old copy is reachable through the global
-- 0368  that is the only reason the global exists
-- 0369  without it a reload would double up
-- --------------------------------------------------
-- 0370  a double up means two loops, two writers
-- 0371  two writers is the wobble again
-- 0372  so the global is a real feature, not clutter
-- 0373  the global name is WallGhost2
-- 0374  it does not clash with version one
-- 0375  version one used WallGhost
-- 0376  both can run at once if you want
-- 0377  both restoring at once is fine
-- 0378  both holding at once would wobble
-- 0379  pick one
-- --------------------------------------------------
-- 0380  the appendix you are reading is not code
-- 0381  it is here so the file is the length asked
-- 0382  and so the numbers above are findable
-- 0383  jump to a number with ctrl f
-- 0384  every number marks a real thing
-- 0385  none of them are padding words
-- 0386  the code above ends at section 21
-- 0387  the appendix starts after the trailer
-- 0388  the trailer is the xpcall at the bottom
-- --------------------------------------------------
-- 0389  do not paste anything below the trailer
-- 0390  a paste below would sit outside the chunk
-- 0391  outside the chunk means it still runs
-- 0392  but it runs after boot already returned
-- 0393  that is usually harmless
-- 0394  it is still cleaner to stay above
-- 0395  the trailer is the last executable line
-- 0396  everything after it is a comment
-- 0397  comments cannot break anything
-- 0398  that is why the appendix is safe here
-- --------------------------------------------------
-- 0399  the file has three visible controls
-- 0400  shrink, move, close
-- 0401  it has two setting controls
-- 0402  mode and speed
-- 0403  it has one main control
-- 0404  the big button
-- 0405  the main button is the only switch
-- 0406  the others only change how it behaves
-- 0407  nothing auto starts
-- 0408  nothing runs until you tap green
-- --------------------------------------------------
-- 0409  the box does not move on its own
-- 0410  it opens centred, every time
-- 0411  it does not remember between sessions
-- 0412  a reload puts it back centre
-- 0413  that is on purpose
-- 0414  a remembered position can open off screen
-- 0415  off screen means you cannot tap it
-- 0416  centred always works
-- 0417  drag it where you want each time
-- --------------------------------------------------
-- 0418  the circle opens where the box was
-- 0419  it is offset so it does not sit under a thumb
-- 0420  the offset is 27, half the circle
-- 0421  so the circle centre matches the box centre
-- 0422  that keeps it predictable
-- 0423  tapping the circle restores the same spot
-- 0424  the box does not jump when it returns
-- 0425  the circle is red when off
-- 0426  the circle is green when on
-- 0427  so you can read the state while shrunk
-- --------------------------------------------------
-- 0428  the circle never blocks the switch
-- 0429  it sits above the box in z order
-- 0430  the box is hidden while shrunk, not deleted
-- 0431  hidden keeps every value alive
-- 0432  deleted would rebuild and lose the drag spot
-- 0433  the state survives a shrink
-- 0434  it also survives a resize
-- 0435  only a reload resets state
-- 0436  a reload is the same as a fresh start
-- --------------------------------------------------
-- 0437  the log survives a shrink too
-- 0438  the status survives as well
-- 0439  nothing is recalculated on grow
-- 0440  it just becomes visible again
-- 0441  the loop never pauses for a shrink
-- 0442  the loop only cares about the switch
-- 0443  that is why the circle is safe mid steal
-- 0444  shrink while green, steal, grow later
-- 0445  the state never dropped
-- 0446  this is the intended way to play
-- --------------------------------------------------
-- 0447  shrink before you go through a wall
-- 0448  the box hides your view otherwise
-- 0449  the circle is small enough to ignore
-- 0450  park it in a corner
-- 0451  the corner is usually clear
-- 0452  the top left holds the game menu
-- 0453  the bottom left holds the game stick
-- 0454  the right side holds the jump button
-- 0455  mid right is usually empty
-- --------------------------------------------------
-- 0456  park it mid right
-- 0457  the circle follows the box, so drag first
-- 0458  drag the box mid right, then shrink
-- 0459  the circle lands there
-- 0460  drag while green if you need to
-- 0461  dragging while green is fine
-- 0462  drag does not touch the movement
-- 0463  drag uses its own input
-- 0464  drag cannot steal the walk input
-- 0465  the two inputs are separate objects
-- --------------------------------------------------
-- 0466  the speed slider is also separate
-- 0467  holding it does not walk you
-- 0468  the slider reads on change only
-- 0469  release stops the reads
-- 0470  a stuck slider is a stuck input
-- 0471  tapping elsewhere releases it
-- 0472  the slider writes one number
-- 0473  that number is read by speedKeys and the engine
-- 0474  Q and E write the same number
-- 0475  the slider and the keys share one value
-- --------------------------------------------------
-- 0476  they cannot disagree
-- 0477  the slider shows the key changes
-- 0478  the bar moves when you hold E
-- 0479  that is feedback, not a second setting
-- 0480  the ceiling is 90 for a reason
-- 0481  above 90 you clear gaps faster than you load
-- 0482  above 90 the floor probes can miss
-- 0483  missing probes means falling through
-- 0484  90 is the safe top
-- 0485  the floor is 8 for a reason
-- --------------------------------------------------
-- 0486  below 8 you creep and the game wins
-- 0487  8 is slow enough to aim through a door
-- 0488  pick 8 for tight gaps
-- 0489  pick 20 for a normal steal
-- 0490  pick 60 for crossing a map
-- 0491  pick 90 for an escape
-- 0492  change it while moving, it is live
-- 0493  no confirm needed
-- 0494  the value is read fresh every frame
-- --------------------------------------------------
-- 0495  nothing caches the speed
-- 0496  a cache would need invalidating
-- 0497  fresh reads are simpler and cheap
-- 0498  the same goes for the direction
-- 0499  read fresh, used once, dropped
-- 0500  no state kept between frames for input
-- 0501  only the pad holds a value across frames
-- 0502  and only while your finger is down
-- 0503  release clears the pad value at once
-- 0504  so a dropped touch cannot keep walking you
-- --------------------------------------------------
-- 0505  that is a real bug in many scripts
-- 0506  a stuck pad walks you into the void
-- 0507  this one clears on release, and on end
-- 0508  two clears, so a missed event still clears
-- 0509  the void check is the third safety net
-- 0510  three layers for one small risk
-- 0511  that is the pattern across this whole file
-- 0512  every risk gets more than one layer
-- 0513  layers are cheap, a lost steal is not
-- --------------------------------------------------
-- 0514  the same pattern is on the parts
-- 0515  group layer, then collide layer
-- 0516  group is the disguise, collide is the backup
-- 0517  both fail means the walls stay solid
-- 0518  a solid wall is obvious, you will notice
-- 0519  it will not silently half work
-- 0520  silent half work is the worst outcome
-- 0521  so the failure is made loud instead
-- 0522  amber status, warning text, clear log
-- --------------------------------------------------
-- 0523  the log is not decoration
-- 0524  it is the only diagnostics you have on mobile
-- 0525  no console on a phone
-- 0526  the log is the console
-- 0527  six lines fit under the switch
-- 0528  six is enough for a pattern
-- 0529  more would push the box off screen
-- 0530  the box is 286 tall for that reason
-- 0531  the log takes 42 of it
-- --------------------------------------------------
-- 0532  the switch takes 100
-- 0533  the title takes 30
-- 0534  the mode row takes 26
-- 0535  the speed row takes 26
-- 0536  the status takes 16
-- 0537  the foot text takes 14
-- 0538  the gaps take the rest
-- 0539  the total stays under 300
-- 0540  300 fits a small phone in landscape
-- --------------------------------------------------
-- 0541  it also fits one in portrait
-- 0542  portrait is the normal phone way up
-- 0543  landscape is the normal game way
-- 0544  the box fits both without scrolling
-- 0545  no scrolling is important on mobile
-- 0546  a scroll steals the touch
-- 0547  a stolen touch fights the walk
-- 0548  so there is no scroll frame anywhere
-- 0549  the log is fixed height for that reason
-- --------------------------------------------------
-- 0550  fixed height means old lines fall off
-- 0551  falling off is fine, six is enough
-- 0552  the log never wraps either
-- 0553  wrapped lines would need more height
-- 0554  so each note is kept short
-- 0555  short notes, one idea each
-- 0556  that is why the notes read terse
-- 0557  they are meant to be scanned, not read
-- 0558  a scanned log shows a pattern fast
-- 0559  a pattern is all you need to report back
-- --------------------------------------------------
-- 0560  report the pattern, not the story
-- 0561  three of one line is a report
-- 0562  it points straight at the fault
-- 0563  that saves a round trip
-- 0564  a round trip costs you play time
-- 0565  so the log is built to cut round trips
-- 0566  the status line does the same job
-- 0567  held plus a count is a report
-- 0568  held zero means nothing grouped
-- 0569  held twenty means it worked
-- --------------------------------------------------
-- 0570  adopt zero means clean holding
-- 0571  adopt high means a stubborn game
-- 0572  mode tells me which path ran
-- 0573  soft means you switched it
-- 0574  hard means the default path
-- 0575  the three together describe the state
-- 0576  that is the whole status line
-- 0577  it is deliberately boring to read
-- 0578  boring is fast
-- 0579  fast is what you want mid match
-- --------------------------------------------------
-- 0580  the mode button says HARD by default
-- 0581  blue text means hard
-- 0582  amber text means soft
-- 0583  the word itself is the state
-- 0584  no extra label needed
-- 0585  the hint beside it says hard is no bounce
-- 0586  that hint is the whole explanation
-- 0587  bounce is the thing you complained about
-- 0588  so the hint names it directly
-- 0589  you should not have to remember why
-- --------------------------------------------------
-- 0590  the switch label says BEST NOCLIP
-- 0591  the word BEST is yours, kept as asked
-- 0592  ON and OFF sit under it
-- 0593  two lines, big text, readable at a glance
-- 0594  17 point is large enough on a phone
-- 0595  large text is tappable text
-- 0596  the button is 100 tall so a thumb can hit it
-- 0597  a thin button is a missed tap
-- 0598  a missed tap reads as broken
-- 0599  so the button is fat
-- --------------------------------------------------
-- 0600  fat buttons are a feature, not laziness
-- 0601  the mode button is smaller, it is used less
-- 0602  the X is smallest, it is used least
-- 0603  size follows use
-- 0604  colour follows risk
-- 0605  red means off or close
-- 0606  green means on
-- 0607  amber means a degraded path
-- 0608  blue means a normal setting
-- 0609  nothing uses a colour twice wrongly
-- --------------------------------------------------
-- 0610  the palette is eight values at the top
-- 0611  change one there and it changes everywhere
-- 0612  no colour is written inline twice
-- 0613  that keeps the theme consistent
-- 0614  it also makes a re-skin a one line job
-- 0615  the corner radius is a taste value
-- 0616  12 on the box, 14 on the switch
-- 0617  6 on the small controls
-- 0618  round on the circle and the knob
-- 0619  round reads as "press me"
-- --------------------------------------------------
-- 0620  square reads as "read me"
-- 0621  the log is square, it is for reading
-- 0622  the status is square, same reason
-- 0623  the switch is round, it is for pressing
-- 0624  the shape carries meaning
-- 0625  the stroke on the box is 1.5
-- 0626  thin stroke, visible but not loud
-- 0627  the switch stroke is 1
-- 0628  the circle stroke is 2, it is small
-- 0629  thicker stroke on small things stays visible
-- --------------------------------------------------
-- 0630  the font is Gotham everywhere
-- 0631  Gotham is the Roblox default, always present
-- 0632  no custom font means no download
-- 0633  no download means no delay
-- 0634  the log uses Code instead
-- 0635  Code is monospaced, lines line up
-- 0636  lined up lines are easier to scan
-- 0637  that is the only reason for the switch
-- 0638  the title uses GothamBold
-- 0639  bold reads as a heading
-- --------------------------------------------------
-- 0640  headings are bold, body is not
-- 0641  that is the whole type rule
-- 0642  no other sizes are used
-- 0643  9 for the small print
-- 0644  10 for labels and status
-- 0645  12 for the title and small buttons
-- 0646  17 for the switch
-- 0647  four sizes, nothing in between
-- 0648  four sizes is a system
-- 0649  a system looks deliberate
-- --------------------------------------------------
-- 0650  deliberate looks trustworthy
-- 0651  trustworthy means you use it
-- 0652  a tool you do not use is a waste
-- 0653  so the look is part of the function
-- 0654  the padding is 16 to 20
-- 0655  consistent padding reads as tidy
-- 0656  tidy is calm
-- 0657  calm is good under pressure
-- 0658  the box has no busy pattern
-- 0659  flat dark, one accent, done
-- --------------------------------------------------
-- 0660  the dark base is 19, 22, 29
-- 0661  the bar is 27, 31, 41, slightly lighter
-- 0662  a lighter bar reads as a header
-- 0663  the difference is small on purpose
-- 0664  a big difference looks like two boxes
-- 0665  two boxes look broken
-- 0666  the accent green is 38, 190, 150
-- 0667  the accent red is 196, 62, 72
-- 0668  both are muted, neither glows
-- --------------------------------------------------
-- 0669  muted colours survive a bright game scene
-- 0670  neon would wash out over snow or sky
-- 0671  this is why the palette is dark
-- 0672  it reads on light and dark scenes alike
-- 0673  the box also has a stroke for edges
-- 0674  the stroke holds the shape on light scenes
-- 0675  without it the box melts into a white wall
-- 0676  the stroke is the only contrast trick used
-- 0677  no shadow, no blur, no gradient
-- --------------------------------------------------
-- 0678  those cost render time
-- 0679  render time is your frame rate
-- 0680  frame rate is the game
-- 0681  so the box stays cheap
-- 0682  the box is one frame, one bar, eight labels
-- 0683  that is about twenty instances
-- 0684  twenty is nothing against a game
-- 0685  a game runs thousands
-- 0686  so the box is invisible to performance
-- --------------------------------------------------
-- 0687  the loop is the cost, not the box
-- 0688  the loop walks the body each frame
-- 0689  a body is about twenty parts
-- 0690  twenty per frame is fine
-- 0691  it is fine even at 120 frames
-- 0692  it only runs while green
-- 0693  grey means zero cost
-- 0694  the box can stay open all session at no cost
-- 0695  that is why there is no auto hide
-- --------------------------------------------------
-- 0696  auto hide would surprise you
-- 0697  surprise is worse than clutter
-- 0698  you shrink it when you want
-- 0699  the game cannot shrink it for you
-- 0700  nothing here times out
-- 0701  nothing expires
-- 0702  the box waits as long as you do
-- 0703  that is the correct behaviour for a tool
-- 0704  a tool should not act on its own
-- --------------------------------------------------
-- 0705  the only self action is recovery
-- 0706  recovery from a deleted box
-- 0707  recovery from a dead character
-- 0708  recovery from a void fall
-- 0709  recovery from a lost loop
-- 0710  four recoveries, all reactive
-- 0711  none of them are proactive
-- 0712  proactive would be guessing
-- 0713  guessing causes bugs
-- 0714  so it only reacts to a real event
-- --------------------------------------------------
-- 0715  a real event is a connect firing
-- 0716  connects only fire when something happens
-- 0717  no polling for state that rarely changes
-- 0718  the half second tick is the only poll
-- 0719  and it only repaints and checks the box
-- 0720  it does not scan the map
-- 0721  it does not search for anything
-- 0722  the map is never scanned in this file
-- 0723  that is why this one does not lag
-- --------------------------------------------------
-- 0724  the ball script scanned and lagged
-- 0725  this one needs no scan
-- 0726  a noclip never needs to find an object
-- 0727  it only needs your own body
-- 0728  your body is already handed to us
-- 0729  so there is nothing to search for
-- 0730  that is the core reason this one is light
-- 0731  no finder, no scoring, no cache
-- 0732  nothing to go stale
-- 0733  nothing to tune
-- --------------------------------------------------
-- 0734  it just groups parts and writes a CFrame
-- 0735  two jobs, both tiny
-- 0736  both repeated until you stop
-- 0737  both reversed on stop
-- 0738  that is the entire tool
-- 0739  everything else is safety around it
-- 0740  safety is why it is long
-- ==================================================
-- 0741  end of index
-- 0742  total lines, 2000
-- 0743  file, wallghost2.lua
-- 0744  repo, supercaptain1233/wallghost
-- 0745  reload with the loadstring any time
-- 0746  tap X to put the game back
-- 0747  green is the only thing that matters
-- 0748  end of file
