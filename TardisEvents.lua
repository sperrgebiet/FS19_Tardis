--
-- MP Stuff

-- Initial Sync

TardisInitialSyncEvent = {}
TardisInitialSyncEvent_mt = Class(TardisInitialSyncEvent, Event)

InitEventClass(TardisInitialSyncEvent, "TardisInitialSyncEvent")

function TardisInitialSyncEvent:emptyNew()
    local self = Event:new(TardisInitialSyncEvent_mt)
	self.className = "TardisInitialSyncEvent"
    return self
end

function TardisInitialSyncEvent:new(dataString)
	Tardis:dp(string.format('%s fires', "TardisInitialSyncEvent:new"));
    local self = TardisInitialSyncEvent:emptyNew()
    self.dataString = dataString
    return self
end

function TardisInitialSyncEvent:readStream(streamId, connection)
	if connection:getIsServer() then
		Tardis:dp(string.format('%s fires', "TardisInitialSyncEvent:readStream"));
		self.dataString = streamReadString(streamId)
		self:run(connection)
	end
end

function TardisInitialSyncEvent:writeStream(streamId, connection)
	if not connection:getIsServer() then
		Tardis:dp(string.format('%s fires', "TardisInitialSyncEvent:writeStream"));
		local dataString = ""

		for k, v in pairs(Tardis.hotspots) do
			--string format: hotspotId=xMapPos;zMapPos#hotspot2=xMapPos2;zMapPos2 etc.
			--so hotspots are seperated by a semicolon, and the hotspotId and xMap & zMap position are seperated by a whitespace
			dataString = dataString .. string.format("%s %s %s;", k, v['xMapPos'], v['zMapPos'])
		end
		streamWriteString(streamId, dataString)
	end
end

function TardisInitialSyncEvent:run(connection)
	Tardis:dp(string.format('%s fires', "TardisInitialSyncEvent:run"));

	if connection:getIsServer() then
		local newHotspots = {}

		-- First we seperate our hotspots based on the semicolon
		for substring in self.dataString:gmatch("[^;]+") do
			
			--And now we create a temp table to seperate every hotspot information which is seperated by whitespace so that we get id, xMapPos and zMapPos
			local tempTable = {}
			for stringMatch in substring:gmatch("%S+") do
				table.insert(tempTable, stringMatch)
			end
			local index = tonumber(tempTable[1])
			newHotspots[index] = {}
			newHotspots[index]['xMapPos'] = tempTable[2]
			newHotspots[index]['zMapPos'] = tempTable[3]
		end

		if g_server == nil then
			-- For each received hotspot we've to create a new one
			for k, v in pairs(newHotspots) do
				Tardis:createMapHotspot(k, v['xMapPos'], v['zMapPos'], true);
			end
		end
	end
end

function TardisInitialSyncEvent.sendEvent(noEventSend)
	Tardis:dp(string.format('%s fires', "TardisInitialSyncEvent:sendEvent"));
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(TardisInitialSyncEvent:new(dataString), nil, nil, self)
		else
			g_client:getServerConnection():sendEvent(TardisInitialSyncEvent:new(dataString))
		end
	end
end

-- Teleport

TardisTeleportEvent = {}
TardisTeleportEvent_mt = Class(TardisTeleportEvent, Event)

InitEventClass(TardisTeleportEvent, "TardisTeleportEvent")

function TardisTeleportEvent:emptyNew()
    local self = Event:new(TardisTeleportEvent_mt)
	self.className = "TardisTeleportEvent"
    return self
end

function TardisTeleportEvent:new(x, z, vehicle, isReset, isHotspot)
    local self = TardisTeleportEvent:emptyNew()
    self.x = x
	self.z = z
	self.vehicle = vehicle
	self.isReset = isReset
	self.isHotspot = isHotspot
    return self
end

function TardisTeleportEvent:readStream(streamId, connection)
	self.x = streamReadFloat32(streamId)
	self.z = streamReadFloat32(streamId)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.isReset = streamReadBool(streamId)
	self.isHotspot = streamReadBool(streamId)
	self:run(connection)
end

function TardisTeleportEvent:writeStream(streamId, connection)
	streamWriteFloat32(streamId, self.x)
	streamWriteFloat32(streamId, self.z)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteBool(streamId, self.isReset)
	streamWriteBool(streamId, self.isHotspot)
end

function TardisTeleportEvent:run(connection)
	Tardis:dp(string.format('%s fires', "TardisTeleportEvent:run"));
	Tardis:teleportToLocation(self.x, self.z, self.vehicle, self.isReset, self.isHotspot)
	if not connection:getIsServer() then
		g_server:broadcastEvent(TardisTeleportEvent:new(self.x, self.z, self.vehicle, self.isReset, self.isHotspot), nil, nil, self)
	end
end

function TardisTeleportEvent.sendEvent(x, z, vehicle, isReset, isHotspot, noEventSend)
	if isReset == nil then
		isReset = false
	end
	if isHotspot == nil then
		isHotspot = false
	end

	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(TardisTeleportEvent:new(x, z, vehicle, isReset, isHotspot), nil, nil, self)
		else
			g_client:getServerConnection():sendEvent(TardisTeleportEvent:new(x, z, vehicle, isReset, isHotspot))
		end
	end
end

-- Create Hotspot

TardisCreateHotspotEvent = {}
TardisCreateHotspotEvent_mt = Class(TardisCreateHotspotEvent, Event)

InitEventClass(TardisCreateHotspotEvent, "TardisCreateHotspotEvent")

function TardisCreateHotspotEvent:emptyNew()
    local self = Event:new(TardisCreateHotspotEvent_mt)
	self.className = "TardisCreateHotspotEvent"
    return self
end

function TardisCreateHotspotEvent:new(hotspotId, x, z)
    local self = TardisCreateHotspotEvent:emptyNew()
    self.hotspotId = hotspotId
    self.x = x
	self.z = z
    return self
end

function TardisCreateHotspotEvent:readStream(streamId, connection)
	self.hotspotId = streamReadInt8(streamId)
	self.x = streamReadFloat32(streamId)
	self.z = streamReadFloat32(streamId)
	self:run(connection)
end

function TardisCreateHotspotEvent:writeStream(streamId, connection)
	streamWriteInt8(streamId, self.hotspotId)
	streamWriteFloat32(streamId, self.x)
	streamWriteFloat32(streamId, self.z)
end

function TardisCreateHotspotEvent:run(connection)
	Tardis:dp(string.format('%s fires', "TardisCreateHotspotEvent:run"));
	Tardis:createMapHotspot(self.hotspotId , self.x, self.z)
	if not connection:getIsServer() then  
		g_server:broadcastEvent(TardisCreateHotspotEvent:new(self.hotspotId, self.x, self.z), nil, nil, self)
	end
end

function TardisCreateHotspotEvent.sendEvent(hotspotId, x, z, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(TardisCreateHotspotEvent:new(hotspotId, x, z), nil, nil, self)
		else
			g_client:getServerConnection():sendEvent(TardisCreateHotspotEvent:new(hotspotId, x, z))
		end
	end
end

-- Remove Hotspot

TardisRemoveHotspotEvent = {}
TardisRemoveHotspotEvent_mt = Class(TardisRemoveHotspotEvent, Event)

InitEventClass(TardisRemoveHotspotEvent, "TardisRemoveHotspotEvent")

function TardisRemoveHotspotEvent:emptyNew()
    local self = Event:new(TardisRemoveHotspotEvent_mt)
	self.className = "TardisRemoveHotspotEvent"
    return self
end

function TardisRemoveHotspotEvent:new(hotspotId)
    local self = TardisRemoveHotspotEvent:emptyNew()
    self.hotspotId = hotspotId
    return self
end

function TardisRemoveHotspotEvent:readStream(streamId, connection)
	self.hotspotId = streamReadInt8(streamId)
	self:run(connection)
end

function TardisRemoveHotspotEvent:writeStream(streamId, connection)
	streamWriteInt8(streamId, self.hotspotId)
end

function TardisRemoveHotspotEvent:run(connection)
	Tardis:dp(string.format('%s fires', "TardisRemoveHotspotEvent:run"));
	Tardis:removeMapHotspot(self.hotspotId)
	if not connection:getIsServer() then  
		g_server:broadcastEvent(TardisRemoveHotspotEvent:new(self.hotspotId), nil, nil, self)
	end
end

function TardisRemoveHotspotEvent.sendEvent(hotspotId, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(TardisRemoveHotspotEvent:new(hotspotId), nil, nil, self)
		else
			g_client:getServerConnection():sendEvent(TardisRemoveHotspotEvent:new(hotspotId))
		end
	end
end
