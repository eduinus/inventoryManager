local component = require("component")
local modem = component.modem
local event = require("event")
local serialization = require("serialization")

-- CHANGE THESE BASED ON YOUR SETUP
modem.open(54978) -- max port is 65535
--modem.open()
--modem.open()
--modem.open()
-- END CONFIG

function tableLength(table) -- presumes table index begins at 1
  count = 0
  while table[count] ~= nil do
    count=count+1
  end
  return count
end

local id, localNetworkCard, remoteAddress, port, distance, payload = event.pull("modem_message")
  
end

-- picks up on robot or remote item requests / searches
-- stores these queries in array (deletes duplicative requests)
-- passes them to server periodically, and then removes them when da server says it's handling it

-- Network setup: linked network cards in server rack, ran with network card to server
