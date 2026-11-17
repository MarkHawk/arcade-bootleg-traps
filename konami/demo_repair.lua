-- demo_repair.lua: the "For repairers" runs in docs/konami-track-and-field.md, on check 2 ("KONAMI" -> "KNNAMI").
-- Run by konami/demo_repair.sh, which carries the battery-backed RAM between runs where the table says so.
-- Environment (any combination):
--   TF_ARM=1    at frame 200 set the games-started counter $2FE4 to 1,499 and start one game (false starts end it
--               quickly), so the 1,500th game arms check 2 for good, as konami/demo_check2.lua does
--   TF_PLAY=f   insert a coin and press 1P start at frame f (an ordinary game; no RAM writes)
--   TF_ERASE=1  DIP "World Records" = "Erase on Reset" (a DIP switch, not a RAM write)
--   TF_FRAMES   run length (default 1200)
-- Logs the ROM bytes under test, the arming state at frame 100, and each run, pass or failure of check 2, and the
-- board resets after a failure (konami/lib_demo.lua). Log: konami/out/demo_check2_TF_SIDE.log.
local D = dofile("konami/lib_demo.lua")
local tf = D.tf
D.setup(2, 0x6753, 0x67AB, 0x67A8)
D.show_rom({0xA6BC, 0xA6BD, 0xA6BE, 0xA6BF, 0xA6C0, 0xA6C1})
if os.getenv("TF_ERASE") == "1" then
  manager.machine.ioport.ports[":DSW2"].fields["World Records"].user_value = 0
  tf.log("DIP World Records = Erase on Reset", true)
end
tf.every_frame(function()
  if tf.frame == 100 then
    tf.log(string.format("at f100: counter $2FE4 = %d, arming signature $2FE7/$2FEE/$2FEF = %02X %02X %02X%s",
      D.c16(0x2FE4), tf.r8(0x2FE7), tf.r8(0x2FEE), tf.r8(0x2FEF),
      (tf.r8(0x2FE7) == 0x19 and tf.r8(0x2FEE) == 0x65 and tf.r8(0x2FEF) == 0xDB) and " (armed)" or " (not armed)"), true)
  end
  if os.getenv("TF_ARM") == "1" and tf.frame == 200 then
    D.w16(0x2FE4, 1499)
    tf.log("set games-started counter $2FE4 = 1499", true)
  end
end)
if os.getenv("TF_ARM") == "1" then
  tf.start_1p(300)
  tf.every_frame(function()
    tf.set_input(":IN0", "P1 Button 1", tf.r8(0x2800) == 3 and tf.r8(0x2806) == 0 and (tf.frame % 8) < 4)
  end)
end
local play = tonumber(os.getenv("TF_PLAY") or "0")
if play > 0 then tf.start_1p(play) end
D.finish_at(tonumber(os.getenv("TF_FRAMES") or "1200"))
