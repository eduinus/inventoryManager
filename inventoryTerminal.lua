local component = require("component")
local modem = component.modem
local transposer = component.transposer
local event = require("event")
local term = require("term")
local sides = require("sides")
local serialization = require("serialization")
local keyboard = require("keyboard")

-- BEGIN CONFIG
local transceiver = sides.front
local outgoingChest = sides.left
local incomingChest = sides.right

-- PORT:
inventoryTerminalPort = 54978

-- END CONFIG

modem.open(inventoryTerminalPort)

function tableLength(table)
  count = 0
  while table[count + 1] ~= nil do
    count=count+1
  end
  return count
end

while true do -- MAIN LOOP
  local id, arg1, arg2, arg3, arg4, arg5 = event.pullMultiple(10, "interrupted", "key_down")
  -- for key_down: id, keyboardAddress, char, code, playerName
  -- for interrupted: id, ...
  print("EVENT PULLED:")

  if id == "interrupted" then -- this means you pressed ctrl + c
    print("-> soft interrupt, closing")
    break

  elseif (id == "key_down") and (arg3 == keyboard.keys.enter) then -- do an item query or request
    print("-> item query:")
    loop = true
    while loop do
      print("-> Enter Item name:")
      local userInput = io.read()
      payLoadArray = {}
      payLoadArray[1] = "genSearch"
      payLoadArray[2] = userInput
      payLoad = serialization.serialize(payLoadArray)
      modem.broadcast(inventoryTerminalPort, payLoad)
      print("-> Query Sent. Listenting for response...")
      local id, arg1, arg2, arg3, arg4, arg5 = event.pullMultiple(10, "modem_message")
      -- for modem_message: id, localNetworkCard, remoteAddress, port, distance, payload
      if id == "modem_message" then
        local resultsTable = serialization.unserialize(arg5)
      else
        print("-> No response!")
        loop = false
        break
      end
      if tableLength(resultsTable) == 0 then
        print("No results.")
      else -- searchResults are >= 1, so we're printing the results

        print("damage---------maxDamage------size-----------maxSize--------id-------------name-----------label----------hasTag---------location-------quantity-------")
        for i=1, tableLength(resultsTable) do -- item attributes
          for o=1, 8 do
            print(string.sub(resultsTable[i][o], 1, 15)) -- print item attribute
            if string.len(resultsTable[i][o]) < 15 then -- print spaces between attributes
              for e=1, (15 - string.len(resultsTable[i][o])) do io.write(" ") end
            end
          end
          print(resultsTable[i][-1]) -- item location
          if string.len(resultsTable[i][-1]) < 15 then -- print spaces between attributes
            for e=1, (15 - string.len(resultsTable[i][-1])) do io.write(" ") end
          end
          print(resultsTable[i].size) -- item quantity -- is this duplicative of third column?
          if string.len(resultsTable[i].size) < 15 then -- print spaces between attributes
            for e=1, (15 - string.len(resultsTable[i].size)) do io.write(" ") end
          end
        end

        print("Request (enter location #) / Search Again (s) / Exit (e)") -- next move?
        local itemLocation = io.read()
        if itemLocation == "E" or itemLocation == "e" then
          loop = false
          print("-> Exiting")
          break
        elseif itemLocation ~= "S" and itemLocation ~= "s" then
          print("Quantity?")
          local itemQuantity = io.read()
          payLoadArray = {}
          payLoadArray[1] = "specRequest"
          payLoadArray[-1] = itemLocation
          payLoadArray[10] = itemQuantity
          payLoad = serialization.serialize(payLoadArray)

          modem.broadcast(inventoryTerminalPort, payLoad)
          print("-> Item request Sent. Listenting for response...")
          local id, arg1, arg2, arg3, arg4, arg5 = event.pullMultiple(10, "modem_message")
          -- for modem_message: id, localNetworkCard, remoteAddress, port, distance, payload
          if id == "modem_message" and arg5 == "done" then
            transposer.transferItem(transceiver, incomingChest, itemQuantity, 9)
            print("--> Item received.")
          else
            print("--> No response!")
            loop = false
            break
          end
          loop = false
          break
        end
      end
    end

  elseif (id == "key_down") and (arg3 == keyboard.keys.q) then -- this means we are closing
    print("-> closing program")
    sleep(0.5)
    break
  end

  for i=1, transposer.getInventorySize(outgoingChest) do -- now send out stuff in the outgoingChest
    if transposer.getStackInSlot(outgoingChest, i) ~= nil then
      transposer.transferItem(outgoingChest, transceiver, 999, i)
      print("-> sent out items from outgoingChest")
    else
      break
    end
  end

-- note escape, enter, ctrl + c options

end
