-- Shared helpers for trackfldu runtime scripts. Load with:
--   package.path = "konami/?.lua;" .. package.path; local tf = require("lib_tf")
-- Everything is RAM-side: taps and pokes, never ROM.
local tf = {}
tf.cpu = manager.machine.devices[":maincpu"]
tf.mem = tf.cpu.spaces["program"]
tf.frame = 0
tf.KEEP = {}            -- taps and notifiers must stay referenced
local logf = nil
local sched = {}
local per_frame = {}

function tf.r8(a) return tf.mem:read_u8(a) end
function tf.w8(a, v) tf.mem:write_u8(a, v) end
function tf.pc() return tf.cpu.state["PC"].value end

function tf.open_log(path)
  logf = io.open(path, "w")
end
-- log(): to the log file always, and to stdout when echo is true (keep stdout short)
function tf.log(msg, echo)
  local line = string.format("[f%05d] %s", tf.frame, msg)
  if logf then logf:write(line .. "\n"); logf:flush() end
  if echo then print("[lua] " .. line) end
end

-- held input from frame f0 to f1 (exclusive)
function tf.press(port, field, f0, f1)
  table.insert(sched, {port = port, field = field, f0 = f0, f1 = f1, on = false})
end
local function run_inputs()
  for _, s in ipairs(sched) do
    local on = tf.frame >= s.f0 and tf.frame < s.f1
    if on ~= s.on then
      manager.machine.ioport.ports[s.port].fields[s.field]:set_value(on and 1 or 0)
      s.on = on
    end
  end
end
-- coin + 1P start at the given frame
function tf.start_1p(at)
  tf.press(":SYSTEM", "Coin 1", at, at + 8)
  tf.press(":SYSTEM", "1 Player Start", at + 60, at + 68)
end

function tf.every_frame(fn) table.insert(per_frame, fn) end

-- direct input control (for patterns decided at runtime)
local held = {}
function tf.set_input(port, field, on)
  local k = port .. "/" .. field
  if held[k] ~= on then
    manager.machine.ioport.ports[port].fields[field]:set_value(on and 1 or 0)
    held[k] = on
  end
end
-- alternate P1 run buttons (1 and 3) while cond() is true. Pattern per 4*period frames:
-- Button 1, nothing, Button 3, nothing. The running code (93E4) only counts a press
-- when the previous input sample had no run button held.
function tf.mash(cond, period)
  period = period or 1
  tf.every_frame(function()
    local phase = math.floor(tf.frame / period) % 4
    local on = cond()
    tf.set_input(":IN0", "P1 Button 1", on and phase == 0)
    tf.set_input(":IN0", "P1 Button 3", on and phase == 2)
  end)
end

function tf.snap(name)
  manager.machine.video:snapshot()
  tf.log("snapshot " .. name, true)
end

-- score as displayed (stored BCD x 10) for player p
function tf.score(p)
  local a = 0x2A80 + 3 * p
  local s = string.format("%02X%02X%02X", tf.r8(a), tf.r8(a + 1), tf.r8(a + 2))
  return tonumber(s) * 10
end

-- log every write to the score bytes $2A80-$2A8B with the PC (PC is the next instruction)
tf.score_writes = {}
function tf.watch_score()
  tf.KEEP.score_tap = tf.mem:install_write_tap(0x2A80, 0x2A8B, "scorewatch",
    function(offset, data, mask)
      local pc = tf.pc()
      local old = tf.r8(offset)
      if old ~= data then
        tf.log(string.format("score write $%04X %02X->%02X pc=%04X", offset, old, data, pc))
        local k = string.format("%04X", pc)
        tf.score_writes[k] = (tf.score_writes[k] or 0) + 1
      end
      return data
    end)
end

-- set the event at game start. The STA <$84 at $6814 is seen by a write tap; returning a
-- value from a tap does not change the write in MAME 0.285, so the new value is poked at
-- the end of that frame, before the event's own setup states run.
function tf.force_event(ev)
  local pending = false
  tf.KEEP.event_tap = tf.mem:install_write_tap(0x2884, 0x2884, "eventforce",
    function(offset, data, mask)
      local pc = tf.pc()
      if (pc == 0x6814 or pc == 0x6816) and data == 0 then pending = true end
    end)
  tf.every_frame(function()
    if pending then
      pending = false
      tf.w8(0x2884, ev)
      tf.log(string.format("game start seen: event 0 -> %d (state $2806=%02X)", ev, tf.r8(0x2806)), true)
    end
  end)
end

-- breakpoints (needs -debug): fn(pc) runs while the CPU is stopped at addr, then resumes.
local bps = {}
tf.bp_hits = {}
function tf.bp(addr, fn)
  local dbg = manager.machine.debugger
  if not dbg then error("tf.bp needs mame -debug") end
  if not bps[addr] then tf.cpu.debug:bpset(addr, "", "") end
  bps[addr] = fn or function() end
end
local function bp_service()
  local dbg = manager.machine.debugger
  if dbg and dbg.execution_state == "stop" then
    local pc = tf.pc()
    tf.bp_hits[pc] = (tf.bp_hits[pc] or 0) + 1
    if bps[pc] then bps[pc](pc) end
    dbg.execution_state = "run"
  end
end
-- log the first N hits of each address (exploration)
function tf.trace_pcs(list, n)
  for _, a in ipairs(list) do
    tf.bp(a, function(pc)
      if tf.bp_hits[pc] <= (n or 3) then
        tf.log(string.format("hit %04X (#%d) ev=%02X st=%02X/%02X att=%02X pl=%02X", pc, tf.bp_hits[pc],
          tf.r8(0x2884), tf.r8(0x2806), tf.r8(0x2809), tf.r8(0x289F), tf.r8(0x28DF)))
      end
    end)
  end
end

function tf.run(fn_end_frame)
  if manager.machine.debugger then
    tf.KEEP.periodic = emu.register_periodic(bp_service)
    manager.machine.debugger.execution_state = "run"
  end
  tf.KEEP.frame = emu.add_machine_frame_notifier(function()
    tf.frame = tf.frame + 1
    run_inputs()
    for _, fn in ipairs(per_frame) do fn() end
    if fn_end_frame and tf.frame >= fn_end_frame then
      tf.log("end", true)
      if logf then logf:close(); logf = nil end
      manager.machine:exit()
    end
  end)
end

return tf
