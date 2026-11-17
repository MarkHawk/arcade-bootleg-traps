-- sdungeon_delayed.lua: Space Dungeon's delayed checksum over the code that prints the copyright, for
-- taito/demo_sdungeon.sh. Needs MAME's debugger (-debug -debugger none) for the breakpoints.
-- The check at $E0C4 adds one byte of $BDC0-$BDFF to a running sum ($87CE) at each event (the thief taking a
-- treasure, which happens in the attract demo); after the 64th it compares the sum with $6A at $E0D3, and on a
-- mismatch runs the penalty at $E0DA, which retypes display-list records (the thief is drawn as a cut-down shape).
-- At frame SD_POKE (default 4400) this script sets the pointer to the 64th byte ($87CF/$87D0 = $BDFF) and the sum to
-- what 63 events would have added (the sum of the loaded bytes $BDC0-$BDFE): "counter poked to 63". The 64th event
-- is the game's own.
-- Always: 5 x Test Advance at start (a fresh NVRAM goes through set-up pages). Logs the loaded bytes at $BDDA and the
-- copyright text at $C45E, the poke, each event, the sum at the compare, any penalty, and "SNAP nnnn seq fF" every
-- SD_SNAPEVERY frames from SD_SNAPFROM to SD_SNAPTO. Exits at SD_END.
local m = manager.machine
local cpu = m.devices[":maincpu"]
local mem = cpu.spaces["program"]
local dbg = m.debugger
local env = function(k, d) return tonumber(os.getenv(k) or "") or d end
local POKE, END = env("SD_POKE", 4400), env("SD_END", 4730)
local SE, SF, ST = env("SD_SNAPEVERY", 2), env("SD_SNAPFROM", 4380), env("SD_SNAPTO", 4720)
local frame, snapn = 0, -1
local function log(s) print(string.format("[lua] f%05d %s", frame, s)) end
local function rd(a, n) local t = {} for i = 0, n - 1 do t[#t + 1] = string.format("%02X", mem:read_u8(a + i)) end return table.concat(t, " ") end
log("loaded $BDDA = " .. rd(0xBDDA, 1) .. " (genuine 40)")
log("loaded $C45E: " .. rd(0xC45E, 22))
local F = {}
for _, p in pairs(m.ioport.ports) do for n, f in pairs(p.fields) do F[n] = f end end
local bps = { [0xE0C4] = "event: one byte added", [0xE0D6] = "sum at the compare (want 6A)", [0xE0DA] = "PENALTY" }
local hits = {}
for a in pairs(bps) do cpu.debug:bpset(a, "", "") end
local function service()
  if dbg.execution_state ~= "stop" then return end
  local pc = cpu.state["PC"].value
  hits[pc] = (hits[pc] or 0) + 1
  if pc == 0xE0C4 then
    if frame >= POKE then log(string.format("%s, pointer $87CF/D0=%04X", bps[pc], mem:read_u16(0x87CF))) end
  elseif bps[pc] and hits[pc] <= 5 then
    log(string.format("%s: A=%02X", bps[pc], cpu.state["D"].value >> 8))
  end
  dbg.execution_state = "run"
end
keep_p = emu.register_periodic(service)
dbg.execution_state = "run"
keep_f = emu.add_machine_frame_notifier(function()
  frame = frame + 1
  for _, a in ipairs({180, 360, 540, 720, 900}) do
    if frame == a then F["Test Advance"]:set_value(1) elseif frame == a + 10 then F["Test Advance"]:set_value(0) end
  end
  if frame == POKE then
    local sum = 0
    for a = 0xBDC0, 0xBDFE do sum = (sum + mem:read_u8(a)) & 0xFF end
    log(string.format("POKE (counter to 63): before $87CE=%02X $87CF/D0=%04X; set $87CF/D0=BDFF, $87CE=%02X",
      mem:read_u8(0x87CE), mem:read_u16(0x87CF), sum))
    mem:write_u8(0x87CE, sum); mem:write_u16(0x87CF, 0xBDFF)
  end
  if SE > 0 and frame >= SF and frame <= ST and (frame - SF) % SE == 0 then
    m.video:snapshot(); snapn = snapn + 1; log(string.format("SNAP %04d seq f%d", snapn, frame))
  end
  if frame >= END then log("penalty runs: " .. (hits[0xE0DA] or 0)); m:exit() end
end)
