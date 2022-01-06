local modem = peripheral.find("modem")
if not modem or not modem.isWireless() then
  return nil
end

mp = {}
-- Init channel 6969

mp.isHost = false
mp.hostChannel = -1
mp.initChannel = 6969
mp.playerId = 0

mp.world = {}
mp.world.boxes = {}
mp.world.root = { 0,0,0 }
mp.userRoot = { 0,0,0 }
mp.players = {}
mp.isConnected = false
mp.timeoutConnection = false

local function printTbl(tbl)
  if type(tbl) == "table" then
    for k,v in pairs(tbl) do
      if type(v) == "table" then
        printTbl(v)
      else
        print(k..":"..tostring(v))
      end
    end
  else
    print(tbl)
  end
end

local function isNumber(coor)
  if coor == nil then
    return false
  end
  return coor == coor
end

-- Host open Init channel and Host Channel
-- Host starts and instantiate
-- Player Id {}, World, World.root at host 0,0,0 and Host Channel

-- Client opens init channel
-- Client choose host channel and opens it
-- Client starts by sending position
-- Await for host to send relative root position and the entire world objects
-- Client close init channel

-- When client updates the host with new box, the host will update the shared world and only broadcast world to the rest of the players
-- Other Clients will listen and update the world accordingly

function mp.listen(timeout)
  if not timeout then timeout = 2 end -- make sure the timeout variable is usable
  local timeoutTimer = os.startTimer(timeout)
  local event, side, ch, rch, msg, dist = os.pullEvent()
  if event == "timer" and side == timeoutTimer then
    print("Connection has timeout")
    return nil, "timeout"
  elseif event == "modem_message" then
    return ch, msg
  end
end

function mp.calculateDist(clientPos, hostRoot)
  return { clientPos[1] - hostRoot[1], clientPos[2] - hostRoot[2], clientPos[3] - hostRoot[3] }
end

-- boxAdd => x,y,z, color
function mp.sendData(msgType, obj, channel)
  local message = { ["type"]=msgType, ["obj"] = obj }
  modem.transmit(channel,channel,message)
end

-- Host constantly listen for new device to join and send all the updated data over
-- Host sends world and root
function mp.hostListenDevices(data)
    local clientPos = data["player_position"]
    local nextPlayerId = #mp.players+1
    table.insert(mp.players, nextPlayerId)
    -- print("Player ", nextPlayerId, " Current Position: ", 
    --   clientPos[0], "/", clientPos[1], "/", clientPos[2])
    print("Received client prompted connection")
    local worldData = { ["world"]=mp.world, ["id"] = nextPlayerId, ["hostChannel"] = mp.hostChannel }
    print("Sending to client")
    mp.sendData("initWorld", worldData, mp.initChannel)
end

-- Client request for world
function mp.initRequest()
  while true do 
    local xPos, yPos, zPos = gps.locate()
    if isNumber(xPos) and isNumber(yPos) and isNumber(zPos) then
      break
    end
  end
  local data = {
    ["player_position"] = { xPos, yPos, zPos }
  }
  mp.sendData("initReq", data, mp.initChannel)
  print("Waiting for host reply")
  while true do
    local ch, msg = mp.listen(1000)
    if ch == mp.initChannel then
      if msg["type"] == "initWorld" and msg["obj"]["hostChannel"] == mp.hostChannel then
        mp.playerId = msg["obj"]["id"]
        mp.world = msg["obj"]["world"]
        mp.isConnected = true
        modem.close(mp.initChannel)
        print("Host acknowledged, ready to network!")
        print("Player Id ", mp.playerId, " is assigned to you!")
        return true
      end
    elseif msg == "timeout" then
      print("Please restart the program")
      error("Connection time out")
    end
  end
end

function mp.instantiateHostData(channel)
  modem.open(channel)
  mp.isHost = true
  local xPos, yPos, zPos
  while true do
    xPos, yPos, zPos = gps.locate()
    if isNumber(xPos) and isNumber(yPos) and isNumber(zPos) then
      break
    end
  end
  print(xPos, yPos, zPos)
  mp.playerId = 0
  mp.userRoot = { math.floor(xPos), math.floor(yPos), math.floor(zPos) }
  mp.hostChannel = channel
end

function mp.instantiateClientData(channel)
  modem.open(channel)
  local xPos, yPos, zPos
  while true do
    xPos, yPos, zPos = gps.locate()
    if isNumber(xPos) and isNumber(yPos) and isNumber(zPos) then
      break
    end
  end
  print(xPos, yPos, zPos)
  mp.hostChannel = channel
  mp.userRoot = { math.floor(xPos), math.floor(yPos), math.floor(zPos) }
end

-- Initiate Host/Client Device through terminal
function mp.initDevice()
  modem.open(mp.initChannel)
  while true do
    print("Host/Client [h/c]: ")
    local event, key, held = os.pullEvent("key")
    if key == keys.h then
      -- Input for channel
      print("You have chose to be a host!")
      print("Please choose a channel[7000-7999]: ")
      os.pullEvent("key")
      -- Choose host channel
      local input = read()
      if tonumber(input) == nil then
        print("Input must be a number")
      -- Correct Input
      elseif tonumber(input) >= 7000 and tonumber(input) < 8000 then
        mp.instantiateHostData(tonumber(input))
        return mp.isHost
      else
        print("Please keep within the range given")
      end

    elseif key == keys.c then
      mp.isHost = false
      -- Input for channel
      print("You have chose to be a client!")
      print("Please join a channel[7000-7999]: ")
      os.pullEvent("key")
      -- Choose host channel
      local input = read()
      if tonumber(input) == nil then
        print("Input must be a number")
      -- Correct Input
      elseif tonumber(input) >= 7000 and tonumber(input) < 8000 then

        mp.instantiateClientData(tonumber(input))
        return mp.isHost

      else
        print("Please keep within the range given")
      end
    end
  end
end

function clientTimeout()

end

function mp.boxDataFilter(objData)
  return {
    ["x"]=objData["x"], 
    ["y"]=objData["y"], 
    ["z"]=objData["z"], 
    ["color"]=objData["color"]
  }
end

function mp.handleWorldData(data)
  if data["action"] == "add" then
    local boxData = mp.boxDataFilter(data)
    table.insert(mp.world.boxes, boxData)
  elseif data["action"] == "removeAll" then
    mp.world.boxes = {}
  end
end

function mp.addBox(x, y, z, color)
  local data = {
    ["action"]="add",
    ["id"] = mp.playerId,
    ["x"]=x, 
    ["y"]=y, 
    ["z"]=z, 
    ["color"]=color
  }
  mp.handleWorldData(data)

  if mp.isHost then
    mp.sendData("clientWorld", data, mp.hostChannel)
  else
    mp.sendData("world", data, mp.hostChannel)
  end
  clientTimeout()
end

function mp.removeAllBox()
  local data = {
    ["action"] = "removeAll",
    ["id"] = mp.playerId
  }
  mp.world.boxes = {}
  if mp.isHost then
    mp.sendData("clientWorld", data, mp.hostChannel)
  else
    mp.sendData("world", data, mp.hostChannel)
  end
end

-- Host listen and update the world to the relevant clients
function mp.hostListenWorld(data)
  mp.handleWorldData(data)

  print("ID:", data["id"])
  for i, id in ipairs(mp.players) do
    if id ~=  data["id"] then
      mp.sendData("clientWorld", data, mp.hostChannel)
    end
  end
end

-- Client listen and update the world
function mp.clientListenWorld(data)
  mp.handleWorldData(data)
end


function mp.handleMultiplayer(msg, held_ch)
  if mp.isHost then
    if msg["type"] == "initReq" and held_ch == mp.initChannel then
      mp.hostListenDevices(msg["obj"])
    elseif msg["type"] == "world" and msg["obj"]["id"] ~= nil then
      -- Host receive data from client and broadcast to the rest
      print("Host Listened")
      mp.hostListenWorld(msg["obj"])
    end
  else
    if msg["type"] == "clientWorld" and held_ch == mp.hostChannel then
      -- Client doesn't send back data but only render the world
      mp.clientListenWorld(msg["obj"])
    end
  end
end

return mp