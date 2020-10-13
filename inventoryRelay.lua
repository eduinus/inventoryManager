local component = require("component")
local modem = component.modem
local event = require("event")
local serialization = require("serialization")

-- BEGIN CONFIG

-- PORTS: (max port is 65535)
inventoryRelayOne = 54979
-- multiple modems? https://ocdoc.cil.li/component:component_access https://oc.cil.li/topic/1532-how-to-separate-multiple-components-of-the-same-name-in-code/

-- END CONFIG

modem.open(inventoryRelayOne)

function tableLength(table) -- presumes table index begins at 1
  count = 0
  while table[count] ~= nil do
    count=count+1
  end
  return count
end

while true do
  local id, localAddress, remoteAddress, port, distance, payload = event.pull("modem_message", "interrupted")
  -- for modem_message: id, localAddress, remoteAddress, port, distance, payload
  print("EVENT PULLED:")

  if id == "modem_message"
    modem.broadcast(port, payload)
    print("-> message on port "..port)
  end

  elseif id == "interrupted"
    print("-> soft interrupt, closing")
    break
  end

end
