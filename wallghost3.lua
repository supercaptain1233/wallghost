local RAW = "https://raw.githubusercontent.com/"
  .. "supercaptain1233/wallghost/main/wallghost3.lua"

pcall(function()
  local o = getgenv().WG3
  if o and o.destroy then o.destroy() end
end)

task.wait(0.2)

local S = {}
getgenv().WG3 = S

S.alive = true
S.on = false
S.hard = true
S.speed = 20
S.conns = {}
S.saved = {}
S.stats = 0
S.log = {}
S.logMax = 5
S.ui = {}
S.gui = nil
S.host = nil
S.char = nil
S.hrp = nil
S.hum = nil
S.pos = nil
S.vy = 0
S.hist = {}
S.histMax = 40
S.adopt = 0
S.mismatch = 0
S.tick = 0
S.frames = 0
S.voids = 0
S.lastSafe = nil
S.busy = false
S.controls = nil
S.controlsTried = false
S.pad = Vector3.new(0, 0, 0)
S.padInput = nil
S.cam = nil
S.walkSaved = nil
S.jumpSaved = nil
S.hipSaved = nil
S.floorY = nil
S.grounded = false
S.dead = false
S.resyncs = 0
S.wall = false
S.accel = 0
S.wantSpeed = 20
S.guardSkip = 0
S.watchAcc = 0
S.hbOn = false
S.rnOn = false
S.msg = ""
S.msgT = 0
S.group = "WG3NoClip"
S.groupOK = false

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

local function safe(fn, ...)
  local ok, a = pcall(fn, ...)
  if ok then return a end
  return nil
end

local function track(c)
  if c then S.conns[#S.conns + 1] = c end
  return c
end

local function note(m)
  S.log[#S.log + 1] = m
  while #S.log > S.logMax do
    table.remove(S.log, 1)
  end
end

local function toast(m)
  S.msg = m
  S.msgT = os.clock()
end

local function clamp(v, a, b)
  if v < a then return a end
  if v > b then return b end
  return v
end

local function flen(v)
  return math.sqrt(v.X * v.X + v.Z * v.Z)
end

local function funit(v)
  local m = flen(v)
  if m < 0.0001 then return nil end
  return Vector3.new(v.X / m, 0, v.Z / m)
end

local function z0()
  return Vector3.new(0, 0, 0)
end

local function live(p)
  return p ~= nil and p.Parent ~= nil
end

local function isP(p)
  if not live(p) then return false end
  return p:IsA("BasePart")
end

local function r2(n)
  return math.floor(n * 100 + 0.5) / 100
end

local function jt(t, s)
  return table.concat(t, s)
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function near(a, b, d)
  return (a - b).Magnitude <= d
end

local function now()
  return os.clock()
end

local function anyDown(keys)
  if not UIS then return false end
  for _, k in ipairs(keys) do
    if UIS:IsKeyDown(k) then return true end
  end
  return false
end

local function pushHist(p)
  if not p then return end
  S.hist[#S.hist + 1] = p
  while #S.hist > S.histMax do
    table.remove(S.hist, 1)
  end
end

local function lastSafePos()
  local n = #S.hist
  if n == 0 then return nil end
  return S.hist[math.max(1, n - 10)]
end

local function clearHist()
  S.hist = {}
end

local C_RED = Color3.fromRGB(198, 60, 70)
local C_GRN = Color3.fromRGB(40, 192, 152)
local C_TON = Color3.fromRGB(8, 26, 20)
local C_TOF = Color3.fromRGB(255, 238, 238)
local C_DIM = Color3.fromRGB(138, 148, 164)
local C_OK = Color3.fromRGB(152, 236, 202)
local C_WRN = Color3.fromRGB(242, 192, 122)
local C_OFF = Color3.fromRGB(108, 118, 134)

local GRAV = 196
local JUMP = 54
local TERM = 220
local HIP = 3.2
local PROBE = 14
local MINSPD = 8
local MAXSPD = 90
local ADOPT = 42
local STEPUP = 4.5
local CEILDIST = 6
local DEADZONE = 0.05

local PROBES = {
  Vector3.new(0, 0, 0),
  Vector3.new(0, 0, -2.2),
  Vector3.new(0, 0, 2.2),
  Vector3.new(-2.2, 0, 0),
  Vector3.new(2.2, 0, 0),
  Vector3.new(1.6, 0, 1.6),
  Vector3.new(-1.6, 0, 1.6),
  Vector3.new(1.6, 0, -1.6),
  Vector3.new(-1.6, 0, -1.6),
}

local rp = RaycastParams.new()
rp.IgnoreWater = true

safe(function()
  rp.FilterType = Enum.RaycastFilterType.Exclude
end)

local rpb = RaycastParams.new()
rpb.IgnoreWater = true

safe(function()
  rpb.FilterType = Enum.RaycastFilterType.Exclude
end)

local function filt()
  local l = {}
  if S.char then
    for _, d in ipairs(S.char:GetDescendants()) do
      if d:IsA("BasePart") then l[#l + 1] = d end
    end
  end
  rp.FilterDescendantsInstances = l
  rpb.FilterDescendantsInstances = l
end

safe(function()
  PhysicsService:RegisterCollisionGroup(S.group)
end)

S.groupOK = safe(function()
  PhysicsService:CollisionGroupSetCollidable(
    S.group, "Default", false)
  return true
end) or false

local function grp()
  return S.groupOK == true
end

local function regrp()
  if not grp() then return false end
  safe(function()
    PhysicsService:RegisterCollisionGroup(S.group)
  end)
  return safe(function()
    PhysicsService:CollisionGroupSetCollidable(
      S.group, "Default", false)
    return true
  end) or false
end

local function snap(p)
  if not isP(p) then return end
  if S.saved[p] then return end
  local t = {
    c = p.CanCollide,
    g = p.CollisionGroup,
    a = p.Anchored,
    m = p.Massless,
    gr = p.Gravity,
    v = p.AssemblyLinearVelocity,
    cf = p.CFrame,
  }
  S.saved[p] = t
end

local function seal(p)
  if not isP(p) then return end
  snap(p)
  if grp() then
    safe(function()
      p.CollisionGroup = S.group
    end)
    safe(function()
      p.CanCollide = true
    end)
  else
    safe(function()
      p.CanCollide = false
    end)
  end
  safe(function()
    p.Massless = true
  end)
  S.stats = S.stats + 1
end

local function sealAll()
  if not S.char then return end
  S.stats = 0
  for _, d in ipairs(S.char:GetDescendants()) do
    seal(d)
  end
end

local function unseal(p, t)
  if not live(p) or not t then return end
  if t.g ~= nil then
    safe(function()
      p.CollisionGroup = t.g
    end)
  end
  if t.c ~= nil then
    safe(function()
      p.CanCollide = t.c
    end)
  end
  if t.m ~= nil then
    safe(function()
      p.Massless = t.m
    end)
  end
  if t.gr ~= nil then
    safe(function()
      p.Gravity = t.gr
    end)
  end
  if t.a ~= nil then
    safe(function()
      p.Anchored = t.a
    end)
  end
  if t.cf ~= nil then
    safe(function()
      p.CFrame = t.cf
    end)
  end
  if t.v ~= nil then
    safe(function()
      p.AssemblyLinearVelocity = t.v
    end)
  end
end

local function unsealAll()
  for p, t in pairs(S.saved) do
    unseal(p, t)
  end
  S.saved = {}
  S.stats = 0
end

local function verifyAll()
  if not S.char then return end
  for _, d in ipairs(S.char:GetDescendants()) do
    if isP(d) then
      if grp() then
        if d.CollisionGroup ~= S.group then
          snap(d)
          safe(function()
            d.CollisionGroup = S.group
          end)
        end
        if not d.CanCollide then
          safe(function()
            d.CanCollide = true
          end)
        end
      elseif d.CanCollide then
        seal(d)
      end
    end
  end
end

local function getCtl()
  if S.controlsTried then return S.controls end
  S.controlsTried = true
  safe(function()
    local ps = LP:FindFirstChild("PlayerScripts")
    local pm = ps and ps:FindFirstChild("PlayerModule")
    if not pm then return end
    local m = require(pm)
    S.controls = m:GetControls()
  end)
  return S.controls
end

local function camBasis()
  local c = workspace.CurrentCamera
  if not c then return nil, nil end
  local l = funit(c.CFrame.LookVector)
  if not l then return nil, nil end
  local r = Vector3.new(-l.Z, 0, l.X)
  return l, r
end

local function toWorld(v)
  if not v then return nil end
  local u = funit(v)
  if not u then return nil end
  local l, r = camBasis()
  if not l then return u end
  local w = (r * u.X) + (l * -u.Z)
  return funit(w)
end

local function padVec()
  if flen(S.pad) < DEADZONE then return nil end
  return S.pad
end

local function ctlVec()
  local c = getCtl()
  if not c then return nil end
  local ok, v = pcall(function()
    return c:GetMoveVector()
  end)
  if not ok then return nil end
  return v
end

local function humVec()
  if not S.char then return nil end
  local h = S.char:FindFirstChildOfClass("Humanoid")
  if not h then return nil end
  return h.MoveDirection
end

local function keyVec()
  if not UIS then return nil end
  local x = 0
  local z = 0
  if anyDown({Enum.KeyCode.W, Enum.KeyCode.Up}) then
    z = z - 1
  end
  if anyDown({Enum.KeyCode.S, Enum.KeyCode.Down}) then
    z = z + 1
  end
  if anyDown({Enum.KeyCode.A, Enum.KeyCode.Left}) then
    x = x - 1
  end
  if anyDown({Enum.KeyCode.D, Enum.KeyCode.Right}) then
    x = x + 1
  end
  if x == 0 and z == 0 then return nil end
  return Vector3.new(x, 0, z)
end

local function rawDir()
  local v = padVec()
  if v then return v, true end
  v = ctlVec()
  if v then return v, true end
  v = keyVec()
  if v then return v, true end
  v = humVec()
  if v then return v, false end
  return nil, false
end

local function readDir()
  local v, needRot = rawDir()
  if not v then return z0() end
  local u
  if needRot then
    u = toWorld(v)
  else
    u = funit(v)
  end
  if not u then return z0() end
  return u
end

local function jumpDown()
  if not UIS then return false end
  if anyDown({Enum.KeyCode.Space}) then return true end
  if not S.hum then return false end
  local st = safe(function()
    return S.hum:GetState()
  end)
  return st == Enum.HumanoidStateType.Jumping
end

local function sprinting()
  if not UIS then return false end
  return anyDown({Enum.KeyCode.LeftShift,
    Enum.KeyCode.RightShift})
end

local function wantUp()
  if not UIS then return false end
  return anyDown({Enum.KeyCode.E})
end

local function wantDown()
  if not UIS then return false end
  return anyDown({Enum.KeyCode.Q})
end

local function wantResync()
  if not UIS then return false end
  return anyDown({Enum.KeyCode.R})
end

local function speedStep(dt)
  if wantUp() then
    S.wantSpeed = clamp(S.wantSpeed + 24 * dt, MINSPD, MAXSPD)
  end
  if wantDown() then
    S.wantSpeed = clamp(S.wantSpeed - 24 * dt, MINSPD, MAXSPD)
  end
  local target = S.wantSpeed
  if sprinting() then
    target = target * 1.6
  end
  S.speed = lerp(S.speed, target, clamp(dt * 8, 0, 1))
end

local function down(from, d)
  return safe(function()
    return workspace:Raycast(from, Vector3.new(0, -d, 0), rp)
  end)
end

local function up(from, d)
  return safe(function()
    return workspace:Raycast(from, Vector3.new(0, d, 0), rpb)
  end)
end

local function findFloor()
  local h = S.hrp
  if not h then return nil end
  filt()
  local b = h.Position
  local best = nil
  for _, o in ipairs(PROBES) do
    local from = b + o + Vector3.new(0, 2.6, 0)
    local r = down(from, PROBE)
    if r and r.Position then
      local y = r.Position.Y + HIP
      if not best or y > best then best = y end
    end
  end
  return best
end

local function ceilingGap()
  local h = S.hrp
  if not h then return nil end
  filt()
  local r = up(h.Position + Vector3.new(0, 1, 0), CEILDIST)
  if r and r.Position then
    return (r.Position.Y - h.Position.Y)
  end
  return nil
end

local function wallAhead(dir)
  local h = S.hrp
  if not h or not dir then return false end
  filt()
  local o = h.Position + (dir * 1.8) + Vector3.new(0, 0.5, 0)
  local r = safe(function()
    return workspace:Raycast(o, dir * 2.4, rp)
  end)
  return r ~= nil
end

local function insideCheck()
  local h = S.hrp
  if not h then return false end
  filt()
  local p = OverlapParams.new()
  safe(function()
    p.FilterType = Enum.RaycastFilterType.Exclude
  end)
  p.FilterDescendantsInstances = rp.FilterDescendantsInstances
  local ok, list = pcall(function()
    return workspace:GetPartBoundsInBox(
      h.CFrame, Vector3.new(2.4, 3.4, 2.4), p)
  end)
  if not ok or not list then return false end
  for _, v in ipairs(list) do
    if v.CanCollide then return true end
  end
  return false
end

local function voidGuard(y)
  if not y then return y end
  if y < -720 then
    S.voids = S.voids + 1
    toast("void pull")
    local s = lastSafePos()
    if s then return s.Y + HIP end
    return 80
  end
  return y
end

local function stepUp(dir)
  local h = S.hrp
  if not h then return nil end
  filt()
  local o = h.Position + (dir * 1.4)
  local r = down(o + Vector3.new(0, STEPUP, 0), STEPUP + 3)
  if r and r.Position then
    return r.Position.Y + HIP
  end
  return nil
end

local function hook()
  local c = LP.Character
  S.char = c
  if not c then return end
  S.hrp = c:FindFirstChild("HumanoidRootPart")
  S.hum = c:FindFirstChildOfClass("Humanoid")
  S.vy = 0
  S.grounded = false
  clearHist()
  if S.hrp then
    S.pos = S.hrp.Position
    S.lastSafe = S.hrp.Position
  end
  filt()
  if S.hum then
    S.walkSaved = S.hum.WalkSpeed
    S.jumpSaved = S.hum.JumpPower
    S.hipSaved = S.hum.HipHeight
  end
  track(c.DescendantAdded:Connect(function(d)
    if not S.on then return end
    if d:IsA("BasePart") then seal(d) end
  end))
  track(c.DescendantRemoving:Connect(function(d)
    if S.saved[d] then S.saved[d] = nil end
  end))
  note("hooked")
end

local function unhook()
  S.hrp = nil
  S.hum = nil
  S.pos = nil
  S.vy = 0
  S.grounded = false
  clearHist()
end

local function humanoidKeeper()
  local h = S.hum
  if not h or not live(h) then return end
  if S.hard then
    if h.WalkSpeed ~= 0 then
      safe(function() h.WalkSpeed = 0 end)
    end
    if h.AutoRotate then
      safe(function() h.AutoRotate = false end)
    end
  else
    if S.walkSaved and h.WalkSpeed ~= S.walkSaved then
      safe(function() h.WalkSpeed = S.walkSaved end)
    end
  end
  local st = safe(function() return h:GetState() end)
  if st == Enum.HumanoidStateType.Freefall then
    if S.grounded then
      safe(function()
        h:ChangeState(Enum.HumanoidStateType.Running)
      end)
    end
  end
  if S.grounded and h.FloorMaterial == Enum.Material.Air then
    safe(function()
      h:ChangeState(Enum.HumanoidStateType.Running)
    end)
  end
end

local function applyJump()
  if S.vy > 0.4 then return end
  if not jumpDown() then return end
  S.vy = JUMP
  S.grounded = false
end

local function applyGrav(dt)
  if jumpDown() then return end
  S.vy = S.vy - GRAV * dt
  if S.vy < -TERM then S.vy = -TERM end
end

local function horizontal(dt, dir)
  if flen(dir) <= DEADZONE then return end
  local step = dir * S.speed * dt
  S.pos = S.pos + step
end

local function vertical(dt)
  local fy = voidGuard(findFloor())
  S.floorY = fy
  local ceil = ceilingGap()
  local ny = S.pos.Y + S.vy * dt
  if fy then
    if ny <= fy then
      ny = fy
      S.vy = 0
      S.grounded = true
    else
      S.grounded = false
    end
  else
    S.grounded = false
  end
  if ceil and S.vy > 0 and ceil < 2.6 then
    S.vy = 0
    ny = S.pos.Y
  end
  S.pos = Vector3.new(S.pos.X, ny, S.pos.Z)
end

local function climb(dir)
  if not S.grounded then return end
  if flen(dir) <= DEADZONE then return end
  local fy = S.floorY
  local sy = stepUp(dir)
  if not sy or not fy then return end
  if sy > fy + 0.6 and sy < fy + STEPUP then
    S.pos = Vector3.new(S.pos.X, sy, S.pos.Z)
  end
end

local function write(h)
  safe(function()
    h.CFrame = CFrame.new(S.pos) * h.CFrame.Rotation
  end)
  safe(function()
    h.AssemblyLinearVelocity = z0()
  end)
  safe(function()
    h.AssemblyAngularVelocity = z0()
  end)
end

local function engine(dt)
  local h = S.hrp
  if not live(h) then return end
  if not S.pos then S.pos = h.Position end
  local dir = readDir()
  horizontal(dt, dir)
  applyJump()
  applyGrav(dt)
  vertical(dt)
  climb(dir)
  write(h)
  pushHist(S.pos)
  S.frames = S.frames + 1
end

local function softEngine(dt)
  local h = S.hrp
  if not live(h) then return end
  local fy = voidGuard(findFloor())
  if fy and h.Position.Y < fy - 1.2 then
    safe(function()
      h.CFrame = CFrame.new(h.Position.X, fy, h.Position.Z)
        * h.CFrame.Rotation
    end)
  end
  S.pos = h.Position
  pushHist(S.pos)
end

local function drift(dt)
  local h = S.hrp
  if not live(h) then return end
  if not S.pos then return end
  local gap = (h.Position - S.pos).Magnitude
  if gap > ADOPT then
    S.mismatch = S.mismatch + dt
    if S.mismatch > 1.1 then
      S.pos = h.Position
      S.vy = 0
      S.mismatch = 0
      S.adopt = S.adopt + 1
      clearHist()
      note("adopt")
    end
  else
    S.mismatch = math.max(0, S.mismatch - dt * 2.5)
  end
end

local function resync()
  local h = S.hrp
  if not live(h) then return end
  S.pos = h.Position
  S.vy = 0
  S.mismatch = 0
  S.resyncs = S.resyncs + 1
  clearHist()
  toast("resynced")
end

local function posGuard()
  local h = S.hrp
  if not live(h) then return end
  if not S.pos then return end
  local gap = (h.Position - S.pos).Magnitude
  if gap < 0.4 then return end
  if gap > ADOPT then return end
  safe(function()
    h.CFrame = CFrame.new(S.pos) * h.CFrame.Rotation
  end)
end

local function paintMain()
  local b = S.ui.main
  if not b then return end
  if S.on then
    b.BackgroundColor3 = C_GRN
    b.TextColor3 = C_TON
    b.Text = "NOCLIP  ON"
  else
    b.BackgroundColor3 = C_RED
    b.TextColor3 = C_TOF
    b.Text = "NOCLIP  OFF"
  end
end

local function paintMode()
  local b = S.ui.mode
  if not b then return end
  if S.hard then
    b.Text = "HARD"
    b.TextColor3 = Color3.fromRGB(182, 232, 255)
  else
    b.Text = "SOFT"
    b.TextColor3 = Color3.fromRGB(242, 202, 152)
  end
end

local function paintStat()
  local l = S.ui.stat
  if not l then return end
  if not S.on then
    l.Text = "walls solid"
    l.TextColor3 = C_DIM
    return
  end
  if not grp() then
    l.Text = "group fail, fallback"
    l.TextColor3 = C_WRN
    return
  end
  local p = {
    "held " .. tostring(S.stats),
    S.hard and "hard" or "soft",
    "adopt " .. tostring(S.adopt),
    "v " .. tostring(S.voids),
  }
  l.Text = jt(p, "  ")
  l.TextColor3 = C_OK
end

local function paintLog()
  local l = S.ui.log
  if not l then return end
  l.Text = jt(S.log, "\n")
end

local function paintMsg()
  local l = S.ui.msg
  if not l then return end
  if now() - S.msgT > 1.6 then
    l.Text = ""
    return
  end
  l.Text = S.msg
end

local function paintSpeed()
  local l = S.ui.spd
  if not l then return end
  l.Text = "SPD " .. tostring(math.floor(S.speed))
end

local function paintAll()
  paintMain()
  paintMode()
  paintStat()
  paintLog()
  paintMsg()
  paintSpeed()
  if S.ui.mini then
    S.ui.mini.BackgroundColor3 = S.on and C_GRN or C_RED
  end
end

function setOn(v)
  if S.busy then return end
  S.busy = true
  S.on = v and true or false
  if S.on then
    hook()
    sealAll()
    S.pos = S.hrp and S.hrp.Position or S.pos
    S.vy = 0
    S.mismatch = 0
    S.adopt = 0
    S.voids = 0
    S.frames = 0
    S.speed = S.wantSpeed
    clearHist()
    if S.hum then
      safe(function() S.hum.WalkSpeed = 0 end)
      safe(function() S.hum.AutoRotate = false end)
      safe(function()
        S.hum:ChangeState(Enum.HumanoidStateType.Running)
      end)
    end
    note("on")
  else
    unsealAll()
    if S.hum and S.walkSaved then
      safe(function() S.hum.WalkSpeed = S.walkSaved end)
    end
    if S.hum then
      safe(function() S.hum.AutoRotate = true end)
    end
    S.pos = S.hrp and S.hrp.Position or nil
    S.vy = 0
    clearHist()
    note("off")
  end
  paintAll()
  S.busy = false
end

function setHard(v)
  S.hard = v and true or false
  if S.hum then
    if S.on and S.hard then
      safe(function() S.hum.WalkSpeed = 0 end)
    elseif S.walkSaved then
      safe(function() S.hum.WalkSpeed = S.walkSaved end)
    end
  end
  if S.hard then
    S.pos = S.hrp and S.hrp.Position or S.pos
    clearHist()
  end
  paintAll()
end

function setSpeedTo(v)
  S.wantSpeed = clamp(v, MINSPD, MAXSPD)
  S.speed = S.wantSpeed
  paintSpeed()
end

function toggle()
  setOn(not S.on)
end

function toggleMode()
  setHard(not S.hard)
end

local function msgTick()
  if S.ui.msg and now() - S.msgT < 1.6 then
    paintMsg()
  elseif S.ui.msg and S.ui.msg.Text ~= "" then
    S.ui.msg.Text = ""
  end
end

local function statTick()
  paintStat()
  paintSpeed()
end

function afk()
  track(LP.Idled:Connect(function()
    safe(function()
      VirtualUser:CaptureController()
      VirtualUser:ClickButton2(Vector2.new())
    end)
    note("afk")
  end))
end

function kickGuard()
  safe(function()
    queue_on_teleport(
      ("loadstring(game:HttpGet('%s'))()"):format(RAW))
  end)
end

function guiGuard()
  if not S.gui then return end
  if S.gui.Parent then return end
  safe(function() S.gui.Parent = S.host end)
  note("gui back")
end

function charGuard()
  track(LP.CharacterAdded:Connect(function()
    task.wait(0.1)
    hook()
    if S.on then
      sealAll()
      S.pos = S.hrp and S.hrp.Position or nil
      S.vy = 0
      clearHist()
      if S.hum then
        safe(function() S.hum.WalkSpeed = 0 end)
        safe(function() S.hum.AutoRotate = false end)
      end
      note("respawn")
    end
    paintAll()
  end))
  track(LP.CharacterRemoving:Connect(unhook))
end

function idGuard()
  safe(function() setthreadidentity(7) end)
end

function loopGuard()
  if S.rnOn or S.hbOn then return end
  if S.on then
    startRender()
  end
end

function speedClampGuard()
  S.wantSpeed = clamp(S.wantSpeed, MINSPD, MAXSPD)
  if S.speed > MAXSPD * 1.7 then S.speed = MAXSPD end
end

function anchorGuard()
  local h = S.hrp
  if not live(h) then return end
  if h.Anchored then
    safe(function() h.Anchored = false end)
    note("anchor off")
  end
end

function hipGuard()
  local h = S.hum
  if not live(h) then return end
  if S.hipSaved and h.HipHeight ~= S.hipSaved then
    safe(function() h.HipHeight = S.hipSaved end)
  end
end

function jumpGuard()
  local h = S.hum
  if not live(h) then return end
  if S.jumpSaved and h.JumpPower ~= S.jumpSaved then
    safe(function() h.JumpPower = S.jumpSaved end)
  end
end

function stateGuard()
  local h = S.hum
  if not live(h) then return end
  local st = safe(function() return h:GetState() end)
  if st == Enum.HumanoidStateType.Seated then
    safe(function()
      h:ChangeState(Enum.HumanoidStateType.Running)
    end)
  end
end

function groupGuard()
  if not grp() then
    S.groupOK = regrp()
    if S.groupOK then
      sealAll()
      note("group back")
    end
  end
end

function accGuard()
  S.watchAcc = S.watchAcc + 1
  if S.watchAcc > 4 then
    S.watchAcc = 0
    anchorGuard()
    hipGuard()
    jumpGuard()
    stateGuard()
    groupGuard()
  end
end

function unbind()
  for _, c in ipairs(S.conns) do
    safe(function() c:Disconnect() end)
  end
  S.conns = {}
end

function restoreHuman()
  local h = S.hum
  if not live(h) then return end
  if S.walkSaved then
    safe(function() h.WalkSpeed = S.walkSaved end)
  end
  if S.jumpSaved then
    safe(function() h.JumpPower = S.jumpSaved end)
  end
  if S.hipSaved then
    safe(function() h.HipHeight = S.hipSaved end)
  end
  safe(function() h.AutoRotate = true end)
end

S.destroy = function()
  if not S.alive then return end
  S.alive = false
  S.on = false
  safe(function() unsealAll() end)
  safe(function() restoreHuman() end)
  safe(function() unbind() end)
  safe(function()
    if S.gui then S.gui:Destroy() end
  end)
  safe(function()
    if getgenv().WG3 == S then
      getgenv().WG3 = nil
    end
  end)
end

function unload()
  S.destroy()
end

function hideAll()
  if S.ui.box then S.ui.box.Visible = false end
  if S.ui.mini then S.ui.mini.Visible = true end
end

function showAll()
  if S.ui.box then S.ui.box.Visible = true end
  if S.ui.mini then S.ui.mini.Visible = false end
end

function boxPos()
  if not S.ui.box then return nil end
  return S.ui.box.Position
end

local function mk(cl, pr, pa)
  local i = Instance.new(cl)
  for k, v in pairs(pr) do
    i[k] = v
  end
  if pa then i.Parent = pa end
  return i
end

local function pickHost()
  local h = nil
  safe(function() h = gethui() end)
  if not h then
    safe(function() h = game:GetService("CoreGui") end)
  end
  if not h then h = LP:FindFirstChild("PlayerGui") end
  return h
end

local function corner(p, r)
  mk("UICorner", { CornerRadius = UDim.new(0, r) }, p)
end

local function stroke(p, c, t)
  mk("UIStroke", { Color = c, Thickness = t }, p)
end

local function round(p)
  mk("UICorner", { CornerRadius = UDim.new(1, 0) }, p)
end

local function buildGui()
  local g = mk("ScreenGui", {
    Name = "WG3UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 1400,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
  })
  safe(function()
    if syn and syn.protect_gui then syn.protect_gui(g) end
  end)
  local h = pickHost()
  g.Parent = h
  S.host = h
  S.gui = g

  local f = mk("Frame", {
    Name = "Box",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(250, 300),
    BackgroundColor3 = Color3.fromRGB(18, 21, 28),
    BorderSizePixel = 0,
  }, g)
  corner(f, 12)
  stroke(f, Color3.fromRGB(58, 68, 86), 1.5)

  local bar = mk("Frame", {
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundColor3 = Color3.fromRGB(26, 30, 40),
    BorderSizePixel = 0,
  }, f)
  corner(bar, 12)
  mk("Frame", {
    Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = Color3.fromRGB(26, 30, 40),
    BorderSizePixel = 0,
  }, bar)

  mk("TextLabel", {
    Text = "noclip",
    Position = UDim2.new(0, 10, 0, 0),
    Size = UDim2.new(0, 70, 1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(212, 222, 238),
    TextXAlignment = Enum.TextXAlignment.Left,
  }, bar)

  local circ = mk("TextButton", {
    Text = "o",
    Position = UDim2.new(1, -96, 0, 4),
    Size = UDim2.new(0, 20, 0, 20),
    BackgroundColor3 = Color3.fromRGB(44, 52, 66),
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(188, 200, 218),
  }, bar)
  round(circ)

  local mv = mk("TextButton", {
    Text = "MOVE",
    Position = UDim2.new(1, -72, 0, 4),
    Size = UDim2.new(0, 44, 0, 20),
    BackgroundColor3 = Color3.fromRGB(44, 52, 66),
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = Color3.fromRGB(188, 200, 218),
  }, bar)
  corner(mv, 6)

  local cx = mk("TextButton", {
    Text = "X",
    Position = UDim2.new(1, -24, 0, 4),
    Size = UDim2.new(0, 20, 0, 20),
    BackgroundColor3 = Color3.fromRGB(188, 56, 66),
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(255, 238, 238),
  }, bar)
  corner(cx, 6)

  local main = mk("TextButton", {
    Text = "NOCLIP  OFF",
    Position = UDim2.new(0, 18, 0, 40),
    Size = UDim2.new(1, -36, 0, 92),
    BackgroundColor3 = C_RED,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextColor3 = C_TOF,
  }, f)
  corner(main, 14)
  stroke(main, Color3.fromRGB(88, 98, 118), 1)

  local mrow = mk("Frame", {
    Position = UDim2.new(0, 18, 0, 140),
    Size = UDim2.new(1, -36, 0, 26),
    BackgroundTransparency = 1,
  }, f)
  mk("TextLabel", {
    Text = "mode",
    Size = UDim2.new(0, 44, 1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = C_DIM,
    TextXAlignment = Enum.TextXAlignment.Left,
  }, mrow)
  local mode = mk("TextButton", {
    Text = "HARD",
    Position = UDim2.new(0, 46, 0, 0),
    Size = UDim2.new(0, 68, 1, 0),
    BackgroundColor3 = Color3.fromRGB(38, 44, 56),
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = Color3.fromRGB(182, 232, 255),
  }, mrow)
  corner(mode, 6)

  local srow = mk("Frame", {
    Position = UDim2.new(0, 18, 0, 172),
    Size = UDim2.new(1, -36, 0, 26),
    BackgroundTransparency = 1,
  }, f)
  local spd = mk("TextLabel", {
    Text = "SPD 20",
    Size = UDim2.new(0, 62, 1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = Color3.fromRGB(168, 180, 198),
    TextXAlignment = Enum.TextXAlignment.Left,
  }, srow)
  local sbar = mk("Frame", {
    Position = UDim2.new(0, 64, 0.5, -3),
    Size = UDim2.new(1, -64, 0, 6),
    BackgroundColor3 = Color3.fromRGB(42, 48, 60),
    BorderSizePixel = 0,
  }, srow)
  round(sbar)
  local sfil = mk("Frame", {
    Size = UDim2.new(0.15, 0, 1, 0),
    BackgroundColor3 = Color3.fromRGB(96, 214, 176),
    BorderSizePixel = 0,
  }, sbar)
  round(sfil)
  local sbtn = mk("TextButton", {
    Text = "",
    Position = UDim2.new(0, 64, 0.5, -10),
    Size = UDim2.new(1, -64, 0, 20),
    BackgroundTransparency = 1,
  }, srow)

  local sdrag = false
  local function setBar()
    local fr = (S.wantSpeed - MINSPD) / (MAXSPD - MINSPD)
    sfil.Size = UDim2.new(clamp(fr, 0.02, 1), 0, 1, 0)
    spd.Text = "SPD " .. tostring(math.floor(S.wantSpeed))
  end

  local stat = mk("TextLabel", {
    Text = "walls solid",
    Position = UDim2.new(0, 14, 0, 204),
    Size = UDim2.new(1, -28, 0, 16),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = C_DIM,
    TextXAlignment = Enum.TextXAlignment.Center,
  }, f)

  local msg = mk("TextLabel", {
    Text = "",
    Position = UDim2.new(0, 14, 0, 222),
    Size = UDim2.new(1, -28, 0, 14),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 9,
    TextColor3 = C_OK,
    TextXAlignment = Enum.TextXAlignment.Center,
  }, f)

  local logl = mk("TextLabel", {
    Text = "",
    Position = UDim2.new(0, 14, 0, 240),
    Size = UDim2.new(1, -28, 0, 46),
    BackgroundTransparency = 1,
    Font = Enum.Font.Code,
    TextSize = 9,
    TextColor3 = C_OFF,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Top,
  }, f)

  local mini = mk("TextButton", {
    Text = "N",
    Position = UDim2.new(0.5, -26, 0.5, -26),
    Size = UDim2.fromOffset(52, 52),
    BackgroundColor3 = C_RED,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Visible = false,
    ZIndex = 6,
  }, g)
  round(mini)
  stroke(mini, Color3.fromRGB(232, 232, 244), 2)

  S.ui.box = f
  S.ui.mini = mini
  S.ui.main = main
  S.ui.mode = mode
  S.ui.stat = stat
  S.ui.msg = msg
  S.ui.log = logl
  S.ui.spd = spd

  track(circ.MouseButton1Click:Connect(function()
    S.ui.mini.Position = UDim2.new(
      f.Position.X.Scale, f.Position.X.Offset - 26,
      f.Position.Y.Scale, f.Position.Y.Offset - 26)
    hideAll()
  end))

  track(mini.MouseButton1Click:Connect(showAll))
  track(main.MouseButton1Click:Connect(toggle))
  track(mode.MouseButton1Click:Connect(toggleMode))
  track(cx.MouseButton1Click:Connect(unload))

  track(sbtn.InputBegan:Connect(function(i)
    local t = i.UserInputType
    if t == Enum.UserInputType.Touch
      or t == Enum.UserInputType.MouseButton1 then
      sdrag = true
    end
  end))

  track(sbtn.InputEnded:Connect(function()
    sdrag = false
  end))

  track(UIS.InputChanged:Connect(function(i)
    if not sdrag then return end
    local rel = (i.Position.X - sbar.AbsolutePosition.X)
      / math.max(sbar.AbsoluteSize.X, 1)
    setSpeedTo(MINSPD + rel * (MAXSPD - MINSPD))
    setBar()
  end))

  local drag = false
  local dstart = nil
  local dpos = nil

  track(mv.InputBegan:Connect(function(i)
    local t = i.UserInputType
    if t == Enum.UserInputType.Touch
      or t == Enum.UserInputType.MouseButton1 then
      drag = true
      dstart = i.Position
      dpos = f.Position
      mv.BackgroundColor3 = Color3.fromRGB(68, 82, 102)
    end
  end))

  track(UIS.InputChanged:Connect(function(i)
    if not drag then return end
    local t = i.UserInputType
    if t == Enum.UserInputType.Touch
      or t == Enum.UserInputType.MouseMovement then
      local d = i.Position - dstart
      f.Position = UDim2.new(
        dpos.X.Scale, dpos.X.Offset + d.X,
        dpos.Y.Scale, dpos.Y.Offset + d.Y)
    end
  end))

  track(UIS.InputEnded:Connect(function(i)
    local t = i.UserInputType
    if t == Enum.UserInputType.Touch
      or t == Enum.UserInputType.MouseButton1 then
      drag = false
      mv.BackgroundColor3 = Color3.fromRGB(44, 52, 66)
    end
  end))

  setBar()
  paintAll()
end

function frameStep(dt)
  if not S.alive then return end
  if not S.on then return end
  if dt <= 0 then return end
  if dt > 0.1 then dt = 0.1 end
  verifyAll()
  speedStep(dt)
  humanoidKeeper()
  if wantResync() then resync() end
  if S.hard then
    engine(dt)
    drift(dt)
    posGuard()
  else
    softEngine(dt)
  end
  accGuard()
  S.tick = S.tick + dt
  if S.tick >= 0.4 then
    S.tick = 0
    guiGuard()
    statTick()
    msgTick()
    speedClampGuard()
    loopGuard()
  end
end

function startRender()
  if S.rnOn then return end
  S.rnOn = true
  track(RunService.RenderStepped:Connect(function(dt)
    frameStep(dt)
  end))
end

function startBeat()
  if S.hbOn then return end
  S.hbOn = true
  track(RunService.Heartbeat:Connect(function(dt)
    frameStep(dt)
  end))
end

function startBoth()
  local ok = pcall(startRender)
  if not ok then startBeat() end
end

function stopLoop()
  S.rnOn = false
  S.hbOn = false
end

function probeFloor()
  return findFloor()
end

function probeCeil()
  return ceilingGap()
end

function probeWall()
  return wallAhead(readDir())
end

function probeInside()
  return insideCheck()
end

function snapBack()
  local h = S.hrp
  if not live(h) then return end
  local s = lastSafePos()
  if not s then return end
  safe(function()
    h.CFrame = CFrame.new(s) * h.CFrame.Rotation
  end)
  S.pos = s
  S.vy = 0
  toast("snap back")
end

function markSafe()
  local h = S.hrp
  if not live(h) then return end
  S.lastSafe = h.Position
end

function holdHere()
  local h = S.hrp
  if not live(h) then return end
  S.pos = h.Position
  S.vy = 0
  S.wantSpeed = 0.01
  clearHist()
  toast("holding")
end

function releaseHold()
  S.wantSpeed = 20
  toast("released")
end

function upNudge(n)
  local h = S.hrp
  if not live(h) then return end
  S.pos = S.pos + Vector3.new(0, n, 0)
  safe(function()
    h.CFrame = CFrame.new(S.pos) * h.CFrame.Rotation
  end)
end

function fwdNudge(n)
  local h = S.hrp
  if not live(h) then return end
  local d = readDir()
  if flen(d) <= DEADZONE then
    d = funit(h.CFrame.LookVector) or Vector3.new(0, 0, -1)
  end
  S.pos = S.pos + (d * n)
  safe(function()
    h.CFrame = CFrame.new(S.pos) * h.CFrame.Rotation
  end)
end

function jumpNow()
  S.vy = JUMP
  S.grounded = false
end

function dropNow()
  S.vy = -TERM
end

function speedRead()
  return S.speed
end

function speedWrite(v)
  setSpeedTo(v)
end

function isOn()
  return S.on
end

function isHard()
  return S.hard
end

function frameCount()
  return S.frames
end

function adoptCount()
  return S.adopt
end

function voidCount()
  return S.voids
end

function groupState()
  return S.groupOK
end

function partCount()
  return S.stats
end

function posNow()
  return S.pos
end

function boot()
  hook()
  buildGui()
  afk()
  kickGuard()
  charGuard()
  idGuard()
  startBoth()
  note("ready")
  paintAll()
end

function failBox(e)
  safe(function()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    local b = Instance.new("TextLabel")
    b.Size = UDim2.fromOffset(300, 90)
    b.Position = UDim2.new(0.5, -150, 0, 60)
    b.BackgroundColor3 = Color3.fromRGB(30, 16, 16)
    b.TextColor3 = Color3.fromRGB(255, 190, 190)
    b.Font = Enum.Font.Code
    b.TextSize = 10
    b.TextWrapped = true
    b.Text = "BOOT FAIL\n" .. tostring(e)
    b.Parent = pg
    task.delay(15, function()
      safe(function() b:Destroy() end)
    end)
  end)
end

function trace(e)
  return tostring(e) .. "\n" .. debug.traceback()
end

local ok, err = xpcall(boot, trace)

if not ok then
  safe(function() warn("[WG3] " .. tostring(err)) end)
  failBox(err)
end

function rebind()
  unbind()
  afk()
  kickGuard()
  charGuard()
  startBoth()
end

function softReset()
  safe(function() unsealAll() end)
  safe(function() restoreHuman() end)
  safe(function() sealAll() end)
  if S.hum then
    safe(function() S.hum.WalkSpeed = 0 end)
  end
  S.pos = S.hrp and S.hrp.Position or nil
  S.vy = 0
  clearHist()
  toast("soft reset")
end

function hardReset()
  setOn(false)
  task.wait(0.1)
  setOn(true)
end

function fullReset()
  S.saved = {}
  S.stats = 0
  S.adopt = 0
  S.voids = 0
  S.mismatch = 0
  S.log = {}
  S.hist = {}
  sealAll()
  S.pos = S.hrp and S.hrp.Position or nil
  S.vy = 0
  paintAll()
  toast("full reset")
end

function report()
  local p = {
    "on=" .. tostring(S.on),
    "hard=" .. tostring(S.hard),
    "grp=" .. tostring(S.groupOK),
    "parts=" .. tostring(S.stats),
    "adopt=" .. tostring(S.adopt),
    "void=" .. tostring(S.voids),
    "frames=" .. tostring(S.frames),
  }
  toast(jt(p, " "))
  note("report")
end

function statLine()
  if not S.pos then return "" end
  return r2(S.pos.X) .. "/" .. r2(S.pos.Y)
    .. "/" .. r2(S.pos.Z)
end

function health()
  if not S.hum then return 0 end
  return S.hum.Health
end

function maxHealth()
  if not S.hum then return 0 end
  return S.hum.MaxHealth
end

function walking()
  return flen(readDir()) > DEADZONE
end

function grounded()
  return S.grounded
end

function inWall()
  return insideCheck()
end

function refresh()
  paintAll()
end

function setStat(s)
  if not S.ui.stat then return end
  S.ui.stat.Text = s
end

function setLog(s)
  if not S.ui.log then return end
  S.ui.log.Text = s
end

function showBox()
  showAll()
end

function hideBox()
  hideAll()
end

function toggleBox()
  if not S.ui.box then return end
  if S.ui.box.Visible then
    hideAll()
  else
    showAll()
  end
end

function dragTo(x, y)
  if not S.ui.box then return end
  S.ui.box.Position = UDim2.fromOffset(x, y)
end

function centerBox()
  if not S.ui.box then return end
  S.ui.box.Position = UDim2.fromScale(0.5, 0.5)
end

function boxVisible()
  if not S.ui.box then return false end
  return S.ui.box.Visible
end

function alive()
  return S.alive
end

function kill()
  S.destroy()
end

function version()
  return 3
end

function rawLink()
  return RAW
end

function reload()
  local l = ("loadstring(game:HttpGet('%s'))()"):format(RAW)
  safe(function()
    local fn = loadstring(l)
    if fn then task.spawn(fn) end
  end)
end

function selfTest()
  local r = {}
  r[#r + 1] = "grp:" .. tostring(grp())
  r[#r + 1] = "hrp:" .. tostring(live(S.hrp))
  r[#r + 1] = "hum:" .. tostring(live(S.hum))
  r[#r + 1] = "gui:" .. tostring(live(S.gui))
  r[#r + 1] = "loop:" .. tostring(S.rnOn or S.hbOn)
  toast(jt(r, " "))
  note("selftest")
end

function ensureOn()
  if not S.on then setOn(true) end
end

function ensureOff()
  if S.on then setOn(false) end
end

function ensureHard()
  if not S.hard then setHard(true) end
end

function ensureSoft()
  if S.hard then setHard(false) end
end

function reacquire()
  hook()
  if S.on then sealAll() end
end

function forcePos(v)
  S.pos = v
  S.vy = 0
  local h = S.hrp
  if not live(h) then return end
  safe(function()
    h.CFrame = CFrame.new(v) * h.CFrame.Rotation
  end)
end

getgenv().WG3api = {
  on = setOn, mode = setHard, speed = setSpeedTo,
}
