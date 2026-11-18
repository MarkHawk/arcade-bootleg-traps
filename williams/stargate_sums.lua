-- stargate_sums.lua: Stargate's two hidden ROM sums, for williams/demo_stargate.sh. Needs MAME's debugger
-- (-debug -debugger none) for the breakpoints. Addresses are CPU addresses in the set `stargate`.
-- CHKS1 ($9CFF) is computed by START at each game start (every 16th byte of $0000-$8FFF; genuine $37); CHKS2 ($BEC2)
-- by ATTR$ in attract (every 9th byte from $D004 to below $F000; genuine $56). Four sites compare them with the
-- constants and, on a mismatch and a random roll, corrupt one random byte of the direct page $9Cxx:
--   GEXBON $6744 (CHKS1, end of a wave; COM at $6755)    SGTRAN $6DD2 (CHKS2; DEC at $6DE3)
--   APST   $2715 (CHKS2; DEC at $2726)                    WORD$  $746C (CHKS1, any text phrase; COM at $747D)
-- Logs: the loaded bytes at $8C40 (genuine 00) and each site's opcode bytes as loaded, the sums when they are stored,
-- every corrupting write (address and the byte before), and a count of compares per site at the end.
-- Inputs: Auto Up off, Advance once at frame 2050 (leaves the "FACTORY SETTINGS RESTORED" page of a fresh NVRAM; the
-- edited set reaches that page later, at about frame 1975, because its ROM test reports an error first), coin at frame
-- 2500 and every 900 frames, 1 Player Start 60 frames later, then the same scripted player on both sides.
-- LABELLED POKE: from frames 3900, 5400, 6900, 8400 and 9900, for 150 frames each, the nine enemy counters that the
-- wave-end check adds up ($BE7C, $BE55-$BE5A, $BE5C, $BE5D) are written 0, so the game's own wave-end code (and
-- GEXBON, with its own random roll) runs. GEXBON corrupts a byte only when SEED is below $30, so several wave ends. No ROM byte, sum or
-- $9Cxx byte is poked. Snapshots ("SNAP nnnn seq fF") every 25 frames from 300 to 2000, for the power-up screens.
local m = manager.machine
local cpu = m.devices[":maincpu"]
local mem = cpu.spaces["program"]
local rom = m.memory.regions[":maincpu"]
local dbg = m.debugger
local frame, snapn = 0, -1
local function log(s) print(string.format("[lua] f%05d %s", frame, s)) end
local function rd(a, k) local t = {} for i = 0, k - 1 do t[#t + 1] = string.format("%02X", rom:read_u8(a + i)) end return table.concat(t, " ") end
log("loaded $8C40 (ROM 9 +C40) = " .. rd(0x8C40, 1) .. " (genuine 00)")
local sites = {
  [0x6744] = "compare GEXBON", [0x6DD2] = "compare SGTRAN", [0x2715] = "compare APST", [0x746C] = "compare WORD$",
  [0x6755] = "BOMB GEXBON (COM ,X)", [0x6DE3] = "BOMB SGTRAN (DEC ,X)", [0x2726] = "BOMB APST (DEC ,Y)",
  [0x747D] = "BOMB WORD$ (COM ,U)", [0xD01E] = "sum ATTR$ stored", [0x6151] = "sum START stored" }
local reg = { [0x6755] = "X", [0x6DE3] = "X", [0x2726] = "Y", [0x747D] = "U" }
local n = {}
for a in pairs(sites) do n[a] = 0; cpu.debug:bpset(a, "", "") end
log("opcodes as loaded: GEXBON " .. rd(0x6744, 2) .. ", SGTRAN " .. rd(0x6DD2, 2) .. ", APST " .. rd(0x2715, 2) ..
  ", WORD$ " .. rd(0x746C, 2))
local function service()
  if dbg.execution_state ~= "stop" then return end
  local pc = cpu.state["PC"].value
  if sites[pc] then
    n[pc] = n[pc] + 1
    if reg[pc] then
      local a = cpu.state[reg[pc]].value
      log(string.format("%s: $%04X, byte before %02X (STATUS %02X)", sites[pc], a, mem:read_u8(a), mem:read_u8(0x9C91)))
    elseif pc == 0xD01E and n[pc] <= 2 then log(string.format("CHKS2 = %02X (genuine 56)", cpu.state["D"].value & 0xFF))
    elseif pc == 0x6151 and n[pc] <= 2 then log(string.format("CHKS1 = %02X (genuine 37)", cpu.state["D"].value >> 8))
    end
  end
  dbg.execution_state = "run"
end
keep_p = emu.register_periodic(service)
dbg.execution_state = "run"
local P0, P1, P2 = m.ioport.ports[":IN0"].fields, m.ioport.ports[":IN1"].fields, m.ioport.ports[":IN2"].fields
local FROM, ADV = 2500, 2050
local POKES = { 3900, 5400, 6900, 8400, 9900 }
local cnt = { 0xBE7C, 0xBE55, 0xBE56, 0xBE57, 0xBE59, 0xBE58, 0xBE5A, 0xBE5C, 0xBE5D }
local function pulse(f, start, len, period)
  if frame < start then return end
  local k = (frame - start) % period
  if k == 0 then f:set_value(1) elseif k == len then f:set_value(0) end
end
keep_f = emu.add_machine_frame_notifier(function()
  frame = frame + 1
  if frame == 1 then P2["Auto Up / Manual Down"]:set_value(0) end
  if frame == ADV then P2["Advance"]:set_value(1) elseif frame == ADV + 5 then P2["Advance"]:set_value(0) end
  if frame >= FROM then
    pulse(P2["Coin 1"], FROM, 4, 900); pulse(P0["1 Player Start"], FROM + 60, 4, 900)
    pulse(P0["Fire"], FROM + 120, 3, 7)
    if frame == FROM + 120 then P0["Thrust"]:set_value(1) end
    local ph = ((frame - FROM) // 90) % 4
    P1["P1 Up"]:set_value(ph == 0 and 1 or 0); P0["P1 Down"]:set_value(ph == 2 and 1 or 0)
    pulse(P0["Reverse"], FROM + 130, 3, 310); pulse(P0["Hyperspace"], FROM + 500, 3, 1700)
  end
  for _, p in ipairs(POKES) do
    if frame >= p and frame < p + 150 then
      if frame == p then log("POKE (labelled): enemy counters := 0 for 150 frames, so the wave ends") end
      for _, a in ipairs(cnt) do mem:write_u8(a, 0) end
    end
  end
  if frame >= 300 and frame <= 2000 and (frame - 300) % 25 == 0 then
    m.video:snapshot(); snapn = snapn + 1; log(string.format("SNAP %04d seq f%d", snapn, frame))
  end
end)
keep_s = emu.add_machine_stop_notifier(function()
  log(string.format("compares reached: GEXBON %d, SGTRAN %d, APST %d, WORD$ %d", n[0x6744], n[0x6DD2], n[0x2715], n[0x746C]))
end)
