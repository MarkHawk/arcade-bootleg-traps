-- dkjr_vine.lua: Donkey Kong Jr., fixed inputs for nintendo/demo_dkjr.sh (the bootleg jrking, genuine dkongjr with one
-- checked tile changed, and unpatched genuine as the control). Changes nothing in ROM or RAM.
-- Coin at frame 200, start at 240. From the first play frame (mode 2 = 0C) the script runs DKJR_SCRIPT, a list of
-- "INPUTS:FRAMES" steps (R right, L left, U up, D down, J jump; e.g. "R:30,RJ:2,U:200"), the same on both sides.
-- DKJR_SEQ "a-b" and DKJR_STEP n: a snapshot every n frames from a to b.
-- Logs: the loaded copyright entry 0x37F4-0x380F (proves which ROM ran), each check pass (sum of 0x37FB-0x3801 with
-- the 0x88 start), 0x6300 at the first play frame, Jr.'s x/y (0x6203/0x6205) every 5 play frames, SNAP lines.
local m = manager.machine
local cpu = m.devices[":maincpu"]
local mem = cpu.spaces["program"]
local logf = io.open(os.getenv("DKJR_LOG"), "w")
local function hexs(a, b) local t = {} for x = a, b do t[#t+1] = string.format("%02X", mem:read_u8(x)) end return table.concat(t, " ") end
logf:write("LOADED 37F4..380F: " .. hexs(0x37F4, 0x380F) .. "\n")
local F = {}
for _, p in pairs(m.ioport.ports) do for n, f in pairs(p.fields) do F[n] = f end end
local steps = {}
for k, n in string.gmatch(os.getenv("DKJR_SCRIPT") or "R:30,RJ:2,U:200", "(%a+):(%d+)") do steps[#steps+1] = {k, tonumber(n)} end
local SEQ_A, SEQ_B = string.match(os.getenv("DKJR_SEQ") or "", "(%d+)-(%d+)")
SEQ_A, SEQ_B = tonumber(SEQ_A), tonumber(SEQ_B)
local STEP = tonumber(os.getenv("DKJR_STEP") or "1")
local frame, play0, snapn, cur = 0, nil, 0, 0x88
chktap = mem:install_read_tap(0x37FB, 0x3801, "chk", function(o, d, mk)
  local pc = cpu.state["PC"].value
  if pc >= 0x2440 and pc <= 0x244C then
    if o == 0x37FB then cur = 0x88 end
    cur = (cur + d) & 0xFF
    if o == 0x3801 then logf:write(string.format("f%d CHECK sum=%02X\n", frame, cur)) end
  end
  return d end)
local function set(keys)
  F["P1 Right"]:set_value(keys:find("R") and 1 or 0); F["P1 Left"]:set_value(keys:find("L") and 1 or 0)
  F["P1 Up"]:set_value(keys:find("U") and 1 or 0); F["P1 Down"]:set_value(keys:find("D") and 1 or 0)
  F["P1 Button 1"]:set_value(keys:find("J") and 1 or 0)
end
notifier = emu.add_machine_frame_notifier(function()
  frame = frame + 1
  F["Coin 1"]:set_value((frame >= 200 and frame < 205) and 1 or 0)
  F["1 Player Start"]:set_value((frame >= 240 and frame < 245) and 1 or 0)
  if not play0 and mem:read_u8(0x600A) == 0x0C then
    play0 = frame; logf:write(string.format("f%d PLAY 6300: %s\n", frame, hexs(0x6300, 0x630F)))
  end
  if play0 then
    local t, keys = frame - play0, ""
    for _, s in ipairs(steps) do if t < s[2] then keys = s[1]; break end; t = t - s[2] end
    set(keys)
    if (frame - play0) % 5 == 0 then logf:write(string.format("f%d t%d keys=%s x=%02X y=%02X\n", frame, frame - play0, keys, mem:read_u8(0x6203), mem:read_u8(0x6205))) end
  end
  if SEQ_A and frame >= SEQ_A and frame <= SEQ_B and (frame - SEQ_A) % STEP == 0 then
    m.video:snapshot(); logf:write(string.format("SNAP %04d seq f%d\n", snapn, frame)); snapn = snapn + 1 end
end)
stopn = emu.add_machine_stop_notifier(function() logf:write("END frames=" .. frame .. "\n"); logf:close() end)
