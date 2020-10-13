local component = require("component")
local modem = component.modem
local transposer = component.transposer
local event = require("event")
local term = require("term")
local sides = require("sides")
local serialization = require("serialization")
local keyboard = require("keyboard")

-- BEGIN CONFIG
local storageSide = sides.right
local transceiver = sides.front

-- PORTS: (max port is 65535)
inventoryTerminalPort = 54978
inventoryRelayOne = 54979

-- END CONFIG

modem.open(inventoryTerminalPort)
modem.open(inventoryRelayOne)

function tableLength(table) -- this presumes table index begins at 1
  count = 0
  while table[count + 1] ~= nil do
    count = count + 1
  end
  return count
end

function genSearch(searchTerm)
  -- searches for an item based on generic searchTerm
  -- returns a table of matching items with their location, and all of their information per ocdoc.cil.li/component:inventory_controller
  local searchResults = {}
  local count = 0
  for i = 1, transposer.getInventorySize(storageSide) do
    local item = transposer.getStackInSlot(storageSide, i)
    if item then
      if string.find(item.name .. "^" .. item.label .. "^" .. item.id .. "^", searchTerm) then -- n.b. string.lower(myString) fix for later
        count = count + 1
        searchResults[count] = item -- add item to searchResults table
        searchResults[count][-1] = i -- add location of item to -1th column in table
      end
    end
  end
  return searchResults
end

function specSearch(damage, maxDamage, size, maxSize, id, name, label, hasTag)
  -- searches for an item based on provided categories
  -- returns a table of matching items with their location, and all of their information per ocdoc.cil.li/component:inventory_controller
  if damage == nil and maxDamage == nil and size == nil and maxSize == nil and id == nil and name == nil and label == nil and hasTag == nil then
    return false
  end
  local searchResults = {}
  local count = 0
  for i = 1, transposer.getInventorySize(storageSide) do
    local item = transposer.getStackInSlot(storageSide, i)
    if item then
      if  (damage == nil or string.find(item.damage, damage)) and  -- n.b. string.lower(myString) fix for later
          (maxDamage == nil or string.find(item.maxDamage, maxDamage)) and  -- n.b. string.lower(myString) fix for later
          (size == nil or string.find(item.size, size)) and  -- n.b. string.lower(myString) fix for later
          (maxSize == nil or string.find(item.maxSize, maxSize)) and  -- n.b. string.lower(myString) fix for later
          (id == nil or string.find(item.id, id)) and  -- n.b. string.lower(myString) fix for later
          (name == nil or string.find(item.name, name)) and  -- n.b. string.lower(myString) fix for later
          (label == nil or string.find(item.label, label)) and  -- n.b. string.lower(myString) fix for later
          (hasTag == nil or string.find(item.hasTag, hasTag)) then  -- n.b. string.lower(myString) fix for later
        count = count + 1
        searchResults[count] = item -- add item to searchResults table
        searchResults[count][-1] = i -- add location of item to -1th column in table
      end
    end
  end
  return searchResults
end

while true do -- MAIN LOOP
  local id, arg1, arg2, arg3, arg4, arg5 = event.pullMultiple(10, "interrupted", "modem_message", "key_down")
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

    -- GENERAL SEARCH

    if payLoad[1] == "genSearch" then -- serve remote item search requests
      modem.send(remoteAddress, port, serialization.serialize(genSearch(payLoad[2])))
      print("--> genSearch served")

    -- SPECIFIC SEARCH

    elseif payLoad[1] == "specSearch" then -- serve remote specific item search requests
      modem.send(remoteAddress, port, serialization.serialize(specSearch(payLoad[2], payLoad[3], payLoad[4], payLoad[5], payLoad[6], payLoad[7], payLoad[8], payLoad[9])))
      print("--> specSearch served")

    -- ITEM REQUEST

    elseif payLoad[1] == "request" then -- serve remote item requests, but hold program until items taken for X time, if not taken, put back in storage.
      print("--> serving item request")
      requestedItem = specSearch(payLoad[2], payLoad[3], payLoad[4], payLoad[5], payLoad[6], payLoad[7], payLoad[8], payLoad[9])
      if tableLength(requestedItem) == 1 then
        transposer.transferItem(storageSide, transceiver, payLoad[10], requestedItem[1][-1], 1) -- payLoad[10] is quantity requested, requestedItem[1][-1] is storage location.
        modem.send(remoteAddress, port, "done")
        print("---> sent requested item")
        for i=1, 10 do
          if transposer.getStackInSlot(transceiver, 1) ~= nil then
            os.sleep(1)
          else
            break
          end
        end
        if transposer.getStackInSlot(transceiver, 1) ~= nil then
          transposer.transferItem(transceiver, storageSide, payLoad[10], 1, requestedItem[1][-1]) -- payLoad[10] is quantity requested, requestedItem[1][-1] is storage location.
          print("---> requested item not accepted")
        end
      elseif tableLength(requestedItem) > 1 then
        modem.send(remoteAddress, port, "moreThanOneSuchItem")
        print("---> more than one item matches request")
      elseif tableLength(requestedItem) < 1 then
        modem.send(remoteAddress, port, "noSuchItem")
        print("---> no item matches request")
      end

    -- SPECIFIC ITEM REQUEST

    elseif payLoad[1] == "specRequest" then -- requests where robot or terminal already knows the location of the item it wants
      print("--> serving specific item request")
      transposer.transferItem(storageSide, transceiver, payLoad[10], payLoad[-1], 1) -- payLoad[10] is quantity requested, requestedItem[-1] is storage location.
      modem.send(remoteAddress, port, "done")
      print("---> sent requested item")
      for i=1, 10 do
        if transposer.getStackInSlot(transceiver, 1) ~= nil then
          os.sleep(1)
        else
          break
        end
      end
      if transposer.getStackInSlot(transceiver, 1) ~= nil then
        transposer.transferItem(transceiver, storageSide, payLoad[10], 1, payLoad[-1]) -- payLoad[10] is quantity requested, requestedItem[-1] is storage location.
        print("---> requested item not accepted")
      end
    end

  elseif (id == "key_down") and (arg3 == keyboard.keys.q) then -- this means we are closing
    print("-> closing program")
    os.sleep(0.5)
    break
  end

  for i=9, transposer.getInventorySize(transceiver) do -- now store any trash items in the transceiver
    if transposer.getStackInSlot(transceiver, i) ~= nil then
      transposer.transferItem(transceiver, storageSide, 999, i)
      print("-> stored items from transceiver")
    else
      break
    end
  end

  -- re-render item inventory graphically if there was a succesful item request or item storage
  -- note recent inventory changes

end
