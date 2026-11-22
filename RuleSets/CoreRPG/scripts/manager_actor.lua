--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

--
-- NOTE: You should not access actor variable information directly;
--		as format and usage may change over time.
--		Use the functions provided to interact with actor records
--
--  **DATA STRUCTURES**
--
-- rActor
--		sType
--		sCreatureNode
-- 		sCTNode
--		sName
--

local _tActorRecordTypes = {};
local _tActorTypePathHandlers = {};
local _tCombatTrackerLookups = {};

function onInit()
	ActorManager.registerStandardRecordTypes();
	ActorManager.registerStandardCTLookup();
end

function registerStandardRecordTypes()
	ActorManager.registerActorRecordType("charsheet");
	ActorManager.registerActorRecordType("npc");
	ActorManager.registerActorRecordType("vehicle");
end
function registerStandardCTLookup()
	ActorManager.registerCTNodeLookup(CombatManager.getCTFromNode);
end

function getActiveActor()
	if Session.IsHost then
		return ActorManager.resolveActor(CombatManager.getActiveCT());
	end

	local sIdentity = User.getCurrentIdentity();
	if (sIdentity or "") == "" then
		return nil;
	end
	return ActorManager.resolveActor("charsheet." .. sIdentity);
end

--
-- ACTOR RESOLUTION
--

function registerActorRecordType(sRecordType)
	if sRecordType == "ct" then
		return;
	end
	_tActorRecordTypes[sRecordType] = true;
end
function registerActorTypePathHandler(sPath, v)
	_tActorTypePathHandlers[sPath] = v;
end

function registerCTNodeLookup(fn)
	table.insert(_tCombatTrackerLookups, fn);
end

function resolveActor(v)
	-- Get actor node
	local nodeActor = nil;
	local sVarType = type(v);
	if sVarType == "table" then
		return v;
	elseif sVarType == "string" then
		if v == "" then
			return nil;
		end
		nodeActor = DB.findNode(v);
		--	NOTE: Handle cases where PC targets another PC they do not own,
		--		which means they do not have access to PC record but they do have access to CT record.
		--	NOTE 2: Technically no longer needed; since all campaign PC data is now shared
		if not nodeActor then
			local sCTPath = ActorManager.getCTPathFromActorNode(v);
			if sCTPath then
				nodeActor = DB.findNode(sCTPath);
			end
		end
	elseif sVarType == "databasenode" then
		nodeActor = v;
	elseif sVarType == "tokeninstance" then
		nodeActor = CombatManager.getCTFromToken(v);
	end
	if not nodeActor then
		return nil;
	end

	-- Determine type unless specified
	local sActorNodePath = DB.getPath(nodeActor);
	local sActorType = ActorManager.getActorRecordTypeFromPath(sActorNodePath);
	if (sActorType or "") == "" then
		return nil;
	end

	-- Return actor information
	local rActor = {};
	if sActorType == "ct" then
		local sClass, sRecord = DB.getValue(nodeActor, "link", "", "");
		rActor.sType = ActorManager.getActorRecordTypeFromPath(sRecord);
		if rActor.sType and rActor.sType ~= "ct" then
			rActor.sCreatureNode = sRecord;
		else
			rActor.sType = RecordDataManager.getRecordTypeFromDisplayClass(sClass);
			rActor.sCreatureNode = sActorNodePath;
		end
		rActor.sCTNode = sActorNodePath;
	else
		rActor.sType = sActorType;
		rActor.sCreatureNode = sActorNodePath;
		rActor.sCTNode = ActorManager.getCTPathFromActorNode(nodeActor);
	end

	rActor.sName = ActorManager.resolveDisplayName(rActor);

	return rActor;
end

-- Internal use only
function getCTPathFromActorNode(nodeActor)
	for _,fn in ipairs(_tCombatTrackerLookups) do
		local nodeCT = fn(nodeActor);
		if nodeCT then
			return DB.getPath(nodeCT);
		end
	end
	return nil;
end

-- Internal use only
function getActorRecordTypeFromPath(sPath)
	if CombatManager.isTrackerCT(sPath) then
		return "ct";
	end

	local sType = RecordDataManager.getRecordTypeFromRecordPath(sPath);
	if _tActorRecordTypes[sType] then
		return sType;
	end

	for sTypePath, vType in pairs(_tActorTypePathHandlers) do
		if UtilityManager.isPathMatch(sPath, sTypePath) then
			if type(vType) == "function" then
				return vType(sPath);
			else
				return vType;
			end
		end
	end

	return nil;
end

-- Internal use only
function resolveDisplayName(rActor)
	if RecordDataManager.getIDMode(rActor.sType) then
		local node = ActorManager.getCTNode(rActor);
		if not node then
			node = ActorManager.getCreatureNode(rActor);
		end
		if node then
			if RecordDataManager.getIDState(rActor.sType, node, true) then
				return DB.getValue(node, "name", "");
			else
				return DB.getValue(node, "nonid_name", "");
			end
		end
	else
		local node = ActorManager.getCTNode(rActor);
		if not node then
			node = ActorManager.getCreatureNode(rActor);
		end
		if node then
			return DB.getValue(node, "name", "");
		end
	end

	return "";
end

--
-- PROPERTIES
--

function getRecordType(v)
	local rActor = ActorManager.resolveActor(v);
	if rActor then
		return rActor.sType or "";
	end
	return "";
end
function isRecordType(v, vRecordType)
	if type(vRecordType) == "table" then
		return StringManager.contains(vRecordType, ActorManager.getRecordType(v));
	end
	return (ActorManager.getRecordType(v) == vRecordType);
end
function isPC(v)
	return ActorManager.isRecordType(v, "charsheet");
end

function getOwner(v)
	local nodeActor = ActorManager.getCreatureNode(v);
	if not nodeActor then
		return "";
	end
	return DB.getOwner(nodeActor);
end
function isOwner(v)
	if Session.IsHost then
		return true;
	end
	local nodeActor = ActorManager.getCreatureNode(v);
	if not nodeActor then
		return false;
	end
	return DB.isOwner(nodeActor);
end

function hasCT(v)
	return (ActorManager.getCTNodeName(v) ~= "");
end
function getCTNodeName(v)
	local rActor = ActorManager.resolveActor(v);
	if rActor then
		return rActor.sCTNode or "";
	end
	return "";
end
function getCTNode(v)
	local sCTNode = ActorManager.getCTNodeName(v);
	if (sCTNode or "") ~= "" then
		return DB.findNode(sCTNode);
	end
	return nil;
end

function getCreatureNodeName(v)
	local rActor = ActorManager.resolveActor(v);
	if rActor then
		return rActor.sCreatureNode or "";
	end
	return "";
end
function getCreatureNode(v)
	local rActor = ActorManager.resolveActor(v);
	if rActor and ((rActor.sCreatureNode or "") ~= "") then
		return DB.findNode(rActor.sCreatureNode);
	end
	return nil;
end

function getFaction(v)
	local rActor = ActorManager.resolveActor(v);
	local nodeCT = ActorManager.getCTNode(rActor);
	return CombatManager.getFactionFromCT(nodeCT);
end
function isFaction(v, sFaction)
	return (ActorManager.getFaction(v) == sFaction);
end

function isVisible(v)
	local rActor = ActorManager.resolveActor(v);
	local nodeCT = ActorManager.getCTNode(rActor);
	if not nodeCT then
		return false;
	end
	if CombatManager.getFactionFromCT(nodeCT) == "friend" then
		return true;
	end
	return CombatManager.getTokenVisibilityFromCT(nodeCT);
end

function getDisplayName(v)
	local rActor = ActorManager.resolveActor(v);
	if not rActor then
		return "";
	end
	return rActor.sName;
end
function getBaseName(v)
	local _,sSourceLinkPath = DB.getValue(ActorManager.getCreatureNode(v), "sourcelink", "", "");
	if sSourceLinkPath ~= "" then
		local nodeSourceLink = DB.findNode(sSourceLinkPath);
		if nodeSourceLink then
			return DB.getValue(nodeSourceLink, "name", "");
		end
	end
	local sName = ActorManager.getDisplayName(v);
	if (sName or "") == "" then
		return "";
	end
	return CombatManager.stripCreatureNumber(sName);
end

function getToken(v)
	local nodeCT = ActorManager.getCTNode(v);
	if not nodeCT then
		return nil;
	end
	return Token.getToken(DB.getValue(nodeCT, "tokenrefnode", ""), DB.getValue(nodeCT, "tokenrefid", ""));
end

--
--	MISC
--

function isEqual(rActor1, rActor2)
	if not rActor1 or not rActor2 then
		return false;
	end
	return (ActorManager.getCreatureNodeName(rActor1) == ActorManager.getCreatureNodeName(rActor2));
end

function getDistanceBetween(rActor, rTarget)
	local tokenSource = ActorManager.getToken(rActor);
	local tokenTarget = ActorManager.getToken(rTarget);
	if not tokenSource or not tokenTarget then
		return nil;
	end
	return Token.getDistanceBetween(tokenSource, tokenTarget);
end
function isInRange(rActor, rTarget, nRange)
	local nTokenRange = ActorManager.getDistanceBetween(rActor, rTarget);
	if not nTokenRange then
		return false;
	end
	return (nTokenRange <= (nRange or 0));
end

function canRest(rActor, sRestType)
	local tData = { tFilter = { sRestType }, };
	return not EffectManager.hasTextOrTag(rActor, "NOREST", tData);
end
function canHeal(rActor, sSubtype)
	local tData = { tFilter = { sSubtype }, };
	return not EffectManager.hasTextOrTag(rActor, "NOHEAL", tData);
end

function checkRest(rActor, sRestType)
	if not ActorManager.canRest(rActor, sRestType) then
		ChatManager.Message(Interface.getString("message_restblocked"), true, rActor);
		return false;
	end
	return true;
end

function hasInventory(rActor)
	return RecordDataManager.getRecordTypeOption(ActorManager.getRecordType(rActor), "bInventory");
end
function hasCurrency(rActor)
	return RecordDataManager.getRecordTypeOption(ActorManager.getRecordType(rActor), "bCurrency");
end


--
--	LEGACY
--

function addActiveEffectNode(rActor, vNode)
	ActorEffectManager.addActiveEffectNode(rActor, vNode);
end
function getEffects(vActor)
	return ActorEffectManager.getEffects(vActor);
end

function getTypeAndNode(v)
	Debug.console("ActorManager.getTypeAndNode/getTypeAndNodeName - DEPRECATED - 2025-04-22 - Use ActorManager.isPC/isRecordType/getCreatureNode/getCTNode");
	local rActor = ActorManager.resolveActor(v);
	if not rActor then
		return nil, nil;
	end

	if ActorManager.isPC(rActor) then
		local nodeCreature = ActorManager.getCreatureNode(rActor);
		if nodeCreature and DB.isOwner(nodeCreature) then
			return "pc", nodeCreature;
		end
	end

	local nodeCT = ActorManager.getCTNode(rActor);
	if nodeCT then
		return "ct", nodeCT;
	end

	if not ActorManager.isPC(rActor) then
		local nodeNPC = ActorManager.getCreatureNode(rActor);
		if nodeNPC then
			return rActor.sType, nodeNPC;
		end
	end

	return nil, nil;
end
function getTypeAndNodeName(v)
	local sType, nodeCreature = ActorManager.getTypeAndNode(v);
	if nodeCreature then
		return sType, DB.getPath(nodeCreature);
	end
	return sType, nil;
end
