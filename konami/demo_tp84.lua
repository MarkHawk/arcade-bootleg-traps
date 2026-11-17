-- demo_tp84.lua: Time Pilot '84 copyright checks, genuine against an edited set (konami/demo_tp84.sh).
-- Fresh NVRAM (the board has none). Steps: DIP Coin A = Free Play, 1P start at f480, P1 holds Left from f700
-- (to see which player's controls the game reads); at TF_POKE (default f1000, mid-play) $5235 := $FFFE by RAM poke
-- (the play-frame counter; the next play frame makes it $FFFF, the value that gates three checks).
-- Logged: every change of $57C8 (current player; it also drives screen flip), which input byte the game
-- reads ($5731 = P1 at $8536, $5732 = P2 at $853A), commands $52/$53 queued at $8F0C (they draw the two
-- message lines, see docs/konami-time-pilot-84.md), and each check's
-- run and fail. Snapshots every frame from TF_SEQ_A to TF_SEQ_B, named in the log ("SNAP nnnn seq fFFFF").
-- Log: konami/out/tp84_TAG.log. No other RAM or ROM writes.
if TD_LOADED then print("[lua] (script re-run after a board reset: ignored)"); return end
TD_LOADED = true
package.path = "konami/?.lua;" .. package.path
local tf = require("lib_tf")
local tag = os.getenv("TF_TAG") or emu.romname()
tf.open_log((os.getenv("TF_OUT") or "konami/out") .. "/tp84_" .. tag .. ".log")
local _t = {}
for a = 0xBD5E, 0xBD6A do _t[#_t + 1] = string.format("%02X", tf.r8(a)) end
tf.log("LOADED $BD5E: " .. table.concat(_t, " ") .. "  (copyright as the checks read it: genuine KONAMI 1984 is ... 4B 4F 4E 41 4D 49 ...)", true)
local POKE = tonumber(os.getenv("TF_POKE") or "1000")
local SA, SB = tonumber(os.getenv("TF_SEQ_A") or "0"), tonumber(os.getenv("TF_SEQ_B") or "-1")
local SA2, SB2 = tonumber(os.getenv("TF_SEQ2_A") or "0"), tonumber(os.getenv("TF_SEQ2_B") or "-1")   -- a second range
local ports = manager.machine.ioport.ports
-- DIP "Coin A" = Free Play (value 0): in MAME a 30-frame coin press at f400 left CREDIT at 00 (not investigated),
-- so a game is started on free play instead; a DIP switch setting, no RAM write.
ports[":DSW1"].fields["Coin A"].user_value = 0
tf.log("DIP Coin A = Free Play", true)
tf.press(":SYSTEM", "1 Player Start", 480, 500)
tf.press(":P1", "P1 Left", 700, 100000)

local nsnap = 0
local function snap(label)
  tf.log(string.format("SNAP %04d %s", nsnap, label), false)
  manager.machine.video:snapshot(); nsnap = nsnap + 1
end
local function c16(a) return tf.r8(a) * 256 + tf.r8(a + 1) end
local function dreg() return tf.cpu.state["D"].value end

local last57c8, toggles, win_toggles, first_toggle = nil, 0, 0, nil
local p1reads, p2reads = 0, 0
local counts = {}
local function count(k) counts[k] = (counts[k] or 0) + 1; return counts[k] end
local function first(k, msg, n)
  local c = count(k)
  if c <= (n or 1) then tf.log(string.format("%s (#%d): $5235=%04X $57C8=%d $57D0=%02X state $57C5=%02X", msg, c, c16(0x5235), tf.r8(0x57C8), tf.r8(0x57D0), tf.r8(0x57C5)), true) end
end

tf.every_frame(function()
  local f = tf.frame
  if f == POKE then
    tf.w8(0x5235, 0xFF); tf.w8(0x5236, 0xFE)
    tf.log(string.format("POKE: $5235 := $%04X (state $57C5=%02X, $57C8=%d)", c16(0x5235), tf.r8(0x57C5), tf.r8(0x57C8)), true)
  end
  local v = tf.r8(0x57C8)
  if last57c8 ~= nil and v ~= last57c8 then
    toggles = toggles + 1; win_toggles = win_toggles + 1
    if not first_toggle then first_toggle = f; tf.log(string.format("FIRST CHANGE of $57C8 (%d -> %d), state $57C5=%02X", last57c8, v, tf.r8(0x57C5)), true) end
  end
  last57c8 = v
  if f % 60 == 0 and f <= 600 then tf.log(string.format("f%d PC=%04X $57FA=%02X", f, tf.pc(), tf.r8(0x57FA)), false) end
  if f % 120 == 0 then
    tf.log(string.format("f%d: $57C8 changed %d times in the last 120 frames; $5235=%04X; input reads P1 %d / P2 %d; state $57C5=%02X $57D0=%02X PC=%04X ROM-fail flag $57FA=%02X",
      f, win_toggles, c16(0x5235), p1reads, p2reads, tf.r8(0x57C5), tf.r8(0x57D0), tf.pc(), tf.r8(0x57FA)), false)
    win_toggles, p1reads, p2reads = 0, 0, 0
  end
  if (f >= SA and f <= SB) or (f >= SA2 and f <= SB2) then snap(string.format("seq f%d", f)) end
end)

tf.bp(0x8536, function() p1reads = p1reads + 1 end)   -- $852E returned $5731 (player 1's input)
tf.bp(0x853A, function() p2reads = p2reads + 1 end)   -- $852E returned $5732 (player 2's input)
tf.bp(0x8F0C, function()
  local d = dreg()
  if d == 0x0052 or d == 0x0053 then
    local n = count("snd" .. d)
    if n <= 3 then tf.log(string.format("TEXT COMMAND $%04X queued at $8F0C (draws message line %d, #%d): $5235=%04X", d, d - 0x51, n, c16(0x5235)), true) end
  end
end)
tf.bp(0x9504, function() first("run9504", "check $9504 (inline, gated) RUNS", 2) end)
tf.bp(0x8354, function() first("run8354", "check $8354 (IRQ tail, gated) RUNS", 2) end)
tf.bp(0xA8EF, function() first("runA8EF", "check $A8EF (message tail, gated) RUNS", 2) end)
tf.bp(0xA7C6, function() first("runA7C6", "check $A7C6 (every play frame, ungated) first RUNS", 1) end)
tf.bp(0xA7D6, function() first("failA7C6", "  ... $A7C6 FAILS: $57C8 toggled", 1) end)
tf.bp(0xA99E, function() first("runA99E", "check $A99E RUNS", 2) end)
tf.bp(0xA9AE, function() first("failA99E", "  ... $A99E FAILS: $57C8 := 1, $57D0 := 0", 2) end)
tf.bp(0xB555, function() first("runB555", "check $B555 RUNS", 2) end)
tf.bp(0xB565, function() first("failB555", "  ... $B555 FAILS: queues text command $52 and sets <$00", 2) end)
tf.bp(0x8364, function() first("fail8354", "  ... $8354 FAILS: queues text commands $52, $53 (the message)", 2) end)
tf.bp(0x9514, function() first("fail9504", "  ... $9504 FAILS: queues text commands $52, $53 (the message)", 2) end)
tf.bp(0xA8FF, function() first("failA8EF", "  ... $A8EF FAILS: $57C8 := 1, $57D0 := 0", 2) end)
tf.bp(0xB66A, function() local c = count("reset"); if c <= 6 then tf.log(string.format("RESET vector code at $B66A runs (#%d)", c), true) end end)
tf.bp(0x8AE5, function() first("gamestart", "GAME START ($8AE5: $57C8 := 0)", 3) end)
-- power-on ROM test: $B774 (BNE to itself) is reached by every board; it only loops if a ROM sum failed
-- ($57FA set). No breakpoint there (a branch to itself would stop the debugger on every pass): sample the PC.
local halted_frames, halted_first = 0, nil
tf.every_frame(function()
  if tf.pc() >= 0xB774 and tf.pc() <= 0xB776 then
    local failed = tf.mem:read_u8(tf.cpu.state["S"].value - 5) ~= 0
    if failed then
      halted_frames = halted_frames + 1
      if not halted_first then halted_first = tf.frame; tf.log("POWER-ON ROM TEST FAILED: CPU sits at $B774 (branch to itself); failing-ROM flag $57FA=" .. string.format("%02X", tf.r8(0x57FA)), true) end
    end
  end
end)
tf.every_frame(function()
  if tf.frame == tonumber(os.getenv("TF_FRAMES") or "2200") - 1 then
    tf.log(string.format("ROM test: %s", halted_first and ("FAILED at f" .. halted_first .. ", halted for " .. halted_frames .. " sampled frames") or "passed (board went on to play)"), true)
    tf.log(string.format("SUMMARY %s: $57C8 changed %d times (first at f%s); text commands $52 x%d, $53 x%d; checks run: A7C6 x%d, 9504 x%d, 8354 x%d, A8EF x%d, A99E x%d, B555 x%d; fails: A7C6 x%d, 9504 x%d, 8354 x%d",
      tag, toggles, tostring(first_toggle), counts["snd82"] or 0, counts["snd83"] or 0, counts["runA7C6"] or 0, counts["run9504"] or 0, counts["run8354"] or 0, counts["runA8EF"] or 0, counts["runA99E"] or 0, counts["runB555"] or 0, counts["failA7C6"] or 0, counts["fail9504"] or 0, counts["fail8354"] or 0), true)
  end
end)
tf.run(tonumber(os.getenv("TF_FRAMES") or "2200"))
