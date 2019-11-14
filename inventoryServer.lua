local component = require("component")
local event = require("event")
local modem = component.modem
local term = require("term")
local serial = require("serialization")
--[[
To do:
-record Inventory storage system
-serve questions to viewing pc
-give commands to put drone, pull drone
-helpful graphics? / data?
  

  check if message from inventory PC
        if so, give orders to pull drone or serve array info

]]--

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

itemStorage = loadTable("inventoryArchive")

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

function relocate(port,itemName) -- starting from HQ, then return!
  if table.getn(itemStorage) == 0 then
    -- go to first
  elseif table.getn(itemStorage) == 7392 then
   -- give up
  else
    for i=1, table.getn(itemStorage)+1 do
      if i = table.getn(itemStorage)+1 then
        itemStorage[i] = {}
        itemStorage[i][1] = itemName
        itemStorage[i][2] = 0
      end
      if itemStorage[i][1] == itemName and itemStorage[i][2] < 262144 then
        if itemStorage[i][2]<262144 then
          invNumToCoords(i) = x,y,z
          if port == pullPort then x+1 z+1 end
          dr(port, "drone.move(0,-2,0)")
          dr(port, "drone.move("..x..",0,"..z..")")
          dr(port, "drone.move(0,"..y..",0)")
          spaceLeft = 262144-itemStorage[i][2]
          invSpot=1
          while invSpot <= 8 do
            dr(port, "drone.select("..invSpot..")")
            if spaceLeft>= dr(port, "ic.getStackInInternalSlot("..invSpot..").size") then
              itemStorage[i][2] = itemStorage[i][2] + dr(port, "ic.getStackInInternalSlot("..invSpot..").size")
              spaceLeft = spaceLeft - dr(port, "ic.getStackInInternalSlot("..invSpot..").size")
              dr(port, "drone.drop("..rowFace(i)..", ic.getStackInInternalSlot("..invSpot..").size")
              invSpot = invSpot + 1
            else
              itemStorage[i][2] = itemStorage[i][2] + spaceLeft
              dr(port, "drone.drop("..rowFace(i)..", "..spaceLeft)
              spaceLeft = spaceLeft - spaceLeft
              
              
              -- move to new slot
              -- initialize as that item in the array, and count at 0
              -- set space left to new value
            end
          end
          
        end
          -- save array
          -- return to center, drop extras back into chest
      end
    end
  end
end

continue = true
while continue do
  x,y,z,r,e = event.pull(1, "key_down")
  if z==113 and r==16 and e=="Eduinus" then
    continue = false
  end

  if storageChange then
    term.clear()
    --render screen according to inventory and display Q as quit option
  end

  if dr(pushPort, "computer.maxEnergy()*0.1 < computer.energy()") then
    foundItem = nil
    sucks = 0
    for slot=dr(pushPort, "ic.getInventorySize(3)"), 1, -1 do
      item = dr(pushPort, "ic.getStackInInternalSlot(3,slot)")
      if foundItem == nil and item ~= nil then
        foundItem = dr(pushPort, "ic.getStackInInternalSlot(3,slot)")
      end
      if item.maxDamage == foundItem.maxDamage and item.name == foundItem.name then
        dr(pushPort, "ic.suckFromSlot(3,slot)")
        sucks = sucks + 1
      end
      if sucks == 8 then break end
    end
    
    -- where am I going?
    -- go there
  end

end
