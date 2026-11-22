--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onInit()
	StartupManager.registerPublicNodes();
end
function onTabletopInit()
	DB.addEventHandler("onDataLoaded", StartupManager.onDataLoaded);
end
function onDataLoaded()
	WindowSaveManager.loadWindowState();
	UserManager.loadIdentityState();
	StartupManager.handleMOTD();
	CampaignSetupManager.handleSetup();
	CampaignSetupManager.handleAutoLoad();
end

--
--	DATABASE ACCESS
--

function registerPublicNodes()
	if Session.IsHost then
		DB.setPublic(DB.createNode("charsheet"), true);
		DB.setPublic(DB.createNode("motd"), true);
		DB.setPublic(DB.createNode("options"), true);
		DB.setPublic(DB.createNode("partysheet"), true);
		DB.setPublic(DB.createNode("calendar"), true);
		DB.setPublic(DB.createNode("combattracker"), true);
		DB.setPublic(DB.createNode("modifiers"), true);
		DB.setPublic(DB.createNode("effects"), true);
		DB.setPublic(DB.createNode("picture"), true);
	end
end

--
--	MOTD (MESSAGE OF THE DAY)
--

function handleMOTD()
	if Session.IsHost then
		return;
	end
	local sMOTD = StringManager.trim(DB.getText("motd.text", ""));
	if sMOTD ~= "" then
		Interface.openWindow("motd", "motd");
	end
end
