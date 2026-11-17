-- bzone_credits.lua: Battlezone, one coin and two Starts, for atari/demo_bzone.sh. Changes nothing in ROM or RAM.
-- Coinage DIP set to 1 Coin/1 Credit. One coin at BZ_COIN s, Start at BZ_START1 s and again at BZ_START2 s.
-- Logs: the loaded copyright bytes ($6F30-$6F39: "ATARI 1980" is 16 3C 16 38 26 ...; "ATARO" has 32 in place of 26)
-- and a sum of the loaded program ROM, so the log shows which ROM ran; every change of the credit count $0E and the
-- lives $CC; each Start with $0370, the checksum result that Start subtracts from the credits; and
-- "SNAP nnnn seq fF c=N" per snapshot (every BZ_STEP frames inside BZ_SEQ, "a-b,c-d"). The game does not show the
-- credit count on screen, so the GIF captions take it from these lines.
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local function env(n, d) return tonumber(os.getenv(n) or "") or d end
local T_COIN, T_S1, T_S2 = env("BZ_COIN", 6), env("BZ_START1", 9), env("BZ_START2", 0)
local STEP = env("BZ_STEP", 4)
local wins = {}
for a, b in (os.getenv("BZ_SEQ") or ""):gmatch("(%d+)-(%d+)") do wins[#wins + 1] = {tonumber(a), tonumber(b)} end
local fields = {}
for tag, p in pairs(manager.machine.ioport.ports) do
  for n, f in pairs(p.fields) do fields[n] = f end
end
local coin, start = fields["Coin 1"], fields["1 Player Start"]
print("coin field", coin ~= nil, "start field", start ~= nil)
local frame, nsnap, lastc, lastl = 0, 0, -1, -1
local function inwin(f)
  for _, w in ipairs(wins) do if f >= w[1] and f <= w[2] and (f - w[1]) % STEP == 0 then return true end end
end
tap = mem:install_read_tap(0x0370, 0x0370, "r0370", function(offset, data, mask)
  local pc = cpu.state["PC"].value
  if pc >= 0x5640 and pc <= 0x5652 then
    print(string.format("%6d f  START: credits $0E=%02X minus $0370=%02X", frame, mem:read_u8(0x0E), data))
  end
  return data
end)
notifier = emu.add_machine_frame_notifier(function()
  frame = frame + 1
  if frame == 1 then
    local t = {}
    for a = 0x6F30, 0x6F39 do t[#t + 1] = string.format("%02X", mem:read_u8(a)) end
    local s = 0
    for a = 0x3000, 0x3FFF do s = s + mem:read_u8(a) end
    for a = 0x5000, 0x7FFF do s = s + mem:read_u8(a) end
    print(string.format("LOADED $6F30: %s  program ROM sum %06X", table.concat(t, " "), s))
    local dip = fields["Coinage"]
    if dip then dip.user_value = 2; print("Coinage set to 1 Coin/1 Credit") else print("no Coinage field") end
  end
  local s = manager.machine.time:as_double()
  if coin then coin:set_value((s >= T_COIN and s < T_COIN + 0.3) and 1 or 0) end
  if start then
    local on = (s >= T_S1 and s < T_S1 + 0.4) or (T_S2 > 0 and s >= T_S2 and s < T_S2 + 0.4)
    start:set_value(on and 1 or 0)
  end
  local c, l = mem:read_u8(0x0E), mem:read_u8(0xCC)
  if c ~= lastc then print(string.format("%6d f %6.1f s  credits $0E = %02X", frame, s, c)); lastc = c end
  if l ~= lastl then print(string.format("%6d f %6.1f s  lives $CC = %02X", frame, s, l)); lastl = l end
  if inwin(frame) then
    print(string.format("SNAP %04d seq f%d c=%d", nsnap, frame, mem:read_u8(0x0E))); nsnap = nsnap + 1
    manager.machine.video:snapshot()
  end
end)
stopper = emu.add_machine_stop_notifier(function() print("end at frame " .. frame) end)
