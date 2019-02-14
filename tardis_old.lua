--
-- TARDIS... a telport mod for FS17
--
-- fcelsa ...from a gift of TyKonKet and Giants...
--
--
-- 2017-03
--
tardis = {};

tardis.modDir = g_currentModDirectory;

local modItem = ModsUtil.findModItemByModName(g_currentModName);
tardis.version = (modItem and modItem.version) and modItem.version or "?.?.?";

addModEventListener(tardis);

function tardis:teleportToLocation(xField, z, theVehicle)
    
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
        if g_currentMission.fieldDefinitionBase ~= nil then
            local fieldDef = g_currentMission.fieldDefinitionBase.fieldDefsByFieldNumber[xField];
            if fieldDef == nil then
                return;
            end
            targetX, targetY, targetZ = getWorldTranslation(fieldDef.fieldBuySymbol);
        else
            return;
        end;
    else
        local worldSizeX = g_currentMission.ingameMap.worldSizeX;
        local worldSizeZ = g_currentMission.ingameMap.worldSizeZ;
        targetX = Utils.clamp(xField, 0, worldSizeX) - worldSizeX * 0.5;
        targetZ = Utils.clamp(z, 0, worldSizeZ) - worldSizeZ * 0.5;
    end;
    
    if theVehicle == nil then
        g_currentMission.player:moveTo(targetX, 0.5, targetZ);
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
            if not vehicle:isa(RailroadVehicle) then  -- rimuovere se ci sono problemi.
                vehicle:removeFromPhysics();
            end;
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

function tardis:loadMap(name)
    self.tardisOn = false;
    self.mousePos = {0.5, 0.5};
    self.worldXpos = 0;
    self.worldZpos = 0;
    self.fieldNumber = 1;
    g_currentMission.tardisBase = self;
end

function tardis:deleteMap()
end

function tardis:mouseEvent(posX, posY, isDown, isUp, button)
    if self.tardisOn then
        local mOX = g_currentMission.ingameMap.mapPosX;
        local mOY = g_currentMission.ingameMap.mapPosY;
        if posX >= mOX and posX <= mOX + g_currentMission.ingameMap.mapWidth then
            self.worldXpos = (posX - mOX) / g_currentMission.ingameMap.maxMapWidth;
        end;
        if posY >= mOY and posY <= mOY + g_currentMission.ingameMap.mapHeight then
            self.worldZpos = 1 - (posY - mOY) / g_currentMission.ingameMap.maxMapHeight;
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
            InputBinding.setShowMouseCursor(false);
        end;
        self.mousePos[1] = posX;
        self.mousePos[2] = posY;
    end;
end;

function tardis:keyEvent(unicode, sym, modifier, isDown)
end;

function tardis:ShowTardis()

	bmModName = "FS17_BetterMinimap"

	if g_modIsLoaded[bmModName] then
		envBM = getfenv(0)[bmModName];
		if envBM.BM.isFullScreen then
			BMMap = true;
		else
			BMMap = false;
		end;
	end;

    if (g_currentMission.ingameMap.isVisible and g_currentMission.ingameMap.state == IngameMap.STATE_MAP) or ( BMMap ) then
		tardis.tardisOn = not tardis.tardisOn;
		if tardis.tardisOn then
			InputBinding.setShowMouseCursor(true);
		else
			InputBinding.setShowMouseCursor(false);
		end;
    end;

	local mCurStat = InputBinding.getShowMouseCursor();
	if tardis.tardisOn and not mCurStat then
		InputBinding.setShowMouseCursor(true);
	end;
end;

function tardis:update(dt)
    if g_currentMission.ingameMap.state == IngameMap.STATE_MAP and self.tardisOn == false then
        g_currentMission:addHelpButtonText(g_i18n:getText("input_TRDS_KEY"), InputBinding.TRDS_KEY);
        g_currentMission:addExtraPrintText(g_i18n:getText("TRDS_HELPER"));
    end;
    if InputBinding.hasEvent(InputBinding.TOGGLE_MAP_SIZE) then
        if self.tardisOn then
            self.tardisOn = false;
            InputBinding.setShowMouseCursor(false);
        end;
    end;
	
    if InputBinding.hasEvent(InputBinding.TRDS_KEY) then
        self.ShowTardis();
    end;	
	
end;

function tardis:draw(dt)
    if self.tardisOn then
        local px = 0.01;
        local py = 0.005;
        local ovrlX = g_currentMission.ingameMap.mapPosX + g_currentMission.ingameMap.mapWidth / 2
        local ovrlY = g_currentMission.ingameMap.mapPosY + g_currentMission.ingameMap.mapHeight / 2
        local name;
        if g_currentMission.controlledVehicle == nil and g_currentMission.player then
            name = g_currentMission.player.controllerName;
        end;
        if g_currentMission.controlledVehicle and not g_currentMission.controlledVehicle:isa(RailroadVehicle) then
            local VCFN = string.lower(g_currentMission.controlledVehicle.configFileName);
            local StoreItem = StoreItemsUtil.storeItemsByXMLFilename[VCFN];
            local storeImage = createImageOverlay(Utils.getFilename(StoreItem.imageActive));
            if storeImage > 0 then
                local storeImgX, storeImgY = getNormalizedScreenValues(128, 128)
                renderOverlay(storeImage, ovrlX + 0.23, ovrlY, storeImgX, storeImgY)
            end;
            name = StoreItem.name;
            
            if g_currentMission.controlledVehicle.attachedImplements ~= nil then
                local allAttached = {}
                local function addAllAttached(vehicle)
                    for _, implA in pairs(vehicle.attachedImplements) do
                        addAllAttached(implA.object);
                        table.insert(allAttached, {vehicle = vehicle, object = implA.object, jointDescIndex = implA.jointDescIndex, inputAttacherJointDescIndex = implA.object.inputAttacherJointDescIndex});
                    end;
                end;
                
                addAllAttached(g_currentMission.controlledVehicle);
                
                for i = table.getn(allAttached), 1, -1 do
                    local VCFN = string.lower(allAttached[i].object.configFileName);
                    local StoreItem = StoreItemsUtil.storeItemsByXMLFilename[VCFN];
                    local storeImage = createImageOverlay(Utils.getFilename(StoreItem.imageActive));
                    local y = 0.7;
                    if storeImage > 0 then
                        local storeImgX, storeImgY = getNormalizedScreenValues(128, 128)
                        renderOverlay(storeImage, ovrlX + 0.23 + 0.085 * i, ovrlY, storeImgX, storeImgY);
                    end;
                    name = name .. " + " .. StoreItem.name;
                end;
            end;
        end;

        if g_currentMission.controlledVehicle and g_currentMission.controlledVehicle:isa(RailroadVehicle) then
            name = "Train system!! are you sure what you doing?";
        end;

        if g_currentMission.controlledVehicle and g_currentMission.controlledVehicle.combine then
            local fillLevel = g_currentMission.controlledVehicle:getUnitFillLevel(g_currentMission.controlledVehicle.overloading.fillUnitIndex);
            if fillLevel > 0 then
                g_currentMission:showBlinkingWarning(g_i18n:getText("warning_combine"));
            end
        end
        
        if self.mousePos[1] > ovrlX then
            px = -(string.len(name) * 0.005) - 0.03;
        end;
        if self.mousePos[2] > ovrlY then
            py = -0.04;
        end;
        renderText(self.mousePos[1] + px, self.mousePos[2] + py, getCorrectTextSize(0.016), name);
        setTextAlignment(RenderText.ALIGN_RIGHT)
        setTextBold(false)
        setTextColor(0, 1, 0.4, 1)
        renderText(g_currentMission.ingameMap.mapPosX + g_currentMission.ingameMap.mapWidth - g_currentMission.ingameMap.coordOffsetX, g_currentMission.ingameMap.mapPosY + g_currentMission.ingameMap.coordOffsetY + 0.010, g_currentMission.ingameMap.fontSize, string.format(" [%04d", self.worldXpos * g_currentMission.terrainSize) .. string.format(",%04d]", self.worldZpos * g_currentMission.terrainSize));
        setTextColor(1, 1, 1, 1)
        setTextAlignment(RenderText.ALIGN_LEFT)
    
    end;

end;


--- client/server event part---
tardisEvent = {};
tardisEvent_mt = Class(tardisEvent, Event);

InitEventClass(tardisEvent, "tardisEvent");

function tardisEvent:emptyNew()
    local self = Event:new(tardisEvent_mt);
    return self;
end;

function tardisEvent:new(xField, z, vehicle)
    local self = tardisEvent:emptyNew()
    self.xField = xField;
    self.z = z;
    self.vehicle = vehicle
    return self;
end;

function tardisEvent:readStream(streamId, connection)
    self.xField = streamReadFloat32(streamId);
    self.z = streamReadFloat32(streamId);
    self.vehicle = readNetworkNodeObject(streamId);
    self:run(connection);
end;

function tardisEvent:writeStream(streamId, connection)
    streamWriteFloat32(streamId, self.xField);
    streamWriteFloat32(streamId, self.z);
    writeNetworkNodeObject(streamId, self.vehicle);
end;

function tardisEvent:run(connection)
    if not connection:getIsServer() then
        g_currentMission.tardisBase:teleportToLocation(self.xField, self.z, self.vehicle);
    end;
end;

---------------------------------------------------------------------------
print(string.format("Script loaded: tardis.lua (v%s)", tardis.version));
