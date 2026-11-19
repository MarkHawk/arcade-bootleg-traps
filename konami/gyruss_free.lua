-- gyruss_free.lua: Gyruss, the free-credit demo for konami/demo_gyruss.sh (genuine gyruss against the copy with
-- "KONAMI" edited to "KNNAMI" and the ROM sums kept). The same inputs on both sides: no coin is ever inserted;
-- 1P Start is pressed at frame 2000 (8 frames); from frame 2040 P1 sweeps left and right and taps fire.
-- Nothing is written to RAM or ROM by this script: it only sets inputs and reads memory.
-- Environment: G_LOG (log file), G_FRAMES (frames to run, default 3000).
-- Log:
--   LOADED  the CRC32 of each 8 KB of the main Z80's ROM as MAME loaded it, and the copyright bytes $37AB-$37B7
--           with the two compensation bytes $37BD and $388A (proves which ROM ran)
--   CREDITS every change of the BCD credit count $9406, with the frame
--   STATE   every change of the game's main and sub state ($942C, $942B)
--   state   the state bytes, credits and lives ($9620) every 60 frames
--   SNAP    one line per snapshot, "SNAP nnnn seq fFFFF c=CC" (CC = credits), for scripts/gif_pair.py: every 4 frames
--           in 740-860 and 1976-2200, every 60 frames otherwise
local m = manager.machine
local mem = m.devices[":maincpu"].spaces["program"]
local logf = io.open(os.getenv("G_LOG"), "w")
local frames = tonumber(os.getenv("G_FRAMES") or "3000")
local frame, nsnap = 0, 0

local function log(msg) logf:write(string.format("[f%06d] %s\n", frame, msg)); logf:flush() end

local crctab = {}
for i = 0, 255 do
  local c = i
  for _ = 1, 8 do c = (c & 1) ~= 0 and (0xEDB88320 ~ (c >> 1)) or (c >> 1) end
  crctab[i] = c
end
local function crc32(region, a, n)
  local c = 0xFFFFFFFF
  for i = a, a + n - 1 do c = crctab[(c ~ region:read_u8(i)) & 0xFF] ~ (c >> 8) end
  return c ~ 0xFFFFFFFF
end
local function hexs(a, b)
  local t = {}
  for x = a, b do t[#t + 1] = string.format("%02X", mem:read_u8(x)) end
  return table.concat(t, " ")
end

local held = {}
local function set_input(port, field, on)
  local k = port .. "/" .. field
  if held[k] ~= on then
    m.ioport.ports[port].fields[field]:set_value(on and 1 or 0)
    held[k] = on
  end
end

local last_cr, last_st
notifier = emu.add_machine_frame_notifier(function()
  frame = frame + 1
  if frame == 1 then
    local r = m.memory.regions[":maincpu"]
    log(string.format("LOADED set %s main 0000:%08x 2000:%08x 4000:%08x", emu.romname(),
      crc32(r, 0x0000, 0x2000), crc32(r, 0x2000, 0x2000), crc32(r, 0x4000, 0x2000)))
    log(string.format("LOADED copyright 37AB-37B7: %s; 37BD: %02X; 388A: %02X", hexs(0x37AB, 0x37B7),
      mem:read_u8(0x37BD), mem:read_u8(0x388A)))
  end
  set_input(":SYSTEM", "1 Player Start", frame >= 2000 and frame < 2008)
  local ph = math.floor(frame / 90) % 2
  set_input(":P1", "P1 Left", frame > 2040 and ph == 0)
  set_input(":P1", "P1 Right", frame > 2040 and ph == 1)
  set_input(":P1", "P1 Button 1", frame > 2040 and (frame % 8) < 4)
  local cr = mem:read_u8(0x9406)
  local st = string.format("942C=%02X 942B=%02X", mem:read_u8(0x942C), mem:read_u8(0x942B))
  if cr ~= last_cr then
    if last_cr then log(string.format("CREDITS %02X -> %02X", last_cr, cr)) end
    last_cr = cr
  end
  if st ~= last_st then log("STATE " .. st); last_st = st end
  if (frame >= 740 and frame <= 860 and frame % 4 == 0) or (frame >= 1976 and frame <= 2200 and frame % 4 == 0)
      or frame % 60 == 0 then
    m.video:snapshot()
    log(string.format("SNAP %04d seq f%d c=%02X", nsnap, frame, cr)); nsnap = nsnap + 1
  end
  if frame % 60 == 0 then
    log(string.format("state %s credits=%02X lives=%02X", st, cr, mem:read_u8(0x9620)))
  end
  if frame >= frames then log("end"); logf:close(); m:exit() end
end)
