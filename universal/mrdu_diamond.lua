-- mrdu_diamond.lua: Mr. Do!'s diamond (SPECIAL) award on genuine mrdo and the bootleg mrdu, for universal/demo_mrdu.sh.
-- A scripted player (fixed seed MRDO_SEED, default 64) plays a real game: coin at frame 600, start at 640, then a
-- random direction or fire every 15 frames; once a diamond exists it steers into it.
-- One RAM write ("rung B"): at the first natural diamond roll (an apple has broken, code at 0x50D3) made while the
-- player is alive and in a normal state, the random state 0xE07B/0xE07C is set to 0x0ED4, whose next step is a winning
-- roll (1 in 512 otherwise). The apple break, the spawn, the walk into the diamond and the award are the game's own.
-- Logs: the loaded check-B bytes (MRDO_CHK: 0x74BB in mrdo, 0x74D2 in mrdu) and ROM 0x7FF8-0x7FFF, so the log shows
-- which ROM ran; the poke; spawn and pick-up; every change of the credit count 0xE006 (BCD); and SNAP lines with
-- c=<credits, in decimal> for the windows in MRDO_WIN ("from-to:step,...").
local m = manager.machine; local cpu = m.devices[":maincpu"]; local mem = cpu.spaces["program"]; local st = cpu.state
local logf = io.open(os.getenv("MRDO_LOG"), "w"); local frame = 0
local rng = tonumber(os.getenv("MRDO_SEED") or "64")
local CHK = tonumber(os.getenv("MRDO_CHK") or "74BB", 16)
local function hx(a, n) local t = {} for i = 0, n - 1 do t[#t+1] = string.format("%02X", mem:read_u8(a + i)) end return table.concat(t, " ") end
logf:write(string.format("%s: seed %d  check-B site %04X: %s  ROM 7FF8..7FFF: %s\n", emu.romname(), rng, CHK, hx(CHK, 0x14), hx(0x7FF8, 8)))
local F = {}
for _, p in pairs(m.ioport.ports) do for n, f in pairs(p.fields) do F[n] = f end end
local function press(name, v) F[name]:set_value(v) end
local poked = false
t1 = mem:install_read_tap(0x50D3, 0x50D3, "roll", function(o, d, k)
  if st["CURPC"].value == 0x50D3 and not poked and mem:read_u8(0xE000) & 0x40 ~= 0 and (mem:read_u8(0xE1C5) & 0x98) == 0x80 then
    poked = true
    logf:write(string.format("POKE f=%d random state E07B %04X -> 0ED4 (a natural roll; player %02X/%02X)\n", frame,
      mem:read_u8(0xE07B) + 256 * mem:read_u8(0xE07C), mem:read_u8(0xE1C6), mem:read_u8(0xE1C8)))
    mem:write_u8(0xE07B, 0xD4); mem:write_u8(0xE07C, 0x0E)
  end end)
t2 = mem:install_write_tap(0xE309, 0xE309, "spawn", function(o, d, k)
  if (d & 0xFF) == 0x80 and st["CURPC"].value >= 0x50E9 and st["CURPC"].value <= 0x50EC then
    logf:write(string.format("SPAWN f=%d (the game's own spawn code, 0x50E9)\n", frame)) end end)
t3 = mem:install_read_tap(0x549B, 0x549B, "pick", function(o, d, k)
  if st["CURPC"].value == 0x549B then logf:write(string.format("PICKUP f=%d credits E006=%02X\n", frame, mem:read_u8(0xE006))) end end)
local wins, nsnap = {}, 0
for a, b, c in string.gmatch(os.getenv("MRDO_WIN") or "", "(%d+)-(%d+):(%d+)") do wins[#wins+1] = {tonumber(a), tonumber(b), tonumber(c)} end
local last, idle = -1, 0
fn = emu.add_machine_frame_notifier(function() frame = frame + 1
  local e000 = mem:read_u8(0xE000)
  if e000 & 0x80 == 0 then idle = idle + 1 else idle = 0 end   -- not in a real game: coin and start again
  if idle == 300 or frame == 600 then press("Coin 1", 1) end
  if idle == 305 or frame == 605 then press("Coin 1", 0) end
  if idle == 340 or frame == 640 then press("1 Player Start", 1) end
  if idle == 345 or frame == 645 then press("1 Player Start", 0) end
  if idle > 400 then idle = 0 end
  if e000 & 0x80 ~= 0 then
    local d0 = mem:read_u8(0xE309)
    if d0 & 0x80 ~= 0 and d0 & 0x20 == 0 then   -- a diamond is on the board: steer into it (turns only on grid lines)
      local p1, p3 = mem:read_u8(0xE1C6), mem:read_u8(0xE1C8)
      local da, db = mem:read_u8(0xE30A) - p1, mem:read_u8(0xE30C) - p3
      local R, L, U, D = 0, 0, 0, 0
      if math.abs(db) >= 2 then
        if p1 % 16 == 8 then if db > 0 then U = 1 else D = 1 end
        elseif da > 0 or (da == 0 and p1 % 16 < 8) then R = 1 else L = 1 end
      elseif math.abs(da) >= 2 then
        if p3 % 16 == 0 then if da > 0 then R = 1 else L = 1 end
        elseif db > 0 then U = 1 else D = 1 end
      end
      press("P1 Right", R); press("P1 Left", L); press("P1 Up", U); press("P1 Down", D); press("P1 Button 1", 0)
    elseif frame % 15 == 0 then
      rng = (rng * 1103515245 + 12345) % 2147483648
      local dir = ({"L","R","U","D","F","N","L","R","U","D"})[(rng // 65536) % 10 + 1]
      press("P1 Left", dir == "L" and 1 or 0); press("P1 Right", dir == "R" and 1 or 0); press("P1 Up", dir == "U" and 1 or 0)
      press("P1 Down", dir == "D" and 1 or 0); press("P1 Button 1", dir == "F" and 1 or 0)
    end
  end
  for _, w in ipairs(wins) do if frame >= w[1] and frame <= w[2] and (frame - w[1]) % w[3] == 0 then
    m.video:snapshot(); logf:write(string.format("SNAP %04d seq f%d c=%X\n", nsnap, frame, mem:read_u8(0xE006))); nsnap = nsnap + 1 end end   -- c: BCD, so %X prints it in decimal
  local e = mem:read_u8(0xE006)
  if e ~= last then logf:write(string.format("CREDITS f=%d E006 %02X -> %02X\n", frame, last & 0xFF, e)); last = e end
end)
sn = emu.add_machine_stop_notifier(function() logf:write(string.format("END frames=%d\n", frame)); logf:close() end)
