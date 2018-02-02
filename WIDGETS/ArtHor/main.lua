-- Horus X10, X10S, 12S
-- LCD: 480*272 readable outdoor color screen
Pitch=0
Roll=0

local shadowed  = 0

-- Function to move values in Companion simulator
local function debugFeed()
  return getDateTime().sec
end

local options = {
  { "Land_color", COLOR, LINE_COLOR},
  { "Sky_color", COLOR, CURVE_COLOR},
  { "Axis_color", COLOR, RED},
  { "Shadow", BOOL, 0 }
}

-- This function is runned once at the creation of the widget
local function create(zone, options)
  local myZone  = { zone=zone, options=options, counter=0 }
  histCellData = {}

  lcd.setColor(CURVE_COLOR, lcd.RGB(0, 163, 224)) -- Sky blue
  lcd.setColor(LINE_COLOR, lcd.RGB(229, 114, 0)) -- Land


  return myZone
end

-- This function allow updates when you change widgets settings
local function update(myZone, options)
  myZone.options = options

  lcd.setColor(CURVE_COLOR, myZone.options.Sky_color) -- Sky blue
  lcd.setColor(LINE_COLOR, myZone.options.Land_color) -- Land

  return
end

-- Here place the artificial horizon drawing routine
local origX, origY, endX, endY = 19,7,72,49  -- This will work as a rectangular widget
local centerX=math.floor((endX-origX)/2 + 0.5 + origX)
local centerY=math.floor((endY-origY)/2 + 0.5 + origY)

local function drawHorizon(zone)
  -- Erase the area
  lcd.drawFilledRectangle(origX,origY,endX-origX+1,endY-origY+1,MAINVIEW_PANES_COLOR)

  local pitch = Pitch
  local roll = Roll

  -- Horizon line drawing
  -- In Pixhawk:
  --  pitch range is +90 to -90: or in between 270 and 90
  --  roll range is +180 to -180: or 0 to 360.
  --  if pitch goes furter, then roll increases by 180 to indicate facing down

  local tanRoll, sinPitch
  local pitchOffsetY
  local inverseYaxis = 0

  local YSpanHalf = (endY-origY)/2 - 1
  local pitchRatio = YSpanHalf / 90     -- Divide by the angle of half the field of view desired. 90 for 180 degrees.

  local attGnd = GREY_DEFAULT   -- Style of the ground part

  --dPitch_1 = pitch % 180
  --if dPitch_1 > 90 then dPitch_1 = 180 - dPitch_1 end

  --cosRoll = math.cos(math.rad(roll == 90 and 89.99 or (roll == 270 and 269.99 or roll)))  -- To avoid zero division
  sinPitch = math.sin(math.rad(pitch == 0 and 0.01 or (pitch == 180 and 179.99 or pitch)))  -- To avoid zero division
  pitchOffsetY=YSpanHalf*sinPitch

  if roll>90 and roll <270 then inverseYaxis=1 end

  -- Fill of the "land" side drawing vertical lines
  tanRoll = math.tan(math.rad(roll == 90 and 89.99 or (roll == 270 and 269.99 or roll)))
  for X1 = origX, endX, 1 do  -- Only one X coordinate, all are vertical lines
    local YOffset = (centerX-X1) * tanRoll
    Y1 = math.floor(YOffset + pitchOffsetY + 0.5)
    if Y1 > YSpanHalf then
      Y1 = YSpanHalf
    elseif Y1 < -YSpanHalf then
      Y1 = -YSpanHalf
    end


    if inverseYaxis == 0  then
    Y2 = YSpanHalf
      lcd.drawLine(X1, centerY + Y1, X1, centerY + Y2 + 1, SOLID, LINE_COLOR)
      lcd.drawLine(X1,centerY-Y2,X1,centerY+Y1-1,SOLID,CURVE_COLOR)
   else
    Y2= -YSpanHalf
      lcd.drawLine(X1, centerY + Y2, X1, centerY + Y1 , SOLID, LINE_COLOR)
      lcd.drawLine(X1,centerY+Y1,X1,centerY-Y2,SOLID,CURVE_COLOR)
   end

  end

  -- Draw a box (for testing)
  --lcd.drawRectangle(origX,origY,endX-origX+1,endY-origY+1, GREY(9))
  -- Patterns are masks from 8 bits numbers
  -- DASHED = 0x77
  -- DASH DOT DASH = 0x6B
  -- LONG DASHES = 0x33
  lcd.drawLine(origX,centerY,endX,centerY,0x77,CURVE_COLOR)



  -- Numbers for pitch and roll
  lcd.drawNumber(centerX-6, origY, Pitch, SMLSIZE)
  lcd.drawNumber(origX,centerY-8,Roll,SMLSIZE)
end


-- This function allow recording of lowest cells when widget is not active
local function background(myZone)
  -- getCels(myZone.options.Sensor)
  return
end

function refresh(myZone)
  if myZone.options.Shadow == 1 then
    shadowed = SHADOWED
  else
    shadowed = 0
  end



  -- Checking the size of the Zone selected
  origX=myZone.zone.x
  origY=myZone.zone.y
  endX=myZone.zone.x+myZone.zone.w-1
  endY=myZone.zone.y+myZone.zone.h-1
  centerX=math.floor((endX-origX)/2 + 0.5 + origX)
  centerY=math.floor((endY-origY)/2 + 0.5 + origY)
  --Pitch=debugFeed()
  --Roll=debugFeed()*6

  --lcd.clear()
  drawHorizon(myZone)
  --lcd.drawNumber(myZone.zone.x,myZone.zone.y,10,SMLSIZE)
end

return { name="ArtHor", options=options, create=create, update=update, background=background, refresh=refresh }