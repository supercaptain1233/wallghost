local RAW = "https://raw.githubusercontent.com/"
  .. "supercaptain1233/wallghost/main/wallghost6.lua"

pcall(function()
  local o = getgenv().WG6
  if o and o.destroy then o.destroy() end
end)

task.wait(0.2)

local S = {}
getgenv().WG6 = S

S.alive = true
S.on = false
S.hard = true
S.speed = 16
S.wantSpeed = 16
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
S.histMax = 36
S.lastReal = nil
S.hold = false
S.holdPos = nil
S.holdGrace = 0
S.holdFrames = 0
S.holds = 0
S.inside = false
S.insideAcc = 0
S.clearRun = 0
S.stuck = 0
S.nudges = 0
S.tick = 0
S.frames = 0
S.voids = 0
S.busy = false
S.busyAt = 0
S.controls = nil
S.controlsTried = false
S.walkSaved = 16
S.jumpSaved = 50
S.jumpHt = nil
S.hipSaved = 2
S.health = 100
S.group = "WG6NoClip"
S.groupOK = false
S.msg = ""
S.msgT = 0
S.watchAcc = 0
S.rnOn = false
S.hbOn = false
S.guardOn = true
S.silent = 0
S.lastHoldAt = 0

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

local function now()
  return os.clock()
end

local function note(m)
  S.log[#S.log + 1] = m
  while #S.log > S.logMax do
    table.remove(S.log, 1)
  end
end

local function toast(m)
  S.msg = m
  S.msgT = now()
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
  return a + (b - a) * clamp(t, 0, 1)
end

local function dist(a, b)
  return (a - b).Magnitude
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

local function oldPos()
  local n = #S.hist
  if n < 4 then return nil end
  return S.hist[n - 3]
end

local function clearHist()
  S.hist = {}
end

local function mk(cl, pr, pa)
  local i = Instance.new(cl)
  for k, v in pairs(pr) do
    i[k] = v
  end
  if pa then i.Parent = pa end
  return i
end

local function corner(p, r)
  local c = Instance.new("UICorner")
  c.CornerRadius = UDim.new(0, r)
  c.Parent = p
end

local function round(p)
  local c = Instance.new("UICorner")
  c.CornerRadius = UDim.new(1, 0)
  c.Parent = p
end

local function stroke(p, col, th)
  local s = Instance.new("UIStroke")
  s.Color = col
  s.Thickness = th
  s.Parent = p
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

local function zeroVel(h)
  safe(function() h.AssemblyLinearVelocity = z0() end)
  safe(function() h.AssemblyAngularVelocity = z0() end)
end

local function place(h, p, rot)
  if rot then
    safe(function() h.CFrame = CFrame.new(p) * rot end)
  else
    safe(function() h.CFrame = CFrame.new(p) end)
  end
end

local function human()
  if not S.char then return nil end
  return S.char:FindFirstChildOfClass("Humanoid")
end

local function safeSpd(n)
  return clamp(n, 6, 90)
end

local function hState(h)
  return safe(function() return h:GetState() end)
end

local function setState(h, st)
  safe(function() h:ChangeState(st) end)
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
local JUMP = 52
local TERM = 210
local HIP = 3.2
local PROBE = 14
local MINSPD = 6
local MAXSPD = 90
local STEPUP = 4.5
local CEIL = 6
local DZ = 0.05
local OPEN_LIM = 9
local WALL_LIM = 1.1
local RELEASE_CLEAR = 0.35
local MIN_HOLD = 8

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
  S.saved[p] = {
    c = p.CanCollide,
    g = p.CollisionGroup,
    m = p.Massless,
    q = p.CanQuery,
  }
end

local function seal(p)
  if not isP(p) then return end
  snap(p)
  if grp() then
    safe(function() p.CollisionGroup = S.group end)
    safe(function() p.CanCollide = true end)
  else
    safe(function() p.CanCollide = false end)
  end
  safe(function() p.Massless = true end)
  safe(function() p.CanQuery = true end)
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
    safe(function() p.CollisionGroup = t.g end)
  end
  if t.c ~= nil then
    safe(function() p.CanCollide = t.c end)
  end
  if t.m ~= nil then
    safe(function() p.Massless = t.m end)
  end
  if t.q ~= nil then
    safe(function() p.CanQuery = t.q end)
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
          safe(function() d.CollisionGroup = S.group end)
        end
        if not d.CanCollide then
          safe(function() d.CanCollide = true end)
        end
        if not d.CanQuery then
          safe(function() d.CanQuery = true end)
        end
        if not d.Massless then
          safe(function() d.Massless = true end)
        end
      elseif d.CanCollide then
        seal(d)
      end
    end
  end
end

local function groupGuard()
  if grp() then return end
  S.groupOK = regrp()
  if S.groupOK then
    sealAll()
    note("group back")
  end
end

local function canWalk()
  local h = S.hum
  if not live(h) then return end
  if S.walkSaved and h.WalkSpeed ~= S.walkSaved then
    safe(function() h.WalkSpeed = S.walkSaved end)
  end
  if not h.AutoRotate then
    safe(function() h.AutoRotate = true end)
  end
end

local function silenceHuman(h)
  if not live(h) then return end
  safe(function() h.WalkSpeed = 0 end)
  safe(function() h.AutoRotate = false end)
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
    local r = down(b + o + Vector3.new(0, 2.6, 0), PROBE)
    if r and r.Position then
      local y = r.Position.Y + HIP
      if not best or y > best then best = y end
    end
  end
  return best
end

local function ceilGap()
  local h = S.hrp
  if not h then return nil end
  filt()
  local r = up(h.Position + Vector3.new(0, 1, 0), CEIL)
  if r and r.Position then
    return r.Position.Y - h.Position.Y
  end
  return nil
end

local function ceilingBlocked()
  local g = ceilGap()
  if not g then return false end
  return g < 2.6
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
  local ok, l = pcall(function()
    return workspace:GetPartBoundsInBox(
      h.CFrame, Vector3.new(2.1, 3.1, 2.1), p)
  end)
  if not ok or not l then return false end
  for _, v in ipairs(l) do
    if v.CanCollide then return true end
  end
  return false
end

local function deepProbe()
  local h = S.hrp
  if not h then return 0 end
  filt()
  local n = 0
  for _, o in ipairs(PROBES) do
    local r = safe(function()
      return workspace:Raycast(h.Position + o,
        h.CFrame.LookVector * 2.2, rp)
    end)
    if r then n = n + 1 end
  end
  return n
end

local function isAirborne()
  local h = S.hum
  if not h then return true end
  return h.FloorMaterial == Enum.Material.Air
end

local function voidFix(y)
  if not y then return y end
  if y < -720 then
    S.voids = S.voids + 1
    toast("void pull")
    local o = oldPos()
    if o then return o.Y + HIP end
    return 80
  end
  return y
end

local function stepUp(dir)
  local h = S.hrp
  if not h then return nil end
  filt()
  local r = down(h.Position + (dir * 1.4)
    + Vector3.new(0, STEPUP, 0), STEPUP + 3)
  if r and r.Position then
    return r.Position.Y + HIP
  end
  return nil
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
  return l, Vector3.new(-l.Z, 0, l.X)
end

local function toWorld(v)
  if not v then return nil end
  local u = funit(v)
  if not u then return nil end
  local l, r = camBasis()
  if not l then return u end
  return funit((r * u.X) + (l * -u.Z))
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
  local h = human()
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

local function readDir()
  local v = ctlVec()
  if v then
    local u = toWorld(v)
    if u then return u end
  end
  v = keyVec()
  if v then
    local u = toWorld(v)
    if u then return u end
  end
  v = humVec()
  if v then
    local u = funit(v)
    if u then return u end
  end
  return z0()
end

local function jumpDown()
  if not UIS then return false end
  if anyDown({Enum.KeyCode.Space}) then return true end
  local h = human()
  if not h then return false end
  return hState(h) == Enum.HumanoidStateType.Jumping
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
    S.wantSpeed = safeSpd(S.wantSpeed + 24 * dt)
  end
  if wantDown() then
    S.wantSpeed = safeSpd(S.wantSpeed - 24 * dt)
  end
  S.speed = lerp(S.speed, S.wantSpeed, dt * 8)
end

local function moveSpeed()
  local base = S.speed
  if base < 4 then base = S.walkSaved end
  if sprinting() then return base * 1.6 end
  return base
end

local function shoveNow(h, dir)
  if not S.guardOn then return false end
  if not S.lastReal then return false end
  local delta = h.Position - S.lastReal
  local d = delta.Magnitude
  if d < 0.3 then return false end
  local lim = S.hard and OPEN_LIM or 22
  if S.hard and S.inside then lim = WALL_LIM end
  if d > lim then return true end
  if flen(dir) > DZ and d > 0.6 then
    if delta:Dot(dir) < -0.1 then return true end
  end
  return false
end

local function hook()
  local c = LP.Character
  S.char = c
  if not c then return end
  S.hrp = c:FindFirstChild("HumanoidRootPart")
  S.hum = c:FindFirstChildOfClass("Humanoid")
  S.vy = 0
  S.hold = false
  S.holdPos = nil
  S.holdGrace = 0
  S.holdFrames = 0
  S.inside = false
  S.clearRun = 0
  S.stuck = 0
  clearHist()
  if S.hrp then
    S.pos = S.hrp.Position
    S.lastReal = S.hrp.Position
  end
  if S.hum then
    S.walkSaved = S.hum.WalkSpeed
    S.jumpSaved = S.hum.JumpPower
    S.jumpHt = safe(function() return S.hum.JumpHeight end)
    S.hipSaved = S.hum.HipHeight
    S.health = S.hum.Health
  end
  filt()
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
  S.hold = false
  S.holdPos = nil
  S.inside = false
  clearHist()
end

local function restoreHuman()
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

local function enterHold(reason)
  if S.hold then return end
  local h = S.hrp
  if not live(h) then return end
  S.hold = true
  S.holdPos = S.lastReal or h.Position
  S.holdGrace = 0
  S.holdFrames = 0
  S.holds = S.holds + 1
  S.lastHoldAt = now()
  zeroVel(h)
  silenceHuman(S.hum)
  note(reason)
end

local function exitHold()
  if not S.hold then return end
  local h = S.hrp
  S.hold = false
  S.holdPos = nil
  if live(h) then
    S.lastReal = h.Position
    S.pos = h.Position
    zeroVel(h)
  end
  canWalk()
  note("free")
end

local function holdStep(dt)
  local h = S.hrp
  if not live(h) then return end
  if not S.holdPos then return end
  local dir = readDir()
  if flen(dir) > DZ then
    S.holdPos = S.holdPos + (dir * moveSpeed() * dt)
  end
  local fy = voidFix(findFloor())
  if fy and S.holdPos.Y <= fy then
    S.holdPos = Vector3.new(S.holdPos.X, fy, S.holdPos.Z)
    S.vy = 0
  end
  if jumpDown() and S.vy <= 0.4 then
    S.vy = JUMP
  end
  if not jumpDown() then
    S.vy = S.vy - GRAV * dt
    if S.vy < -TERM then S.vy = -TERM end
  end
  local ny = S.holdPos.Y + S.vy * dt
  if fy and ny < fy then ny = fy end
  if ceilingBlocked() and S.vy > 0 then
    S.vy = 0
    ny = S.holdPos.Y
  end
  S.holdPos = Vector3.new(S.holdPos.X, ny, S.holdPos.Z)
  place(h, S.holdPos, h.CFrame.Rotation)
  zeroVel(h)
  pushHist(S.holdPos)
  S.pos = S.holdPos
  S.lastReal = S.holdPos
  S.holdFrames = S.holdFrames + 1
  S.frames = S.frames + 1
  if S.inside then
    S.holdGrace = 0
  else
    S.holdGrace = S.holdGrace + dt
    if S.holdGrace > RELEASE_CLEAR and S.holdFrames > MIN_HOLD then
      exitHold()
    end
  end
end

local function freeStep(dt)
  local h = S.hrp
  if not live(h) then return end
  if not S.lastReal then
    S.lastReal = h.Position
    return
  end
  local dir = readDir()
  if shoveNow(h, dir) then
    enterHold("shove")
    return
  end
  S.lastReal = h.Position
  S.pos = h.Position
  canWalk()
  if not isAirborne() then
    local st = hState(S.hum)
    if st == Enum.HumanoidStateType.Freefall then
      setState(S.hum, Enum.HumanoidStateType.Running)
    end
  end
  local fy = voidFix(findFloor())
  if fy and h.Position.Y < fy - 2.2 then
    place(h, Vector3.new(h.Position.X, fy, h.Position.Z),
      h.CFrame.Rotation)
  end
  if flen(dir) > DZ and S.inside then
    local v = safe(function() return h.AssemblyLinearVelocity end)
    if v and flen(v) < 0.55 then
      S.stuck = S.stuck + dt
      if S.stuck > 0.25 then
        S.stuck = 0
        S.nudges = S.nudges + 1
        place(h, h.Position + (dir * 0.9), h.CFrame.Rotation)
        S.lastReal = h.Position
        enterHold("stuck")
      end
    else
      S.stuck = 0
    end
  else
    S.stuck = 0
  end
  pushHist(h.Position)
  S.frames = S.frames + 1
end

local function softStep(dt)
  local h = S.hrp
  if not live(h) then return end
  local fy = voidFix(findFloor())
  if fy and h.Position.Y < fy - 1.4 then
    place(h, Vector3.new(h.Position.X, fy, h.Position.Z),
      h.CFrame.Rotation)
  end
  S.lastReal = h.Position
  S.pos = h.Position
  pushHist(h.Position)
end

local function stepMode(dt)
  if S.hold then
    holdStep(dt)
    return
  end
  if S.hard then
    freeStep(dt)
  else
    softStep(dt)
  end
end

local function resync()
  local h = S.hrp
  if not live(h) then return end
  S.hold = false
  S.holdPos = nil
  S.holdGrace = 0
  S.lastReal = h.Position
  S.pos = h.Position
  S.vy = 0
  S.stuck = 0
  clearHist()
  zeroVel(h)
  canWalk()
  toast("resync")
end

local function snapBack()
  local h = S.hrp
  if not live(h) then return end
  local o = oldPos()
  if not o then return end
  place(h, o, h.CFrame.Rotation)
  S.lastReal = o
  S.pos = o
  S.vy = 0
  S.hold = false
  toast("snap")
end

local function holdHere()
  local h = S.hrp
  if not live(h) then return end
  enterHold("manual")
  S.holdPos = h.Position
  zeroVel(h)
  toast("holding")
end

local function releaseHold()
  exitHold()
  toast("released")
end

local function nudgeY(n)
  local h = S.hrp
  if not live(h) then return end
  local p = (S.holdPos or h.Position) + Vector3.new(0, n, 0)
  if S.hold then S.holdPos = p end
  place(h, p, h.CFrame.Rotation)
end

local function nudgeF(n)
  local h = S.hrp
  if not live(h) then return end
  local d = readDir()
  if flen(d) <= DZ then
    d = funit(h.CFrame.LookVector) or Vector3.new(0, 0, -1)
  end
  local p = (S.holdPos or h.Position) + (d * n)
  if S.hold then S.holdPos = p end
  place(h, p, h.CFrame.Rotation)
end

local function anchorGuard()
  local h = S.hrp
  if not live(h) then return end
  if h.Anchored then
    safe(function() h.Anchored = false end)
    note("anchor")
  end
end

local function hipGuard()
  local h = S.hum
  if not live(h) then return end
  if S.hipSaved and h.HipHeight ~= S.hipSaved then
    safe(function() h.HipHeight = S.hipSaved end)
  end
end

local function jumpGuard()
  local h = S.hum
  if not live(h) then return end
  if S.jumpSaved and h.JumpPower ~= S.jumpSaved then
    safe(function() h.JumpPower = S.jumpSaved end)
  end
  if S.jumpHt then
    local jh = safe(function() return h.JumpHeight end)
    if jh and jh ~= S.jumpHt then
      safe(function() h.JumpHeight = S.jumpHt end)
    end
  end
end

local function stateGuard()
  local h = S.hum
  if not live(h) then return end
  local st = hState(h)
  if st == Enum.HumanoidStateType.Seated then
    setState(h, Enum.HumanoidStateType.Running)
  end
  if st == Enum.HumanoidStateType.Physics then
    setState(h, Enum.HumanoidStateType.Running)
  end
  if st == Enum.HumanoidStateType.Freefall and not isAirborne() then
    setState(h, Enum.HumanoidStateType.Running)
  end
end

local function speedGuard()
  S.wantSpeed = safeSpd(S.wantSpeed)
  if S.speed > MAXSPD * 2 then S.speed = MAXSPD end
end

local function healthGuard()
  local h = S.hum
  if not live(h) then return end
  if h.Health <= 0 then return end
  S.health = h.Health
end

local function guiGuard()
  if not S.gui then return end
  if S.gui.Parent then return end
  safe(function() S.gui.Parent = S.host end)
  note("gui back")
end

local function loopGuard()
  if S.rnOn or S.hbOn then return end
  if S.on then startRender() end
end

local function walkGuard()
  local h = S.hum
  if not live(h) then return end
  if S.hold then
    if h.WalkSpeed ~= 0 then
      safe(function() h.WalkSpeed = 0 end)
    end
    return
  end
  if S.walkSaved and h.WalkSpeed ~= S.walkSaved then
    safe(function() h.WalkSpeed = S.walkSaved end)
  end
end

local function rotGuard()
  local h = S.hum
  if not live(h) then return end
  if S.hold then return end
  if not h.AutoRotate then
    safe(function() h.AutoRotate = true end)
  end
end

local function gravityGuard()
  local h = S.hrp
  if not live(h) then return end
  if h.Gravity ~= 196 then
    safe(function() h.Gravity = 196 end)
  end
end

local function insideGuard()
  S.insideAcc = S.insideAcc + 1
  if S.insideAcc < 2 then return end
  S.insideAcc = 0
  S.inside = insideCheck()
  if S.inside then
    S.clearRun = 0
  else
    S.clearRun = S.clearRun + 1
  end
end

local function accGuard()
  S.watchAcc = S.watchAcc + 1
  if S.watchAcc < 5 then return end
  S.watchAcc = 0
  anchorGuard()
  hipGuard()
  jumpGuard()
  stateGuard()
  groupGuard()
  speedGuard()
end

local function allGuards()
  walkGuard()
  rotGuard()
  gravityGuard()
  healthGuard()
  insideGuard()
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
    l.Text = "group fail"
    l.TextColor3 = C_WRN
    return
  end
  local p = {
    S.hold and "HELD" or "walk",
    S.inside and "inwall" or "open",
    "held " .. tostring(S.stats),
    "h " .. tostring(S.holds),
  }
  l.Text = jt(p, "  ")
  l.TextColor3 = S.hold and C_WRN or C_OK
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

local function paintSpd()
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
  paintSpd()
  if S.ui.mini then
    S.ui.mini.BackgroundColor3 = S.on and C_GRN or C_RED
  end
end

function setOn(v)
  if S.busy and now() - (S.busyAt or 0) > 0.4 then
    S.busy = false
  end
  if S.busy then return end
  S.busy = true
  S.busyAt = now()
  S.on = v and true or false

  if S.on then
    safe(function()
      hook()
      sealAll()
    end)
    S.hold = false
    S.holdPos = nil
    S.holdGrace = 0
    S.holdFrames = 0
    S.speed = S.wantSpeed
    S.voids = 0
    S.frames = 0
    S.stuck = 0
    S.inside = false
    clearHist()
    safe(canWalk)
    if S.hum then
      setState(S.hum, Enum.HumanoidStateType.Running)
    end
    note("on")
  else
    S.hold = false
    S.holdPos = nil
    S.lastReal = nil
    S.stuck = 0
    safe(function() unsealAll() end)
    safe(function() restoreHuman() end)
    clearHist()
    note("off")
  end

  safe(paintAll)
  S.busy = false
end

function setHard(v)
  S.hard = v and true or false
  S.hold = false
  S.holdPos = nil
  S.lastReal = S.hrp and S.hrp.Position or nil
  S.stuck = 0
  canWalk()
  paintAll()
end

function setSpeedTo(v)
  S.wantSpeed = safeSpd(v)
  S.speed = S.wantSpeed
  paintSpd()
end

function toggle()
  if S.busy and now() - (S.busyAt or 0) > 0.4 then
    S.busy = false
  end
  if S.busy then return end
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
  paintSpd()
end

function afk()
  track(LP.Idled:Connect(function()
    safe(function()
      VirtualUser:CaptureController()
      VirtualUser:ClickButton2(Vector2.new())
    end)
  end))
end

function kickGuard()
  safe(function()
    queue_on_teleport(
      ("loadstring(game:HttpGet('%s'))()"):format(RAW))
  end)
end

function charGuard()
  track(LP.CharacterAdded:Connect(function()
    task.wait(0.1)
    hook()
    if S.on then
      sealAll()
      canWalk()
      clearHist()
      note("respawn")
    end
    paintAll()
  end))
  track(LP.CharacterRemoving:Connect(unhook))
end

function idGuard()
  safe(function() setthreadidentity(7) end)
end

function unbind()
  for _, c in ipairs(S.conns) do
    safe(function() c:Disconnect() end)
  end
  S.conns = {}
end

S.destroy = function()
  if not S.alive then return end
  S.alive = false
  S.on = false
  S.busy = false
  S.hold = false
  safe(function() unsealAll() end)
  safe(function() restoreHuman() end)
  safe(function() unbind() end)
  safe(function()
    if S.gui then S.gui:Destroy() end
  end)
  safe(function()
    if getgenv().WG6 == S then
      getgenv().WG6 = nil
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

function toggleBox()
  if not S.ui.box then return end
  if S.ui.box.Visible then hideAll() else showAll() end
end

function boxVisible()
  if not S.ui.box then return false end
  return S.ui.box.Visible
end

function centerBox()
  if not S.ui.box then return end
  S.ui.box.Position = UDim2.fromScale(0.5, 0.5)
end

function dragTo(x, y)
  if not S.ui.box then return end
  S.ui.box.Position = UDim2.fromOffset(x, y)
end

local function buildGui()
  local g = mk("ScreenGui", {
    Name = "WG6UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 1700,
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
    Size = UDim2.fromOffset(246, 292),
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
    Position = UDim2.new(0, 18, 0, 38),
    Size = UDim2.new(1, -36, 0, 88),
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
    Position = UDim2.new(0, 18, 0, 134),
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
    Position = UDim2.new(0, 18, 0, 166),
    Size = UDim2.new(1, -36, 0, 26),
    BackgroundTransparency = 1,
  }, f)
  local spd = mk("TextLabel", {
    Text = "SPD 16",
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
    Size = UDim2.new(0.12, 0, 1, 0),
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
    Position = UDim2.new(0, 14, 0, 198),
    Size = UDim2.new(1, -28, 0, 16),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = C_DIM,
    TextXAlignment = Enum.TextXAlignment.Center,
  }, f)

  local msg = mk("TextLabel", {
    Text = "",
    Position = UDim2.new(0, 14, 0, 216),
    Size = UDim2.new(1, -28, 0, 14),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 9,
    TextColor3 = C_OK,
    TextXAlignment = Enum.TextXAlignment.Center,
  }, f)

  local logl = mk("TextLabel", {
    Text = "",
    Position = UDim2.new(0, 14, 0, 234),
    Size = UDim2.new(1, -28, 0, 44),
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
    mini.Position = UDim2.new(
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
  allGuards()
  speedStep(dt)
  if wantResync() then resync() end
  stepMode(dt)
  accGuard()
  S.tick = S.tick + dt
  if S.tick >= 0.4 then
    S.tick = 0
    guiGuard()
    statTick()
    msgTick()
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
  safe(function() warn("[WG6] " .. tostring(err)) end)
  failBox(err)
end

function softReset()
  safe(function() unsealAll() end)
  safe(function() restoreHuman() end)
  safe(function() sealAll() end)
  S.hold = false
  S.holdPos = nil
  S.lastReal = S.hrp and S.hrp.Position or nil
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
  S.voids = 0
  S.holds = 0
  S.log = {}
  S.hist = {}
  sealAll()
  clearHist()
  toast("full reset")
end

function report()
  local p = {
    "on=" .. tostring(S.on),
    "grp=" .. tostring(S.groupOK),
    "hold=" .. tostring(S.hold),
    "inwall=" .. tostring(S.inside),
    "parts=" .. tostring(S.stats),
  }
  toast(jt(p, " "))
  note("report")
end

function probeFloor()
  return findFloor()
end

function probeCeil()
  return ceilGap()
end

function probeInside()
  return insideCheck()
end

function probeDeep()
  return deepProbe()
end

function setGuard(v)
  S.guardOn = v and true or false
end

function guardOn()
  return S.guardOn
end

function holdNow()
  return S.hold
end

function holdCount()
  return S.holds
end

function partCount()
  return S.stats
end

function groupState()
  return S.groupOK
end

function frameCount()
  return S.frames
end

function isOn()
  return S.on
end

function isHard()
  return S.hard
end

function posNow()
  return S.pos
end

function statLine()
  if not S.pos then return "" end
  return r2(S.pos.X) .. "/" .. r2(S.pos.Y)
    .. "/" .. r2(S.pos.Z)
end

function healthNow()
  local h = S.hum
  if not live(h) then return 0 end
  return h.Health
end

function walking()
  return flen(readDir()) > DZ
end

function inWall()
  return insideCheck()
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

function forcePos(v)
  S.holdPos = v
  S.hold = true
  local h = S.hrp
  if live(h) then place(h, v, h.CFrame.Rotation) end
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
  local r = {
    "grp:" .. tostring(grp()),
    "hrp:" .. tostring(live(S.hrp)),
    "loop:" .. tostring(S.rnOn or S.hbOn),
    "busy:" .. tostring(S.busy),
  }
  toast(jt(r, " "))
end

getgenv().WG6api = {
  on = setOn, mode = setHard, speed = setSpeedTo,
  hold = holdHere, release = releaseHold, resync = resync,
  forceOff = ensureOff,
}
