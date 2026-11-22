--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function setData(rActor)
	local sName = ActorManager.getDisplayName(rActor);

	local sAsset;
	local nodeCT = ActorManager.getCTNode(rActor);
	if nodeCT then
		sAsset = DB.getValue(nodeCT, "picture", "");
		if sAsset == "" then
			sAsset = DB.getValue(nodeCT, "token3Dflat", "");
			if sAsset == "" then
				sAsset = UtilityManager.resolveDisplayToken(DB.getValue(nodeCT, "token", ""), sName);
			end
		end
	else
		sAsset = UtilityManager.resolveDisplayToken("", sName);
	end

	title.setValue(sName);
	asset.setAsset(sAsset);
end
