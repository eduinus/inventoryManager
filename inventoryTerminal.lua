local component = require("component")
local modem = component.modem
local event = require("event")
local term = require("term")
local sides = require("sides")
local serialization = require("serialization")
local keyboard = require("keyboard")

-- BEGIN CONFIG
local localChest = sides.up
local remoteChest = sides.front
local bufferChest = sides.back

while true do -- MAIN LOOP
  local id, arg1, arg2, arg3, arg4, arg5 = event.pullMultiple("interrupted", "modem_message", "key_down")
  -- for modem_message: id, localNetworkCard, remoteAddress, port, distance, payload
  -- for key_down: id, keyboardAddress, char, code, playerName
  -- for interrupted: id, ...
  print("EVENT PULLED:")

  if id == "interrupted" then -- this means you pressed ctrl + c
    print("-> soft interrupt, closing")
    break

  elseif id == "modem_message" then -- this means we have some sort of remote query
    print("-> modem message")
    remoteAddress = arg2
    port = arg3
    payLoad = serialization.unserialize(arg5)
    if payLoad[1] == "genSearch" then -- serve remote item search requests
      modem.send(remoteAddress, port, serialization.serialize(genSearch(payLoad[2])))
      print("--> genSearch served")
    elseif payLoad[1] == "specSearch" then -- serve remote specific item search requests
      modem.send(remoteAddress, port, serialization.serialize(specSearch(payLoad[2], payLoad[3], payLoad[4], payLoad[5], payLoad[6], payLoad[7], payLoad[8], payLoad[9])))
      print("--> specSearch served")
    elseif payLoad[1] == "request" then -- serve remote item requests, but hold program until items taken for X time, if not taken, put back in storage.
      print("--> serving request")
      requestedItem = specSearch(payLoad[2], payLoad[3], payLoad[4], payLoad[5], payLoad[6], payLoad[7], payLoad[8], payLoad[9])
      if tableLength(requestedItem) == 1 then
        transposer.transferItem(storageSide, remoteChest, payLoad[10], requestedItem[1][-1], 1)
        print("---> sent requested item")
        for i=1, 10 do
          if transposer.getStackInSlot(remoteChest, 1) ~= nil then
            os.sleep(1)
          end
        end
        if transposer.getStackInSlot(remoteChest, 1) ~= nil then
          modem.send(remoteAddress, port, "noGrab")
          transposer.transferItem(remoteChest, storageSide, payLoad[10], 1, requestedItem[1][-1])
          print("---> requested item not accepted")
        end
        modem.send(remoteAddress, port, "done")
      elseif tableLength(requestedItem) > 1 then
        modem.send(remoteAddress, port, "moreThanOneSuchItem")
        print("---> more than one item matches request")
      elseif tableLength(requestedItem) < 1 then
        modem.send(remoteAddress, port, "noSuchItem")
        print("---> no item matches request")
      end
    end

  elseif (id == "key_down") and (arg3 == keyboard.keys.enter) then -- this means we have some sort of local query
    print("-> local query / request")
    loop = true
    while loop do
      print("Enter Item name:")
      local userInput = io.read()
      local resultsTable = genSearch(userInput)
      if tableLength(resultsTable) == 0 then
        print("No results.")
      else
        print("damage---------maxDamage------size-----------maxSize--------id-------------name-----------label----------hasTag---------location-------quantity-------")
        for i=1, tableLength(resultsTable) do
          for o=1, 8 do
            print(resultsTable[i][o])
            for e=1, (15 - string.len(resultsTable[i][o])) do io.write(" ") end
          end
          print(resultsTable[i][-1])
          for e=1, (15 - string.len(resultsTable[i][-1])) do io.write(" ") end
          print(resultsTable[i].size)
          for e=1, (15 - string.len(resultsTable[i].size)) do io.write(" ") end
        end
        print("Request? (enter location #) or Search Again? (S)")
        local itemLocation = io.read()
        if itemLocation ~= "S" and itemLocation ~= "s" then
          print("Quantity?")
          local itemQuantity = io.read()
          transposer.transferItem(storageSide, localChest, itemQuantity, itemLocation, 1)
          loop = false
        end
      end
    end

  elseif (id == "key_down") and (arg3 == keyboard.keys.escape) then -- this means we are closing
    print("-> closing program")
    sleep(0.5)
    break
  end

  for i=1, transposer.getInventorySize(bufferChest) do -- now store any items in buffer chest
    if transposer.getStackInSlot(bufferChest, i) ~= nil then
      transposer.transferItem(bufferChest, storageSide, 999, i)
      print("-> stored items from bufferChest")
    else
      break
    end
  end

  -- render item inventory graphically when not in use if you stored items from buffer chest OR if items were removed from buffer chest
  -- note recent inventory changes

end
