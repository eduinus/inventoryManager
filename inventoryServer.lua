--[[local component = require("component")
local event = require("event")
local modem = component.modem

To do:
-record Inventory storage system
-serve questions to viewing pc
-give commands to put drone, pull drone
-helpful graphics? / data?
  
while true do
  if storage has changed, render screen differently
  tell pusher to check if needs to charge.
      tell pusher to check if anything is in the chest
        if so, store the item (such up as much of it as you can, fill 2 if necessary)
  check if message from inventory PC
        if so, give orders to pull drone or serve array info
end
]]--

while true do
x = event.pull(1, "key_down")
print(x)
end
