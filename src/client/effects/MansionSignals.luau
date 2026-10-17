--!strict

-- Avisos locais entre controllers do Casarão (só no cliente): a porta que
-- bate avisa o ambiente (os lustres perto balançam).

local slammed = Instance.new("BindableEvent")

local MansionSignals = {}

-- Uma porta do Casarão bateu ao fechar, com o centro do vão em `position`.
MansionSignals.doorSlammed = slammed.Event

function MansionSignals.fireDoorSlammed(position: Vector3)
	slammed:Fire(position)
end

return table.freeze(MansionSignals)
