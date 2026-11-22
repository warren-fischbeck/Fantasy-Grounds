--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onInit()
	setColor(ColorManager.getButtonTextColor());
	if Session.IsHost then
		registerMenuItem(Interface.getString("ct_menu_initmenu"), "turn", 7);
		registerMenuItem(Interface.getString("ct_menu_initall"), "shuffle", 7, 8);
		registerMenuItem(Interface.getString("ct_menu_initnpc"), "mask", 7, 7);
		registerMenuItem(Interface.getString("ct_menu_initpc"), "portrait", 7, 6);
		registerMenuItem(Interface.getString("ct_menu_initclear"), "pointer_circle", 7, 4);

		registerMenuItem(Interface.getString("ct_menu_itemdelete"), "delete", 3);
		registerMenuItem(Interface.getString("ct_menu_itemdeletenonfriendly"), "delete", 3, 1);
		registerMenuItem(Interface.getString("ct_menu_itemdeletefoe"), "delete", 3, 3);

		registerMenuItem(Interface.getString("ct_menu_effectdelete"), "radial_effect", 5);
		registerMenuItem(Interface.getString("ct_menu_effectdeleteall"), "pointer_circle", 5, 7);
		registerMenuItem(Interface.getString("ct_menu_effectdeleteexpiring"), "pointer_cone", 5, 5);

		ActionCore.buildRestMenu(self, 8);
	end
end

function onClickDown()
	return true;
end
function onClickRelease(button)
	if button == 1 then
		Interface.openContextMenu();
		return true;
	end
end

function onMenuSelection(selection, subselection)
	if Session.IsHost then
		if selection == 7 then
			if subselection == 4 then
				CombatManager.resetInit();
			elseif subselection == 8 then
				CombatManager.rollInit();
			elseif subselection == 7 then
				CombatManager.rollInit("npc");
			elseif subselection == 6 then
				CombatManager.rollInit("pc");
			end
		elseif selection == 3 then
			if subselection == 1 then
				CombatManager.deleteNonFaction("friend");
			elseif subselection == 3 then
				CombatManager.deleteFaction("foe");
			end
		end
		if selection == 5 then
			if subselection == 7 then
				CombatManager.resetCombatantEffects();
			elseif subselection == 5 then
				EffectManagerD20.clearExpiringEffects();
			end
		end
		if selection == 8 then
			ActionCore.handleRestCombat(subselection);
		end
	end
end
