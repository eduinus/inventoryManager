local component = require("component")
local modem = component.modem
local event = require("event")
local serialization = require("serialization")

-- BEGIN CONFIG
modem.open(54978) -- ports to robots etc. go here - max port is 65535
-- modem.open()
-- modem.open()
-- modem.open()

-- END CONFIG

function tableLength(table) -- presumes table index begins at 1
  count = 0
  while table[count] ~= nil do
    count=count+1
  end
  return count
end

while true do
  local id, localAddress, remoteAddress, port, distance, payload = event.pull("modem_message")
  -- for modem_message: id, localAddress, remoteAddress, port, distance, payload

  -- localAddress is the address of the modem component the message was received by.
  -- remoteAddress is the address of the network card the message was sent from.
  -- port is the port number the message was delivered to.

  modem.broadcast(port, payload)


  -- handle genSearch?    - pass to main Server, pass table back
    -- modem.send(remoteAddress, port, serialization.serialize(genSearch(payLoad[2])))

  -- handle specSearch?   - pass to main Server, pass table back
    -- modem.send(remoteAddress, port, serialization.serialize(specSearch(payLoad[2], payLoad[3], payLoad[4], payLoad[5], payLoad[6], payLoad[7], payLoad[8], payLoad[9])))

  -- handle requests?     - pass to main Server, pass success etc. back
    -- modem.send(remoteAddress, port, "noGrab") -- if robot doesn't take it out of the transciever
    -- modem.send(remoteAddress, port, "done") -- when request is done and one item was found matching request
    -- modem.send(remoteAddress, port, "moreThanOneSuchItem") -- request is done but more than one item was found, so not sending them.
    -- modem.send(remoteAddress, port, "noSuchItem") -- request done because no items found matching description.

end

-- multiple modems? https://ocdoc.cil.li/component:component_access https://oc.cil.li/topic/1532-how-to-separate-multiple-components-of-the-same-name-in-code/
