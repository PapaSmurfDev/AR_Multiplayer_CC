local modules = peripheral.find("neuralInterface")
if not modules then error("Must have a neural interface", 0) end
-- if not modules.hasModule("plethora:scanner") then error("The Entity scanner is missing", 0) end
if not modules.hasModule("plethora:glasses") then error("The overlay glasses are missing", 0) end
local modem = peripheral.find("modem")
if modem == nil then
  wireless = false
  error("Can't open modem")
else
  wireless = true
end

local mp = require("mpapi") -- Custom written multiplayer api

--- Now we've got our neural interface, let's extract the canvas and ensure nothing else is on it.
-- Configuration
local save = {}
local saveName = "overlaySave.save"
local saveNameRoot = "overlaySave.root"

local rootx = 0
local rooty = 0
local rootz = 0
-- Configuration End

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

local function generateRandomColor()
  local colorRange = {
    "0","1","2","3","4","5","6","7","8","9","A",
    "B", "C", "D", "E", "F"
  }
  local randomColor = ""
  for i = 1,6 do
    randomColor = randomColor..colorRange[math.random(1,#colorRange)]
  end

  randomColor = randomColor.."FF"

  return randomColor
end

local function addBox(x,y,z,color)
  if x ~= nil and y ~= nil and z ~= nil then
    y = math.floor(y) - 1.7
    x = math.floor(x) - 0.65
    z = math.floor(z) - 0.82
    if not color then
      color = tonumber(generateRandomColor(), 16)
    end

    mp.addBox(x,y,z, color)
  else
      print("Error adding box, try again")
  end
end

local function isNumber(coor)
  return coor == coor
end

local function initCanvas()
  local curx, cury, curz

  while true do
    curx, cury, curz = gps.locate()
    if isNumber(curx) and isNumber(cury) and isNumber(curz) then
      break
    end
  end

  canvas = modules.canvas3d().create({0,0,0})
  canvas.clear()

  ui_canvas = modules.canvas()

  local width, height = ui_canvas.getSize()

  ui_canvas.addRectangle(width - 70, 0, 100, 20, 0x00000044)
  local text = ui_canvas.addText({ x = width - 65, y = 5 }, "Channel"..tostring(mp.hostChannel))
  text.setScale(1)

  addBox(curx,cury,curz, 0xFF0000FF)
end

local function calculateDiff(a,b)
  return math.abs(a) - math.abs(b)
end


local deviceInit = false


term.clear()
while not deviceInit do
  mp.initDevice()

  if not mp.isHost then
    if mp.initRequest() then
      deviceInit = true
    else
      print("Please try again, timeout")
      error()
    end
  else
    -- Host break loop
      deviceInit = true
  end
end

local function writeCenter(params)
  local width, height = term.getSize()

  term.setCursorPos(width/2-#params["str"]/2, params["yLoc"])
  term.write(params["str"])
end

local function drawDivider(params)
  local width, height = term.getSize()

  for i = 1,width do
    term.setCursorPos(i, params["yLoc"])
    term.write(params["sym"])
  end
end

local function writeLeft(params)
  term.setCursorPos(1, params["yLoc"])
  term.write(params["str"])
end

local function updateStatus(channel, boxCount)
    local width, height = term.getSize()

    local status = {
      { ["func"]=writeCenter, { ["str"]="Welcome to PapaNicSmurf's", ["yLoc"]=0 } },
      { ["func"]=writeCenter, { ["str"]="Colourful AR World!", ["yLoc"]=0 } },
      { ["func"]=drawDivider,  { ["sym"]="*" } },
      { ["func"]=writeCenter,  { ["str"]="Channel: "..channel, ["yLoc"]=0 } },
      { ["func"]=writeCenter, { ["str"]="Box Count: "..boxCount, ["yLoc"]=0 } },
      { ["func"]=drawDivider,  { ["sym"]="*" } },
      { ["func"]=writeCenter, { ["str"]="Press c to place a block", ["yLoc"]=0 } },
      { ["func"]=writeCenter, { ["str"]="Press x to remove all blocks", ["yLoc"]=0 } },
      { ["func"]=writeCenter, { ["str"]="Press b to quit the program", ["yLoc"]=0 } }
    }

    term.clear()

    for i=1, #status do
      status[i][1]["yLoc"] = i
      status[i].func(status[i][1])
    end
end

local function getCurrentLocation()
  local h = http.get("https://dynmap.switchcraft.pw/up/world/world/" .. os.epoch("utc")) -- epoch is the important part!
  local data = textutils.unserialiseJSON(h.readAll())
  h.close()
  local playerName
  for i, senseTbl in pairs(modules.sense()) do
    if senseTbl.x == 0 and senseTbl.y == 0 and senseTbl.z == 0 then
      playerName = senseTbl["name"]
    end
  end

  for k,v in pairs(data["players"]) do
    if v["name"] == playerName then
      return v["x"], v["y"], v["z"]
    end
  end
end
-- local curx, cury, curz = getCurrentLocation()

local function renderBoxes()
  canvas.clear()
  for i,box in ipairs(mp.world.boxes) do
    canvas.addBox(box.x-mp.userRoot[1], box.y-mp.userRoot[2], box.z-mp.userRoot[3], box.color)
  end
  updateStatus(mp.hostChannel, #mp.world.boxes)
end

local function addBoxButton()
  local curx, cury, curz = gps.locate()
  if isNumber(curx) and isNumber(cury) and isNumber(curz) then
    addBox(curx, cury, curz)
  else
    print("Box not added")
  end
end

local function mainLoop(event, key_side, held_ch, rch, msg, dist)
    if event == "key" then
      if key_side == keys.c then
        addBoxButton()
        renderBoxes()
      elseif key_side == keys.x then
        print("Remove all boxes")
        mp.removeAllBox()
        renderBoxes()
      elseif key_side == keys.b then
        mp.world = {}
        print("stopping program")
        canvas.clear()
        ui_canvas.clear()
        running = false
        modem.close(mp.hostChannel)
        if mp.isHost then
          modem.close(mp.initChannel)
        end
      end
    elseif event == "modem_message" then
      mp.handleMultiplyer(msg, held_ch)
    end
end

term.clear()
term.setCursorPos(1,1)
initCanvas()

running = true

renderBoxes()
while running do
  os.startTimer(1)
  local event, key_side, held_ch, rch, msg, dist = os.pullEvent()
  if event =="timer" then
    -- renderBoxes()
  elseif event == "key" or "modem_message" then
    mainLoop(event, key_side, held_ch, rch, msg, dist)
  end
end