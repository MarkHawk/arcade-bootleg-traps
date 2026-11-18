-- defender_bomb.lua: Defender's logo trap (WCURS), for williams/demo_defender.sh. Needs MAME's debugger
-- (-debug -debugger none) for the breakpoints. Addresses are the Red label's (MAME set `defender`).
-- At the first attract logo the code at $C80B reads the logo colour (palette slot named by the operand at $C6F8); if
-- its red component is full, it stores the end point of the WILLIAMS handwriting (CUREND, $6245) into WCURS ($A0B8).
-- In play, SBLNK compares WCURS with $6245 ($E116); on a mismatch, in a game (not attract) and when SEED is $A0, it
-- writes HSEED to $A0xx (xx = LSEED), a random byte of the game's own variables ($E12E).
-- Logs: the loaded byte at $C6F8 (bank 1 offset $6F8; genuine 0F), WCURS at frame 4000 (after the first attract
-- logo, at about frame 3440, and before play), and each bomb write. At the
-- end: counts of compares reached (CHK), failed compares in a game (ELIG) and bomb writes (BOMB).
-- Inputs: Auto Up on, Advance pulsed every 20 frames from 300 to 3000 (a fresh NVRAM boots to the audit pages), then
-- from frame 4200: coin every 900 frames, 1 Player Start 60 frames later, Fire pulsed, Thrust held, Up and Down in turn,
-- Reverse and Hyperspace now and then. The same inputs on both sides. Nothing is poked.
local m = manager.machine
local cpu = m.devices[":maincpu"]
local mem = cpu.spaces["program"]
local dbg = m.debugger
local frame = 0
local function log(s) print(string.format("[lua] f%05d %s", frame, s)) end
log(string.format("loaded $C6F8 (bank 1 +6F8) = %02X (genuine 0F)", m.memory.regions[":banked"]:read_u8(0x6F8)))
local CHK, ELIG, BOMB = 0xE116, 0xE120, 0xE12E
local n = { [CHK] = 0, [ELIG] = 0, [BOMB] = 0 }
for a in pairs(n) do cpu.debug:bpset(a, "", "") end
local function service()
  if dbg.execution_state ~= "stop" then return end
  local pc = cpu.state["PC"].value
  if n[pc] then
    n[pc] = n[pc] + 1
    if pc == BOMB then
      log(string.format("BOMB write: $%04X := %02X (STATUS %02X, WCURS %04X)", cpu.state["X"].value,
        cpu.state["D"].value & 0xFF, mem:read_u8(0xA0BA), mem:read_u16(0xA0B8)))
    end
  end
  dbg.execution_state = "run"
end
keep_p = emu.register_periodic(service)
dbg.execution_state = "run"
local P0, P1, P2 = m.ioport.ports[":IN0"].fields, m.ioport.ports[":IN1"].fields, m.ioport.ports[":IN2"].fields
local FROM = 4200
local function pulse(f, start, len, period)
  if frame < start then return end
  local k = (frame - start) % period
  if k == 0 then f:set_value(1) elseif k == len then f:set_value(0) end
end
keep_f = emu.add_machine_frame_notifier(function()
  frame = frame + 1
  if frame == 1 then P2["Auto Up / Manual Down"]:set_value(1) end
  if frame >= 300 and frame <= 3000 then
    local k = frame % 20
    if k == 0 then P2["Advance"]:set_value(1) elseif k == 5 then P2["Advance"]:set_value(0) end
  end
  if frame >= FROM then
    pulse(P2["Coin 1"], FROM, 4, 900); pulse(P0["1 Player Start"], FROM + 60, 4, 900)
    pulse(P0["Fire"], FROM + 120, 3, 7)
    if frame == FROM + 120 then P0["Thrust"]:set_value(1) end
    local ph = ((frame - FROM) // 90) % 4
    P1["P1 Up"]:set_value(ph == 0 and 1 or 0); P0["P1 Down"]:set_value(ph == 2 and 1 or 0)
    pulse(P0["Reverse"], FROM + 130, 3, 310); pulse(P0["Hyperspace"], FROM + 500, 3, 1700)
  end
  if frame == 4000 then log(string.format("WCURS ($A0B8) after the first attract logo = %04X (genuine 6245)", mem:read_u16(0xA0B8))) end
end)
keep_s = emu.add_machine_stop_notifier(function()
  log(string.format("totals: WCURS %04X at the end; CHK %d (compare reached), ELIG %d (failed in a game), BOMB %d (bomb writes)",
    mem:read_u16(0xA0B8), n[CHK], n[ELIG], n[BOMB]))
end)
