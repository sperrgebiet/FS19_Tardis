-- Tardis.lua for FS19
-- Author: sperrgebiet
-- Please see https://github.com/sperrgebiet/FS19_Tardis for additional information, credits, issues and everything else

Tardis = {};
Tardis.eventName = {};

Tardis.ModName = g_currentModName;
Tardis.ModDirectory = g_currentModDirectory;
Tardis.Version = "0.9.1.2";

-- Integration environment for VehicleExplorer
envVeEx = nil;

Tardis.camBackup = {};
Tardis.hotspots = {};

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
	FSBaseMission.registerActionEvents = Utils.appendedFunction(FSBaseMission.registerActionEvents, Tardis.registerActionEvents);
	Player.registerActionEvents = Utils.appendedFunction(Player.registerActionEvents, Tardis.registerActionEventsPlayer);
	
	Tardis.TardisActive = false;
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

-- Global action events
function Tardis:registerActionEvents(isSelected, isOnActiveVehicle)
	local actions = {
					"tardis_showTardisCursor",
					"tardis_useHotspot1",
					"tardis_useHotspot2",
					"tardis_useHotspot3",
					"tardis_useHotspot4",
					"tardis_useHotspot5",
					"tardis_deleteHotspot"
				};

	for _, action in pairs(actions) do
		local actionMethod = string.format("action_%s", action);
		local result, eventName = InputBinding.registerActionEvent(g_inputBinding, action, self, Tardis[actionMethod], false, true, false, true)
		if result then
			table.insert(Tardis.eventName, eventName);
			g_inputBinding.events[eventName].displayIsVisible = true;
		end
	end
		
end

function Tardis:registerActionEventsPlayer()
end

function Tardis.registerEventListeners(vehicleType)
	local functionNames = {	"onRegisterActionEvents", };
	
	for _, functionName in ipairs(functionNames) do
		SpecializationUtil.registerEventListener(vehicleType, functionName, Tardis);
	end
end

--Vehicle functions
function Tardis:onRegisterActionEvents(isSelected, isOnActiveVehicle)
	
	local result, eventName = InputBinding.registerActionEvent(g_inputBinding, 'tardis_resetVehicle',self, Tardis.action_tardis_resetVehicle ,false ,true ,false ,true)
	if result then
		table.insert(Tardis.eventName, eventName);
		g_inputBinding.events[eventName].displayIsVisible = true;
    end
		
end

function Tardis:keyEvent(unicode, sym, modifier, isDown)
end

function Tardis:mouseEvent(posX, posY, isDown, isUp, button)
	--Tardis:dp(string.format('posX {%s) posY {%s}', posX, posY));
    if Tardis.isActionAllowed() then
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
                local veh = g_currentMission.controlledVehicle;
				g_client:getServerConnection():sendEvent(tardisEvent:new(xField, z, veh));
			else
				--Tardis:dp(string.format('telePort param1 {%s} - param2 {%s}', Tardis.worldXpos * g_currentMission.terrainSize, Tardis.worldZpos * g_currentMission.terrainSize));
				Tardis:teleportToLocation(Tardis.worldXpos * g_currentMission.terrainSize, Tardis.worldZpos * g_currentMission.terrainSize);
			end
            Tardis.TardisActive = false;
            g_inputBinding:setShowMouseCursor(false);
        end;
        Tardis.mousePos[1] = posX;
        Tardis.mousePos[2] = posY;
    end
end

function Tardis:draw()
	if Tardis.TardisActive then
	    --local ovrlX = g_currentMission.hud.ingameMap.mapPosX + g_currentMission.hud.ingameMap.mapWidth / 2;
		--local ovrlX = g_currentMission.hud.ingameMap.mapPosX + g_currentMission.hud.ingameMap.mapOffsetX + getTextWidth(g_currentMission.hud.ingameMap.mapLabelTextSize, g_currentMission.hud.ingameMap.mapLabelText);
		--local ovrlX = g_currentMission.hud.ingameMap.mapPosX + getTextWidth(g_currentMission.hud.ingameMap.mapLabelTextSize, g_currentMission.hud.ingameMap.mapLabelText);
		local ovrlX = g_currentMission.hud.ingameMap.mapPosX + getTextWidth(g_currentMission.hud.ingameMap.mapLabelTextSize, g_currentMission.hud.ingameMap.mapLabelText);
		local ovrlY = g_currentMission.hud.ingameMap.mapPosY + g_currentMission.hud.ingameMap.maxMapHeight;
        local px = 0.01;
        local py = 0.005;	
		local name;
		local veh;
		local drawImage = false;		--There are so many cases where we don't want to draw a image, so easier to just set it to true in case it's the currently controlled vehicle
		
		if envVeEx ~= nil and envVeEx.VehicleSort.showVehicles and envVeEx.VehicleSort.config[22][2] then
			local realVeh = g_currentMission.vehicles[envVeEx.VehicleSort.Sorted[envVeEx.VehicleSort.selectedIndex]];
			if realVeh ~= nil then
				veh = realVeh;
			end
		elseif g_currentMission.controlledVehicle ~= nil then
			veh = g_currentMission.controlledVehicle;
			drawImage = true;
		end
		
		if veh ~= nil then
			--Get image size
			local storeImgX, storeImgY = getNormalizedScreenValues(128, 128)
				
			if drawImage then
				Tardis:DrawImage(veh, ovrlX, ovrlY)
			end
			
			name = veh:getName();
			
			if veh.getAttachedImplements ~= nil then
                local allAttached = {}
                local function addAllAttached(vehicle)
                    for _, implA in pairs(vehicle:getAttachedImplements()) do
                        addAllAttached(implA.object);
                        table.insert(allAttached, {vehicle = vehicle, object = implA.object, jointDescIndex = implA.jointDescIndex, inputAttacherJointDescIndex = implA.object.inputAttacherJointDescIndex});
                    end
                end
                
                addAllAttached(veh);
                
                for i = table.getn(allAttached), 1, -1 do
					if drawImage then
						Tardis:DrawImage(allAttached[i].object, ovrlX + storeImgX * i, ovrlY)				
					end

                    name = name .. " + " .. allAttached[i].object:getName();
                end
            end
		end
		
		if veh and Tardis:isTrain(veh) then
			g_currentMission:showBlinkingWarning(g_i18n.modEnvironments[Tardis.ModName].texts.warning_train, 2000);
            name = veh:getName();
        end
		
		if veh and Tardis:isCrane(veh) then
			g_currentMission:showBlinkingWarning(g_i18n.modEnvironments[Tardis.ModName].texts.warning_crane, 2000);
            name = veh:getName();
        end		
		
		if name == nil or string.len(name) == 0 then
			name = string.format('%s %s', g_i18n.modEnvironments[Tardis.ModName].texts.lonelyFarmer, g_gameSettings.nickname);
		end
		
		if veh and veh.spec_combine ~= nil and veh.getFillLevelInformation ~= nil then
			local fillLevelTable = {};
			veh:getFillLevelInformation(fillLevelTable);
			
			for _,fillLevelVehicle in pairs(fillLevelTable) do
				fillLevel = fillLevelVehicle.fillLevel;
			end
			
			if fillLevel ~= nil and fillLevel > 0 then
                g_currentMission:showBlinkingWarning(g_i18n.modEnvironments[Tardis.ModName].texts.warning_combine, 2000);
            end
        end
		
		if Tardis.mousePos[1] > ovrlX then
            --px = -(string.len(name) * 0.005) - 0.03;
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

function Tardis:action_tardis_showTardisCursor(actionName, keyStatus, arg3, arg4, arg5)
	Tardis:dp(string.format('%s fires', actionName));
	Tardis:showTardis();
end

function Tardis:action_tardis_resetVehicle(actionName, keyStatus, arg3, arg4, arg5)
	Tardis:dp(string.format('%s fires', actionName));
	
	if g_currentMission.controlledVehicle then
		-- We can provide dummy values, as we'll do the actual stuff in the teleport function
		Tardis:teleportToLocation(0, 0, nil, true);
	end
end

function Tardis:action_tardis_useHotspot1(actionName, keyStatus, arg3, arg4, arg5)
	Tardis:dp(string.format('%s fires', actionName));
	Tardis:useOrSetHotspot(1);
end

function Tardis:action_tardis_useHotspot2(actionName, keyStatus, arg3, arg4, arg5)
	Tardis:dp(string.format('%s fires', actionName));
	Tardis:useOrSetHotspot(2);
end

function Tardis:action_tardis_useHotspot3(actionName, keyStatus, arg3, arg4, arg5)
	Tardis:dp(string.format('%s fires', actionName));
	Tardis:useOrSetHotspot(3);
end

function Tardis:action_tardis_useHotspot4(actionName, keyStatus, arg3, arg4, arg5)
	Tardis:dp(string.format('%s fires', actionName));
	Tardis:useOrSetHotspot(4);
end

function Tardis:action_tardis_useHotspot5(actionName, keyStatus, arg3, arg4, arg5)
	Tardis:dp(string.format('%s fires', actionName));
	Tardis:useOrSetHotspot(5);
end

function Tardis:action_tardis_deleteHotspot(actionName, keyStatus, arg3, arg4, arg5)
	Tardis:dp(string.format('%s fires', actionName));
	local hotspotId = Tardis:hotspotNearby();
	if hotspotId > 0 then
		Tardis:dp(string.format('Found hotspot {%d}. Going to delete it.', hotspotId), 'action_deleteHotspot');
		Tardis:removeMapHotspot(hotspotId);
	else
		Tardis:dp('No hotspots nearby', 'action_deleteHotspot');
		Tardis:showBlinking(nil, 3);
	end
end

--
-- Tardis specific functions
--

function Tardis:showTardis()

    if (g_currentMission.hud.ingameMap.isVisible and g_currentMission.hud.ingameMap.state == IngameMap.STATE_MAP) then
		Tardis.TardisActive = not Tardis.TardisActive;
		if Tardis.TardisActive then
			g_inputBinding:setShowMouseCursor(true);
			Tardis:Freeze(true);
			
			--It's getting confusing when we want to use Tardis and VehicleExplorer at the same but, although the integration was disabled
			--So better to close the vehicle list from VeEx in that case
			if envVeEx ~= nil and not envVeEx.VehicleSort.config[22][2] and envVeEx.VehicleSort.showVehicles then
				envVeEx.VehicleSort.showVehicles = false;
			end
		else
			Tardis.TardisActive = false;
			g_inputBinding:setShowMouseCursor(false);
			Tardis:Freeze(false);
		end
	elseif Tardis.TardisActive then
		Tardis.TardisActive = false;
		g_inputBinding:setShowMouseCursor(false);
    end
end

function Tardis:teleportToLocation(x, z, veh, isReset, isHotspot)

    x = tonumber(x);
    z = tonumber(z);
    if x == nil then
        return;
    end;

	if envVeEx ~= nil and veh == nil then
		if envVeEx.VehicleSort.showVehicles and envVeEx.VehicleSort.config[22][2] then
			local realVeh = g_currentMission.vehicles[envVeEx.VehicleSort.Sorted[envVeEx.VehicleSort.selectedIndex]];
			if realVeh ~= nil then
				veh = realVeh;
				if veh ~= g_currentMission.controlledVehicle then
					envVeEx.VehicleSort.wasTeleportAction = true;
				end
			end
		end
	end
	
	if veh == nil then
		veh = g_currentMission.controlledVehicle;
	end

	-- We don't want to teleport cranes or trains
	if veh ~= nil and (Tardis:isTrain(veh) or Tardis:isCrane(veh)) then
		Tardis:Freeze(false);
		return false;
	end
	
	local targetX, targetY, targetZ = 0, 0, 0;
	
    if not isReset and not isHotspot then	
		local worldSizeX = g_currentMission.hud.ingameMap.worldSizeX;
		local worldSizeZ = g_currentMission.hud.ingameMap.worldSizeZ;
		targetX = MathUtil.clamp(x, 0, worldSizeX) - worldSizeX * 0.5;
		targetZ = MathUtil.clamp(z, 0, worldSizeZ) - worldSizeZ * 0.5;
    elseif isHotspot then
		targetX = x;
		targetZ = z;
	else
		targetX, targetY, targetZ = getWorldTranslation(g_currentMission.controlledVehicle.rootNode);
	end
	
	Tardis:dp(string.format('targetX {%s} - targetZ {%s}', tostring(targetX), tostring(targetZ)), 'teleportToLocation');
	
    if veh == nil and not isReset then
		g_currentMission.player:moveTo(targetX, 0.5, targetZ, false, false);
		Tardis:Freeze(false);
    else
        local vehicleCombos = {};
        local vehicles = {};

        local function addVehiclePositions(vehicle)
            local x, y, z = getWorldTranslation(vehicle.rootNode);
            table.insert(vehicles, {vehicle = vehicle, offset = {worldToLocal(veh.rootNode, x, y, z)}});
            
			if not Tardis:isHorse(veh) then
				if #vehicle:getAttachedImplements() > 0 then
					for _, impl in pairs(vehicle:getAttachedImplements()) do
						addVehiclePositions(impl.object);
						table.insert(vehicleCombos, {vehicle = vehicle, object = impl.object, jointDescIndex = impl.jointDescIndex, inputAttacherJointDescIndex = impl.object.spec_attachable.inputAttacherJointDescIndex});
					end
					
					for i = table.getn(vehicle:getAttachedImplements()), 1, -1 do
						vehicle:detachImplement(1, true);
					end
				end
			end

			vehicle:removeFromPhysics();
        end
        
        addVehiclePositions(veh);
        
        for k, data in pairs(vehicles) do
            local x, y, z = targetX, targetY, targetZ;
            if k > 1 then
                x, _, z = localToWorld(veh.rootNode, unpack(data.offset));
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
		
		Tardis:Freeze(false);
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

function Tardis:isHorse(obj)
	return obj['typeName'] == 'horse';
end

function Tardis:Freeze(setFreeze)
	local veh = g_currentMission.controlledVehicle;

	if setFreeze then
		if veh ~= nil then
			local veh = g_currentMission.controlledVehicle;
			-- We just want to mess with the cameras when we can ensure that we can do a backup first
			if Tardis.camBackup[veh.id] == nil then
				Tardis.camBackup[veh.id] = {};
				for	i, v in ipairs(veh.spec_enterable.cameras) do
					local cam = {i, v.isRotatable};
					table.insert(Tardis.camBackup[veh.id], cam);
					v.isRotatable = false;
				end
			end
		else
			g_currentMission.isPlayerFrozen = true;
		end
	else
		if veh ~= nil then
			if Tardis.camBackup[veh.id] ~= nil then
				for _, v in ipairs(Tardis.camBackup[veh.id]) do
					veh.spec_enterable.cameras[v[1]]['isRotatable'] = v[2];
				end
				Tardis.camBackup[veh.id] = nil;
			end
		end
		--Always unfreeze player
		g_currentMission.isPlayerFrozen = false;
	end

end

function Tardis:useOrSetHotspot(hotspotId)
	Tardis:dp(string.format('hotspotId: {%d}', hotspotId), 'useOrSetHotspot');
	if Tardis.hotspots[hotspotId] ~= nil then

		local x = Tardis.hotspots[hotspotId]['xMapPos'];
		local z = Tardis.hotspots[hotspotId]['zMapPos'];
		Tardis:dp(string.format('Hotspot {%d} exists. Teleporting now to: x {%s}, z {%s}', hotspotId, tostring(x), tostring(z)), 'createMapHotspot');
		Tardis:teleportToLocation(x, z, nil, false, true);
	else
		Tardis:createMapHotspot(hotspotId);
	end
end

function Tardis:createMapHotspot(hotspotId, paramX, paramZ)
	Tardis:dp(string.format('Going to create mapHotspot {%d}', hotspotId), 'createMapHotspot');
	local x = paramX;
	local y = nil;
	local z = paramZ;
	
	local name = string.format('%s %s', g_i18n.modEnvironments[Tardis.ModName].texts.hotspot, hotspotId);
	local hotspot = MapHotspot:new(name,  MapHotspot.CATEGORY_MISSION);
	
	if x == nil and z == nil then
		x, y, z = getWorldTranslation(g_currentMission.player.rootNode);
	end
	hotspot:setWorldPosition(x, z);
	
	hotspot:setImage(nil, getNormalizedUVs(MapHotspot.UV.FARM_HOUSE), {0.0044, 0.15, 0.6376, 1})
	hotspot:setBackgroundImage(nil, getNormalizedUVs(MapHotspot.UV.FARM_HOUSE));
	
	g_currentMission:addMapHotspot(hotspot);
	
	Tardis.hotspots[hotspotId] = hotspot;
	-- if there is a paramX and paramZ it means we got it from the savegame, so no need for a blinking warning
	if paramX == nil and paramZ == nil then
		Tardis:showBlinking(hotspotId, 1);
	end
end

function Tardis:removeMapHotspot(hotspotId)
	g_currentMission:removeMapHotspot(Tardis.hotspots[hotspotId]);
	Tardis.hotspots[hotspotId] = nil;
	Tardis:showBlinking(hotspotId, 2);
end

function Tardis:saveHotspots(missionInfo)
	if #Tardis.hotspots > 0 then

	    if missionInfo.isValid and missionInfo.xmlKey ~= nil then
			local tardisKey = missionInfo.xmlKey .. ".TardisHotspots";

			for k, v in pairs(Tardis.hotspots) do
				setXMLFloat(missionInfo.xmlFile, tardisKey .. '.hotspot' .. k .. '#xMapPos' , v.xMapPos);
				setXMLFloat(missionInfo.xmlFile, tardisKey .. '.hotspot' .. k .. '#zMapPos' , v.zMapPos);
			end
		end
	end
end

function Tardis:loadHotspots()
    if g_currentMission == nil or not g_currentMission:getIsServer() then return end

	--    if g_currentMission.missionInfo.isValid then
	
	local xmlFile = Utils.getFilename("careerSavegame.xml", g_currentMission.missionInfo.savegameDirectory.."/");
	local savegame = loadXMLFile('careerSavegameXML', xmlFile);
    local tardisKey = g_currentMission.missionInfo.xmlKey .. ".TardisHotspots";

	Tardis:dp(string.format('Going to load {%s} from {%s}', tardisKey, xmlFile), 'loadHotspots');

	if hasXMLProperty(savegame, tardisKey) then
		Tardis:dp(string.format('{%s} exists.', tardisKey), 'loadHotspots');
			
		for i=1, 5 do
			local hotspotKey = tardisKey .. '.hotspot' .. i;
			if hasXMLProperty(savegame, hotspotKey) then
				local xMapPos = getXMLFloat(savegame, hotspotKey .. "#xMapPos");
				local zMapPos = getXMLFloat(savegame, hotspotKey .. "#zMapPos");
				Tardis:dp(string.format('Loaded MapHotSpot {%d} from savegame. xMapPos {%s}, zMapPos {%s}', i, tostring(xMapPos), tostring(zMapPos)), 'loadHotspots');
				Tardis:createMapHotspot(i, xMapPos, zMapPos);
			end
		end
	end

end

function Tardis.loadedMission()
	Tardis:loadHotspots();
end

function Tardis.saveToXMLFile(missionInfo)
	Tardis:saveHotspots(missionInfo);
end

-- it would be nicer to do that with triggers if possible. But it should do the job for now
function Tardis:hotspotNearby()
	local range = 25;
	
	local playerX, _, playerZ = getWorldTranslation(g_currentMission.player.rootNode);
	local hotspotNearby = false;

	for k, v in pairs(Tardis.hotspots) do
		local hsX = v.xMapPos;
		local hsZ = v.zMapPos;
		if (playerX >= (hsX - range) and playerX <= (hsX + range)) and (playerZ >= (hsZ - range) and playerZ <= (hsZ + range)) then
			Tardis:dp(string.format('Hotspot {%d} nearby', k), 'hotspotNearby');
			return k;
		end
	end
	
	return 0;
end

function Tardis:showBlinking(hotspotId, action)
	--action: 1 created, 2 deleted, 3 nohotspots
	local text = '';
	if action == 1 then
		text = string.format('%s %d %s', g_i18n.modEnvironments[Tardis.ModName].texts.hotspot, hotspotId, g_i18n.modEnvironments[Tardis.ModName].texts.warning_created);		
	elseif action == 2 then
		text = string.format('%s %d %s', g_i18n.modEnvironments[Tardis.ModName].texts.hotspot, hotspotId, g_i18n.modEnvironments[Tardis.ModName].texts.warning_deleted);
	elseif action == 3 then
		text = g_i18n.modEnvironments[Tardis.ModName].texts.warning_nohotspot;
	end
	g_currentMission:showBlinkingWarning(text, 2000);
end

function Tardis:isActionAllowed()
	-- We don't want to accidently switch vehicle when the vehicle list is opened and we change to a menu
	if string.len(g_gui.currentGuiName) > 0 or #g_gui.dialogs > 0 then
		return false;
	elseif Tardis.TardisActive then
		return true;
	end
end

Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, Tardis.loadedMission)
FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, Tardis.saveToXMLFile)