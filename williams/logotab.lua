-- logotab.lua: decode Defender's WILLIAMS handwriting table (LGOTAB) from the ROMs MAME loaded, for
-- williams/demo_logotab.sh. Env LOGOTAB_AT: the table's CPU address in bank 1 (hex; $C941 in the Red label).
-- Stroke format (Williams' source, amode1.src, LOGO1-LOGO10): a byte up to $AA is data, two 4-bit moves (bit 7 x-1,
-- bit 6 x+1, bit 5 y-1, bit 4 y+1, then the low nibble the same way), one pixel per step (the second only if the low
-- nibble is non-zero); $FF null; $FE x y = HYPER (move the cursor there and draw a pixel); anything else above $AA
-- quits. CUREND = ((x >> 1) << 8) | y at the quit is what the logo check stores into WCURS.
-- Prints the table's length, HYPER count, pixel count, last 10 bytes, end cursor and CUREND, then "PX x y" per pixel.
local m = manager.machine
local rg = m.memory.regions[":banked"]
local at = tonumber(os.getenv("LOGOTAB_AT") or "C941", 16)
local base = at - 0xC000          -- bank 1 is the first 4 KB of the banked region
local x, y, i, hy, px = 0, 0, 0, 0, {}
while i < 1024 do
  local a = rg:read_u8(base + i); i = i + 1
  if a <= 0xAA then
    repeat
      if a & 0x80 ~= 0 then x = x - 1 end
      if a & 0x40 ~= 0 then x = x + 1 end
      if a & 0x20 ~= 0 then y = y - 1 end
      if a & 0x10 ~= 0 then y = y + 1 end
      a = (a << 4) & 0xFF
      px[#px + 1] = { x & 0xFF, y & 0xFF }
    until a == 0
  elseif a == 0xFE then
    x, y = rg:read_u8(base + i), rg:read_u8(base + i + 1); i = i + 2; hy = hy + 1; px[#px + 1] = { x, y }
  elseif a ~= 0xFF then break end
end
local last = {}
for k = i - 10, i - 1 do last[#last + 1] = string.format("%02X", rg:read_u8(base + k)) end
x, y = x & 0xFF, y & 0xFF
print(string.format("[lua] LGOTAB $%04X: %d bytes, %d HYPERs, %d pixels, last 10 bytes %s, end x $%02X y $%02X, CUREND $%04X",
  at, i, hy, #px, table.concat(last, " "), x, y, ((x >> 1) << 8) | y))
for _, p in ipairs(px) do print(string.format("[lua] PX %d %d", p[1], p[2])) end
m:exit()
