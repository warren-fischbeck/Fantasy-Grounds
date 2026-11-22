-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

OOB_MSGTYPE_EFFECT_NOTIFY = "effect_notify";
_tEffectAddToastBatch = nil;

function onInit()
	GameManager.addEventFunction("onEffectAdd", OverlayEffectManager.notifyEffectAdd);
	GameManager.addEventFunction("onEffectExpire", OverlayEffectManager.notifyEffectExpire);

	OOBManager.registerOOBMsgHandler(OverlayEffectManager.OOB_MSGTYPE_EFFECT_NOTIFY, OverlayEffectManager.handleEffectNotify);
end

function notifyEffectAdd(rActor, nodeEffect, tData)
	tData = tData or {};
	tData.sAction = "add";
	OverlayEffectManager.notifyEffectAction(rActor, nodeEffect, tData);
end
function notifyEffectExpire(rActor, nodeEffect, tData)
	tData = tData or {};
	tData.sAction = "expire";
	OverlayEffectManager.notifyEffectAction(rActor, nodeEffect, tData);
end
function notifyEffectAction(rActor, nodeEffect, tData)
	if not rActor or not nodeEffect then
		return;
	end
	if tData and tData.bSkipAnnounce then
		return;
	end

	local msgOOB = {
		type = OverlayEffectManager.OOB_MSGTYPE_EFFECT_NOTIFY,
		sAction = tData and tData.sAction,
		nTokenNotify = (tData and tData.bTokenNotify and 1) or 0,
		nAccent = (tData and tData.bAccent and 1) or 0,
		sAccentColor = tData and tData.sAccentColor,
		sFadeDirection = tData and tData.sFadeDirection,
		sActorNode = ActorManager.getCreatureNodeName(rActor),
		sPath = DB.getPath(nodeEffect),
	};
	Comm.deliverOOBMessage(msgOOB);
end
function handleEffectNotify(msgOOB)
	if not msgOOB or ((msgOOB.sPath or "") == "") then
		return;
	end
	local nodeEffect = DB.findNode(msgOOB.sPath);
	if not nodeEffect then
		return;
	end
	local rActor = ActorManager.resolveActor(msgOOB.sActorNode);

	if not Session.IsHost then
		local bSecret = (DB.getValue(nodeEffect, "isgmonly", 0) == 1);
		if bSecret then
			return;
		end
		if not ActorManager.isVisible(rActor) then
			return;
		end
	end

	if msgOOB.sAction == "add" then
		OverlayEffectManager.handleEffectAddNotify(rActor, nodeEffect);
	else
		local tData = {
			bTokenNotify = ((tonumber(msgOOB.nTokenNotify) or 0) == 1),
			bAccent = ((tonumber(msgOOB.nAccent) or 0) == 1),
			sAccentColor = msgOOB.sAccentColor,
			sFadeDirection = msgOOB.sFadeDirection,
		};
		OverlayEffectManager.handleEffectActionNotify(msgOOB.sAction, rActor, nodeEffect, tData);
	end
end

function handleEffectAddNotify(rActor, nodeEffect)
	if not rActor or not nodeEffect then
		return;
	end
	-- Get display info for effect
	local tEffectDisplayData = TokenManager.getEffectDisplayInfoDefault(rActor, nodeEffect);
	if not tEffectDisplayData then
		return;
	end

	local rOrigin = ActorManager.resolveActor(DB.getValue(tEffectDisplayData.node, "source_name", ""));
	if not OverlayActionManager.batchNotify(rOrigin, rActor, "effect", tEffectDisplayData) then
		OverlayEffectManager.performEffectAddNotify(rOrigin, rActor, tEffectDisplayData);
	end
end
function performEffectAddNotifyBatch(rSource, tActions)
	for _, tAction in ipairs(tActions or {}) do
		OverlayEffectManager.handleEffectAddNotifyToken(rTarget, tEffectDisplayData);	
	end
	OverlayEffectManager.handleEffectAddNotifyBatchToast(rSource, tActions);
end
function performEffectAddNotify(rSource, rTarget, tEffectDisplayData)
	OverlayEffectManager.handleEffectAddNotifyToken(rTarget, tEffectDisplayData);	
	OverlayEffectManager.handleEffectAddNotifyToast(rTarget, tEffectDisplayData);	
end
function handleEffectAddNotifyToken(rActor, tEffectDisplayData)
	if not rActor or not tEffectDisplayData then
		return;
	end

	OverlayManager.showTokenIconEffectAdd(rActor, tEffectDisplayData);
end
function handleEffectAddNotifyBatchToast(_, tActions)
	if #tActions == 0 then
		return;
	end
	local sEffect = tActions[1].tData.sName;
	local tTargets = {};
	for _,tAction in ipairs(tActions) do
		table.insert(tTargets, tAction.rTarget);
	end
	OverlayEffectManager.helperEffectNotifyToast("add", sEffect, tTargets);
end
function handleEffectAddNotifyToast(rActor, tEffectDisplayData)
	if not rActor or not tEffectDisplayData then
		return;
	end
	OverlayEffectManager.helperEffectNotifyToast("add", tEffectDisplayData.sName, { rActor });
end

function handleEffectActionNotify(sAction, rActor, nodeEffect, tData)
	if not rActor or not nodeEffect then
		return;
	end
	local tEffectDisplayData = TokenManager.getEffectDisplayInfoDefault(rActor, nodeEffect);
	if not tEffectDisplayData then
		return;
	end

	OverlayEffectManager.handleEffectActionNotifyToken(sAction, rActor, tEffectDisplayData, tData);
	OverlayEffectManager.handleEffectActionNotifyToast(sAction, rActor, tEffectDisplayData);	
end
function handleEffectActionNotifyToken(sAction, rActor, tEffectDisplayData, tData)
	if not rActor or not tEffectDisplayData or not tData then
		return;
	end
	if not tData.bTokenNotify then
		return;
	end

	tEffectDisplayData.bAccent = tData.bAccent;
	tEffectDisplayData.sAccentColor = tData.sAccentColor;
	tEffectDisplayData.sFadeDirection = tData.sFadeDirection;
	tEffectDisplayData.sText = tEffectDisplayData.sText or tEffectDisplayData.sName;
	OverlayManager.showTokenIconQuick(rActor, tEffectDisplayData);
end
function handleEffectActionNotifyToast(sAction, rActor, tEffectDisplayData)
	if not rActor or not tEffectDisplayData then
		return;
	end
	OverlayEffectManager.helperEffectNotifyToast(sAction, tEffectDisplayData.sName, { rActor });
end
function helperEffectNotifyToast(sAction, sEffect, tTargets)
	local tToastText = {};

	local sEffectText = string.format("<font name=\"toast-italic\">%s</font>", sEffect or "");
	table.insert(tToastText, sEffectText);

	local tTargetNames = {};
	for _, rTarget in ipairs(tTargets or {}) do
		table.insert(tTargetNames, ActorManager.getDisplayName(rTarget));
	end
	if #tTargetNames > 0 then
		local sResultText = string.format("<font name=\"toast-bold\">%s:</font> %s", Interface.getString("combat_result_effect_" .. (sAction or "")), table.concat(tTargetNames, ", "));
		table.insert(tToastText, sResultText);
	end

	local tOverlayData = {
		sOption = "TOAST_COMBAT",
		sToastType = "info",
		sTitle = Interface.getString("effect_toast_title_" .. (sAction or "")),
		sText = table.concat(tToastText, "\r"),
	};
	OverlayManager.showToastMessage(tOverlayData);
end
