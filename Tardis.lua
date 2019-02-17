-- fcelsa ...from a gift of TyKonKet and Giants...
--
--
-- 2017-03

Tardis = {};
Tardis.eventName = {};

Tardis.ModName = g_currentModName;
Tardis.ModDirectory = g_currentModDirectory;
Tardis.Version = "0.0.0.1";

-- Integration environment for VehicleExplorer
envVeEx = {};

Tardis.camBackup = nil;

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
	FSBaseMission.registerActionEvents = Utils.appendedFunction(FSBaseMission.registerActionEvents, Tardis.RegisterActionEvents);
	
	Tardis.tardisOn = false;
    Tardis.mousePos = {0.5, 0.5};
    Tardis.worldXpos = 0;
    Tardis.worldZpos = 0;
    Tardis.fieldNumber = 1;
	
	-- Integration with Vehicle Explorer
	local VeExName = "FS19_VehicleExplorer";

	if g_modIsLoaded[VeExName] then
		envVeEx = getfenv(0)[VeExName];
		print("Tardis: VehicleExplorer integration available");
	end
end

function Tardis:RegisterActionEvents(isSelected, isOnActiveVehicle)

	local result, eventName = InputBinding.registerActionEvent(g_inputBinding, 'showTardisCursor',self, Tardis.action_showTardisCursor ,false ,true ,false ,true)
	if result then
		table.insert(Tardis.eventName, eventName);
		g_inputBinding.events[eventName].displayIsVisible = true;
    end
	
	local result, eventName = InputBinding.registerActionEvent(g_inputBinding, 'resetVehicle',self, Tardis.action_resetVehicle ,false ,true ,false ,true)
	if result then
		table.insert(Tardis.eventName, eventName);
		g_inputBinding.events[eventName].displayIsVisible = true;
    end
		
end

function Tardis:keyEvent(unicode, sym, modifier, isDown)
end

function Tardis:mouseEvent(posX, posY, isDown, isUp, button)
	--Tardis:dp(string.format('posX {%s) posY {%s}', posX, posY));
    if Tardis.tardisOn then
        local mOX = g_currentMission.hud.ingameMap.mapPosX;
        local mOY = g_currentMission.hud.ingameMap.mapPosY;
        if posX >= mOX and posX <= mOX + g_currentMission.hud.ingameMap.mapWidth then
            Tardis.worldXpos = (posX - mOX) / g_currentMission.hud.ingameMap.maxMapWidth;
        end;
        if posY >= mOY and posY <= mOY + g_currentMission.hud.ingameMap.mapHeight then
            Tardis.worldZpos = 1 - (posY - mOY) / g_currentMission.hud.ingameMap.maxMapHeight;
        end;
        if isDown and button == Input.MOUSE_BUTTON_LEFT then
			Tardis:dp(string.format('posX {%s} posY {%s} - mOX {%s} mOY {%s} - worldXpos {%s} worldZpos {%s}', posX, posY, mOX, mOY, Tardis.worldXpos, Tardis.worldZpos));
			if not g_currentMission:getIsServer() and g_currentMission.controlledVehicle then
                local xField = Tardis.worldXpos * g_currentMission.terrainSize;
                local z = Tardis.worldZpos * g_currentMission.terrainSize;
                local theVehicle = g_currentMission.controlledVehicle;
				g_client:getServerConnection():sendEvent(tardisEvent:new(xField, z, theVehicle));
			else
			--Tardis:dp(string.format('telePort param1 {%s} - param2 {%s}', Tardis.worldXpos * g_currentMission.terrainSize, Tardis.worldZpos * g_currentMission.terrainSize));
            Tardis:teleportToLocation(Tardis.worldXpos * g_currentMission.terrainSize, Tardis.worldZpos * g_currentMission.terrainSize);
			end;
            Tardis.tardisOn = false;
            g_inputBinding:setShowMouseCursor(false);
        end;
        Tardis.mousePos[1] = posX;
        Tardis.mousePos[2] = posY;
    end
end

function Tardis:draw()
	if Tardis.tardisOn then
	    --local ovrlX = g_currentMission.hud.ingameMap.mapPosX + g_currentMission.hud.ingameMap.mapWidth / 2;
		--local ovrlX = g_currentMission.hud.ingameMap.mapPosX + g_currentMission.hud.ingameMap.mapOffsetX + getTextWidth(g_currentMission.hud.ingameMap.mapLabelTextSize, g_currentMission.hud.ingameMap.mapLabelText);
		--local ovrlX = g_currentMission.hud.ingameMap.mapPosX + getTextWidth(g_currentMission.hud.ingameMap.mapLabelTextSize, g_currentMission.hud.ingameMap.mapLabelText);
		local ovrlX = g_currentMission.hud.ingameMap.mapPosX + getTextWidth(g_currentMission.hud.ingameMap.mapLabelTextSize, g_currentMission.hud.ingameMap.mapLabelText);
		local ovrlY = g_currentMission.hud.ingameMap.mapPosY + g_currentMission.hud.ingameMap.maxMapHeight;
        local px = 0.01;
        local py = 0.005;	
		local name;
		local theVehicle;
		local drawImage = false;		--There are so many cases where we don't want to draw a image, so easier to just set it to true in case it's the currently controlled vehicle
		
		if envVeEx ~= nil and g_currentMission.controlledVehicle == nil then
			if envVeEx.VehicleSort.showSteerables and envVeEx.VehicleSort.config[22][2] then
				local realVeh = g_currentMission.vehicles[envVeEx.VehicleSort.Sorted[envVeEx.VehicleSort.selectedIndex]];
				if realVeh ~= nil then
					theVehicle = realVeh;
				end
			end
		elseif g_currentMission.controlledVehicle ~= nil then
			theVehicle = g_currentMission.controlledVehicle;
			drawImage = true;
		end
		
		if theVehicle ~= nil then
			--Get image size
			local storeImgX, storeImgY = getNormalizedScreenValues(128, 128)
				
			if drawImage then
				Tardis:DrawImage(theVehicle, ovrlX, ovrlY)
			end
			
			name = theVehicle:getName();
			
			if theVehicle.getAttachedImplements ~= nil then
                local allAttached = {}
                local function addAllAttached(vehicle)
                    for _, implA in pairs(vehicle:getAttachedImplements()) do
                        addAllAttached(implA.object);
                        table.insert(allAttached, {vehicle = vehicle, object = implA.object, jointDescIndex = implA.jointDescIndex, inputAttacherJointDescIndex = implA.object.inputAttacherJointDescIndex});
                    end
                end
                
                addAllAttached(theVehicle);
                
                for i = table.getn(allAttached), 1, -1 do
					if drawImage then
						Tardis:DrawImage(allAttached[i].object, ovrlX + storeImgX * i, ovrlY)				
					end

                    name = name .. " + " .. allAttached[i].object:getName();
                end
            end
		end
		
		if theVehicle and Tardis:isTrain(theVehicle) then
			g_currentMission:showBlinkingWarning(g_i18n.modEnvironments[Tardis.ModName].texts.warning_train, 2000);
            name = theVehicle:getName();
        end
		
		if theVehicle and Tardis:isCrane(theVehicle) then
			g_currentMission:showBlinkingWarning(g_i18n.modEnvironments[Tardis.ModName].texts.warning_crane, 2000);
            name = theVehicle:getName();
        end		
		
		if name == nil or string.len(name) == 0 then
			name = string.format('%s %s', g_i18n.modEnvironments[Tardis.ModName].texts.lonelyFarmer, g_gameSettings.nickname);
		end
		
		if theVehicle and theVehicle.spec_combine then
			local fillLevelTable = {};
			theVehicle:getFillLevelInformation(fillLevelTable);
			
			for _,fillLevelVehicle in pairs(fillLevelTable) do
				fillLevel = fillLevelVehicle.fillLevel;
			end
			
			if fillLevel > 0 then
                g_currentMission:showBlinkingWarning(g_i18n.modEnvironments[Tardis.ModName].texts.warning_combine, 2000);
            end
        end
		
		if Tardis.mousePos[1] > ovrlX then
            px = -(string.len(name) * 0.005) - 0.03;
        end

        if Tardis.mousePos[2] > ovrlY then
            py = -0.04;
        end

        renderText(Tardis.mousePos[1] + px, Tardis.mousePos[2] + py, getCorrectTextSize(0.016), name);
        setTextAlignment(RenderText.ALIGN_RIGHT)
        setTextBold(false)
        setTextColor(0, 1, 0.4, 1)
        renderText(g_currentMission.inGameMenu.hud.ingameMap.mapPosX + g_currentMission.inGameMenu.hud.ingameMap.mapWidth - g_currentMission.inGameMenu.hud.ingameMap.coordOffsetX, g_currentMission.inGameMenu.hud.ingameMap.mapPosY + g_currentMission.inGameMenu.hud.ingameMap.coordOffsetY + 0.010, g_currentMission.inGameMenu.hud.ingameMap.fontSize, string.format(" [%04d", Tardis.worldXpos * g_currentMission.terrainSize) .. string.format(",%04d]", Tardis.worldZpos * g_currentMission.terrainSize));
        setTextColor(1, 1, 1, 1)
        setTextAlignment(RenderText.ALIGN_LEFT)
		
	end
end

function Tardis:delete()
end

function Tardis:deleteMap()
end

-- Functions for actionEvents/inputBindings

function Tardis:action_showTardisCursor(actionName, keyStatus, arg3, arg4, arg5)
	Tardis:dp("action_showTardisCursor fires", "action_showTardisCursor");
	Tardis:ShowTardis();
end

function Tardis:action_resetVehicle(actionName, keyStatus, arg3, arg4, arg5)
	Tardis:dp("action_resetVehicle fires", "action_resetVehicle");
	
	if g_currentMission.controlledVehicle then
		-- We can provide dummy values, as we'll do the actual stuff in the teleport function
		Tardis:teleportToLocation(0, 0, nil, true);
	end
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
			--if Tardis.camBackup == nil then
			--	if g_currentMission.controlledVehicle ~= nil then
			--		Tardis.camBackup = {};
			--		for	i, v in ipairs(g_currentMission.controlledVehicle.spec_enterable.cameras) do
			--			local cam = {i, v.isRotatable};
			--			table.insert(Tardis.camBackup, cam);
			--			v.isRotatable = false;
			--		end
			--	else
			--		Tardis.camBackup = g_currentMission.player.inputInformation.isMouseRotation;
			--		g_currentMission.player.inputInformation.isMouseRotation = false;
			--	end
			--end
		else
			Tardis.tardisOn = false;
			g_inputBinding:setShowMouseCursor(false);
			
			--if Tardis.camBackup ~= nil then
			--	if g_currentMission.controlledVehicle ~= nil then
			--		for _, v in ipairs(Tardis.camBackup) do
			--			g_currentMission.controlledVehicle.spec_enterable.cameras[v[1]].isRotatable = v[2];
			--		end
			--		Tardis.camBackup = nil;
			--	else
			--		g_currentMission.player.inputInformation.isMouseRotation = Tardis.camBackup;
			--		Tardis.camBackup = nil;
			--	end
			--end
		end
	elseif Tardis.tardisOn then
		Tardis.tardisOn = false;
		g_inputBinding:setShowMouseCursor(false);
    end
end

function Tardis:teleportToLocation(xField, z, theVehicle, isReset)
    
    xField = tonumber(xField);
    z = tonumber(z);
    if xField == nil then
        return;
    end;

	if envVeEx ~= nil then
		if envVeEx.VehicleSort.showSteerables and envVeEx.VehicleSort.config[22][2] then
			local realVeh = g_currentMission.vehicles[envVeEx.VehicleSort.Sorted[envVeEx.VehicleSort.selectedIndex]];
			if realVeh ~= nil then
				theVehicle = realVeh;
			end
		end
	end
	
    if theVehicle == nil then
        theVehicle = g_currentMission.controlledVehicle;
    end

	local targetX, targetY, targetZ = 0, 0, 0;
	
    if not isReset then	
		if z == nil then
			if g_fieldManager.fields ~= nil then
				targetX, targetY, targetZ = getWorldTranslation(g_fieldManager.fields[xField].mapHotspot);
			else
				return;
			end;
		else
			local worldSizeX = g_currentMission.hud.ingameMap.worldSizeX;
			local worldSizeZ = g_currentMission.hud.ingameMap.worldSizeZ;
			targetX = MathUtil.clamp(xField, 0, worldSizeX) - worldSizeX * 0.5;
			targetZ = MathUtil.clamp(z, 0, worldSizeZ) - worldSizeZ * 0.5;
		end
    else
		targetX, targetY, targetZ = getWorldTranslation(g_currentMission.controlledVehicle.rootNode);
	end
	
	Tardis:dp(string.format('targetX {%s} - targetZ {%s}', tostring(targetX), tostring(targetZ)), 'teleportToLocation');
	
    if theVehicle == nil and not isReset then
		g_currentMission.player:moveTo(targetX, 0.5, targetZ, false, false);
    else
        local vehicleCombos = {};
        local vehicles = {};

        local function addVehiclePositions(vehicle)
            local x, y, z = getWorldTranslation(vehicle.rootNode);
            table.insert(vehicles, {vehicle = vehicle, offset = {worldToLocal(theVehicle.rootNode, x, y, z)}});
            
			if #vehicle:getAttachedImplements() > 0 then
				for _, impl in pairs(vehicle:getAttachedImplements()) do
					addVehiclePositions(impl.object);
					table.insert(vehicleCombos, {vehicle = vehicle, object = impl.object, jointDescIndex = impl.jointDescIndex, inputAttacherJointDescIndex = impl.object.spec_attachable.inputAttacherJointDescIndex});
				end
				
				for i = table.getn(vehicle:getAttachedImplements()), 1, -1 do
					vehicle:detachImplement(1, true);
				end
			end

--ToDo
--            if not vehicle:isa(RailroadVehicle) then  -- rimuovere se ci sono problemi.
                vehicle:removeFromPhysics();
--            end
        end
        
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
        
		if #vehicleCombos > 0 then
			for _, combo in pairs(vehicleCombos) do
				combo.vehicle:attachImplement(combo.object, combo.inputAttacherJointDescIndex, combo.jointDescIndex, true, nil, nil, false);
			end
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

function Tardis:isCrane(obj)
	return obj['typeName'] == 'crane';
end

function Tardis:isTrain(obj)
	return obj['typeName'] == 'locomotive';
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