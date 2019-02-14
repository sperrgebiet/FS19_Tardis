Tardis = {};
Tardis.eventName = {};

Tardis.ModName = g_currentModName;
Tardis.ModDirectory = g_currentModDirectory;
Tardis.Version = "1.0.0.0";


Tardis.debug = fileExists(Tardis.ModDirectory ..'debug');

print(string.format('Tardis v%s - DebugMode %s)', Tardis.Version, tostring(Tardis.debug)));

addModEventListener(Tardis);

function Tardis:dp(val, fun, msg) -- debug mode, write to log
  if not Tardis.debug then
    return;
  end
  if msg == nil then
    msg = ' ';
  else
    msg = string.format(' msg = [%s] ', tostring(msg));
  end
  local pre = 'Tardis DEBUG:';
  if type(val) == 'table' then
    if #val > 0 then
      print(string.format('%s BEGIN Printing table data: (%s)%s(function = [%s()])', pre, tostring(val), msg, tostring(fun)));
      DebugUtil.printTableRecursively(val, '.', 0, 3);
      print(string.format('%s END Printing table data: (%s)%s(function = [%s()])', pre, tostring(val), msg, tostring(fun)));
    else
      print(string.format('%s Table is empty: (%s)%s(function = [%s()])', pre, tostring(val), msg, tostring(fun)));
    end
  else
    print(string.format('%s [%s]%s(function = [%s()])', pre, tostring(val), msg, tostring(fun)));
  end
end


function Tardis:prerequisitesPresent(specializations)
	return true;
end

function Tardis:loadMap(name)
	print("--- loading Tardis V".. Tardis.Version .. " | ModName " .. Tardis.ModName .. " ---");
end

function Tardis:onLoad(savegame)
	FSBaseMission.registerActionEvents = Utils.appendedFunction(FSBaseMission.registerActionEvents, Tardis.RegisterActionEvents);
end

function Tardis:RegisterActionEvents(isSelected, isOnActiveVehicle)

	local result, eventName = InputBinding.registerActionEvent(g_inputBinding, 'showTardisCursor',self, Tardis.action_showTardisCursor ,false ,true ,false ,true)
	if result then
		table.insert(Tardis.eventName, eventName);
		g_inputBinding.events[eventName].displayIsVisible = Tardis.config[13][2];
    end
		
end

function Tardis:removeActionEvents()
	Tardis.eventName = {};
	if Tardis.debug then
		print("--- Tardis Debug ... Tardis:removeActionEventsPlayer(Tardis.eventName)");
		DebugUtil.printTableRecursively(Tardis.eventName,"----",0,1)
	end
end

function Tardis.registerEventListeners(vehicleType)
	local functionNames = {	"onLoad" };
	
	for _, functionName in ipairs(functionNames) do
		SpecializationUtil.registerEventListener(vehicleType, functionName, Tardis);
	end
end

function Tardis:keyEvent(unicode, sym, modifier, isDown)
end

function Tardis:mouseEvent(posX, posY, isDown, isUp, button)
    if self.tardisOn then
        local mOX = g_currentMission.hud.ingameMap.mapPosX;
        local mOY = g_currentMission.hud.ingameMap.mapPosY;
        if posX >= mOX and posX <= mOX + g_currentMission.hud.ingameMap.mapWidth then
            self.worldXpos = (posX - mOX) / g_currentMission.hud.ingameMap.maxMapWidth;
        end;
        if posY >= mOY and posY <= mOY + g_currentMission.hud.ingameMap.mapHeight then
            self.worldZpos = 1 - (posY - mOY) / g_currentMission.hud.ingameMap.maxMapHeight;
        end;
        if isDown and button == 1 then
			if not g_currentMission:getIsServer() and g_currentMission.controlledVehicle then
                local xField = self.worldXpos * g_currentMission.terrainSize;
                local z = self.worldZpos * g_currentMission.terrainSize;
                local theVehicle = g_currentMission.controlledVehicle;
				g_client:getServerConnection():sendEvent(tardisEvent:new(xField, z, theVehicle));
			else
            	self:teleportToLocation(self.worldXpos * g_currentMission.terrainSize, self.worldZpos * g_currentMission.terrainSize);
			end;
            self.tardisOn = false;
            g_inputBinding:setShowMouseCursor(false);
        end;
        self.mousePos[1] = posX;
        self.mousePos[2] = posY;
    end
end

function Tardis:draw()
	if self.TardisOn then
	
		if g_currentMission.controlledVehicle and not g_currentMission.controlledVehicle:isa(RailroadVehicle) then
			self:DrawImage(g_currentMission.controlledVehicle,  self.ovrlX + 0.23, self.ovrlY)
			
			local vehName = g_currentMission.controlledVehicle:getName();
			
			if g_currentMission.controlledVehicle.getAttachedImplements ~= nil then
                local allAttached = {}
                local function addAllAttached(vehicle)
                    for _, implA in pairs(vehicle:getAttachedImplements()) do
                        addAllAttached(implA.object);
                        table.insert(allAttached, {vehicle = vehicle, object = implA.object, jointDescIndex = implA.jointDescIndex, inputAttacherJointDescIndex = implA.object.inputAttacherJointDescIndex});
                    end;
                end;
                
                addAllAttached(g_currentMission.controlledVehicle);
                
                for i = table.getn(allAttached), 1, -1 do
					self:DrawImage(allAttached[i].object,  self.ovrlX + 0.23 + 0.085 * i, self.ovrlY)				
                    name = name .. " + " .. allAttached[i].object:getName();
                end
            end
		end
		
		--if g_currentMission.controlledVehicle and g_currentMission.controlledVehicle:isa(RailroadVehicle) then
        --    name = "Train system!! are you sure what you doing?";
        --end
		
		--if g_currentMission.controlledVehicle and g_currentMission.controlledVehicle.combine then
        --    local fillLevel = g_currentMission.controlledVehicle:getUnitFillLevel(g_currentMission.controlledVehicle.overloading.fillUnitIndex);
        --    if fillLevel > 0 then
        --        g_currentMission:showBlinkingWarning(g_i18n:getText("warning_combine"));
        --    end
        --end
		
		if self.mousePos[1] > ovrlX then
            px = -(string.len(name) * 0.005) - 0.03;
        end

        if self.mousePos[2] > ovrlY then
            py = -0.04;
        end
        renderText(self.mousePos[1] + px, self.mousePos[2] + py, getCorrectTextSize(0.016), name);
        setTextAlignment(RenderText.ALIGN_RIGHT)
        setTextBold(false)
        setTextColor(0, 1, 0.4, 1)
        renderText(g_currentMission.inGameMenu.hud.ingameMap.mapPosX + g_currentMission.inGameMenu.hud.ingameMap.mapWidth - g_currentMission.inGameMenu.hud.ingameMap.coordOffsetX, g_currentMission.inGameMenu.hud.ingameMap.mapPosY + g_currentMission.inGameMenu.hud.ingameMap.coordOffsetY + 0.010, g_currentMission.inGameMenu.hud.ingameMap.fontSize, string.format(" [%04d", self.worldXpos * g_currentMission.terrainSize) .. string.format(",%04d]", self.worldZpos * g_currentMission.terrainSize));
        setTextColor(1, 1, 1, 1)
        setTextAlignment(RenderText.ALIGN_LEFT)
		
	end
end

end

function Tardis:delete()
end

function Tardis:deleteMap()
end

-- Functions for actionEvents/inputBindings

function Tardis:action_showTardisCursor(actionName, keyStatus, arg3, arg4, arg5)
	Tardis:dp("action_showTardisCursor fires", "action_showTardisCursor");
	self.ShowTardis();
end


--
-- Tardis specific functions
--

function Tardis:InitTardis()
	Tardis.paddingX = 0.01;
	Tardis.paddingY = 0.005;
	Tardis.overlayX = g_currentMission.inGameMenu.hud.ingameMap.mapWidth / 2;
	Tardis.overlayY = g_currentMission.inGameMenu.hud.ingameMap.mapHeight / 2;
	Tardis.playerName = g_gameSettings.nickname;
end


function Tardis:ShowTardis()

    if (g_currentMission.hud.ingameMap.isVisible and g_currentMission.hud.ingameMap.state == IngameMap.STATE_MAP) then
		Tardis.tardisOn = not Tardis.tardisOn;
		if Tardis.tardisOn then
			g_inputBinding:setShowMouseCursor(true);
		else
			g_inputBinding:setShowMouseCursor(false);
		end;
    end;

	local mCurStat = InputBinding.getShowMouseCursor();
	if tardis.tardisOn and not mCurStat then
		g_inputBinding:setShowMouseCursor(true);
	end;
end

function Tardis:teleportToLocation(xField, z, theVehicle)
    
    xField = tonumber(xField);
    z = tonumber(z);
    if xField == nil then
        return;
    end;

    if theVehicle == nil then
        theVehicle = g_currentMission.controlledVehicle;
    end;
    
    local targetX, targetY, targetZ = 0, 0, 0;
    if z == nil then
        if g_fieldManager.fields ~= nil then
            targetX, targetY, targetZ = getWorldTranslation(g_fieldManager.fields[xField].mapHotspot);
        else
            return;
        end;
    else
        local worldSizeX = g_currentMission.hud.ingameMap.worldSizeX;
        local worldSizeZ = g_currentMission.hud.ingameMap.worldSizeZ;
        targetX = Utils.clamp(xField, 0, worldSizeX) - worldSizeX * 0.5;
        targetZ = Utils.clamp(z, 0, worldSizeZ) - worldSizeZ * 0.5;
    end;
    
    if theVehicle == nil then
        Player:moveTo(targetX, 0.5, targetZ);
    else
        local vehicleCombos = {};
        local vehicles = {};
        local function addVehiclePositions(vehicle)
            local x, y, z = getWorldTranslation(vehicle.rootNode);
            table.insert(vehicles, {vehicle = vehicle, offset = {worldToLocal(theVehicle.rootNode, x, y, z)}});
            
            for _, impl in pairs(vehicle.attachedImplements) do
                addVehiclePositions(impl.object);
                table.insert(vehicleCombos, {vehicle = vehicle, object = impl.object, jointDescIndex = impl.jointDescIndex, inputAttacherJointDescIndex = impl.object.inputAttacherJointDescIndex});
            end;
            
            for i = table.getn(vehicle.attachedImplements), 1, -1 do
                vehicle:detachImplement(1, true);
            end;
            --if not vehicle:isa(RailroadVehicle) then  -- rimuovere se ci sono problemi.
                vehicle:removeFromPhysics();
            --end;
        end;
        
        addVehiclePositions(theVehicle);
        
        for k, data in pairs(vehicles) do
            local x, y, z = targetX, targetY, targetZ;
            if k > 1 then
                x, _, z = localToWorld(theVehicle.rootNode, unpack(data.offset));
            end;
            local _, ry, _ = getWorldRotation(data.vehicle.rootNode);
            data.vehicle:setRelativePosition(x, 0.5, z, ry, true);
            data.vehicle:addToPhysics();
        end
        
        for _, combo in pairs(vehicleCombos) do
            combo.vehicle:attachImplement(combo.object, combo.inputAttacherJointDescIndex, combo.jointDescIndex, true, nil, nil, false);
        end
    end

end

function Tardis:DrawImage(obj, imgX, imgY)
	local imgFileName = Tardis:getStoreImageByConf(obj.configFileName);

	local storeImage = createImageOverlay(imgFileName);
	if storeImage > 0 then
		local storeImgX, storeImgY = getNormalizedScreenValues(128, 128)
		renderOverlay(storeImage, imgX, imgY, storeImgX, storeImgY)
	end
end

function Tardis:getStoreImageByConf(confFile)
	local storeItem = g_storeManager.xmlFilenameToItem[string.lower(confFile)];
	if storeItem ~= nil then
		local imgFileName = storeItem.imageFilename;
		if string.find(imgFileName, 'locomotive') then
			imgFileName = "data/store/store_empty.png";
		end
		return imgFileName;
	end
end

--- client/server event part---
TardisEvent = {};
TardisEvent_mt = Class(TardisEvent, Event);

InitEventClass(TardisEvent, "TardisEvent");

function TardisEvent:emptyNew()
    local self = Event:new(TardisEvent_mt);
    return self;
end;

function TardisEvent:new(xField, z, vehicle)
    local self = TardisEvent:emptyNew()
    self.xField = xField;
    self.z = z;
    self.vehicle = vehicle
    return self;
end;

function TardisEvent:readStream(streamId, connection)
    self.xField = streamReadFloat32(streamId);
    self.z = streamReadFloat32(streamId);
    self.vehicle = readNetworkNodeObject(streamId);
    self:run(connection);
end;

function TardisEvent:writeStream(streamId, connection)
    streamWriteFloat32(streamId, self.xField);
    streamWriteFloat32(streamId, self.z);
    writeNetworkNodeObject(streamId, self.vehicle);
end;

function TardisEvent:run(connection)
    if not connection:getIsServer() then
        g_currentMission.TardisBase:teleportToLocation(self.xField, self.z, self.vehicle);
    end;
end;