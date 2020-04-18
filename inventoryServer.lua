local event = require("event")
local component = require("component")
local modem = component.modem
local transposer = component.transposer
local term = require("term")
local sides = require("sides")

-- CHANGE THESE BASED ON YOUR SETUP
local storageSide = sides.down
local localChest = sides.up
local remoteChest = sides.front
local bufferChest = sides.back
-- END CONFIG

function tableLength(table)
  count = 1
  while table[count] ~= nil do
    count=count+1
  end
  return count-1
end

function search(searchTerm)
-- searches for an item based on searchTerm
-- returns a table of items with their location, and all of their information per ocdoc.cil.li/component:inventory_controller
searchResults = {}
local count = 0
  for i = 1, (transposer.getInventorySize(storageside)) do
    local item = transposer.getStackInSlot(storageside, i)
    if item then
      if string.find(item.name .. "^" .. item.label .. "^" .. item.id .. "^", searchTerm) then
        count = count + 1
        searchResults[count] = item -- add item to searchResults table
        searchResults[count][-1] = i -- add location of item to -1th column in table
      end
    end
  end
  return searchResults
end

function retrieve(itemLocation, quantity, destination)
-- pulls items at itemLocation in quantity given
  
end

while true do
  local id, arg1, arg2, arg3, arg4, arg5 = event.pullMultiple("interrupted", "modem_message", "key_down")
  -- for modem_message: id, localNetworkCard, remoteAddress, port, distance, payload
  -- for key_down: id, keyboardAddress, char, code, playerName
  -- for interrupted: id, ...

  if id == "interrupted" then -- this means you pressed ctrl + c
    print("soft interrupt, closing")
    break

  elseif id == "modem_message" then -- this means we have some sort of remote query
    print("user clicked", x, y)
    -- serve remote items search requests
    -- serve remote item requests, but hold program until items taken for X time.

  elseif id == "key_down" then -- this means we have some sort of local query
    -- serve local item search requests
    -- serve local item requests
  end

  -- now store any items in buffer chest
  -- render item inventory graphically when not in use if you stored items from buffer chest OR if items were removed from buffer chest
  -- note recent inventory changes
end
