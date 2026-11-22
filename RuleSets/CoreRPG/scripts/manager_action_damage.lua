--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function encodeActionText(rAction)
	return ActionCore.encodeActionText(rAction, "action_damage_tag");
end
function decodeRollData(rRoll)
	ActionCore.decodeRollData(rRoll, "action_damage_tag");
end
function decodeRangeText(s, sDefault)
	return ActionCore.decodeRangeText(s, "action_damage_tag", sDefault);
end
function decodeLabelText(s)
	return ActionCore.decodeLabelText(s, "action_damage_tag");
end

function getDamageTypeIcon(s)
	if (s or "") == "" then
		return "damage-generic";
	end
	if StringManager.contains({ "acid", "corrosive", "water", }, s) then
		return "damage-acid";
	elseif StringManager.contains({ "bludgeoning", "blunt", "crushing", }, s) then
		return "damage-bludgeoning";
	elseif StringManager.contains({ "cold", }, s) then
		return "damage-cold";
	elseif StringManager.contains({ "fire", "heat", "laser", }, s) then
		return "damage-fire";
	elseif StringManager.contains({ "force", "energy", }, s) then
		return "damage-force";
	elseif StringManager.contains({ "lightning", "electricity", "plasma", }, s) then
		return "damage-lightning";
	elseif StringManager.contains({ "necrotic", "negative", "unholy", }, s) then
		return "damage-necrotic";
	elseif StringManager.contains({ "piercing", "ballistic", }, s) then
		return "damage-piercing";
	elseif StringManager.contains({ "poison", "gas", "radiation", }, s) then
		return "damage-poison";
	elseif StringManager.contains({ "psychic", "mental", "psionic", "spirit", "void", }, s) then
		return "damage-psychic";
	elseif StringManager.contains({ "radiant", "positive", "holy", }, s) then
		return "damage-radiant";
	elseif StringManager.contains({ "slashing", "kinetic", "physical", }, s) then
		return "damage-slashing";
	elseif StringManager.contains({ "thunder", "sonic", }, s) then
		return "damage-thunder";
	end
	return "damage-generic";
end
function getDamageTypeColor(s)
	if (s or "") == "" then
		return "FF0000";
	end
	if StringManager.contains({ "acid", "corrosive", "gas", "poison", "radiation", }, s) then
		return "00FF00";
	elseif StringManager.contains({ "cold", "sonic", "thunder", "water", }, s) then
		return "0000FF";
	elseif StringManager.contains({ "fire", "heat", "laser", }, s) then
		return "FF0000";
	elseif StringManager.contains({ "force", "energy", "mental", "necrotic", "negative", "psionic", "psychic", "spirit", "unholy", "void", }, s) then
		return "800080";
	elseif StringManager.contains({ "lightning", "electricity", "holy", "plasma", "positive", "radiant", }, s) then
		return "FFD700";
	end
	return "FF0000";
end

--
--	GENERAL DAMAGE STATE HANDLING
--

OOB_MSGTYPE_APPLYDMGSTATE = "applydmgstate";

function registerStandardDamageStateHandlers()
	OOBManager.registerOOBMsgHandler(ActionDamageCore.OOB_MSGTYPE_APPLYDMGSTATE, ActionDamageCore.handleApplyDamageState);
end

local _tDamageState = {};

function notifyApplyDamageState(rSource, rTarget, sAttack, sState)
	local msgOOB = {};
	msgOOB.type = ActionDamageCore.OOB_MSGTYPE_APPLYDMGSTATE;
	msgOOB.sSourceNode = ActorManager.getCTNodeName(rSource);
	msgOOB.sTargetNode = ActorManager.getCTNodeName(rTarget);
	msgOOB.sAttack = sAttack;
	msgOOB.sState = sState;

	Comm.deliverOOBMessage(msgOOB, "");
end
function handleApplyDamageState(msgOOB)
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rTarget = ActorManager.resolveActor(msgOOB.sTargetNode);
	if Session.IsHost then
		ActionDamageCore.setDamageState(rSource, rTarget, msgOOB.sAttack, msgOOB.sState);
	end
end

function setDamageState(rSource, rTarget, sAttack, sState)
	if not Session.IsHost then
		ActionDamageCore.notifyApplyDamageState(rSource, rTarget, sAttack, sState);
		return;
	end

	local sSourceCT = ActorManager.getCTNodeName(rSource);
	local sTargetCT = ActorManager.getCTNodeName(rTarget);
	if (sSourceCT == "") or (sTargetCT == "") then
		return;
	end

	_tDamageState[sSourceCT] = _tDamageState[sSourceCT] or {};
	_tDamageState[sSourceCT][sTargetCT] = _tDamageState[sSourceCT][sTargetCT] or {};
	_tDamageState[sSourceCT][sTargetCT][sAttack or ""] = sState;
end
function getDamageState(rSource, rTarget, sAttack)
	local sSourceCT = ActorManager.getCTNodeName(rSource);
	local sTargetCT = ActorManager.getCTNodeName(rTarget);
	if (sSourceCT == "") or (sTargetCT == "") then
		return "";
	end

	if not _tDamageState[sSourceCT] then
		return "";
	end
	if not _tDamageState[sSourceCT][sTargetCT] then
		return "";
	end
	if not _tDamageState[sSourceCT][sTargetCT][sAttack or ""] then
		return "";
	end

	local sState = _tDamageState[sSourceCT][sTargetCT][sAttack or ""];
	_tDamageState[sSourceCT][sTargetCT][sAttack or ""] = nil;
	return sState;
end

--
--	MISC
--

function getDamageTypeArray(s)
	if not s then
		return {};
	end

	local tDamageTypes = {};
	for _,v in ipairs(StringManager.splitByPattern(s:lower(), ",", true)) do
		if ActionCore.isDamageType(v) then
			table.insert(tDamageTypes, v);
		end
	end
	return tDamageTypes;
end
