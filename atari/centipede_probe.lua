-- centipede_probe.lua: what Centipede's POKEY credit check reads, on any Centipede set, in MAME. Nothing is changed.
--
--   st=$(mktemp -d)
--   mame centipdb -rompath ~/roms -nvram_directory "$st/nvram" -cfg_directory "$st/cfg" \
--        -video none -sound none -nothrottle -seconds_to_run 1200 -autoboot_script atari/centipede_probe.lua
--   rm -rf "$st"
--
-- Run it from the repo root, with a fresh temporary folder per run (so it starts from an empty NVRAM), on
-- centiped (genuine, for comparison), centipdb, centipdb2 or millpac (the bootlegs that kept the check). It also
-- works on the other clones, but on caterplr, magworm and magworma the check has been changed or removed, so
-- there is little to see.
--
-- At power-up and at every game start, Centipede reads $100A (the POKEY's random number) twice and adds the
-- difference (EOR) to the credit count at $C8: at $28A2/$28A5 in revision 4, $289F/$28A2 in these bootlegs. This
-- script:
--   1. prints the main CPU's read handlers for $1000-$10FF, i.e. what $100A is wired to on that set in MAME;
--   2. logs every read of $100A made by the check, and whether the two reads of each pair differ;
--   3. inserts a coin every 30 seconds and presses 1 Player Start every 10 seconds, leaving the controls alone;
--   4. logs every change to $C8 (a binary count), and prints a summary when MAME exits.
-- The values in docs/centipede.md ("The three that kept the check, in MAME") came from 1,200-second runs.

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]

print("Read handlers covering $1000-$10FF:")
for _, e in ipairs(mem.map.entries) do
  if e.address_start <= 0x10ff and e.address_end >= 0x1000 then
    print(string.format("  %04X-%04X mirror %04X  read: %s", e.address_start, e.address_end, e.address_mirror,
      tostring(e.read.handlertype)))
  end
end

local function field(name)
  for _, p in pairs(manager.machine.ioport.ports) do
    for n, f in pairs(p.fields) do if n == name then return f end end
  end
end
local coin, start = field("Coin 1"), field("1 Player Start")

local reads, pairs_run, differed, values, first = 0, 0, 0, {}, nil
tap = mem:install_read_tap(0x100a, 0x100a, "probe", function(offset, data, mask)
  local pc = cpu.state["PC"].value
  if pc >= 0x289c and pc <= 0x28a8 then          -- the two reads at the check, in any revision or bootleg
    reads = reads + 1
    values[string.format("%02X", data)] = true
    if reads % 2 == 1 then
      first = data
    else
      pairs_run = pairs_run + 1
      if data ~= first then differed = differed + 1 end
      print(string.format("  check run %d (%s): $100A read %02X then %02X, adds %d", pairs_run,
        pairs_run == 1 and "power-up" or "game start", first, data, first ~ data))
    end
  end
  return data
end)

local frame, last = 0, -1
notifier = emu.add_machine_frame_notifier(function()
  frame = frame + 1
  local t = frame % 600
  if coin then coin:set_value((t >= 100 and t < 106 and (frame // 600) % 3 == 0) and 1 or 0) end
  if start then start:set_value((t >= 500 and t < 506) and 1 or 0) end
  local c = mem:read_u8(0xc8)
  if frame > 3 and c ~= last then print(string.format("%6d frames  credits %d", frame, c)) end
  last = c
end)

stopper = emu.add_machine_stop_notifier(function()
  local seen = {}
  for v in pairs(values) do seen[#seen + 1] = v end
  table.sort(seen)
  print(string.format("Summary: %d check runs (power-up + %d game starts), values read: %s, pairs that differed: %d",
    pairs_run, math.max(pairs_run - 1, 0), #seen > 0 and table.concat(seen, " ") or "none", differed))
end)
