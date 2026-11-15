-- demo_check2.lua: check 2, the "KONAMI" text and code-byte check in the interrupt handler ($6753).
-- Trigger: the games-started counter $2FE4 reaching exactly 1,500 arms it for good (signature
-- $2FE7/$2FEE/$2FEF := 19 65 DB at F9A6). Demo: set $2FE4 = 1,499, start one game; false starts end
-- it quickly; the check then runs in the attract-mode interrupt handler.
-- Edited set: "KONAMI" -> "KNNAMI" ($A6BD). Run from the repo root: konami/demo.sh 2 ROM_FOLDER.
local D = dofile("konami/lib_demo.lua")
local tf = D.tf
D.setup(2, 0x6753, 0x67AB, 0x67A8)
D.show_rom({0xA6BC, 0xA6BD, 0xA6BE, 0xA6BF, 0xA6C0, 0xA6C1})
tf.every_frame(function()
  if tf.frame == 200 then
    D.w16(0x2FE4, 1499)
    tf.log(string.format("set games-started counter $2FE4 = %d (signature %02X %02X %02X)", D.c16(0x2FE4),
      tf.r8(0x2FE7), tf.r8(0x2FEE), tf.r8(0x2FEF)), true)
  end
end)
tf.start_1p(300)
local armed = false
tf.bp(0xF9A6, function()
  if armed then return end
  armed = true
  D.snap("armed")
  tf.log(string.format("ARMED: $2FE4 = %d, signature 19 65 DB written at F9A6", D.c16(0x2FE4)), true)
end)
-- false starts: hold the run button in the ready phase of each race
tf.every_frame(function()
  tf.set_input(":IN0", "P1 Button 1", tf.r8(0x2800) == 3 and tf.r8(0x2806) == 0 and (tf.frame % 8) < 4)
end)
D.at_frames({900, 3690, 3720, 3800, 4400, 5390})
D.finish_at(tonumber(os.getenv("TF_FRAMES") or "5400"))
