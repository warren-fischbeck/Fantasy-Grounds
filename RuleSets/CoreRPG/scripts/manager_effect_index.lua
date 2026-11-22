--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onTabletopInit()
	EffectIndexManager.initIndex();
end

--
--	INITIALIZATION AND MONITORING
--

function initIndex()
	EffectIndexManager.rebuildCombatEffectData();

	-- Combatant effect handling
	CombatManager.setCustomDeleteCombatantHandler(EffectIndexManager.onCombatantDeleted);
	CombatManager.setCustomPreDeleteCombatantEffectHandler(EffectIndexManager.onCombatantEffectDeleted);
	CombatManager.addAllCombatantEffectFieldChangeHandler("label", "onAdd", EffectIndexManager.onCombatantEffectFieldChanged);
	CombatManager.addAllCombatantEffectFieldChangeHandler("label", "onUpdate", EffectIndexManager.onCombatantEffectFieldChanged);
	CombatManager.addAllCombatantEffectFieldChangeHandler("isactive", "onAdd", EffectIndexManager.onCombatantEffectFieldChanged);
	CombatManager.addAllCombatantEffectFieldChangeHandler("isactive", "onUpdate", EffectIndexManager.onCombatantEffectFieldChanged);
	CombatManager.addAllCombatantEffectFieldChangeHandler("apply", "onAdd", EffectIndexManager.onCombatantEffectFieldChanged);
	CombatManager.addAllCombatantEffectFieldChangeHandler("apply", "onUpdate", EffectIndexManager.onCombatantEffectFieldChanged);

	-- Global effect handling
	CombatManager.addAllEffectFieldChangeHandler("label", "onAdd", EffectIndexManager.onEffectFieldChanged);
	CombatManager.addAllEffectFieldChangeHandler("label", "onUpdate", EffectIndexManager.onEffectFieldChanged);
	CombatManager.addAllEffectFieldChangeHandler("isactive", "onAdd", EffectIndexManager.onEffectFieldChanged);
	CombatManager.addAllEffectFieldChangeHandler("isactive", "onUpdate", EffectIndexManager.onEffectFieldChanged);
	CombatManager.addAllEffectFieldChangeHandler("apply", "onAdd", EffectIndexManager.onEffectFieldChanged);
	CombatManager.addAllEffectFieldChangeHandler("apply", "onUpdate", EffectIndexManager.onEffectFieldChanged);
end

function rebuildCombatEffectData()
	for _,nodeCT in pairs(CombatManager.getAllCombatantNodes()) do
		for _, nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
			EffectIndexManager.rebuildEffectData(nodeEffect);
		end
	end
end
function onCombatantDeleted(nodeCT)
	if not nodeCT then
		return;
	end
	for _,nodeEffect in ipairs(DB.getChildList(nodeCT, "effects")) do
		EffectIndexManager.clearEffectData(nodeEffect);
	end
end
function onCombatantEffectDeleted(nodeEffect)
	EffectIndexManager.clearEffectData(nodeEffect);
end
function onCombatantEffectFieldChanged(nodeField)
	if not nodeField then
		return;
	end
	EffectIndexManager.clearEffectData(DB.getParent(nodeField));
end
function onEffectFieldChanged(nodeField)
	if not nodeField then
		return;
	end
	EffectIndexManager.clearEffectData(DB.getParent(nodeField));
end

--
--	EFFECT DATA INDEX
--

function buildEffectData(nodeEffect)
	if not nodeEffect then
		return nil;
	end
	return {
		node = nodeEffect,
		nActive = DB.getValue(nodeEffect, "isactive", 0),
		sLabel = EffectVarManager.getEffectVarFromNode(nodeEffect, "sName", ""),
	};
end

local _tEffectData = {};
function clearAllEffectData()
	_tEffectData = {};
end
function getEffectData(nodeEffect)
	if not nodeEffect then
		return nil;
	end
	if not _tEffectData[nodeEffect] then
		EffectIndexManager.rebuildEffectData(nodeEffect);
	end
	return _tEffectData[nodeEffect];
end
function rebuildEffectData(nodeEffect)
	local tEffectData = EffectIndexManager.buildEffectData(nodeEffect);
	if tEffectData then
		if _tEffectData[nodeEffect] and (_tEffectData[nodeEffect].sLabel == tEffectData.sLabel) then
			tEffectData.tComps = _tEffectData[nodeEffect].tComps;
		end
		_tEffectData[nodeEffect] = tEffectData;
	end
end
function clearEffectData(nodeEffect)
	if not nodeEffect then
		return;
	end
	_tEffectData[nodeEffect] = nil;
end

function getEffectCompsData(nodeEffect)
	return EffectManager.parseEffectComps(EffectIndexManager.getEffectData(nodeEffect));
end
