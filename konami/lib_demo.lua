-- lib_demo.lua: shared part of the check demos (konami/demo_check1.lua, konami/demo_check2.lua).
-- Each demo runs twice, on the genuine trackfldu and on the one-byte edited set built by
-- konami/build_roms.py, with identical inputs and forces; konami/demo.sh does both.
-- Environment: TF_SIDE = genuine | edited (only used for file names; the ROM decides).
-- Log: TF_OUT/demo_checkN_SIDE.log (TF_OUT default konami/out). Snapshots: MAME's snapshot directory;
-- each is listed in the log as "SNAP nnnn label".
package.path = "konami/?.lua;" .. package.path
local tf = require("lib_tf")
local D = {tf = tf}

function D.setup(check, run, pass, fail, effect)
  D.check = check
  D.side = os.getenv("TF_SIDE") or "genuine"
  D.name = string.format("demo_check%d_%s", check, D.side)
  tf.open_log((os.getenv("TF_OUT") or "konami/out") .. "/" .. D.name .. ".log")
  tf.log(string.format("check %d demo, %s set; ROM byte under test listed below", check, D.side), true)
  D.nsnap = 0
  D.result = nil
  D.failed_at = nil
  D.resets = 0
  -- the check: runs at `run`, fails at `fail`, passes at `pass` (when pass is reached right after run)
  local ran = nil
  tf.bp(run, function()
    ran = tf.frame
    D.runs = (D.runs or 0) + 1
    if D.runs <= 3 then
      tf.log(string.format("CHECK %d RUNS at $%04X (#%d)", check, run, D.runs), true)
      if D.runs == 1 then D.snap("check runs") end
    end
  end)
  tf.bp(pass, function()
    if D.last_fail == tf.frame then return end
    if ran and tf.frame - ran <= 1 and (D.passes or 0) < 3 then
      D.passes = (D.passes or 0) + 1
      tf.log(string.format("  check %d PASSES ($%04X)", check, pass), true)
      if not D.result then D.result = "pass"; D.result_frame = tf.frame end
      if D.passes == 1 then D.after("after pass", 60) end
    end
  end)
  tf.bp(fail, function()
    D.fails = (D.fails or 0) + 1
    D.last_fail = tf.frame
    if D.fails <= 3 then tf.log(string.format("  check %d FAILS ($%04X)", check, fail), true) end
    if not D.result then D.result = "fail"; D.result_frame = tf.frame end
    if not effect and not D.failed_at then D.failed_at = tf.frame; D.snap("at failure") end
  end)
  -- checks whose failure acts later (check 1): the failure action itself
  if effect then
    local acts = 0
    tf.bp(effect, function()
      acts = acts + 1
      if acts <= 3 then tf.log(string.format("FAILURE ACTION at $%04X (#%d)", effect, acts), true) end
      if not D.failed_at then D.failed_at = tf.frame; D.snap("at failure action") end
    end)
  end
  -- after a failure: where the CPU is, how often the board resets, what the screen shows
  tf.bp(0x6000, function()
    if not D.failed_at then return end
    D.resets = D.resets + 1
    if D.resets <= 5 or D.resets % 20 == 0 then
      tf.log(string.format("board RESET (code at $6000 runs, #%d)", D.resets), true)
    end
  end)
  tf.every_frame(function()
    if D.failed_at then
      local dt = tf.frame - D.failed_at
      if dt > 0 and dt <= 240 and dt % 30 == 0 then
        tf.log(string.format("  +%d frames after failure: PC=%04X mode=%02X phase=%02X state=%02X", dt, tf.pc(),
          tf.r8(0x2800), tf.r8(0x2803), tf.r8(0x2806)))
      end
      if dt == 60 then D.snap("failure +60") end
      if dt == 600 then D.snap("failure +600") end
    end
  end)
  return D
end

function D.snap(label)
  tf.log(string.format("SNAP %04d %s", D.nsnap, label))
  manager.machine.video:snapshot()
  D.nsnap = D.nsnap + 1
end

-- take a snapshot n frames from now
local pending = {}
function D.after(label, n) table.insert(pending, {tf.frame + n, label}) end
tf.every_frame(function()
  for i = #pending, 1, -1 do
    if tf.frame >= pending[i][1] then D.snap(pending[i][2]); table.remove(pending, i) end
  end
end)

-- TF_SEQ="from-to,from-to": a snapshot every 4 frames in those windows, labelled "seq fNNNN" (for GIFs)
local seq = {}
for a, b in string.gmatch(os.getenv("TF_SEQ") or "", "(%d+)-(%d+)") do table.insert(seq, {tonumber(a), tonumber(b)}) end
tf.every_frame(function()
  for _, w in ipairs(seq) do
    if tf.frame >= w[1] and tf.frame <= w[2] and (tf.frame - w[1]) % 4 == 0 then
      D.snap(string.format("seq f%04d", tf.frame)); return
    end
  end
end)

-- snapshots at fixed frames on both sides (for the side-by-side sheets): label "fNNNN"
function D.at_frames(list)
  local want = {}
  for _, f in ipairs(list) do want[f] = true end
  tf.every_frame(function() if want[tf.frame] then D.snap(string.format("f%04d", tf.frame)) end end)
end

function D.c16(a) return tf.r8(a) * 256 + tf.r8(a + 1) end
function D.w16(a, v) tf.w8(a, v // 256); tf.w8(a + 1, v % 256) end

-- log the ROM byte(s) under test, as the CPU sees them
function D.show_rom(list)
  for _, a in ipairs(list) do
    tf.log(string.format("ROM $%04X = %02X", a, tf.r8(a)), true)
  end
end

-- end of run: one summary line, then exit
function D.finish_at(n)
  tf.every_frame(function()
    if tf.frame == n - 1 then
      D.snap("end of run")
    end
    if tf.frame == n then
      tf.log(string.format("SUMMARY check %d %s: check ran %d time(s), result %s%s, board resets %d, final mode=%02X PC=%04X",
        D.check, D.side, D.runs or 0, D.result or "check never ran",
        D.result_frame and string.format(" at f%d", D.result_frame) or "", D.resets, tf.r8(0x2800), tf.pc()), true)
    end
  end)
  tf.run(n + 1)
end

return D
