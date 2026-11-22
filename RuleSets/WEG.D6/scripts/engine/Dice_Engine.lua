DiceEngine = {};

local _fHandleResolution;
local _tPending = {};
local _nRollId = 0;

function onInit()

	_fHandleResolution = ActionsManager.handleResolution;

	ActionsManager.handleResolution =
		DiceEngine.handleResolution;

	Comm.addKeyedEventHandler(
		"onDiceLanded",
		"diceengineexplode",
		DiceEngine.onExplosionLanded
	);
end

function DiceEngine.onClose()

	if _fHandleResolution then
		ActionsManager.handleResolution = _fHandleResolution;
	end

	Comm.removeKeyedEventHandler(
		"onDiceLanded",
		"diceengineexplode",
		onExplosionLanded
	);

	_tPending = {};
end

function DiceEngine.nextId()

	_nRollId = _nRollId + 1;

	return "DE" .. tostring(_nRollId);
end

function DiceEngine.handleResolution(
	rRoll,
	rSource,
	aTargets
)

	--
	-- Explosion rolls resume here
	--

	if rRoll.sType == "diceengineexplode" then

		_fHandleResolution(
			rRoll,
			rSource,
			aTargets
		);

		return;
	end

	--
	-- Original roll
	--

	if not DiceEngine.shouldExplode(rRoll) then

		_fHandleResolution(
			rRoll,
			rSource,
			aTargets
		);

		return;
	end

	local sRollId = DiceEngine.nextId();

	_tPending[sRollId] =
	{
		rRoll = UtilityManager.copyDeep(rRoll),
		rSource = rSource,
		aTargets = UtilityManager.copyDeep(aTargets)
	};

	DiceEngine.launchExplosion(
		sRollId
	);
end

function DiceEngine.shouldExplode(rRoll)

	if not rRoll then
		return false;
	end

	if not rRoll.aDice or #rRoll.aDice == 0 then
		return false;
	end

	local vDie = rRoll.aDice[1];

	if not vDie then
		return false;
	end



	local nResult = vDie.result or 0;

	if nResult == 1 then
		local msg = ChatManager.createBaseMessage(nil, nil);
		msg.text = "The first die is a 1. There is a chance for mishap!";
		msg.secret = true;

		Comm.deliverChatMessage(msg);
	end

	return (nResult == 6);
end

function DiceEngine.launchExplosion(
	sRollId
)

	Comm.throwDice(
		"diceengineexplode",
		{ "d6" },
		0,
		"[EXPLOSION]",
		{
			rollid = sRollId
		}
	);
end

function DiceEngine.onExplosionLanded(
	draginfo
)

	local tData =
		draginfo.getCustomData();

	if not tData then
		return;
	end

	local sRollId =
		tData.rollid;

	if not sRollId then
		return;
	end

	local tPending =
		_tPending[sRollId];

	if not tPending then
		return;
	end

	local aDice =
		draginfo.getDiceData();

	if not aDice
	or not aDice[1] then
		return;
	end

	local nResult =
		aDice[1].result or 0;

	table.insert(
		tPending.rRoll.aDice,
		{
			type = "d6",
			result = nResult,
			value = nResult
		}
	);

	if nResult == 6 then

		DiceEngine.launchExplosion(
			sRollId
		);

		return;
	end

	tPending.rRoll.nTotal =
		ActionsManager.total(
			tPending.rRoll
		);

	_fHandleResolution(
		tPending.rRoll,
		tPending.rSource,
		tPending.aTargets
	);

	_tPending[sRollId] = nil;
end