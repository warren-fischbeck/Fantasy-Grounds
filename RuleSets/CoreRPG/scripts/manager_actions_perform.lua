--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

-- NOTE: GameManager.setFunction("onActionGetRoll", fn) required in ruleset code to support these functions
-- NOTE: Format of tActionQueueEntry for performActionQueueEntry and in list for performActionQueue is primarily specified by ruleset.
-- 			Exceptions:
--				sTargeting = specify none/self to override targeting; also, each/all will override for GameManager.getActionProperty(sDragType, "sTargeting") default
--				sTrigger = triggered roll type for opposed rolls
--				sAuto = result automation filter (must be set by ruleset, but filtering performed here.)
-- NOTE: Future action optional triggers can be controlled by specifying result condition string in the action data entry
--			(i.e. if hit, then do more; if not save, then do more)
--			Situations like half damage on miss are already handled for spells in most ruleset (no result condition needed)
-- 			Use ActionsPerformManager.setResultState(rSource, rTarget, sState) to set the active result condition string

OOB_MSGTYPE_ACTION_SET_RESULT_STATE = "actionsetresultstate";
OOB_MSGTYPE_ACTION_ROLL_COMPLETE = "actionrollcomplete";

function onInit()
	Comm.registerSlashHandler("cq", ActionsPerformManager.clearAllActionQueues);
	OOBManager.registerOOBMsgHandler(ActionsPerformManager.OOB_MSGTYPE_ACTION_ROLL_COMPLETE, ActionsPerformManager.handleActionRollCompleted);
	OOBManager.registerOOBMsgHandler(ActionsPerformManager.OOB_MSGTYPE_ACTION_SET_RESULT_STATE, ActionsPerformManager.handleActionResultState);
end

local _tActionQueuesByActor = {};
function peekActorActionQueueData(rActor)
	local sSource = ActorManager.getCreatureNodeName(rActor);
	if sSource == "" then
		return nil;
	end
	return (_tActionQueuesByActor[sSource] or {})[1];
end
function enqueueActorActionQueueData(rActor, tTargets, tActionQueueData)
	local sSource = ActorManager.getCreatureNodeName(rActor);
	if sSource == "" then
		return;
	end
	_tActionQueuesByActor[sSource] = _tActionQueuesByActor[sSource] or {};
	table.insert(_tActionQueuesByActor[sSource], { tTargets = tTargets or {}, tSet = tActionQueueData, tResultState = {}, tNextResultState = {}, });
end
function dequeueActorActionQueueData(rActor)
	local sSource = ActorManager.getCreatureNodeName(rActor);
	if sSource == "" then
		return;
	end
	if #(_tActionQueuesByActor[sSource] or {}) <= 0 then
		return;
	end
	table.remove(_tActionQueuesByActor[sSource], 1);
end
function clearActorActionQueues(rActor)
	local sSource = ActorManager.getCreatureNodeName(rActor);
	if sSource == "" then
		return;
	end
	_tActionQueuesByActor[sSource] = {};
end
function clearAllActionQueues()
	_tActionQueuesByActor = {};
end

function performActionQueue(rActor, tTargets, tActionQueueData)
	if #(tActionQueueData or {}) <= 0 then
		return;
	end

	ActionsPerformManager.enqueueActorActionQueueData(rActor, tTargets, tActionQueueData);
	ActionsPerformManager.performNextQueueAction(rActor);
end
function performNextQueueAction(rActor)
	local tActionQueueData = ActionsPerformManager.peekActorActionQueueData(rActor);
	if not tActionQueueData then
		return;
	end
	if tActionQueueData.bRolling then
		return;
	end

	local tActionQueueEntry = tActionQueueData.tSet[1];
	if not tActionQueueEntry then
		ActionsPerformManager.finalizeQueueAction(rActor);
		return;
	end
	tActionQueueData.tActionTargets = ActionsPerformManager.getNextActionTargets(rActor, tActionQueueData, tActionQueueEntry);
	local tRollTargets = ActionsPerformManager.getNextActionRollTargets(rActor, tActionQueueData, tActionQueueEntry);

	-- Skip the action if the actor had targets, but none of them qualify (i.e. sAuto result filter)
	-- NOTE: For "totargets", the action target is always the actor, so check the qualifying roll targets instead
	if #(tActionQueueData.tTargets) > 0 then
		local bSkip;
		if tActionQueueEntry.sTargeting == "totargets" then
			bSkip = (#(tRollTargets or {}) == 0);
		else
			bSkip = not StringManager.contains({ "self", "none", }, tActionQueueEntry.sTargeting) and (#(tActionQueueData.tActionTargets) == 0);
		end
		if bSkip then
			ActionsPerformManager.finalizeQueueAction(rActor);
			return;
		end
	end

	if ActionsPerformManager.performActionQueueEntry(rActor, tActionQueueData.tActionTargets, tActionQueueEntry, tRollTargets) then
		tActionQueueData.bRolling = true;
	else
		ActionsPerformManager.finalizeQueueAction(rActor);
	end
end
function getNextActionTargets(rActor, tActionQueueData, tActionQueueEntry)
	local sTargeting = (tActionQueueEntry and tActionQueueEntry.sTargeting) or "";
	if sTargeting == "none" then
		return {};
	elseif StringManager.contains({ "self", "totargets", }, sTargeting) then
		return { rActor };
	end

	local tActionTargets = {};
	for k,rTarget in ipairs(tActionQueueData.tTargets) do
		local tResultData = ActionsPerformManager.getActionResultStateByIndex(rActor, k);
		if ((tActionQueueEntry.sAuto or "") == "") or (tActionQueueEntry.sAuto == (tResultData.sAuto or "")) then
			table.insert(tActionTargets, rTarget);
		end
		if tActionQueueEntry.sType == "damage" then
			ActionDamageCore.setDamageState(rActor, rTarget, tResultData.sDamageLabel, tResultData.sDamageResult);
		end
	end
	return tActionTargets;
end

-- NOTE: For "totargets" targeting, the action is applied to the actor (tActionTargets = { rActor }),
--			but the roll itself needs the actor's targets (i.e. effect-specific targeting).
--			Returns nil when the roll should use the same targets as the action.
function getNextActionRollTargets(rActor, tActionQueueData, tActionQueueEntry)
	local sTargeting = (tActionQueueEntry and tActionQueueEntry.sTargeting) or "";
	if sTargeting ~= "totargets" then
		return nil;
	end

	local tRollTargets = {};
	for k,rTarget in ipairs(tActionQueueData.tTargets or {}) do
		local tResultData = ActionsPerformManager.getActionResultStateByIndex(rActor, k);
		if ((tActionQueueEntry.sAuto or "") == "") or (tActionQueueEntry.sAuto == (tResultData.sAuto or "")) then
			table.insert(tRollTargets, rTarget);
		end
	end
	return tRollTargets;
end

-- NOTE: tRollTargets (optional) = targets passed to onActionGetRoll, if different than action targets (i.e. "totargets")
function performActionQueueEntry(rActor, tTargets, tActionQueueEntry, tRollTargets)
	if not rActor then
		return false;
	end
	if not tActionQueueEntry then
		return false;
	end

	local rRoll = GameManager.callFunction("onActionGetRoll", rActor, tRollTargets or tTargets, tActionQueueEntry);
	if not rRoll then
		return false;
	end

	local tTargetGroups = ActionsPerformManager.getActionQueueEntryTargetingGroups(rActor, tTargets, rRoll, tActionQueueEntry);
	ActionsManager.actionDirect(rActor, rRoll.sType, { rRoll }, tTargetGroups);
	return true;
end
function getActionQueueEntryTargetingGroups(rActor, tTargets, rRoll, tActionQueueEntry)
	local sTargeting = (tActionQueueEntry and tActionQueueEntry.sTargeting) or "";
	if (sTargeting or "") == "" then
		sTargeting = GameManager.getActionProperty(rRoll.sType, "sTargeting") or "";
	end
	if sTargeting == "none" then
		return { { } };
	elseif StringManager.contains({ "self", "totargets", }, sTargeting) then
		return { { rActor } };
	elseif sTargeting == "each" then
		if #(tTargets or {}) <= 0 then
			return { { } };
		end

		local tTargetGroups = {};
		for _,rTarget in ipairs(tTargets) do
			table.insert(tTargetGroups, { rTarget });
		end
		return tTargetGroups;
	end
	return { tTargets or {}, };
end

function getActionResultStateByIndex(rSource, k)
	local tActionQueueData = ActionsPerformManager.peekActorActionQueueData(rSource);
	if not tActionQueueData then
		return {};
	end
	return tActionQueueData.tResultState[k] or {};
end
function setActionResultState(rSource, rTarget, tData)
	ActionsPerformManager.notifyActionResultState(rSource, rTarget, tData);
end
function notifyActionResultState(rSource, rTarget, tData)
	local msgOOB = {
		type = ActionsPerformManager.OOB_MSGTYPE_ACTION_SET_RESULT_STATE,
		sSourceNode = ActorManager.getCreatureNodeName(rSource);
		sTargetNode = ActorManager.getCreatureNodeName(rTarget);
		jsonData = Utility.encodeJSON(tData or {}) or "",
	};
	Comm.deliverOOBMessage(msgOOB);
end
function handleActionResultState(msgOOB)
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rTarget = ActorManager.resolveActor(msgOOB.sTargetNode);
	local tData = Utility.decodeJSON(msgOOB.jsonData) or {};
	ActionsPerformManager.setActionResultStateInternal(rSource, rTarget, tData);
end
function setActionResultStateInternal(rSource, rTarget, tData)
	if tData.sDamageLabel and tData.sDamageResult then
		ActionDamageCore.setDamageState(rSource, rTarget, tData.sDamageLabel, tData.sDamageResult);
	end

	local tActionQueueData = ActionsPerformManager.peekActorActionQueueData(rSource);
	if not tActionQueueData then
		return;
	end

	for k, rActionQueueTarget in ipairs(tActionQueueData.tTargets) do
		if ActorManager.isEqual(rActionQueueTarget, rTarget) then
			if not tActionQueueData.tNextResultState[k] then
				tActionQueueData.tNextResultState[k] = tData;
				return;
			end
		end
	end
end

function prepareForNextAction(rSource)
	local tActionQueueData = ActionsPerformManager.peekActorActionQueueData(rSource);
	if not tActionQueueData then
		return;
	end

	tActionQueueData.nCompleted = nil;
	for k, tResultData in pairs(tActionQueueData.tNextResultState) do
		tActionQueueData.tResultState[k] = tResultData;
	end
	tActionQueueData.tNextResultState = {};
end

function notifyActionRollCompleted(rSource, rTarget, rRoll)
	local msgOOB = {
		type = ActionsPerformManager.OOB_MSGTYPE_ACTION_ROLL_COMPLETE,
		sSourceNode = ActorManager.getCreatureNodeName(rSource);
		sTargetNode = ActorManager.getCreatureNodeName(rTarget);
		jsonRoll = Utility.encodeJSON(rRoll) or "",
	};
	Comm.deliverOOBMessage(msgOOB);
end
function handleActionRollCompleted(msgOOB)
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rTarget = ActorManager.resolveActor(msgOOB.sTargetNode);
	local rRoll = Utility.decodeJSON(msgOOB.jsonRoll);

	if ActionsPerformManager.checkActionComplete(rSource, rTarget, rRoll) then
		ActionsPerformManager.finalizeQueueAction(rSource);
	end
	if ActionsPerformManager.checkActionComplete(rTarget, rSource, rRoll) then
		ActionsPerformManager.finalizeQueueAction(rTarget);
	end
end
function checkActionComplete(rSource, rTarget, rRoll)
	local tActionQueueData = ActionsPerformManager.peekActorActionQueueData(rSource);
	if not tActionQueueData then
		return false;
	end
	local tActionQueueEntry = tActionQueueData.tSet[1];
	if not tActionQueueEntry then
		return true;
	end

	-- CHECK FOR MATCHING ROLL TYPE
	if (rRoll.sType or "") == "" then
		return false;
	end

	-- CHECK FOR MATCHING TARGET; AND THAT ALL TARGETS ACCOUNTED FOR
	if #(tActionQueueData.tActionTargets or {}) <= 0 then
		return true;
	end

	-- CHECK FOR OPPOSED ROLLS TO RESOLVE
	local sOpposed = (tActionQueueEntry and tActionQueueEntry.sOpposed) or "";
	if ((sOpposed ~= "") and (tActionQueueEntry.sOpposed ~= rRoll.sType)) or ((sOpposed == "") and (tActionQueueEntry.sType ~= rRoll.sType)) then
		return false;
	end

	local rTargetMatch = nil;
	for _,rSetTarget in ipairs(tActionQueueData.tActionTargets) do
		if ActorManager.isEqual(rTarget, rSetTarget) then
			rTargetMatch = rSetTarget;
			break;
		end
	end
	if not rTargetMatch then
		return false;
	end

	tActionQueueData.nCompleted = (tActionQueueData.nCompleted or 0) + 1;
	return (tActionQueueData.nCompleted >= #(tActionQueueData.tActionTargets));
end
function finalizeQueueAction(rActor)
	local tActionQueueData = ActionsPerformManager.peekActorActionQueueData(rActor);
	if not tActionQueueData then
		return;
	end

	tActionQueueData.bRolling = false;
	if #(tActionQueueData.tSet or {}) > 0 then
		table.remove(tActionQueueData.tSet, 1);
	end

	if #(tActionQueueData.tSet or {}) > 0 then
		ActionsPerformManager.prepareForNextAction(rActor);
	else
		ActionsPerformManager.dequeueActorActionQueueData(rActor);
	end

	ActionsPerformManager.performNextQueueAction(rActor);
end
