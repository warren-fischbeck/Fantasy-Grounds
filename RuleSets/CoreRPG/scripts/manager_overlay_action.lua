--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onInit()
	GameManager.addEventFunction("onActionPostTargeting", OverlayActionManager.handleTargeting);
end

-- notifyDeliver(rActor, msgOOB)
function notifyDeliver(_, msgOOB)
	if msgOOB.bSecret then
		local tRecipients = { "" };
		-- if Session.IsHost then
		-- 	local sUser = ActorManager.getOwner(rActor);
		-- 	if (sUser or "") ~= "" then
		-- 		table.insert(tRecipients, sUser);
		-- 	end
		-- else
		-- 	table.insert(tRecipients, User.getUsername());
		-- end
		Comm.deliverOOBMessage(msgOOB, tRecipients);
	else
		Comm.deliverOOBMessage(msgOOB);
	end
end

local _tActionBatchAllow = { "attack", "damage", "effect", "save", };
function isNotifyBatchAllowed(sActionKey)
	return StringManager.contains(_tActionBatchAllow, sActionKey);
end
function handleTargeting(rSource, tTargetGroups, rRolls)
	if not rRolls or ((rRolls.sDragType or "") == "") then
		return;
	end

	local nTargets = 0;
	for _,tTargets in ipairs(tTargetGroups or {}) do
		nTargets = nTargets + #(tTargets or {});
	end
	if nTargets < 2 then
		return;
	end

	if StringManager.contains({ "attack", "damage", "effect", }, rRolls.sDragType) then
		OverlayActionManager.setupNotifyBatch(rSource, rRolls.sDragType, nTargets);
	elseif StringManager.contains({ "castsave", "powersave", "spellsave", }, rRolls.sDragType) then
		OverlayActionManager.setupNotifyBatch(rSource, "save", nTargets);
	elseif StringManager.contains({ "cast", }, rRolls.sDragType) then
		for _, rRoll in ipairs(rRolls) do
			if StringManager.contains({ "attack", }, rRoll.sType) then
				OverlayActionManager.setupNotifyBatch(rSource, "attack", nTargets);
				break;
			end
		end
		for _, rRoll in ipairs(rRolls) do
			if StringManager.contains({ "castsave", "powersave", "spellsave", }, rRoll.sType) then
				OverlayActionManager.setupNotifyBatch(rSource, "save", nTargets);
				break;
			end
		end
	end
end

function batchNotify(rSource, rTarget, sActionKey, tData)
	if not rTarget or not tData then
		return false;
	end
	if not OverlayActionManager.isNotifyBatchAllowed(sActionKey) then
		return false;
	end
	local tBatch = OverlayActionManager.getNotifyBatch(rSource, sActionKey);
	if not tBatch then
		return false;
	end
	table.insert(tBatch.tActions, { rTarget = rTarget, tData = tData, });
	tBatch.nResolved = tBatch.nResolved + 1;
	if tBatch.nResolved >= tBatch.nTargets then
		OverlayActionManager.flushNotifyBatch(rSource, sActionKey);
	end
	return true;
end
function flushNotifyBatch(rSource, sActionKey)
	local tBatch = OverlayActionManager.popNotifyBatch(rSource, sActionKey);
	if not tBatch or (#(tBatch.tActions or {}) == 0) then
		return;
	end

	if sActionKey == "attack" then
		OverlayCombatManager.performAttackNotifyBatch(rSource, tBatch.tActions);
	elseif sActionKey == "damage" then
		OverlayCombatManager.performDamageNotifyBatch(rSource, tBatch.tActions);
	elseif sActionKey == "effect" then
		OverlayEffectManager.performEffectAddNotifyBatch(rSource, tBatch.tActions);
	elseif sActionKey == "save" then
		OverlayCombatManager.performSaveNotifyBatch(rSource, tBatch.tActions);
	end
end

local _tNotifyBatchMap = {};
function getNotifyBatch(rSource, sActionKey)
	local sActorKey = ActorManager.getCreatureNode(rSource);
	if not _tNotifyBatchMap[sActorKey] then
		return nil;
	end
	return _tNotifyBatchMap[sActorKey][sActionKey or ""];
end
function setupNotifyBatch(rSource, sActionKey, nTargets)
	local sActorKey = ActorManager.getCreatureNode(rSource);
	_tNotifyBatchMap[sActorKey] = _tNotifyBatchMap[sActorKey] or {};
	if _tNotifyBatchMap[sActorKey][sActionKey or ""] then
		OverlayActionManager.flushNotifyBatch(rSource, sActionKey);
	end
	_tNotifyBatchMap[sActorKey][sActionKey or ""] = { nTargets = nTargets, nResolved = 0, tActions = {}, };
end
function popNotifyBatch(rSource, sActionKey)
	local sActorKey = ActorManager.getCreatureNode(rSource);
	if not _tNotifyBatchMap[sActorKey] then
		return nil;
	end
	local tBatch = _tNotifyBatchMap[sActorKey][sActionKey or ""];
	_tNotifyBatchMap[sActorKey][sActionKey or ""] = nil;
	return tBatch;
end
