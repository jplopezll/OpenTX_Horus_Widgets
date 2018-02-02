-- Widget script for Taranis Horus X10, X10S, 12S
--   Data from FrSky S.Port passthrough
--   Optimised for LCD color screen size: 480*272
--
-- This script reuses some coding found in:
--   https://github.com/jplopezll/OpenTX_FrSkySPort_passthrough_master
--   by Juan Pedro López
-- 
-- For FrSky S.Port and Ardupilot passthrough protocol check:
--   https://cdn.rawgit.com/ArduPilot/ardupilot_wiki/33cd0c2c/images/FrSky_Passthrough_protocol.xlsx
--
-- Copyright (C) 2018. Juan Pedro López
--   https://github.com/jplopezll
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY, without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, see <http://www.gnu.org/licenses>.
--


-- Implementation of messages queue (up t0 10 will be recorded, scroll with + a - keys)
local msgsDisplay=0         -- Message to be displayed
local msgsRcvdPos=0         -- Index to position of the last messaged received
local msgsChunksMax=9       -- Maximum number of 4xchunks to be stored
local msgsChunksIndex=0     -- Index to current chunk beeing received
local msgsRcvd={}       -- FIFO bBuffer with the last 10 messages received from S.Port
  msgsRcvd[0]=""
  msgsRcvd[1]=""
  msgsRcvd[2]=""
  msgsRcvd[3]=""
  msgsRcvd[4]=""
  msgsRcvd[5]=""
  msgsRcvd[6]=""
  msgsRcvd[7]=""
  msgsRcvd[8]=""
  msgsRcvd[9]=""

local SeverityMeaning = {}
  SeverityMeaning[0]="[Emrg]"
  SeverityMeaning[1]="[Alrt]"
  SeverityMeaning[2]="[Crit]"
  SeverityMeaning[3]="[Err]"
  SeverityMeaning[4]="[Wrng]"
  SeverityMeaning[5]="[Noti]"
  SeverityMeaning[6]="[Info]"
  SeverityMeaning[7]="[Debg]"
  SeverityMeaning[8]="[]"

local FlightModeName = {}
  -- Pixhawk Flight Modes verified
  FlightModeName[0]="ND"
  FlightModeName[1]="Stabilize"
  FlightModeName[2]="ND"
  FlightModeName[3]="Alt Hold"
  FlightModeName[4]="ND"
  FlightModeName[5]="ND"
  FlightModeName[6]="Loiter"
  FlightModeName[7]="RTL"
  FlightModeName[8]="Circle"
  FlightModeName[9]="ND"
  FlightModeName[10]="ND"
  FlightModeName[11]="ND"
  FlightModeName[12]="Drift"
 
  FlightModeName[31]="No Telemetry"


local drawSection={}     -- Track what sections to redraw
  drawSection[0]=0
  drawSection[1]=0
  drawSection[2]=0
  drawSection[3]=0
  drawSection[4]=0
  drawSection[5]=0
  drawSection[6]=0
  drawSection[7]=0
  drawSection[8]=0


-- Rounding function
local function round(num) 
  if num >= 0 then return math.floor(num + 0.5)
  else return math.ceil(num - 0.5) end
end


local function draw5000(zone)
  -- Page footer area (passthrough messages)
  --lcd.drawFilledRectangle(zone.zone.x, zone.zone.y, zone.zone.x + zone.zone.w , zone.zone.y + zone.zone.h ,INVERS)
  --lcd.drawFilledRectangle(zone.zone.x,zone.zone.y,zone.zone.x+zone.zone.w,zone.zone.y+zone.zone.h)
  lcd.drawText(zone.zone.x, zone.zone.y,((msgsRcvdPos+9-msgsDisplay)%10)..msgsRcvd[msgsDisplay],SMLSIZE)
  --lcd.drawFilledRectangle(0,57,212,7,GREY(12))

  drawSection[0]=0
end


local shadowed  = 0


-- Function to move values in Companion simulator
local function debugFeed()
  return getDateTime().sec
end


local options = {
  { "Shadow", BOOL, 0 }
}

-- This function is runned once at the creation of the widget
local function create(zone, options)
  local myZone  = { zone=zone, options=options, counter=0 }
  histCellData = {}

  lcd.setColor(CURVE_COLOR, lcd.RGB(0, 163, 224)) -- Sky blue
  lcd.setColor(LINE_COLOR, lcd.RGB(229, 114, 0)) -- Land

  -- (I) Means decoding is already implemented
  -- 0x0800         -- No need to implement. Directly accessible via normal sensors discovery
  --GLatitude=0     -- 32 bits. Degrees
  --GLongitude=0    -- (I) 32 bits. Degrees

  -- 0x5000         -- (I) 32 bits. Sending 4 characters with 7 bits at a time. Msg sent 3 times.
  MsgSeverity=8     -- (I) 3 bits. Severity is sent as the MSB of each of the last three bytes of the last chunk (bits 24, 16, and 8) since a character is on 7 bits.
  MsgText=""        -- (I) 28 bits. The 7 LSB bits of each byte.
  MsgLastReceived="Nothing"
  MsgLastChunk=0
  MsgPrevChunk=""
  MsgByte1=0        -- (I) For the LSB of the message, bits 0 to 7
  MsgByte2=0        -- (I)    bits 8 to 15
  MsgByte3=0        -- (I)    bits 16 to 23
  MsgByte4=0        -- (I) For the MSB of the message, bits 24 to 31

  -- 0x5001
  StatusFtMode=31   -- (I) 5 bits
  --StatusSimpleSS=0  -- 2 bits
  StatusLandComp=0  -- (I) 1 bit
  StatusArmed=0     -- (I) 1 bit
  StatusBatFS=0     -- (I) 1 bit
  StatusEKFFS=0     -- (I) 1 bit

  -- 0x5002
  GPSNumSats=0      -- (I) 4 bits
  GPSFix=0          -- (I) 2 bits. NO_GPS=0, NO_FIX=1, GPS_OK_FIX_2D=2, GPS_OK_FIX_3D>=3 - 4 3D Fix alta precisión
  --GPSHDOP=0       -- (I) 1+7 bits. 10^x + dm
  --GPSVDOP=0       -- (I) 1+7 bits. 10^x + dm
  GPSAlt=0          -- (I) 2+7+1 bits. 10^x + dm * sign

  -- 0x5003
  UAVBatVolt=0      -- (I) 9 bits. dV
  UAVCurr=0         -- (I) 1+7 bits. 10^x + dA
  UAVCurrTot=0      -- (I) 15 bits. mAh. Limit to 32767 = 15 bits

  -- 0x5004
  HomeDist=0        -- (I) 2+10 bits. 10^x + m.
  HomeAngle=0       -- (I) 7 bits. Multiply by 3 to get degrees
  HomeAlt=0         -- (I) 2+10+1 bit. 10^x + dm * sign

  -- 0x5005
  SpdVert=0         -- (I) 1+7+1 bits. 10^x + dm * sign
  SpdHor=0          -- (I) 1+7 bits. 10^x + dm
  Yaw=0             -- (I) 11 bits. 0.2 degrees.

  -- 0x5006
  Roll=0            -- (I) 11 bits. 0.2 egrees.
  Pitch=0           -- (I) 10 bits. 0.2 degrees.
  --RngFindDist=0     -- 1+10 bits. 10^x + cm.

  -- 0x5007         -- 8 bits. Reserve fist 8 bits for param ID
  MAVType=0         -- (I) 8 bits.
  UAVBattCapacity=5800   -- (I) 24 bits. mAh
  UAVBattCapResFS=0 -- (I) 24 bits. mAh
  UAVBattVoltFS=0   -- (I) 4 bits. dV

  -- Local Taranis variables getValue
  --TxVoltageId=getFieldInfo("tx-voltage").id   -- (I) 
  --TxVoltage = getValue(TxVoltageId)           -- (I) 
  --Timer1Id=getFieldInfo("timer1").id          -- (I) 
  --Timer1=getValue(Timer1Id)                   -- (I) 
  --RSSIPerId=getFieldInfo("RSSI").id           -- (I) 
  --RSSIPer=getValue(RSSIPerId)                 -- (I) 

  return myZone
end

-- This function allow updates when you change widgets settings
local function update(myZone, options)
  myZone.options = options
end


-- This function allow recording of lowest cells when widget is not active
local function background()
  -- Prepare to extract SPort data
  local sensorID,frameID,dataID,value = sportTelemetryPop()
  while dataID~=nil do
    -- unpack 0x5000  -- 32 bits. Sending 4 characters with 7 bits at a time. Msg sent 3 times.
    -- 0x5000         -- (I) 32 bits. Sending 4 characters with 7 bits at a time. Msg sent 3 times.
    --MsgSeverity=0     -- (I) 3 bits. Severity is sent as the MSB of each of the last three bytes of the last chunk (bits 24, 16, and 8) since a character is on 7 bits.
    --MsgText=" "       -- (I) 28 bits. The 7 LSB bits of each byte.
    --MsgLastReceived="No messages"
    --MsgLastChunk=0
    --MsgPrevChunk=""
    --MsgByte1=0        -- (I) For the LSB of the message, bits 0 to 7
    --MsgByte2=0        -- (I)    bits 8 to 15
    --MsgByte3=0        -- (I)    bits 16 to 23
    --MsgByte4=0        -- (I) For the MSB of the message, bits 24 to 31
    if dataID == 0x5000 then
      MsgByte1=bit32.extract(value,0,7)      -- For the LSB of the message, bits 0 to 7
      MsgByte2=bit32.extract(value,8,7)      --    bits 8 to 15
      MsgByte3=bit32.extract(value,16,7)     --    bits 16 to 23
      MsgByte4=bit32.extract(value,24,7)     -- For the MSB of the message, bits 24 to 31

      -- Decode the 32 bits chunk, 4 bytes
      local MsgNewChunk=""
      if (MsgByte4~=0) then
        MsgNewChunk=string.char(MsgByte4)
      else
        MsgLastChunk=1
      end
      if (MsgByte3~=0) then
        MsgNewChunk=MsgNewChunk..string.char(MsgByte3)
      else
        MsgLastChunk=1
      end
      if (MsgByte2~=0) then
        MsgNewChunk=MsgNewChunk..string.char(MsgByte2)
      else
        MsgLastChunk=1
      end
      if (MsgByte1~=0) then
        MsgNewChunk=MsgNewChunk..string.char(MsgByte1)
      else
        MsgLastChunk=1
      end

      -- If the new chunk is different from the last one and there is space, write
      if (MsgPrevChunk~=MsgNewChunk and msgsChunksIndex<msgsChunksMax) then
        MsgText=MsgText..MsgNewChunk
        MsgPrevChunk=MsgNewChunk
        msgsChunksIndex=msgsChunksIndex+1
      end

      -- If end of message detected, get severity, store in buffer and increment index
      if MsgLastChunk==1 then
        if MsgText~="" then
          MsgSeverity=(bit32.extract(value,23,1)*4)+(bit32.extract(value,15,1)*2)+bit32.extract(value,7,1)
          msgsRcvd[msgsRcvdPos]=SeverityMeaning[MsgSeverity]..MsgText
          msgsDisplay=msgsRcvdPos    -- This will set the display to the last received message (0)
          msgsRcvdPos=(msgsRcvdPos+1)%10
        end

        MsgLastChunk=0
        MsgText=""
        msgsChunksIndex=0
        -- Draw received data
        drawSection[0]=drawSection[0]+1
      end

    end

    -- unpack 0x5001 packet
    if dataID == 0x5001 then
      StatusFtMode=bit32.extract(value,0,5)    -- 5 bits
      --StatusSimpleSS=bit32.extract(value,5,2)  -- 2 bits
      StatusLandComp=bit32.extract(value,7,1)    -- 1 bit
      StatusArmed=bit32.extract(value,8,1)     -- 1 bit
      StatusBatFS=bit32.extract(value,9,1)     -- 1 bit
      StatusEKFFS=bit32.extract(value,10,1)     -- 1 bit

      -- Draw received data
      drawSection[1]=drawSection[1]+1
    end

    -- unpack 0x5002 packet
    if dataID == 0x5002 then
      GPSNumSats = bit32.extract(value,0,4)
      GPSFix = bit32.extract(value,4,2)
      --GPSHDOP = bit32.extract(value,7,7)*(10^(bit32.extract(value,6,1)-1))
      --GPSVDOP = bit32.extract(value,15,7)*(10^(bit32.extract(value,14,1)-1))
      GPSAlt = bit32.extract(value,24,7)*(10^bit32.extract(value,22,2))  -- In dm
      --if (bit32.extract(value,31,1) == 1) then GPSAlt = -GPSAlt end

      -- Draw received data
      drawSection[2]=drawSection[2]+1
    end

    -- unpack 0x5003 packet
    if dataID == 0x5003 then
      UAVBatVolt=bit32.extract(value,0,9) -- 9 bits. dV
      UAVCurr=bit32.extract(value,10,7)*(10^bit32.extract(value,9,1)) -- 1+7 bits. 10^x + dA
      UAVCurrTot=bit32.extract(value,17,15) -- 15 bits. mAh. Limit to 32767 = 15 bits

      -- Draw received data
      drawSection[3]=drawSection[3]+1
    end

     -- unpack 0x5004 packet
    if dataID == 0x5004 then
      HomeDist=bit32.extract(value,2,10)*(10^bit32.extract(value,0,2)) -- 2+10 bits. 10^x + m.
      HomeAngle=bit32.extract(value,12,7)*3 -- 7 bits. By 3 to get up to 360 degrees.
      HomeAlt=bit32.extract(value,21,10)*(10^bit32.extract(value,19,2)) -- 2+10+1 bit. 10^x + dm * sign
      if (bit32.extract(value,31,1) == 1) then HomeAlt = -HomeAlt end

      -- Draw received data
      drawSection[4]=drawSection[4]+1
    end
   
    -- unpack 0x5005 packet
    if dataID == 0x5005 then
     SpdVert= bit32.extract(value,1,7)*(10^bit32.extract(value,0,1)) -- 1+7+1 bits. 10^x + dm * sign
     if (bit32.extract(value,8,1) == 1) then SpdVert = -SpdVert end
     SpdHor=bit32.extract(value,10,7)*(10^bit32.extract(value,9,1)) -- 1+7 bits. 10^x + dm (per second?)
     Yaw = bit32.extract(value,17,11) * 0.2

      -- Draw received data
      drawSection[5]=drawSection[5]+1
    end
    
    -- unpack 0x5006 packet
    if dataID == 0x5006 then
      Roll = (bit32.extract(value,0,11) - 900) * 0.2
      Pitch = (bit32.extract(value,11,10 ) - 450) * 0.2

      -- Draw received data
      drawSection[6]=drawSection[6]+1
      --drawSection[5]=drawSection[5]+1
    end

    -- unpack 0x5007 packet
    if dataID == 0x5007 then
      -- 0x5007         -- 8 bits. Reserve fist 8 bits for param ID
      local ParamID=bit32.extract(value,24,8)
      --if ParamID==0x10 then MAVType=bit32.extract(value,0,8) end -- 8 bits.
      if ParamID==0x20 then UAVBattCapacity=bit32.extract(value,0,24) end -- 24 bits. mAh
      if ParamID==0x30 then UAVBattCapResFS=bit32.extract(value,0,24) end -- 24 bits. mAh
      if ParamID==0x40 then UAVBattVoltFS=bit32.extract(value,0,24) end -- 24 bits. dV

      -- Draw received data
      drawSection[7]=drawSection[7]+1
    end

    -- Update normal local telemetry data by its id (faster method)

    if runTime > (lastUpdtTelem+timeToTelemUpdt) then
      lastUpdtTelem=runTime
      TxVoltage = getValue(TxVoltageId)
      Timer1=getValue(Timer1Id)
      RSSIPer=getValue(RSSIPerId)

      -- Draw received data
      drawSection[8]=drawSection[8]+1

      -- Redraw all the screen
      screenCleared=0
    end

    -- Check if there are messages in the queue to avoid exit from the while-do loop
    sensorID,frameID,dataID,value = sportTelemetryPop()
  end
  return
end


---------------------------------------------------------------
-- Visible loop function
---------------------------------------------------------------
function refresh(myZone)
  -- Call the background function for queue extraction while on focus
  background()

  -- Capture key press events
  --if (e==EVT_PLUS_FIRST) then msgsDisplay=(msgsDisplay+1)%10 end
  --if (e==EVT_MINUS_FIRST) then msgsDisplay=(msgsDisplay+9)%10 end



  -- Draw received messages
  draw5000(myZone)

  -- Checking the size of the Zone selected


  -- Calculate params to be passed to other scripts
  Pitch=debugFeed()
  Roll=debugFeed()*6

end

return { name="PssThrgMsg", options=options, create=create, update=update, background=background, refresh=refresh }