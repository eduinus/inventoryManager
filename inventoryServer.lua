local component = require("component")
local event = require("event")
local modem = component.modem
local term = require("term")
local serial = require("serialization")

function dr(port, cmd)
  modem.broadcast(port, "return "..cmd)
  return select(6, event.pull(5, "modem_message"))
end

pushPort = 2412
pullPort = 2413
modem.open(pushPort)
modem.open(pullPort)
modem.broadcast(pushPort, "drone=component.proxy(component.list('drone')())")
modem.broadcast(pullPort, "drone=component.proxy(component.list('drone')())")
modem.broadcast(pushPort, "ic=component.proxy(component.list('inventory_controller')())")
modem.broadcast(pullPort, "ic=component.proxy(component.list('inventory_controller')())")

modem.open(2411) -- inventory pull requests

function loadTable(location)
  --returns a table stored in a file.
  local tableFile = pcall(io.open(location))
  if tableFile == false then return {} end
  return serialization.unserialize(tableFile:read("*all"))
end

function saveTable(table, location)
  --saves a table to a file
  local tableFile = assert(io.open(location, "w"))
  tableFile:write(serialization.serialize(table))
  tableFile:close()
end

itemStorage = loadTable("inventoryArchive.txt")

function invNumToCoords(num)
  local col = math.ceil(num / 8)
  local row = math.ceil(col / 42)
  local rack = (num - 1) % 8
  
  if row % 2 ~= 0 then
    local z = -21 + (4 * ((row - 1)/2))
  else
    local z = -18 + (4 * ((row - 2)/2))
  end
  
  local x = -20 + ((col-1 % 42))
  
  local y =  -9 + rack
  
  return x, y, z
end

function rowFace(num)
  local col = math.ceil(num / 8)
  local row = math.ceil(col / 42)
  if row % 2 ~= 0 then
    return 3
  else
    return 2
  end
end

function cleanseArray(array)
  for i=1, table.getn(array) do
	if array[i][2] <1 then
	  array[i][2] = nil
	  array[i][1] = nil
	  array[i] = nil
	end
  end
end

function pushRelocate(port,itemName) -- starting from HQ, then return!
  if table.getn(itemStorage) == 7392 then
    dr(port, "setStatusText('Storage Full!')") -- why are we broadcasting this?
	return false
  else
    for i=1, table.getn(itemStorage)+1 do
      if (i == table.getn(itemStorage)+1) or (table.getn(itemStorage) == 0) then
        itemStorage[i] = {}
        itemStorage[i][1] = itemName
        itemStorage[i][2] = 0
      end
      if itemStorage[i][1] == itemName and itemStorage[i][2] < 262144 then
		  x,y,z = invNumToCoords(i)
		  if port == pullPort then x = x-1 z = z-1 end
		  dr(port, "drone.move(0,-2,0)")
		  dr(port, "drone.move("..x..",0,"..z..")")
		  dr(port, "drone.move(0,"..y..",0)")
		  spaceLeft = 262144-itemStorage[i][2]
		  invSpot=1
		  while invSpot <= 8 do
			dr(port, "drone.select("..invSpot..")")
			if spaceLeft >= dr(port, "ic.getStackInInternalSlot("..invSpot..").size") then
			  itemStorage[i][2] = itemStorage[i][2] + dr(port, "ic.getStackInInternalSlot("..invSpot..").size")
			  spaceLeft = spaceLeft - dr(port, "ic.getStackInInternalSlot("..invSpot..").size")
			  dr(port, "drone.drop("..rowFace(i)..", ic.getStackInInternalSlot("..invSpot..").size)")
			  invSpot = invSpot + 1
			else
			  itemStorage[i][2] = itemStorage[i][2] + spaceLeft
			  dr(port, "drone.drop("..rowFace(i)..", "..spaceLeft..")")
			  spaceLeft = spaceLeft - spaceLeft
			end
		  end
		  saveTable(itemStorage, "inventoryArchive.txt")
		  dr(port, "drone.move(0,"..(-1 * y)..",0)")
		  dr(port, "drone.move("..((-1 * x)+2)..",0,"..((-1 * z)-1)..")")
		  for invSpot=1, 8 do
			dr(port, "drone.select("..invSpot..")")
			dr(port, "drone.drop(1)")
		  end
		  dr(port, "drone.move(-2,0,1)")
		  dr(port, "drone.move(0,2,0)")
		  return true
	  end
    end
  end
end

function pullRelocate(port,itemName,quantity) -- starting from HQ, then return!
  quantity = quantityTBD
  while quantityTBD > 0 do
	for i=1, table.getn(itemStorage) do -- tell bot to move to right spot
      if itemStorage[i][1] == itemName and itemStorage[i][2] > 0 then
	    x,y,z = invNumToCoords(i)
	    if port == pullPort then x = x-1 z = z-1 end
	    break
	  end
	  if i == table.getn(itemStorage) then
	    dr(port, "setStatusText('No such item(s)')")
		return false
	  end
    end
	dr(port, "drone.move(0,-2,0)")
	dr(port, "drone.move("..x..",0,"..z..")")
	dr(port, "drone.move(0,"..y..",0)")
	invSpot = 1
	while invSpot <= 8 and quantityTBD > 0 do
	  dr(port, "drone.select("..invSpot..")")
	  dr(port, "drone.suck("..rowFace(i)..", "..quantityTBD..")")
	  quantityTBD = quantityTBD - dr(port, "ic.getStackInInternalSlot().size")
	  itemStorage[i][2] = itemStorage[i][2] - dr(port, "ic.getStackInInternalSlot().size")
	  invSpot = invSpot + 1
	end
	dr(port, "drone.move(0,"..(-1 * y)..",0)")
    dr(port, "drone.move("..((-1 * x)-1)..",0,"..((-1 * z)-2)..")")
	for invSpot = 1, 8 do
	  dr(port, "drone.select("..invSpot..")")
	  dr(port, "drone.drop(1)")
	end
	dr(port, "drone.move(1,0,2)")
	dr(port, "drone.move(0,2,0)")
	cleanseArray(itemStorage)
	saveTable(itemStorage, "inventoryArchive.txt")
	return true
  end	
end

continue = true
while continue do
  evt,y,z,r,e,request = event.pull(1)
  if evt == "key_down" then
	  if z==113 and r==16 then
		continue = false
		print("quitting")
		break
	  end
	  if z==13 and r==28 then
		dr(pullPort, "drone.move(0,2,0)")
		dr(pushPort, "drone.move(0,2,0)")
		print("awoke")
	  end
  end
  
  if evt=="modem_message" then
	if string.sub(request, 1, 2) == "s;" then
	  searchItem = string.sub(request, 3, string.len(request))
	  local results = {} resultsCount = 1
	  for i=1, table.getn(itemStorage) do
		if string.find(itemStorage[i][1], searchItem) ~= nil then
			results[resultsCount] = {}
			results[resultsCount][1] = itemStorage[i][1]
			results[resultsCount][2] = itemStorage[i][2]
			resultsCount = resultsCount + 1
		end
	  end
	  m.broadcast(2411, results)
	  command = true
	end
	if string.sub(request, 1, 2) == "p;" then
	  pullItemString = string.sub(request, 3, string.len(request))
		pullArray = {}
		boop=1
	  for token in string.gmatch(pullItemString, "[^;]+") do
		if boop == 1 then
		  pullItem = token
		  boop = boop + 1
		else
		  pullItemQuantity = token
		end
	  end
	  pullRelocate(pullPort,pullItem,pullItemQuantity)
	  storageChange = true
	end
  end

  if dr(pushPort, "computer.maxEnergy()*0.1 < computer.energy()") then -- if drone doesn't need to charge...
    foundItem = nil
    sucks = 0
    for slot = dr(pushPort, "ic.getInventorySize(3)"), 1, -1 do
      item = dr(pushPort, "ic.getStackInSlot(3,"..slot..")")
      if foundItem == nil and item ~= nil then
        foundItem = dr(pushPort, "ic.getStackInSlot(3,"..slot..")")
      end
      if foundItem ~= nil and item.maxDamage == foundItem.maxDamage and item.name == foundItem.name then
        dr(pushPort, "ic.suckFromSlot(3,"..slot..")")
        sucks = sucks + 1
      end
	  if (slot == 1 or sucks == 8) and dr(pushPort, "ic.getStackInInternalSlot(1)") ~= nil then
        pushRelocate(pushPort,foundItem.name)
		storageChange = true
		break
	  end
    end
  end
  
  if storageChange or command then
    term.clear()
    --render screen according to inventory and display Q as quit option and show when activated
	--also show recent operations! (command)
	-- also show start button (enter) and show when activated
  end
  storageChange = false
  command = false
end
