--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

OOB_MSGTYPE_FAILEDSAVEEFF = "failedsaveeff";

function onInit()
	EffectManager.setTagOptions("SAVEDMG", { bIgnoreDisabled = true, });

    OOBManager.registerOOBMsgHandler(ActionSaveCore.OOB_MSGTYPE_FAILEDSAVEEFF, ActionSaveCore.handleFailedEffectSave);
end

function encodeActionText(rAction)
	return ActionCore.encodeActionText(rAction, "action_save_tag");
end
function decodeRollData(rRoll)
	ActionCore.decodeRollData(rRoll, "action_save_tag");
end
function decodeRangeText(s, sDefault)
	return ActionCore.decodeRangeText(s, "action_save_tag", sDefault);
end
function decodeLabelText(s)
	return ActionCore.decodeLabelText(s, "action_save_tag");
end

--
--	EFFECT SAVE RESULT HANDLING
--

function handleSaveSuccess(rActor, rOrigin, rRoll)
	if (rRoll.sSaveDesc or ""):match("%[HALF ON SAVE]") then
		ActionSaveCore.handleSaveDamage(rActor, rOrigin, rRoll);
	end

	if StringManager.contains({ "any", "success", }, rRoll.sEffectExpire) and ((rRoll.sEffectRecord or "") ~= "") then
		EffectManager.expireEffectByNode(nil, DB.findNode(rRoll.sEffectRecord), { bImmediate = true, });
	end
end
function handleSaveFail(rActor, rOrigin, rRoll)
	ActionSaveCore.handleSaveDamage(rActor, rOrigin, rRoll);
	if StringManager.contains({ "any", "fail", }, rRoll.sEffectExpire) and ((rRoll.sEffectRecord or "") ~= "") then
		EffectManager.expireEffectByNode(nil, DB.findNode(rRoll.sEffectRecord), { bImmediate = true, });
	end
	ActionSaveCore.notifyFailedEffectSave(rActor, rRoll.sEffectRecord);
end

function applyOngoingDamage(rActor, tCompData, rEffectActor)
	local rRoll = ActionHealthD20.getOngoingDamageRoll(rActor, tCompData);
	if not rRoll then
		return;
	end

	local rOrigin = EffectManager.getSourceActor(tCompData.node) or rEffectActor or rActor;

	local sLabel = Interface.getString("effect_special_DMGO");
	rRoll.sDesc = ActionDamageCore.encodeActionText({ label = sLabel, });
	rRoll.bSecret = (DB.getValue(tCompData.node, "isgmonly", 0) == 1);

	ActionsManager.actionDirect(rOrigin, rRoll.sType, { rRoll }, { { rActor } });
end

function handleSaveDamage(rActor, _, rRoll)
	if (rRoll.sEffectRecord or "") == "" then
		return;
	end

	local nodeEffect = DB.findNode(rRoll.sEffectRecord);
	local rSourceActor = EffectManager.getSourceActor(nodeEffect) or ActorManager.resolveActor(DB.getChild(nodeEffect, "...")) or rActor;

	for _,tCompData in ipairs(EffectQueryManager.getActiveEffectCompsData(rSourceActor, nodeEffect)) do
		if tCompData.type == "SAVEDMG" then
			ActionSaveCore.performSaveDamage(rSourceActor, rActor, tCompData);
		end
	end
end
function performSaveDamage(rSource, rTarget, tCompData)
	local rRoll = ActionHealthD20.getOngoingDamageRoll(rTarget, tCompData);
	if not rRoll then
		return;
	end

	rRoll.sDesc = ActionDamageCore.encodeActionText({ label = Interface.getString("effect_special_SAVE"), });
	ActionsManager.actionDirect(rSource, rRoll.sType, { rRoll }, { { rTarget } });
end

function notifyFailedEffectSave(rActor, sEffectRecord)
	if (sEffectRecord or "") == "" then
		return;
	end
	local msgOOB = {
		type = ActionSaveCore.OOB_MSGTYPE_FAILEDSAVEEFF,
		sActorNode = ActorManager.getCreatureNodeName(rActor),
		sEffectNode = sEffectRecord,
	};
	Comm.deliverOOBMessage(msgOOB, "");
end
function handleFailedEffectSave(msgOOB)
	local nodeEffect = DB.findNode(msgOOB.sEffectNode);
	if not nodeEffect then
		return;
	end

	local rActor = ActorManager.resolveActor(msgOOB.sActorNode);
	EffectManager.handleEffectSaveFail(rActor, nodeEffect);
end
