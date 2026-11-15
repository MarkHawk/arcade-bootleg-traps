-- demo_check1.lua: check 1, ROM byte $C418 in the high jump mole bonus ($E376).
-- Trigger: the mole bonus (each of its 4 animation steps runs the compare; a mismatch sets $2A8E).
-- The failure acts at the player's next failed third attempt (state 4, E3AD: JMP $D000).
-- Demo, 1-player game starting at the high jump, no run-up input (every jump fails):
--   1. on the third try at the opening height, put the game in the state the mole needs (what
--      an earlier third-try clear at 2.15 m leaves: $29D3 = 1; bar at 2.35 m)
--      and switch the attempt to "cleared": the mole runs and pays 1,000;
--   2. the event ends, and the next event is set to the high jump again ($2884 := 5 at 759E), as
--      if a later round had come round to it; with no input the player fails three times.
-- Edited set: $C418 B1 -> B4. Run from the repo root: konami/demo.sh 1 ROM_FOLDER.
local D = dofile("konami/lib_demo.lua")
local tf = D.tf
D.setup(1, 0xE376, 0xE380, 0xE37D, 0xE3B2)
D.show_rom({0xC418})
tf.force_event(5)
tf.start_1p(120)
local first, runup, redirected = true, 0, false
tf.every_frame(function()
  if tf.r8(0x2800) == 3 and tf.r8(0x2803) == 2 and tf.r8(0x2806) == 1 then runup = runup + 1 else runup = 0 end
  if first and runup == 30 and tf.r8(0x289F) == 2 then
    first = false
    tf.w8(0x29D3, 1)
    tf.w8(0x286A, 0x00); tf.w8(0x286B, 0x02); tf.w8(0x286C, 0x03); tf.w8(0x286D, 0x05)
    tf.w8(0x2806, 3); tf.w8(0x2809, 0)
    tf.log("third try: $29D3 := 1, bar := 2.35 m, attempt switched to cleared (mole bonus)", true)
  end
end)
tf.bp(0xE399, function()
  tf.log(string.format("mole bonus paid (E399), check flag $2A8E = %02X", tf.r8(0x2A8E)), true)
  D.after("mole bonus", 20)
end)
tf.bp(0x759E, function()
  if not first and not redirected then
    redirected = true
    tf.log(string.format("next event %d -> 5 (high jump again)", tf.r8(0x2884)), true)
    tf.w8(0x2884, 5)
  end
end)
-- state 4 (failed attempt): log each one in the second high jump (the first 4 times)
local fails = 0
tf.bp(0xE3A7, function()
  if redirected and fails < 4 then
    fails = fails + 1
    tf.log(string.format("failed attempt, index %d, $2A8E = %02X", tf.r8(0x289F), tf.r8(0x2A8E)), true)
    if tf.r8(0x289F) == 2 then D.snap("third failed attempt") end
  end
end)
D.at_frames({3440, 3470, 6520, 6600, 7200, 8990})
D.finish_at(tonumber(os.getenv("TF_FRAMES") or "9000"))
