-- bzone_100k.lua: Battlezone past 100,000 points, for atari/demo_bzone.sh 100k. One RAM poke per game: the score's
-- thousands byte $B8 := $99 (99,000) two seconds into each game; the kill that passes 100,000 is the game's own. A
-- scripted player sits still and fires every 8 frames. Free play; Start is pressed whenever no game is running, until
-- a game has passed 99,000 ($B9, hundred-thousands, non-zero).
-- Logs: the loaded copyright bytes, credits $0E, lives $CC, score $B8/$B9, writes to $0345 (set at the second bonus
-- tank, $6192; cleared only if the copyright check passes, $51CA) and "SNAP nnnn seq fF c=N" every BZ_STEP frames.
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local function env(n, d) return tonumber(os.getenv(n) or "") or d end
local STEP = env("BZ_STEP", 20)
local startf, passed = -1, false
local F = {}
for _, p in pairs(manager.machine.ioport.ports) do for n, f in pairs(p.fields) do F[n] = f end end
local frame, nsnap, poked = 0, 0, false
local last = {}
w345 = mem:install_write_tap(0x0345, 0x0345, "w345", function(o, d, m)
  if last.w345 ~= d then
    print(string.format("%6d f  $0345 <- %02X (pc %04X)", frame, d, cpu.state["PC"].value)); last.w345 = d
  end
end)
notifier = emu.add_machine_frame_notifier(function()
  frame = frame + 1
  if frame == 1 then
    local t = {}
    for a = 0x6F30, 0x6F39 do t[#t + 1] = string.format("%02X", mem:read_u8(a)) end
    print("LOADED $6F30: " .. table.concat(t, " "))
    F["Coinage"].user_value = 0
  end
  local s = manager.machine.time:as_double()
  local lives = mem:read_u8(0xCC)
  if lives > 0 and startf < 0 then startf = frame end
  if lives == 0 and startf >= 0 then startf = -1; poked = false end
  if mem:read_u8(0xB9) > 0 then passed = true end
  F["1 Player Start"]:set_value((not passed and lives == 0 and s > 5 and frame % 120 < 10) and 1 or 0)
  F["P1 Button 1"]:set_value((lives > 0 and frame % 8 < 2) and 1 or 0)
  if startf >= 0 and not poked and frame - startf == 120 then
    poked = true; mem:write_u8(0xB8, 0x99)
    print(string.format("%6d f  POKE $B8 := 99 (score 99,000)", frame))
  end
  for _, a in ipairs({0x0E, 0xCC, 0xB8, 0xB9}) do
    local v = mem:read_u8(a)
    if last[a] ~= v then print(string.format("%6d f %6.1f s  $%02X = %02X", frame, s, a, v)); last[a] = v end
  end
  if frame % STEP == 0 then
    print(string.format("SNAP %04d seq f%d c=%d", nsnap, frame, mem:read_u8(0x0E))); nsnap = nsnap + 1
    manager.machine.video:snapshot()
  end
end)
stopper = emu.add_machine_stop_notifier(function() print("end at frame " .. frame) end)
