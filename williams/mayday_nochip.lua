-- mayday_nochip.lua: Mayday's protection read-back, for williams/demo_mayday.sh. Needs MAME's debugger
-- (-debug -debugger none) for the breakpoints. Addresses are CPU addresses in the set `maydaya`.
-- At power-up the game stores $62 and $E2 at $A193/$A194. Two sites read $A190/$A191 back and compare: main $EEC0
-- (CMPA $A193, in the routine run when an object is destroyed) and bank 1 $C750 (CMPA $A194, the first attract
-- process). On the real board something answers those reads with $62 and $E2. MAME answers them with its own hack
-- (protection_r returns $A193/$A194), which is "with chip" here.
-- MAYDAY_NOCHIP=1: from frame 3000, a Lua read tap on $A190-$A191 returns the plain RAM byte instead of MAME's answer:
-- "no chip". It is switched on at frame 3000, after the attract-mode check at $C750 (reached in attract with these inputs) has
-- passed with MAME's answer, so that the check shown is the one at $EEC0. With the tap on from power-up, the $C750
-- check fails first and the board restarts (seen, not examined further). No ROM is changed. Logs the loaded bytes at both compare sites, every compare (A as read against the constant, the first 5),
-- and "SNAP nnnn seq fF" every 5 frames from 4900 to 5400.
-- Inputs: Auto Up off and no Advance (Mayday boots straight to attract); from frame 4200, coin every 900 frames,
-- 1 Player Start 60 frames later, Fire pulsed, Up and Down in turn. The same inputs on both sides.
local m = manager.machine
local cpu = m.devices[":maincpu"]
local mem = cpu.spaces["program"]
local dbg = m.debugger
local frame, snapn = 0, -1
local function log(s) print(string.format("[lua] f%05d %s", frame, s)) end
local function rd(r, a, k) local t = {} for i = 0, k - 1 do t[#t + 1] = string.format("%02X", r:read_u8(a + i)) end return table.concat(t, " ") end
log("loaded main $EEC0 = " .. rd(m.memory.regions[":maincpu"], 0xEEC0 - 0xD000, 3) .. " (CMPA $A193), bank 1 $C750 = " ..
  rd(m.memory.regions[":banked"], 0x0750, 3) .. " (CMPA $A194)")
local NOCHIP = os.getenv("MAYDAY_NOCHIP") == "1"
log(NOCHIP and "no chip from frame 3000: reads of $A190/$A191 will return plain RAM"
  or "with chip: MAME's protection_r answers $A190/$A191 throughout")
local sites = { [0xEEC0] = { "A193", 0xA193 }, [0xC750] = { "A194", 0xA194 } }
local n = { [0xEEC0] = 0, [0xC750] = 0 }
for a in pairs(sites) do cpu.debug:bpset(a, "", "") end
local function service()
  if dbg.execution_state ~= "stop" then return end
  local pc = cpu.state["PC"].value
  if sites[pc] then
    n[pc] = n[pc] + 1
    if n[pc] <= 5 then
      log(string.format("compare at $%04X: read %02X, wants %02X ($%s)", pc, cpu.state["D"].value >> 8,
        mem:read_u8(sites[pc][2]), sites[pc][1]))
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
  if frame == 1 then P2["Auto Up / Manual Down"]:set_value(0) end
  if NOCHIP and frame == 3000 then
    local ram = m.memory.shares[":videoram"]
    keep_t = mem:install_read_tap(0xA190, 0xA191, "nochip", function(off, data, mask) return ram:read_u8(off) end)
    log("no chip: tap on")
  end
  if frame >= FROM then
    pulse(P2["Coin 1"], FROM, 4, 900); pulse(P0["1 Player Start"], FROM + 60, 4, 900)
    pulse(P0["Fire"], FROM + 120, 3, 7)
    local ph = ((frame - FROM) // 90) % 4
    P1["P1 Up"]:set_value(ph == 0 and 1 or 0); P0["P1 Down"]:set_value(ph == 2 and 1 or 0)
  end
  if frame >= 4900 and frame <= 5400 and (frame - 4900) % 5 == 0 then
    m.video:snapshot(); snapn = snapn + 1; log(string.format("SNAP %04d seq f%d", snapn, frame))
  end
end)
keep_s = emu.add_machine_stop_notifier(function()
  log(string.format("compares reached: $EEC0 %d, $C750 %d", n[0xEEC0], n[0xC750]))
end)
