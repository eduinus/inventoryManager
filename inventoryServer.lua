local event = require("event")
local component = require("component")
local modem = component.modem
local ct = component.transposer
local term = require("term")
local sides = require("sides")

while true do
  local id, _, x, y = event.pullMultiple("interrupted", "modem_message", "key_down")

  if id == "interrupted" then -- this means you pressed ctrl + c
    print("soft interrupt, closing")
    break

  elseif id == "modem_message" then -- this means we have some sort of remote query
    print("user clicked", x, y)
    -- serve remote items search requests
    -- serve remote item requests

  elseif id == "touch" then -- this means we have some sort of local query
    print("key_down", x, y)
    -- serve local item search requests
    -- serve local item requests

    -- If given an argument search attached storage (storageside) for items and if
    --   one match pull upto 64 items into the attached chest (chestside)
    --   If multiple items lists the items, give slot number to pull from that
    --   slot
    --   If no arguments return all items in chest (chestside)
    local storageside = sides.down -- change as necessary
    local chestside = sides.up -- change as necessary

    local args, opts = shell.parse(...) -- kill this

    if args[1] then
        local searchfor = args[1]

        local counted = 0
        if not tonumber(searchfor) then
            local i = 0
            for i =1, (ct.getInventorySize(storageside)) do
                local item = ct.getStackInSlot(storageside, i)

                if item then
                    if string.find(item.name .. "^" .. item.label .. "^", searchfor) then
                        print(i .. ": " .. item.name .. " - " .. item.label .. " (" .. item.size .. ")")
                        counted = counted + 1
                        slot = i
                    end
                end
            end
        else
            slot = tonumber(searchfor)
            counted = 1
        end

        if counted == 1 then
            ct.transferItem(storageside, chestside, 64, slot)
        end
    else  -- No arguments indicate send everything back
        for i = ct.getInventorySize(chestside), 1, -1 do
            ct.transferItem(chestside, storageside, 64, i)
        end
    end

  end
  -- now store any items in buffer chest
  -- render item inventory graphically when not in use if you stored items in the above chest! (only if so)
  -- note recent inventory changes
end
