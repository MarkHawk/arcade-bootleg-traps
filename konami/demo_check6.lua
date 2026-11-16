-- demo_check6.lua: make Track & Field's check 6 (start of each attract demo, $762E) run, and log
-- whether it passes. Fresh NVRAM expected (konami/demo_atlantol.sh check6 and recovery). Check 6 is armed by the NVRAM
-- flag $2FFF bits 7-6 = 01, which the game sets itself (ORA #$40 at $7547-$754C) after the last
-- event of a round in which at least 3 of the 4 player slots at $2B80 were used. Here the flag is
-- forced instead (a RAM poke, standing in for one 3- or 4-player game played earlier on this
-- board); the ROM is not changed. Addresses are the same in hyprolym and atlantol (walk map).
--   frame 200: if the flag isn't already 01, set it ($2FFF := ($2FFF & $3F) | $40).
-- A watchdog reset reloads this script; the flag is then only logged, never written again, so a
-- second failure shows that the NVRAM flag alone keeps the check armed.
-- TF_NOFORCE=1: write nothing at all (for runs that start from a saved NVRAM, konami/demo_atlantol.sh recovery,
-- or from an empty one).
-- TF_TAG names the log (konami/out/TAG.log); snapshots go to MAME's -snapshot_directory.
if C6_LOADED then print("[lua] (script re-run after a board reset: ignored)"); return end
C6_LOADED = true
package.path = "konami/?.lua;" .. package.path
local tf = require("lib_tf")
local tag = os.getenv("TF_TAG") or emu.romname()
tf.open_log((os.getenv("TF_OUT") or "konami/out") .. "/" .. tag .. ".log")

local CK, PASS, FAIL, HANG = 0x762E, 0x766C, 0x7669, 0x8A28
local snaps = {}
local function snap_once(name)
  if not snaps[name] then snaps[name] = true; tf.snap(tag .. "_" .. name) end
end

tf.every_frame(function()
  if tf.frame == 200 then
    local v = tf.r8(0x2FFF)
    if os.getenv("TF_NOFORCE") == "1" then
      tf.log(string.format("no RAM writes (TF_NOFORCE): $2FFF = %02X at power-on (%s)", v,
        (v & 0xC0) == 0x40 and "check 6 armed, from NVRAM" or "check 6 not armed"), true)
    elseif v & 0xC0 == 0x40 then
      tf.log(string.format("$2FFF = %02X: check 6 already armed (kept in NVRAM), not written", v), true)
    else
      tf.w8(0x2FFF, (v & 0x3F) | 0x40)
      tf.log(string.format("forced $2FFF %02X -> %02X (check 6 armed)", v, tf.r8(0x2FFF)), true)
    end
  end
  -- TF_COINAT=f1,f2,...: insert a coin and press 1 Player Start at each of these frames
  for at in string.gmatch(os.getenv("TF_COINAT") or "", "%d+") do
    at = tonumber(at)
    if tf.frame == at then
      tf.press(":SYSTEM", "Coin 1", at + 1, at + 5); tf.press(":SYSTEM", "1 Player Start", at + 60, at + 66)
    end
    if tf.frame == at + 200 then
      tf.log(string.format("coin + start at f%d: now mode %02X, credits %d, PC %04X", at, tf.r8(0x2800), tf.r8(0x2823), tf.pc()), true)
    end
  end
  -- attract-mode views for the record: title / copyright screens
  if tf.frame % 150 == 0 and tf.frame <= 1800 then tf.snap(string.format("%s_attract_f%04d", tag, tf.frame)) end
end)

local ran_at, nfail, npass, hang_at = nil, 0, 0, nil
tf.bp(0x6000, function() tf.log("RESET: code at $6000 runs", true) end)
local demos = 0
tf.bp(0x7625, function()
  demos = demos + 1
  if demos <= 6 then tf.log(string.format("attract demo starts (#%d): gate reads $2FFF=%02X (check 6 %s)", demos, tf.r8(0x2FFF),
    (tf.r8(0x2FFF) & 0xC0) == 0x40 and "runs" or "skipped"), true) end
end)
tf.every_frame(function()
  if tf.frame == tonumber(os.getenv("TF_FRAMES") or "6000") - 30 then snap_once("last") end
end)
tf.bp(CK, function()
  ran_at = tf.frame
  tf.log(string.format("check 6 RUNS at $%04X ($2FFF=%02X)", CK, tf.r8(0x2FFF)), true)
end)
tf.bp(PASS, function()
  if ran_at and tf.frame - ran_at <= 2 then
    npass = npass + 1
    tf.log("  ... check 6 PASSES", true)
    snap_once("pass")
  end
end)
tf.bp(FAIL, function()
  if ran_at and tf.frame - ran_at <= 2 then
    nfail = nfail + 1
    tf.log(string.format("  ... check 6 FAILS (#%d): LBRA $%04X", nfail, HANG), true)
    snap_once("fail")
  end
end)
-- no breakpoint on the BRA-to-itself (it would stop on every loop): sample the PC each frame
tf.every_frame(function()
  if nfail > 0 and not hang_at and tf.pc() == HANG then hang_at = tf.frame end
  if hang_at and tf.frame - hang_at == 30 then
    tf.log(string.format("  +30 frames: PC=%04X (BRA to itself at $%04X)", tf.pc(), HANG), true)
    snap_once("hang")
  end
end)
-- TF_WATCHDOG=N: SIMULATE a watchdog (atlantol only; MAME's init_atlantol ignores writes to $1000,
-- so its own watchdog never arms). A write tap notes each write to $1000; if none comes for N
-- frames, soft-reset the machine, as MAME's watchdog_timer_device does when it fires (its default
-- timeout, used by every Track & Field set, is 3 s = 180 frames).
local WD = tonumber(os.getenv("TF_WATCHDOG") or "0")
if WD > 0 then
  local last_kick, resets = nil, 0
  tf.KEEP.wd_tap = tf.mem:install_write_tap(0x1000, 0x1000, "wdsim", function(offset, data, mask) last_kick = tf.frame end)
  tf.every_frame(function()
    if last_kick and tf.frame - last_kick > WD then
      resets = resets + 1
      if resets <= 5 then tf.log(string.format("SIMULATED watchdog: no write to $1000 for %d frames: reset #%d (PC %04X, mode %02X, event %02X)", WD, resets, tf.pc(), tf.r8(0x2800), tf.r8(0x2884)), true) end
      if resets <= 2 then snap_once("wd_reset" .. resets) end
      last_kick = nil
      manager.machine:soft_reset()
    end
  end)
end
tf.run(tonumber(os.getenv("TF_FRAMES") or "6000"))
