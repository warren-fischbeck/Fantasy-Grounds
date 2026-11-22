--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onInit()
	if Session.IsHost then
		registerMenuItem(Interface.getString("ct_menu_effectadd"), "pointer", 2);
	end
end

function onFilter(w)
	return Session.IsHost or DB.isOwner(w.getDatabaseNode()) or ((w.isgmonly.getValue() == 0) and (w.isactive.getValue() == 1));
end

function onMenuSelection(selection)
	if Session.IsHost then
		if selection == 2 then
			createWindow(nil, true);
		end
	end
end
function onEnter()
	if Session.IsHost then
		createWindow(nil, true);
		return true;
	end
end
function onDrop(_, _, draginfo)
	if Session.IsHost then
		CombatDropManager.handleGlobalEffectsDrop(draginfo);
	end
end
