-- popeye_lives.lua: Popeye's high-score ROM sum, for nintendo/demo_popeye.sh.
-- Both sides: coin at frame 600, 1P start at 640, a scripted player (fixed seed) from frame 661; the player 1 score's
-- top byte 0x8FEB is poked to 05 at frame 1400 (a top-five score), so the game over leads to a name entry, which
-- times out naturally; the sum at 0x142F then runs (about frame 5891). A second coin and start (6400, 6440) begin the
-- next game, whose lives come from the lives setting 0x8FF0.
-- POP_EDIT=1: at frame 30 one unused ROM byte, 0x76F0 (FF fill), is changed to FE in MAME's decrypted copy of the
-- program ROM (the ROM files are encrypted; no file is changed). The 32 KB sum is then FF instead of 00, and the game
-- replaces the lives setting with a random 1 to 4 (LD A,R / AND 03 / INC A at 0x143D).
-- Logs: the bytes at 0x76E8 as the CPU reads them (before and after the edit), the poke, every write to 0x8FF0
-- (lives setting) and 0x8800 (lives in play), and "SNAP nnnn seq fF" every 4 frames from POP_SEQ_A to POP_SEQ_B.
local m = manager.machine
local cpu = m.devices[":maincpu"]
local mem = cpu.spaces["program"]
local logf = io.open(os.getenv("POP_LOG"), "w")
local frame = 0
local function hx(a, n) local t = {} for i = 0, n - 1 do t[#t+1] = string.format("%02X", mem:read_u8(a + i)) end return table.concat(t, " ") end
logf:write(string.format("%s: ROM 76E8: %s\n", emu.romname(), hx(0x76E8, 16)))
local EDIT = os.getenv("POP_EDIT") == "1"
local A, B = tonumber(os.getenv("POP_SEQ_A") or "6960"), tonumber(os.getenv("POP_SEQ_B") or "7500")
local F = {}
for _, p in pairs(m.ioport.ports) do for n, f in pairs(p.fields) do F[n] = f end end
local function press(name, v) F[name]:set_value(v) end
w1 = mem:install_write_tap(0x8FF0, 0x8FF0, "w8ff0", function(off, data, mask)
  logf:write(string.format("W 8FF0 (lives setting) f=%d pc=%04X %02X -> %02X\n", frame, cpu.state["CURPC"].value, mem:read_u8(off), data & 0xFF)) end)
w2 = mem:install_write_tap(0x8800, 0x8800, "w8800", function(off, data, mask)
  local old, new = mem:read_u8(off), data & 0xFF
  if old & 0x7F ~= new & 0x7F then
    logf:write(string.format("W 8800 (lives) f=%d pc=%04X %02X -> %02X\n", frame, cpu.state["CURPC"].value, old, new)) end end)
local rng, nsnap = 4321, 0
local rgn = m.memory.regions[":maincpu"]
fn = emu.add_machine_frame_notifier(function()
  frame = frame + 1
  if EDIT and frame == 30 then
    local old = mem:read_u8(0x76F0); rgn:write_u8(0x76F0, 0xFE)
    logf:write(string.format("EDIT f=30 76F0 %02X -> FE (CPU now reads %02X)\n", old, mem:read_u8(0x76F0)))
  end
  for _, c in ipairs({600, 6400}) do
    if frame == c then press("Coin 1", 1) elseif frame == c + 5 then press("Coin 1", 0) end
  end
  if frame == 640 or frame == 6440 then press("1 Player Start", 1) elseif frame == 645 or frame == 6445 then press("1 Player Start", 0) end
  if frame > 660 and frame % 15 == 0 then
    rng = (rng * 1103515245 + 12345) % 2147483648; local r = (rng // 65536) % 6
    press("P1 Left", r == 0 and 1 or 0); press("P1 Right", r == 1 and 1 or 0)
    press("P1 Up", r == 2 and 1 or 0); press("P1 Down", r == 3 and 1 or 0); press("P1 Button 1", r == 4 and 1 or 0)
  end
  if frame == 1400 then
    local old = mem:read_u8(0x8FEB); mem:write_u8(0x8FEB, 0x05)
    logf:write(string.format("POKE f=1400 8FEB (score, top byte) %02X -> 05\n", old))
  end
  if frame >= A and frame <= B and (frame - A) % 4 == 0 then
    logf:write(string.format("SNAP %04d seq f%d\n", nsnap, frame)); nsnap = nsnap + 1; m.video:snapshot()
  end
end)
sn = emu.add_machine_stop_notifier(function() logf:write(string.format("END frames=%d\n", frame)); logf:close() end)
