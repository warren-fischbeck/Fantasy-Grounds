--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function encodeActionText(rAction)
	return ActionCore.encodeActionText(rAction, "action_attack_tag");
end
function decodeRollData(rRoll)
	ActionCore.decodeRollData(rRoll, "action_attack_tag");
end
function decodeRangeText(s, sDefault)
	return ActionCore.decodeRangeText(s, "action_attack_tag", sDefault);
end
function decodeLabelText(s)
	return ActionCore.decodeLabelText(s, "action_attack_tag");
end

--
--	GENERAL CRIT STATE HANDLING
--

local _tCritState = {};

function setCritState(rSource, rTarget)
	local sSource = ActorManager.getCreatureNodeName(rSource);
	if (sSource == "") then
		return;
	end
	local sTargetCT = ActorManager.getCTNodeName(rTarget);

	_tCritState[sSource] = _tCritState[sSource] or {};
	_tCritState[sSource][sTargetCT] = true;
end
function getCritState(rSource, rTarget)
	local sSource = ActorManager.getCreatureNodeName(rSource);
	if (sSource == "") then
		return false;
	end
	if not _tCritState[sSource] then
		return false;
	end
	local sTargetCT = ActorManager.getCTNodeName(rTarget);

	local bReturn = _tCritState[sSource][sTargetCT] or false;
	_tCritState[sSource][sTargetCT] = nil;
	return bReturn;
end
function clearCritState(rSource, rTarget)
	if rTarget then
		local sSource = ActorManager.getCreatureNodeName(rSource);
		if (sSource == "") then
			return;
		end
		local sTargetCT = ActorManager.getCTNodeName(rTarget);

		_tCritState[sSource] = _tCritState[sSource] or {};
		_tCritState[sSource][sTargetCT] = nil;
	else
		local sSource = ActorManager.getCreatureNodeName(rSource);
		if (sSource == "") then
			return;
		end

		_tCritState[sSource] = nil;
	end
end
