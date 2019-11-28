local component = require("component")
local event = require("event")
local modem = component.modem
local term = require("term")
local serialization = require("serialization")
 
function dr(port, cmd)
  modem.broadcast(port, "return "..cmd)
  ayy = select(6, event.pull(1, "modem_message"))
  os.sleep(0.25)
  return ayy
end
 
function tableLength(table)
  count = 1
  while table[count] ~= nil do
    count=count+1
  end
  return count-1
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
  local tableFile = io.open(location,"r")
  if tableFile == nil then return {} end
  return serialization.unserialize(tableFile:read("*all"))
end
 
function saveTable(table, location)
  --saves a table to a file
  local tableFile = io.open(location, "w")
  tableFile:write(serialization.serialize(table))
  tableFile:close()
end
 
itemStorage = loadTable("inventoryArchive.txt")
 
function invNumToCoords(num)
  col = math.ceil(num / 8)
  row = math.ceil(col / 42)
  rack = (num - 1) % 8
  if row % 2 ~= 0 then
    z = -21 + (4 * ((row - 1)/2))
  else
    z = -18 + (4 * ((row - 2)/2))
  end
  x = -20 + ((col-1 % 42))
  y =  -9 + rack
  return x, y, z
end
 
function rowFace(num)
  col = math.ceil(num / 8)
  row = math.ceil(col / 42)
  if row % 2 ~= 0 then
    return 3
  else
    return 2
  end
end
 
function cleanseArray(array)
  for i=1, tableLength(array) do
    if array[i][2] <1 then
      array[i][1] = nil
      array[i][2] = nil
      array[i][3] = nil
      array[i][4] = nil
      array[i][5] = nil
      array[i] = nil
    end
  end
end
 
function waitForStop(port)
  while dr(port, "drone.getVelocity() > 0.1") do
    os.sleep(1)
  end
end
 
function pushRelocate(port,itemName,id,dmg,label) -- starting from HQ, then return!
  if tableLength(itemStorage) == 7392 then
    dr(port, "setStatusText('Storage Full!')")
    return false
  else
    for i=1, tableLength(itemStorage)+1 do
      if (i == tableLength(itemStorage)+1) or (tableLength(itemStorage) == 0) then
        itemStorage[i] = {}
        itemStorage[i][1] = itemName
        itemStorage[i][2] = 0
    itemStorage[i][3] = id
    itemStorage[i][4] = dmg
    itemStorage[i][5] = label
      end
      if itemStorage[i][3] == id and itemStorage[i][4] == dmg and itemStorage[i][2] < 262144 then
        x,y,z = invNumToCoords(i)
    print("Coords: "..invNumToCoords(i))
    if port == pullPort then x = x-1 z = z-1 end
    print("Moving to item Spot :)")
    dr(port, "drone.move(0,-2,0)")
    waitForStop(port)
    dr(port, "drone.move("..x..",0,"..z..")")
    waitForStop(port)
    dr(port, "drone.move(0,"..y..",0)")
    waitForStop(port)
    spaceLeft = 262144-itemStorage[i][2]
    invSpot=1
    while invSpot <= 8 do
      if not dr(port, "ic.getStackInInternalSlot("..invSpot..") ~= nil") then
        break
      end
      dr(port, "drone.select("..invSpot..")")
      payLoad = dr(port, "ic.getStackInInternalSlot("..invSpot..").size")
      print("payLoad: "..payLoad)
      print(spaceLeft)
      if spaceLeft >= payLoad then
        itemStorage[i][2] = itemStorage[i][2] + payLoad
        spaceLeft = spaceLeft - payLoad
        dr(port, "drone.drop("..rowFace(i)..", "..payLoad..")")
        invSpot = invSpot + 1
      else
        itemStorage[i][2] = itemStorage[i][2] + spaceLeft
        dr(port, "drone.drop("..rowFace(i)..", "..spaceLeft..")")
        spaceLeft = spaceLeft - spaceLeft
      end
    end
    saveTable(itemStorage, "inventoryArchive.txt")
    dr(port, "drone.move(0,"..(-1 * y)..",0)")
    waitForStop(port)
    dr(port, "drone.move("..((-1 * x)+2)..",1,"..((-1 * z)-1)..")")
    waitForStop(port)
    for invSpot=1, 8 do
      dr(port, "drone.select("..invSpot..")")
      dr(port, "drone.drop(1)")
    end
    print("Emptied Drone :)")
    dr(port, "drone.move(-2,0,1)")
    waitForStop(port)
    dr(port, "drone.move(0,1,0)")
    waitForStop(port)
    print("Home!")
    return true
      end
    end
  end
end
 
function pullRelocate(port,itemName,quantity) -- starting from HQ, then return!
  quantity = quantityTBD
  while quantityTBD > 0 do
    for i=1, tableLength(itemStorage) do -- tell bot to move to right spot
      if itemStorage[i][1] == itemName and itemStorage[i][2] > 0 then
        x,y,z = invNumToCoords(i)
    if port == pullPort then x = x-1 z = z-1 end
    break
      end
      if i == tableLength(itemStorage) then
        dr(port, "setStatusText('No such item(s)')")
        return false
      end
    end
    dr(port, "drone.move(0,-2,0)")
    waitForStop(port)
    dr(port, "drone.move("..x..",0,"..z..")")
    waitForStop(port)
    dr(port, "drone.move(0,"..y..",0)")
    waitForStop(port)
    invSpot = 1
    while invSpot <= 8 and quantityTBD > 0 do
      dr(port, "drone.select("..invSpot..")")
      dr(port, "drone.suck("..rowFace(i)..", "..quantityTBD..")")
      quantityTBD = quantityTBD - dr(port, "ic.getStackInInternalSlot().size")
      itemStorage[i][2] = itemStorage[i][2] - dr(port, "ic.getStackInInternalSlot().size")
      invSpot = invSpot + 1
    end
    dr(port, "drone.move(0,"..(-1 * y)..",0)")
    waitForStop(port)
    dr(port, "drone.move("..((-1 * x)-1)..",0,"..((-1 * z)-2)..")")
    waitForStop(port)
    for invSpot = 1, 8 do
      dr(port, "drone.select("..invSpot..")")
      dr(port, "drone.drop(1)")
    end
    dr(port, "drone.move(1,0,2)")
    waitForStop(port)
    dr(port, "drone.move(0,2,0)")
    waitForStop(port)
    cleanseArray(itemStorage)
    saveTable(itemStorage, "inventoryArchive.txt")
    return true
  end  
end
 
continue = true
while continue do
  evt,y,z,r,e,request = event.pull(1)
  -- removed quit and awake key commands
  if evt=="modem_message" then
    if request ~= nil then
    if string.sub(request, 1, 2) == "s;" then
      searchItem = string.sub(request, 3, string.len(request))
      local results = {} resultsCount = 1
      for i=1, tableLength(itemStorage) do
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
  end
  
  needToCharge = dr(pushPort, "computer.maxEnergy()*0.9 > computer.energy()")
  
  if needToCharge then -- if drone doesn't need to charge...
    while dr(pushPort, "computer.maxEnergy()*0.95 > computer.energy()") do
      os.sleep(10)
    end
  else
    print("Storing Items")
    foundItemID = nil
    sucks = 0
    slotx = dr(pushPort, "ic.getInventorySize(3)")
    for slot = 1, slotx do
      print("Checking slot "..slot)
      something = dr(pushPort, "ic.getStackInSlot(3,"..slot..") ~= nil")
      print(something)
      if something then
        itemID = dr(pushPort, "ic.getStackInSlot(3,"..slot..").id")
    itemDmg = dr(pushPort, "ic.getStackInSlot(3,"..slot..").damage")
	itemLabel = dr(pushPort, "ic.getStackInSlot(3,"..slot..").label")
        print(itemID..":"..itemDmg)
    if foundItemID == nil then
          foundItemID = itemID
      foundItemDmg = itemDmg
          foundItemName = dr(pushPort, "ic.getStackInSlot(3,"..slot..").name")
      foundItemLabel = itemLabel
      print("Found an item: "..foundItemName)
        end
    if foundItemID ~= nil and foundItemID == itemID and foundItemDmg == itemDmg and foundItemLabel == itemLabel then
      dr(pushPort, "drone.select(1)")
      dr(pushPort, "ic.suckFromSlot(3,"..slot..")")
      print("Sucked a stack of the item.")
          sucks = sucks + 1
        end
      end
      if (slot == slotx or sucks == 8 or not something) and sucks > 0 then
        print("Storing the stuff!")
    pushRelocate(pushPort, foundItemName, foundItemID, foundItemDmg,foundItemLabel)
        storageChange = true
    break
      end
    end
  end
 
  if storageChange or command then
    term.clear()
    --render screen according to inventory
    --also show recent operations! (command)
    -- cntrl alt c to quit
  end
  storageChange = false
  command = false
end
