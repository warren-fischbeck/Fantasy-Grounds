--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

local rInternalEffect = nil;

function setEffect(rEffect)
	button.setText(rEffect.sDisplayName or rEffect.sName);
	rInternalEffect = rEffect;
end
function getEffect()
	return rInternalEffect;
end

function onDragStart(_, _, _, draginfo)
	return ActionEffect.performRoll(draginfo, nil, rInternalEffect);
end
function onButtonPress(_, _)
	local rRoll = ActionEffect.getRoll(nil, rInternalEffect);
	if not rRoll then
		return true;
	end

	rRoll.sType = "effect";

	local rTarget = ActorManager.getActiveActor();
	ActionsManager.resolveAction(nil, rTarget, rRoll);
	return true;
end
