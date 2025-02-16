--[[
Copyright 2025 Figura Goofballs

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

local lib = {}

local function copy(tbl)
   local new = {}

   for key, value in pairs(tbl) do
      if type(value) == "table" then
         new[key] = copy(value)
      else
         new[key] = value
      end
   end

   return new
end

local eightColorMap = {"black", "red", "green", "yellow", "blue", "light_purple", "aqua", "white"}

local ansi24BitColor = "\x1b[38;2;%i;%i;%im"
local ansi256Color = "\x1b[38;5;%im"
local ansi = {
   b = {
      variable = "bold";
      escape = "\x1b[1m";
      unescape = "\x1b[22m";
   },
   i = {
      variable = "italic";
      escape = "\x1b[3m";
      unescape = "\x1b[23m";
   },
   u = {
      variable = "underline";
      escape = "\x1b[4m";
      unescape = "\x1b[24m";
   },
   s = {
      variable = "strikethrough";
      escape = "\x1b[9m";
      unescape = "\x1b[29m";
   }
}

function lib.toAnsi(str)
   local layers = {
      {
         bold = false;
         italic = false;
         underline = false;
         strikethrough = false;
         color = {false, ""};
      }
   }
   local formatLayers = {
      bold = false;
      italic = false;
      underline = false;
      strikethrough = false;
      color = {false, ""}
   }
   local final = ""

   local iter = 0
   local checking = false
   local color = false
   local layer = 2
   while iter <= #str do
      iter = iter + 1
      local char = str:sub(iter, iter)

      if color then
         local hex = str:sub(iter, iter + 6):match("%x%x%x%x%x%x")
         local int = str:sub(iter, iter + 3):match("%d%d?%d?")

         if hex then
            local rgb = tonumber("0x" .. hex)
            local r = bit32.rshift(bit32.band(rgb, 0xff0000), 16)
            local g = bit32.rshift(bit32.band(rgb, 0xff00), 8)
            local b = bit32.band(rgb, 0xff)

            final = final .. ansi24BitColor:format(r, g, b)
            formatLayers.color = {true, ansi24BitColor:format(r, g, b)}
            iter = iter + 5
         elseif int then
            if tonumber(int) <= 7 then
               final = final .. "\x1b[" .. (int + 30) .. "m"
               formatLayers.color = {true, "\x1b[" .. (int + 30) .. "m"}
            else
               final = final .. ansi256Color:format(int)
               formatLayers.color = {true, ansi256Color:format(int)}
            end
            iter = iter + (#int - 1)
         end
         color = false
      elseif checking then
         if char == "[" then
            layers[layer] = {
               bold = formatLayers.bold;
               italic = formatLayers.italic;
               underline = formatLayers.underline;
               strikethrough = formatLayers.strikethrough;
               color = formatLayers.color;
            }

            layer = layer + 1
            checking = false
            goto continue
         elseif char == "]" then
            final = final .. "]"
            checking = false
            goto continue
         elseif char == "$" then
            final = final .. "$"
            checking = false
            goto continue
         end

         if ansi[char] then
            final = final .. ansi[char].escape
            formatLayers[ansi[char].variable] = true
         elseif char == "c" then
            color = true
         end
      else
         if char == "]" then
            if layer == 1 then
               final = final .. "]"
            end

            layer = layer - 1
            final = final .. "\x1b[0m"
            for _, v in pairs(ansi) do
               if layers[layer - 1][v.variable] then
                  final = final .. v.escape
               end
            end
            if layers[layer - 1].color[1] then
               final = final .. layers[layer].color[2]
            end
            formatLayers = copy(layers[layer - 1])
            layers[layer] = nil

            goto continue
         elseif char == "$" then
            checking = true
            goto continue
         end

         final = final .. char
      end

      ::continue::
   end

   return final
end

function lib.toMinecraft(str)
   local layers = {
      {
         bold = false;
         italic = false;
         underline = false;
         strikethrough = false;
         color = "white";
      }
   }
   local compose = {
      bold = false;
      italic = false;
      underline = false;
      strikethrough = false;
      color = "white",
      text = ""
   }
   local newCompose = copy(compose)
   local final = {}

   local iter = 0
   local checking = false
   local color = false
   local layer = 2
   while iter <= #str do
      iter = iter + 1
      local char = str:sub(iter, iter)

      if color then
         local hex = str:sub(iter, iter + 6):match("%x%x%x%x%x%x")
         local int = str:sub(iter, iter + 3):match("%d%d?%d?")

         if hex then
            newCompose.color = "#" .. hex
            iter = iter + 5
         elseif int then
            if tonumber(int) <= 7 then
               newCompose.color = eightColorMap[tonumber(int) + 1]
            else
               error("256 color not supported for Minecraft")
            end
            iter = iter + (#int - 1)
         end
         color = false
      elseif checking then
         if char == "[" then
            layers[layer] = {
               bold = newCompose.bold;
               italic = newCompose.italic;
               underline = newCompose.underline;
               strikethrough = newCompose.strikethrough;
               color = newCompose.color;
               text = ""
            }
            final[#final + 1] = compose
            compose = layers[layer]

            layer = layer + 1
            checking = false
            goto continue
         elseif char == "]" then
            compose.text = compose.text .. "]"
            checking = false
            goto continue
         elseif char == "$" then
            compose.text = compose.text .. "$"
            checking = false
            goto continue
         end

         if ansi[char] then
            newCompose[ansi[char].variable] = true
         elseif char == "c" then
            color = true
         end
      else
         if char == "]" then
            if layer == 1 then
               compose.text = compose.text .. "]"
            end

            layer = layer - 1
            final[#final + 1] = compose
            compose = copy(layers[layer - 1])
            layers[layer] = nil

            goto continue
         elseif char == "$" then
            checking = true
            goto continue
         end

         compose.text = (compose.text or "") .. char
      end

      ::continue::
   end

   final[#final + 1] = compose

   return final
end

return lib

