--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

-- NOTE: Low-light vision mechanics not supported (i.e. light multiplication) (3.5E/PFRPG)

DEFAULT_LIGHT_COLOR = "FFFFFFFF";
DEFAULT_LIGHT_FALLOFF_BRIGHT = 25;
DEFAULT_LIGHT_FALLOFF_DIM = 50;
DEFAULT_LIGHT_ANIM_SPEED = 100;

SETTINGS_TOKENLIGHT_LIST = "settings.tokenlight";

local _tTokenLightPresets = {};
-- NOTE: .sName assigned dynamically from string asset "lighting_" .. <key> in populateLightPresets
-- NOTE: .sEffectTag assigned dynamically from string asset "lighting_" .. <key> .. "_tag" in populateLightPresets
local _tTokenLightDefaults = {
	["candle"] = {
		sColor = "FFFFFCC3",
		nBright = 1,
		nDim = 2,
		sAnimType = "flicker",
		nAnimSpeed = 100,
		nDuration = 600,
	},
	["lamp"] = {
		sColor = "FFFFF3E1",
		nBright = 3,
		nDim = 9,
		sAnimType = "flicker",
		nAnimSpeed = 25,
		nDuration = 3600,
	},
	["torch"] = {
		sColor = "FFFFF3E1",
		nBright = 4,
		nDim = 8,
		sAnimType = "flicker",
		nAnimSpeed = 25,
		nDuration = 600,
	},
	["lantern"] = {
		sColor = "FFF9FEFF",
		nBright = 6,
		nDim = 12,
		nDuration = 3600,
	},
	["lantern_bullseye"] = {
		sColor = "FFF9FEFF",
		nBright = 12,
		nDim = 24,
		nFOV = 53.13,
		nDuration = 3600,
	},
	["spell_darkness"] = {
		sColor = "FF000000",
		nBright = 3,
		nDim = 3,
		nDuration = 100,
	},
	["spell_light"] = {
		sColor = "FFFFF3E1",
		nBright = 4,
		nDim = 8,
		nDuration = 600,
	},
};

local _tVisionTypes = {};
local _tVisionTypesBlinded = {};
local _tVisionFields = { "senses" };

function onInit()
	if Session.IsHost then
		DB.setPublic(DB.createNode(VisionManager.SETTINGS_TOKENLIGHT_LIST), true);
	end

	EffectManager.setTagOptions("LIGHT", { bIgnoreExpire = true, bIgnoreTarget = true });
	EffectManager.setTagOptions("VISION", { bIgnoreExpire = true, bIgnoreTarget = true });
	EffectManager.setTagOptions("VISMAX", { bIgnoreExpire = true, bIgnoreTarget = true });
	EffectManager.setTagOptions("VISMOD", { bIgnoreExpire = true, bIgnoreTarget = true });

	VisionManager.addVisionType(Interface.getString("vision_darkvision"), "darkvision");
	VisionManager.addVisionType(Interface.getString("vision_blindsight"), "blindsight", true);
	VisionManager.addVisionType(Interface.getString("vision_tremorsense"), "blindsight", true);
	VisionManager.addVisionType(Interface.getString("vision_truesight"), "truesight");
end
function onTabletopInit()
	if Session.IsHost then
		if DB.getChildCount(VisionManager.SETTINGS_TOKENLIGHT_LIST) == 0 then
			VisionManager.populateLightPresets();
		end
		VisionManager.updateLightPresets();
		DB.addHandler(VisionManager.SETTINGS_TOKENLIGHT_LIST, "onChildUpdate", VisionManager.updateLightPresets);

		for _,vField in ipairs(_tVisionFields) do
			CombatManager.addCombatantFieldChangeHandler(vField, "onUpdate", VisionManager.updateTokenVision);
		end
	else
		VisionManager.updateLightPresets();
		DB.addHandler(VisionManager.SETTINGS_TOKENLIGHT_LIST, "onChildUpdate", VisionManager.updateLightPresets);
	end
end

--
-- LIGHTING FUNCTIONS
--

function getLightDefaults()
	return _tTokenLightDefaults;
end
function getLightDefault(sKey)
	if (sKey or "") == "" then
		return nil;
	end
	return _tTokenLightDefaults[sKey];
end
function clearLightDefaults()
	_tTokenLightDefaults = {};
end
function addLightDefault(sKey, rLight)
	if sKey and rLight and (sKey ~= "") then
		_tTokenLightDefaults[sKey] = rLight;
	end
end
function addLightDefaults(tLights)
	for sKey,rLight in pairs(tLights) do
		VisionManager.addLightDefault(sKey, rLight);
	end
end
function removeLightDefault(sKey)
	_tTokenLightDefaults[sKey] = nil;
end

function clearLightPresets()
	_tTokenLightPresets = {};
end
function addLightPreset(tLight)
	table.insert(_tTokenLightPresets, tLight);
end
function updateLightPresets()
	VisionManager.clearLightPresets();
	for _,nodeLight in ipairs(DB.getChildList(VisionManager.SETTINGS_TOKENLIGHT_LIST)) do
		local tLight = {
			sName = DB.getValue(nodeLight, "name", ""),
			sColor = DB.getValue(nodeLight, "color", ""),
			nBright = DB.getValue(nodeLight, "bright", 0),
			nDim = DB.getValue(nodeLight, "dim", 0),
			nBrightFalloff = DB.getValue(nodeLight, "falloff", VisionManager.DEFAULT_LIGHT_FALLOFF_BRIGHT),
			nDimFalloff = DB.getValue(nodeLight, "dimfalloff", VisionManager.DEFAULT_LIGHT_FALLOFF_DIM),
			sAnimType = DB.getValue(nodeLight, "animtype", ""),
			nAnimSpeed = DB.getValue(nodeLight, "animspeed", VisionManager.DEFAULT_LIGHT_ANIM_SPEED),
			nFOV = DB.getValue(nodeLight, "fov", 0),
			sEffectTag = DB.getValue(nodeLight, "tag", ""),
			nDuration = DB.getValue(nodeLight, "duration", 0),
		};
		VisionManager.addLightPreset(tLight);
	end
end
function populateLightPresets()
	for sKey,tLightData in pairs(_tTokenLightDefaults) do
		VisionManager.populateLightPreset(sKey, tLightData);
	end
end
function populateLightPreset(sKey, tLightData)
	tLightData.sName = Interface.getString("lighting_" .. sKey);
	if tLightData.sName == "" then
		tLightData.sName = sKey;
	end
	tLightData.sEffectTag = Interface.getString("lighting_" .. sKey .. "_tag"):lower();
	if tLightData.sEffectTag == "" then
		tLightData.sEffectTag = tLightData.sName:lower();
	end

	local nodeLight = DB.createChild(VisionManager.SETTINGS_TOKENLIGHT_LIST);
	DB.setValue(nodeLight, "name", "string", tLightData.sName or "");
	DB.setValue(nodeLight, "color", "string", tLightData.sColor or "");
	DB.setValue(nodeLight, "bright", "number", (tLightData.nBright or 0) * GameSystem.getDistanceUnitsPerGrid());
	DB.setValue(nodeLight, "dim", "number", (tLightData.nDim or 0) * GameSystem.getDistanceUnitsPerGrid());
	DB.setValue(nodeLight, "falloff", "number", tLightData.nBrightFalloff or VisionManager.DEFAULT_LIGHT_FALLOFF_BRIGHT);
	DB.setValue(nodeLight, "dimfalloff", "number", tLightData.nDimFalloff or VisionManager.DEFAULT_LIGHT_FALLOFF_DIM);
	DB.setValue(nodeLight, "animtype", "string", tLightData.sAnimType or "");
	DB.setValue(nodeLight, "animspeed", "number", tLightData.nAnimSpeed or VisionManager.DEFAULT_LIGHT_ANIM_SPEED);
	DB.setValue(nodeLight, "fov", "number", tLightData.nFOV or 0);
	DB.setValue(nodeLight, "tag", "string", tLightData.sEffectTag or "");
	DB.setValue(nodeLight, "duration", "number", tLightData.nDuration or 0);
end

function findLightPresetDataByTag(sKey)
	if (sKey or "") == "" then
		return nil;
	end
	for _,rPresetData in ipairs(_tTokenLightPresets) do
		local sEffectTag = rPresetData.sEffectTag;
		if sEffectTag == "" then
			sEffectTag = rPresetData.sName;
		end
		if sKey:lower() == sEffectTag:lower() then
			return rPresetData;
		end
	end
end
function getLightPresetEffects()
	local tEffects = {};
	for _,rPresetData in ipairs(_tTokenLightPresets) do
		local sEffectTag = rPresetData.sEffectTag;
		if sEffectTag == "" then
			sEffectTag = rPresetData.sName;
		end
		local nBright = rPresetData.nBright;
		local nDim = rPresetData.nDim;
		if (sEffectTag ~= "") and ((nBright > 0) or (nDim > 0)) then
			local sEffect = "LIGHT: " .. nBright;
			if nDim ~= (2 * nBright) then
				sEffect = sEffect .. "/" .. nDim;
			end
			sEffect = sEffect .. " " .. sEffectTag;

			local rEffect = {
				sDisplayName = rPresetData.sName,
				sName = sEffect,
				nDuration = rPresetData.nDuration or 0,
			};
			table.insert(tEffects, rEffect);
		end
	end
	table.sort(tEffects, function(a,b) return a.sDisplayName < b.sDisplayName end);
	return tEffects;
end

--
-- VISION FUNCTIONS
--

function addVisionType(sText, sKey, bIgnoreBlind)
	_tVisionTypes[sText:lower()] = sKey;
	if bIgnoreBlind then
		_tVisionTypesBlinded[sText:lower()] = sKey;
	end
end
function removeVisionType(sText)
	_tVisionTypes[sText:lower()] = nil;
	_tVisionTypesBlinded[sText:lower()] = nil;
end
function isBlindedVisionKey(s)
	for _,sVisionKey in pairs(_tVisionTypesBlinded) do
		if s == sVisionKey then
			return true;
		end
	end
	return false;
end

function clearVisionFields()
	_tVisionFields = {};
end
function addVisionField(s)
	if (s or "") ~= "" then
		table.insert(_tVisionFields, s);
	end
end
function getVisionFields()
	return _tVisionFields;
end

--
--	ACTOR FUNCTIONS
--

function getActorVisions(vActor)
	local rActor = ActorManager.resolveActor(vActor);

	local tData = {
		defaultvision = not EffectManager.hasCondition(rActor, "Blinded", { bIgnoreExpire = true, }),
		defaultrange = 0,
		rangemax = 0,
		rangemod = 0,
		tVisionData = {},
	};

	VisionManager.getActorVisionsEffectData(rActor, tData);
	VisionManager.getActorVisionsSensesData(rActor, tData);
	VisionManager.getActorVisionsDefault(rActor, tData);
	VisionManager.getActorVisionsApplyMods(rActor, tData);

	return tData.tVisionData;
end
function getActorVisionsEffectData(rActor, tData)
	tData.rangemax = EffectManager.getMinMod(rActor, "VISMAX") or 0;
	tData.rangemod = EffectManager.getBonusMod(rActor, "VISMOD") or 0;

	for _,tCompData in ipairs(EffectManager.getCompsDataByTag(rActor, "VISION")) do
		local sPath = DB.getPath(tCompData.node);
		if (sPath or "") ~= "" then
			if (tCompData.sRemainder or "") == "" then
				tData.defaultrange = math.max(tData.defaultrange or 0, math.max(tCompData.mod or 0, 0));
			else
				tData.tVisionData[sPath] = VisionManager.getVisionDataFromString(tData, tCompData.sRemainder:lower(), tCompData.mod);
			end
		end
	end
end
function getActorVisionsSensesData(rActor, tData)
	local nodeActor = ActorManager.getCreatureNode(rActor);
	for _,sField in ipairs(VisionManager.getVisionFields()) do
		for k,s in ipairs(StringManager.split((DB.getText(nodeActor, sField, "") or ""):lower(), ",;\r\n", true)) do
			tData.tVisionData[sField .. k] = VisionManager.getVisionDataFromString(tData, s, tonumber(s:match("(%d+)")));
		end
	end
end
function getVisionDataFromString(tData, s, nDistance)
	if ((s or "") == "") then
		return nil;
	end

	if tData.defaultvision then
		for sVisionKey, sVisionPreset in pairs(_tVisionTypes) do
			if StringManager.startsWith(s, sVisionKey) then
				return { name = sVisionPreset, distance = nDistance or 0, };
			end
		end
	else
		for sVisionKey, sVisionPreset in pairs(_tVisionTypesBlinded) do
			if StringManager.startsWith(s, sVisionKey) then
				return { name = sVisionPreset, distance = nDistance or 0, };
			end
		end
	end
end
function getActorVisionsDefault(rActor, tData)
	if tData.defaultvision then
		tData.tVisionData[""] = { name = "", distance = tData.defaultrange, };
	else
		tData.tVisionData[""] = { name = "", distance = -1, };
	end
end
function getActorVisionsApplyMods(rActor, tData)
	for _,tVisionData in pairs(tData.tVisionData) do
		tVisionData.distance = VisionManager.applyActorVisionMods(tData, tVisionData.name, tVisionData.distance);
	end
end
function applyActorVisionMods(tData, sVision, nDistance)
	if nDistance < 0 then
		return -1;
	end

	-- Visions that bypass blindness are not affected by VISMOD and VISMAX
	if VisionManager.isBlindedVisionKey(sVision) then
		return nDistance;
	end

	local nLimitedDistance;
	if tData.rangemax <= 0 then
		nLimitedDistance = nDistance;
	else
		if nDistance <= 0 then
			nLimitedDistance = tData.rangemax;
		else
			nLimitedDistance = math.min(nDistance, tData.rangemax);
		end
	end

	local nReducedDistance;
	if tData.rangemod == 0 then
		nReducedDistance = nLimitedDistance;
	else
		if nLimitedDistance <= 0 then
			nReducedDistance = nLimitedDistance;
		else
			nReducedDistance = nLimitedDistance + tData.rangemod;
			if nReducedDistance <= 0 then
				nReducedDistance = -1;
			end
		end
	end

	return nReducedDistance;
end

function getActorLights(vActor)
	local rActor = ActorManager.resolveActor(vActor);

	local tData = {
		tLightData = {},
	};

	VisionManager.getActorLightsEffectData(rActor, tData);

	return tData.tLightData;
end
function getActorLightsEffectData(rActor, tData)
	for _,tCompData in ipairs(EffectManager.getCompsDataByTag(rActor, "LIGHT")) do
		local sPath = DB.getPath(tCompData.node);
		if (sPath or "") ~= "" then
			tData.tLightData[sPath] = VisionManager.getActorLightEffectData(tCompData);
		end
	end
end
function getActorLightEffectData(tCompData)
	if not tCompData then
		return nil;
	end

	local nBrightDistance = math.floor(tCompData.mod);
	local nDimDistance = nil;
	if tCompData.mod2 then
		nDimDistance = math.floor(tCompData.mod2);
	end
	if not nDimDistance then
		nDimDistance = nBrightDistance * 2;
	end

	local tRemainder = StringManager.parseWords(tCompData.sRemainder);

	-- If number is zero, check remainder
	if (nBrightDistance == 0) and (nDimDistance == 0) then
		-- Ignore LIGHT effect with no distance and no tags
		if #tRemainder <= 0 then
			return nil;
		end

		-- Get effect light data from preset if defined
		local rPreset = VisionManager.findLightPresetDataByTag(tRemainder[1]);
		if rPreset then
			return VisionManager.getActorLightPresetData(rPreset);
		end
	end

	-- Next, parse light effect tag, color, animation type/speed or fov setting
	-- 	Ex: "LIGHT: # [color] [<animtype> <animspeed>] [fov #]"
	local nRemainderIndex = 1;
	local sColor = nil;
	local nBrightFalloff = nil;
	local nDimFalloff = nil;
	local sAnimType = nil;
	local nAnimSpeed = nil;
	local nFOV = nil;
	while nRemainderIndex <= #tRemainder do
		local sCheckLower = tRemainder[nRemainderIndex]:lower();
		local rPresetData = VisionManager.findLightPresetDataByTag(sCheckLower);
		if rPresetData then
			sColor = rPresetData.sColor or VisionManager.DEFAULT_LIGHT_COLOR;
			nBrightFalloff = rPresetData.nBrightFalloff;
			nDimFalloff = rPresetData.nDimFalloff;
			sAnimType = rPresetData.sAnimType;
			nAnimSpeed = rPresetData.nAnimSpeed;
			nFOV = rPresetData.nFOV;
			break;
		elseif StringManager.contains({ "flash", "flicker", "pulse", }, sCheckLower) then
			sAnimType = sCheckLower;
			if StringManager.isNumberString(tRemainder[nRemainderIndex + 1]) then
				nAnimSpeed = tonumber(tRemainder[nRemainderIndex + 1]) or 0;
				nRemainderIndex = nRemainderIndex + 1;
			end
		elseif sCheckLower == "fov" then
			if StringManager.isNumberString(tRemainder[nRemainderIndex + 1]) then
				nFOV = tonumber(tRemainder[nRemainderIndex + 1]) or 0;
				nRemainderIndex = nRemainderIndex + 1;
			end
		elseif sCheckLower:match("^%x%x%x%x%x%x%x*$") then
			sColor = sCheckLower;
		end
		nRemainderIndex = nRemainderIndex + 1;
	end

	if (nBrightDistance == 0) and (nDimDistance == 0) then
		return nil;
	end

	-- Add to effect light data
	local tActorLightData = {
		color = sColor or VisionManager.DEFAULT_LIGHT_COLOR,
		bright = nBrightDistance,
		dim = nDimDistance,
		falloff = nBrightFalloff,
		dimfalloff = nDimFalloff,
		animtype = sAnimType,
		animspeed = nAnimSpeed,
		fov = nFOV,
	};
	return tActorLightData;
end
function getActorLightPresetData(rPresetData)
	if not rPresetData then
		return nil;
	end
	if rPresetData.nBright <= 0 and rPresetData.nDim <= 0 then
		return nil;
	end

	local sColor = rPresetData.sColor;
	local bInverse = false;
	if sColor then
		local sColorLower = sColor:lower();
		if (sColorLower == "ff000000") or (sColorLower == "000000") then
			bInverse = true;
		end
	else
		sColor = VisionManager.DEFAULT_LIGHT_COLOR;
	end

	local tActorLightData = {
		color = sColor,
		inverse = bInverse,
		bright = rPresetData.nBright,
		dim = rPresetData.nDim,
		falloff = rPresetData.nBrightFalloff or VisionManager.DEFAULT_LIGHT_FALLOFF_BRIGHT,
		dimfalloff = rPresetData.nDimFalloff or VisionManager.DEFAULT_LIGHT_FALLOFF_DIM,
		animtype = rPresetData.sAnimType or "",
		animspeed = rPresetData.nAnimSpeed or VisionManager.DEFAULT_LIGHT_ANIM_SPEED,
		fov = rPresetData.nFOV,
	};
	return tActorLightData;
end

--
-- TOKEN UPDATE FUNCTIONS
--

function updateTokenVision(nodeField)
	local nodeCT = DB.getParent(nodeField);
	local tokenCT = CombatManager.getTokenFromCT(nodeCT);
	if tokenCT then
		VisionManager.updateTokenVisionHelper(tokenCT, nodeCT);
	end
end
function updateTokenVisionHelper(tokenCT, nodeCT)
	local tTokenVisionsData = VisionManager.getTokenVisionData(tokenCT, nodeCT);
	if not tTokenVisionsData then
		return;
	end
	local tActorVisionData = VisionManager.getActorVisions(nodeCT);
	VisionManager.resolveTokenVision(tTokenVisionsData, tActorVisionData);
	VisionManager.saveTokenVisionInfo(tTokenVisionsData);
end
function getTokenVisionData(tokenCT, nodeCT)
	if not tokenCT or not nodeCT then
		return nil;
	end

	local tTokenVisionsData = {
		token = tokenCT,
		distanceunits = tokenCT.getImageDistanceBaseUnits(),
		node = nodeCT,
		tPrevVisionIDs = {},
		tResolvedVisionIDs = {},
	};
	VisionManager.getTokenVisionPrevData(tTokenVisionsData);
	return tTokenVisionsData;
end
function getTokenVisionPrevData(tTokenVisionsData)
	for _,s in ipairs(StringManager.split(DB.getValue(tTokenVisionsData.node, "addedvisions", ""), "|")) do
		local sKey, sPath = s:match("^(%d+)=(.*)$");
		if (sPath or "") ~= "" then
			local nID = tonumber(sKey) or 0;
			if nID > 0 then
				tTokenVisionsData.tPrevVisionIDs[sPath] = nID;
			end
		else
			-- Cleanup old field format
			if StringManager.isNumberString(sKey) then
				tTokenVisionsData.token.removeVision(tonumber(s) or 0);
			end
		end
	end
end
function resolveTokenVision(tTokenVisionsData, tActorVisionData)
	for sPath, nID in pairs(tTokenVisionsData.tPrevVisionIDs) do
		if Token.isVision(tTokenVisionsData.token, nID) then
			local tTokenVisionData = VisionManager.applyGridVisionDistance(tTokenVisionsData, tActorVisionData[sPath]);
			if tTokenVisionData then
				Token.updateVision(tTokenVisionsData.token, nID, tTokenVisionData);
				tTokenVisionsData.tResolvedVisionIDs[sPath] = nID;
			else
				Token.removeVision(tTokenVisionsData.token, nID);
			end
		end
	end
	for sPath, tVisionData in pairs(tActorVisionData) do
		if sPath == "" then
			local tTokenVisionData = VisionManager.applyGridVisionDistance(tTokenVisionsData, tVisionData);
			if tTokenVisionData then
				Token.setDefaultVision(tTokenVisionsData.token, true);
				Token.setDefaultVisionRange(tTokenVisionsData.token, tTokenVisionData.distance);
			else
				Token.setDefaultVision(tTokenVisionsData.token, false);
				Token.setDefaultVisionRange(tTokenVisionsData.token, 0);
			end
		elseif not tTokenVisionsData.tResolvedVisionIDs[sPath] then
			local tTokenVisionData = VisionManager.applyGridVisionDistance(tTokenVisionsData, tVisionData);
			if tTokenVisionData then
				local nID = Token.addVision(tTokenVisionsData.token, tTokenVisionData);
				if nID > 0 then
					tTokenVisionsData.tResolvedVisionIDs[sPath] = nID;
				end
			end
		end
	end
end
function applyGridVisionDistance(tTokenVisionsData, tVisionData)
	if not tTokenVisionsData or not tVisionData then
		return nil;
	end

	local nGridDistance = math.floor(tVisionData.distance / tTokenVisionsData.distanceunits);
	if (nGridDistance <= 0) and (tVisionData.distance ~= 0) then
		return nil;
	end
	local tTokenVisionData = UtilityManager.copyDeep(tVisionData);
	tTokenVisionData.distance = nGridDistance;
	return tTokenVisionData;
end
function saveTokenVisionInfo(tTokenVisionsData)
	local tVisionFieldData = {};
	for sPath, nID in pairs(tTokenVisionsData.tResolvedVisionIDs) do
		table.insert(tVisionFieldData, string.format("%d=%s", nID, sPath));
	end
	DB.setValue(tTokenVisionsData.node, "addedvisions", "string", table.concat(tVisionFieldData, "|"));
end

function updateTokenLightingHelper(tokenCT, nodeCT)
	local tTokenLightsData = VisionManager.getTokenLightingInfo(tokenCT, nodeCT);
	if not tTokenLightsData then
		return;
	end
	local tActorLightData = VisionManager.getActorLights(nodeCT);
	VisionManager.resolveTokenLighting(tTokenLightsData, tActorLightData);
	VisionManager.saveTokenLightingInfo(tTokenLightsData);
end
function getTokenLightingInfo(tokenCT, nodeCT)
	if not tokenCT or not nodeCT then
		return nil;
	end

	local rActor = ActorManager.resolveActor(nodeCT);
	local nTokenDistanceBaseUnits = tokenCT.getImageDistanceBaseUnits();

	local tTokenLightsData = {
		actor = rActor,
		token = tokenCT,
		distanceunits = nTokenDistanceBaseUnits,
		node = nodeCT,
		tPrevLightIDs = {},
		tResolvedLightIDs = {},
	};
	VisionManager.getTokenLightingPrevData(tTokenLightsData);
	return tTokenLightsData;
end
function getTokenLightingPrevData(tTokenLightsData)
	for _,s in ipairs(StringManager.split(DB.getValue(tTokenLightsData.node, "addedlights", ""), "|")) do
		local sKey, sPath = s:match("^(%d+)=(.*)$");
		if (sPath or "") ~= "" then
			local nLightID = tonumber(sKey) or 0;
			if nLightID > 0 then
				tTokenLightsData.tPrevLightIDs[sPath] = nLightID;
			end
		else
			-- Cleanup old field format
			if StringManager.isNumberString(sKey) then
				tTokenLightsData.token.removeLight(tonumber(s) or 0);
			end
		end
	end
end
function resolveTokenLighting(tTokenLightsData, tActorLightData)
	for sPath, nLightID in pairs(tTokenLightsData.tPrevLightIDs) do
		if Token.isLight(tTokenLightsData.token, nLightID) then
			local tTokenLightData = VisionManager.applyGridLightingDistance(tTokenLightsData, tActorLightData[sPath]);
			if tTokenLightData then
				Token.updateLight(tTokenLightsData.token, nLightID, tTokenLightData);
				tTokenLightsData.tResolvedLightIDs[sPath] = nLightID;
			else
				Token.removeLight(tTokenLightsData.token, nLightID);
			end
		end
	end
	for sPath, tLightData in pairs(tActorLightData) do
		if not tTokenLightsData.tResolvedLightIDs[sPath] then
			local tTokenLightData = VisionManager.applyGridLightingDistance(tTokenLightsData, tLightData);
			if tTokenLightData then
				local nLightID = Token.addLight(tTokenLightsData.token, tTokenLightData);
				if nLightID > 0 then
					tTokenLightsData.tResolvedLightIDs[sPath] = nLightID;
				end
			end
		end
	end
end
function applyGridLightingDistance(tTokenLightsData, tLightData)
	if not tTokenLightsData or not tLightData then
		return nil;
	end

	local nBrightGridDistance = math.floor(tLightData.bright / tTokenLightsData.distanceunits);
	local nDimGridDistance = math.floor(tLightData.dim / tTokenLightsData.distanceunits);
	if nBrightGridDistance <= 0 and nDimGridDistance <= 0 then
		return nil;
	end
	local tTokenLightData = UtilityManager.copyDeep(tLightData);
	tTokenLightData.bright = nBrightGridDistance;
	tTokenLightData.dim = nDimGridDistance;
	return tTokenLightData;
end
function saveTokenLightingInfo(tTokenLightsData)
	local tLightFieldData = {};
	for sPath, nLightID in pairs(tTokenLightsData.tResolvedLightIDs) do
		table.insert(tLightFieldData, string.format("%d=%s", nLightID, sPath));
	end
	DB.setValue(tTokenLightsData.node, "addedlights", "string", table.concat(tLightFieldData, "|"));
end

--
--	MISC
--

function isConcealedFrom(rActor, rTarget, tData)
	return ((rActor ~= nil) and not VisionManager.canPerceive(rActor, rTarget, tData));
end

function canPerceive(rActor, rTarget, tData)
	if not rActor then
		return false;
	end

	if rTarget and VisionManager.isInvisible(rTarget, rActor, tData) then
		return false;
	end
	if VisionManager.isBlinded(rActor, rTarget, tData) then
		return false;
	end

	return true;
end

function isInvisible(rActor, rTarget, tData)
	if not rActor then
		return false;
	end

	local tCheckData = { bIgnoreExpire = true, tActionTags = tData and tData.tActionTags, };
	if not EffectManager.hasCondition(rActor, "Invisible", tCheckData) then
		return false;
	end
	if EffectManager.hasCondition(rActor, "NOINVISIBLE", tCheckData) then
		return false;
	end
	if EffectManager.hasCondition(rTarget, "SEEINVISIBLE", tCheckData) then
		return false;
	end

	return true;
end

function isBlinded(rActor, rTarget, tData)
	if not rActor then
		return false;
	end

	local tCheckData = { bIgnoreExpire = true, tActionTags = tData and tData.tActionTags, };
	if not EffectManager.hasCondition(rActor, "Blinded", tCheckData) then
		return false;
	end
	if not rTarget then
		return true;
	end

	local nRange = ActorManager.getDistanceBetween(rActor, rTarget);
	local tActorVisionData = VisionManager.getActorVisions(rActor);
	for sPath, tVisionData in pairs(tActorVisionData) do
		if VisionManager.isBlindedVisionKey(tVisionData.name) then
			if tVisionData.distance == 0 then
				return false;
			elseif nRange and (tVisionData.distance > 0) and (tVisionData.distance >= nRange) then
				return false;
			end
		end
	end

	return true;
end
