-- demo_atlantol.lua: trigger Konami's check 6 on the unmodified atlantol (Atlant Olimpic) by normal play only.
-- Run with konami/demo_atlantol.sh natural ROM_FOLDER (about 20 minutes of emulator time; no RAM writes).
-- Nothing is written to RAM or ROM. Inputs only: DIP switches, coins, start buttons and the
-- players' left / right / button. The bot reads RAM to decide when to press (as a player
-- watching the screen would); it never writes RAM.
--
-- Plan: start an N-player game (default 3). All players mash left/right (the run controls; not
-- during "ready" in the races, to avoid false starts) and tap the button now and then. When a
-- player fails to qualify and the game offers a continue, the bot takes it: it presses the start
-- buttons every 50 frames, inserting one coin first if no credit is left ($2823 = credits; not
-- needed on free play). Once the game sets the check 6 flag itself ($754C: ORA #$40 into $2FFF,
-- after the last event of round 1 with 3+ player slots still in use), the players stop
-- continuing; if a credit is left, one more 1-player game is started and left to end. Then the
-- board goes to attract mode, where check 6 runs at the start of each demo ($762E).
--
-- Environment:
--   TF_DIPS   "Field=hex,..." DIP settings, e.g. "Coin A=0,Difficulty=60,Lives=0" (empty: MAME defaults)
--   TF_N      players (3 or 4)        TF_FRAMES  run length      TF_RUN  frames per run phase (1)
--   TF_SEQ    "FROM-TO/STEP": snapshot every STEP frames in that range (for a GIF); also
--             "fail+A-B/STEP", "flag+..." or "over+..." (first frame out of play after the flag)
--   TF_SNAP   snapshot every N frames (0 = off)
--   TF_END_AFTER_FAIL  stop the run this many frames after check 6 first fails
-- Log: konami/out/TAG.log (TAG = TF_TAG, default the set name), with "SNAP nnnn label" lines naming MAME's snapshot files.
if N6_LOADED then print("[lua] (script re-run after a board reset: ignored)"); return end
N6_LOADED = true
package.path = "konami/?.lua;" .. package.path
local tf = require("lib_tf")
local tag = os.getenv("TF_TAG") or emu.romname()
tf.open_log((os.getenv("TF_OUT") or "konami/out") .. "/" .. tag .. ".log")
local N = tonumber(os.getenv("TF_N") or "3")
local RUN = tonumber(os.getenv("TF_RUN") or "1")
local SNAP = tonumber(os.getenv("TF_SNAP") or "0")
local FRAMES = tonumber(os.getenv("TF_FRAMES") or "60000")
local ports = manager.machine.ioport.ports

local nsnap = 0
local function snap(label)
  tf.log(string.format("SNAP %04d %s", nsnap, label), false)
  manager.machine.video:snapshot(); nsnap = nsnap + 1
end

-- DIP switches
local dips = os.getenv("TF_DIPS") or ""
for k, v in string.gmatch(dips, "([^=,]+)=(%x+)") do
  for _, pn in ipairs({":DSW1", ":DSW2"}) do
    local f = ports[pn].fields[k]
    if f then f.user_value = tonumber(v, 16); tf.log(string.format("DIP %s %s = %02X", pn, k, tonumber(v, 16)), true) end
  end
end
local free = dips:find("Coin A=0") ~= nil
tf.log("DIPs " .. (dips == "" and "MAME defaults" or dips) .. (free and " (free play)" or " (coin play)"), true)

local coins, flag_frame, fail_frame, over_frame, checks = 0, nil, nil, nil, 0
local function setf(port, field, on) ports[port].fields[field]:set_value(on and 1 or 0) end
local P = { {":IN0", "P1"}, {":IN0", "P2"}, {":IN1", "P3"}, {":IN1", "P4"} }
local STARTS = { {":SYSTEM", "1 Player Start"}, {":SYSTEM", "2 Players Start"}, {":IN0", "3 Players Start"}, {":IN1", "4 Players Start"} }

local function coin(at) tf.press(":SYSTEM", "Coin 1", at, at + 4); coins = coins + 1 end

-- game start
if not free then for i = 0, N - 1 do coin(100 + 20 * i) end end
tf.press(STARTS[N][1], STARTS[N][2], 300, 306)

-- name entry ($F7E9 in atlantol runs every frame while a name is entered)
local in_entry = -100
tf.bp(0xF7E9, function() in_entry = tf.frame end)

local btn_until = 0
tf.every_frame(function()
  local f = tf.frame
  if f < 320 then return end
  local playing = tf.r8(0x2800) == 3
  if flag_frame then                   -- after the flag: hands off, so the game ends
    for i = 1, 4 do
      setf(P[i][1], P[i][2] .. " Left", false); setf(P[i][1], P[i][2] .. " Right", false)
      setf(P[i][1], P[i][2] .. " Button 1", false)
    end
    return
  end
  if f - in_entry <= 2 then            -- name entry: stick still, tap the button ("AAA")
    for i = 1, 4 do
      setf(P[i][1], P[i][2] .. " Left", false); setf(P[i][1], P[i][2] .. " Right", false)
      setf(P[i][1], P[i][2] .. " Button 1", f % 16 < 4)
    end
    return
  end
  local phase = playing and math.floor(f / RUN) % 4 or 1
  local ev = tf.r8(0x2884)
  if (ev == 0 or ev == 3) and tf.r8(0x2806) == 0 then phase = 1 end   -- no false starts
  if playing and f % 90 == 0 then btn_until = f + 12 end
  for i = 1, 4 do
    setf(P[i][1], P[i][2] .. " Left", phase == 0)
    setf(P[i][1], P[i][2] .. " Right", phase == 2)
    setf(P[i][1], P[i][2] .. " Button 1", playing and f < btn_until)
  end
end)

-- continues (before the flag), and using up a leftover credit (after it)
tf.every_frame(function()
  local f, mode, credits = tf.frame, tf.r8(0x2800), tf.r8(0x2823)
  if f < 700 then return end
  if not flag_frame then
    if mode == 3 and f % 50 == 0 and not free and credits == 0 then coin(f) end
    local on = mode == 3 and (f % 50) >= 10 and (f % 50) < 14
    for i = 1, 4 do setf(STARTS[i][1], STARTS[i][2], on) end
  else
    local on = mode == 2 and credits > 0 and f % 60 < 4
    setf(":SYSTEM", "1 Player Start", on)
    for i = 2, 4 do setf(STARTS[i][1], STARTS[i][2], false) end
  end
end)

-- state log (changes only)
local last
local function alive()
  local n, s = 0, ""
  for i = 0, 3 do
    local v = tf.r8(0x2B80 + 32 * i); if v ~= 0 then n = n + 1 end
    s = s .. string.format("%s%02X:%02X", i > 0 and " " or "", v, tf.r8(0x2B81 + 32 * i))   -- in-game flag : lives
  end
  return n, s
end
tf.every_frame(function()
  local n, s = alive()
  local line = string.format("mode %02X event %02X done %02X alive %d (%s) credits %d 2FFF %02X",
    tf.r8(0x2800), tf.r8(0x2884), tf.r8(0x2882), n, s, tf.r8(0x2823), tf.r8(0x2FFF))
  if line ~= last then tf.log(line, false); last = line end
  if SNAP > 0 and tf.frame % SNAP == 0 then snap(string.format("f%05d", tf.frame)) end
end)

-- snapshot sequences for a GIF
local seqs = {}
for spec in string.gmatch(os.getenv("TF_SEQ") or "", "[^,]+") do
  local rel, a, b, step = spec:match("^(%a*)%+?(%d+)%-(%d+)/(%d+)$")
  table.insert(seqs, {rel = rel, a = tonumber(a), b = tonumber(b), step = tonumber(step)})
end
tf.every_frame(function()
  if flag_frame and not over_frame and tf.r8(0x2800) ~= 3 then
    over_frame = tf.frame
    tf.log(string.format("game over (mode %02X), credits %d", tf.r8(0x2800), tf.r8(0x2823)), true)
  end
  for _, q in ipairs(seqs) do
    local base = ({fail = fail_frame, flag = flag_frame, over = over_frame})[q.rel]
    if q.rel == "" then base = 0 end
    if base then
      local d = tf.frame - base
      if d >= q.a and d <= q.b and d % q.step == 0 then snap(string.format("seq f%d", tf.frame)) end
    end
  end
end)

-- the game's own flag and check 6
tf.bp(0x754C, function()
  if not flag_frame then
    flag_frame = tf.frame
    local n, s = alive()
    tf.log(string.format("FLAG SET BY THE GAME at $754C: last event of round 1, %d of 4 slots in use (%s); $2FFF %02X -> %02X; coins so far %d",
      n, s, tf.r8(0x2FFF), tf.r8(0x2FFF) | 0x40, coins), true)
    snap("flagset")
  end
end)
tf.bp(0x762E, function()
  checks = checks + 1
  tf.log(string.format("check 6 RUNS (#%d) at the start of an attract demo ($2FFF=%02X)", checks, tf.r8(0x2FFF)), true)
end)
tf.bp(0x7669, function()
  if not fail_frame then
    fail_frame = tf.frame
    tf.log("  ... check 6 FAILS: screen address $37F0 is not $36CA; LBRA $8A28 (BRA to itself)", true)
    snap("check6_fail")
  end
end)
tf.every_frame(function()
  if fail_frame and (tf.frame - fail_frame) % 600 == 300 then
    tf.log(string.format("  fail +%d frames: PC=%04X", tf.frame - fail_frame, tf.pc()), true)
  end
  local END_AFTER = tonumber(os.getenv("TF_END_AFTER_FAIL") or "0")
  if (tf.frame == FRAMES - 1) or (END_AFTER > 0 and fail_frame and tf.frame - fail_frame == END_AFTER) then
    tf.log(string.format("SUMMARY: flag set by the game %s; check 6 ran %d time(s), %s; coins inserted %d",
      flag_frame and ("at f" .. flag_frame) or "NO", checks, fail_frame and ("failed at f" .. fail_frame) or "no failure", coins), true)
    if tf.frame ~= FRAMES - 1 then tf.log("end", true); manager.machine:exit() end
  end
end)
tf.run(FRAMES)
