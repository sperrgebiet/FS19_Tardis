--[[
RegisterSpecialization

Author:		Ifko[nator]
Date:		02.01.2019
Version:	1.0
]]

RegisterSpecialization = {};
RegisterSpecialization.currentModDirectory = g_currentModDirectory;

local modDesc = loadXMLFile("modDesc", RegisterSpecialization.currentModDirectory .. "modDesc.xml");

RegisterSpecialization.debugPriority = Utils.getNoNil(getXMLInt(modDesc, "modDesc.registerSpecializations#debugPriority"), 0);

local function printError(errorMessage, isWarning, isInfo)
	local prefix = "::ERROR:: ";
	
	if isWarning then
		prefix = "::WARNING:: ";
	elseif isInfo then
		prefix = "::INFO:: ";
	end;
	
	print(prefix .. "from the RegisterSpecialization.lua: " .. tostring(errorMessage));
end;

local function printDebug(debugMessage, priority, addString)
	if RegisterSpecialization.debugPriority >= priority then
		local prefix = "";
		
		if addString then
			prefix = "::DEBUG:: from the RegisterSpecialization.lua: ";
		end;
		
		print(prefix .. tostring(debugMessage));
	end;
end;

local specializationNumber = 0;

while true do
	local specializationKey = string.format("modDesc.registerSpecializations.registerSpecialization(%d)", specializationNumber);
	
	if not hasXMLProperty(modDesc, specializationKey) then
		break;
	end;
	
	local specializationName = Utils.getNoNil(getXMLString(modDesc, specializationKey .. "#name"), "");
	local specializationClassName = Utils.getNoNil(getXMLString(modDesc, specializationKey .. "#className"), "");
	local specializationFilename = Utils.getNoNil(Utils.getFilename(getXMLString(modDesc, specializationKey .. "#filename"), RegisterSpecialization.currentModDirectory), ""); 
	local searchedSpecializations = StringUtil.splitString(" ", Utils.getNoNil(getXMLString(modDesc, specializationKey .. "#searchedSpecializations"), ""));
	
	local searchedSpecializationsString = "";
	
	local function getSearchedSpecializations(searchedSpecializations)
		for _, searchedSpecialization in pairs(searchedSpecializations) do
			if searchedSpecializationsString ~= "" then 
				searchedSpecialization = ", " .. searchedSpecialization; 
			end;
			
			searchedSpecializationsString = searchedSpecializationsString .. searchedSpecialization;
		end;
		
		return searchedSpecializationsString;
	end;
	
	printDebug("specializationName =  " .. specializationName .. " specializationClassName " .. specializationClassName .. " specializationFilename = " .. specializationFilename .. " searchedSpecializations = " .. getSearchedSpecializations(searchedSpecializations), 1, true);
	
	if specializationName ~= ""
		and specializationClassName ~= ""
		and specializationFilename ~= "" and fileExists(specializationFilename)
		and searchedSpecializations ~= ""
	then
		if g_specializationManager:getSpecializationByName(specializationName) == nil then
			g_specializationManager:addSpecialization(specializationName, specializationClassName, specializationFilename, true, nil);
			
			for vehicleType, vehicle in pairs(g_vehicleTypeManager.vehicleTypes) do
				if vehicle ~= nil then
					for name in pairs(vehicle.specializationsByName) do
						for _, searchedSpecialization in pairs(searchedSpecializations) do	
							if string.lower(name) == string.lower(searchedSpecialization) then
								local specializationObject = g_specializationManager:getSpecializationObjectByName(specializationName);
								
								if vehicle.specializationsByName[specializationName] == nil then
									vehicle.specializationsByName[specializationName] = specializationObject;
									
									table.insert(vehicle.specializationNames, specializationName);
									table.insert(vehicle.specializations, specializationObject);
									
									printDebug("Added Specialization '" .. specializationName .. "' succsessfully to vehicle type '" .. vehicleType .. "'.", 1, true);
								end;
							end;
						end;
					end;
				end;
			end;
		end;
	else
		if specializationName == nil then
			printError("Missing specialization name! Skipping this specialization now!", false, false);
		elseif specializationClassName == nil then
			printError("Missing specialization class name! Skipping specialization '" .. specializationName .. "' now!", false, false);
		elseif specializationFilename == nil then
			printError("Missing specialization filename! Skipping specialization '" .. specializationName .. "' now!", false, false);
		elseif searchedSpecializations == nil then
			printError("Missing searched specialization names! Skipping specialization '" .. specializationName .. "' now!", false, false);
		end;
	end;
	
	specializationNumber = specializationNumber + 1;
end;