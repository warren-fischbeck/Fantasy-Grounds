--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onTabletopInit()
	ActionsManager.registerResultHandler("effect", ActionEffect.onEffect);
	Interface.addKeyedEventHandler("onHotkeyDrop", "", ActionEffect.onHotkeyDrop);
end

function onHotkeyDrop(draginfo)
	local rEffect = EffectManager.decodeEffectFromDrag(draginfo);
	if rEffect then
		draginfo.setSlot(1);
		draginfo.setStringData(EffectManager.encodeEffectAsText(rEffect));
	end
end

function performRoll(draginfo, rActor, rAction)
	local rRoll = ActionEffect.getRoll(rActor, rAction);
	if not rRoll then
		return false;
	end

	ActionsManager.performAction(draginfo, rActor, rRoll);
	return true;
end
function getRoll(rActor, rAction, tTargets)
	local rRoll = EffectManager.encodeEffect(rAction);
	if rRoll.sDesc == "" then
		return nil;
	end

	local sTargeting = rAction.sTargeting or "";
	if sTargeting == "self" then
		rRoll.bSelfTarget = true;
	elseif sTargeting == "toself" then
		rRoll.sTargets = ActorManager.getCTNodeName(rActor);
	elseif sTargeting == "totargets" then
		rRoll.bSelfTarget = true;
		tTargets = tTargets or TargetingManager.getFullTargets(rActor);
		local tTargetPaths = {};
		for _,v in ipairs(tTargets) do
			local sCTNode = ActorManager.getCTNodeName(v);
			if sCTNode ~= "" then
				table.insert(tTargetPaths, sCTNode);
			end
		end
		rRoll.sTargets = table.concat(tTargetPaths, "|");
	end

	rRoll.tActionTags = rAction.tActionTags;

	return rRoll;
end

function onEffect(rSource, rTarget, rRoll)
	-- Decode effect from roll
	local rEffect = EffectManager.decodeEffect(rRoll);
	if not rEffect then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectdecodefail"));
		return;
	end

	-- Determine origin actor and add to effect data
	local rOrigin = EffectManager.getSourceActor(rEffect);
	if not rOrigin then
		rOrigin = rSource;
		if not rOrigin then
			if Session.IsHost then
				rOrigin = ActorManager.resolveActor(CombatManager.getActiveCT());
			else
				local sIdentity = User.getCurrentIdentity();
				if sIdentity then
					rOrigin = ActorManager.resolveActor(CombatManager.getCTFromNode("charsheet." .. sIdentity));
				end
			end
		end
		rEffect.sSource = ActorManager.getCTNodeName(rOrigin);
	end

	-- Determine origin user
	if (rEffect.sUser or "") == "" then
		rEffect.sUser = ActorManager.getOwner(rOrigin);
	end

	-- If no target, then report to chat window and exit
	if not rTarget then
		EffectManager.onUntargetedDrop(rEffect);
		rRoll.sDesc = EffectManager.encodeEffectAsText(rEffect);

		-- Report effect to chat window
		local rMessage = ActionsManager.createActionMessage(nil, rRoll, { sIcon = "action_effect", });
		Comm.deliverChatMessage(rMessage);
		return;
	end

	-- If target not in combat tracker, then we're done
	if not ActorManager.hasCT(rTarget) then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectdroptargetnotinct"));
		return;
	end

	-- If source is non-friendly faction and target does not exist or is non-friendly, then effect should be GM only
	if (rSource and not ActorManager.isFaction(rSource, "friend")) and (not rTarget or not ActorManager.isFaction(rTarget, "friend")) then
		rEffect.nGMOnly = 1;
	end

	-- Pass along any effect-specific targeting information
	rEffect.sTargets = rRoll.sTargets;

	-- Resolve
	EffectManager.addEffectByTable(rTarget, rEffect);
end
