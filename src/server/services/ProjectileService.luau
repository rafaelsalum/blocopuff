--!strict

-- Simula os disparos do Puffador no servidor, só a parte que decide: o raio
-- da mira anda a cada quadro e o que ele acerta vale (blocos para o
-- ArenaService, personagens e superfícies para os handlers registrados).
-- O servidor não desenha nada: avisa os clientes pelo remote "PuffShots"
-- ("Fired" quando sai, "Ended" quando para, "Clear" ao limpar tudo) e cada
-- cliente desenha o disparo a 60 quadros por segundo (PuffShotController),
-- com o rastro e as partículas do Puff equipado. Não conhece regras de
-- rodada, participantes ou o RemoteEvent de disparo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.config.GameConfig)
local PuffCatalog = require(ReplicatedStorage.Shared.config.PuffCatalog)
local PuffadorConstants = require(ReplicatedStorage.Shared.modules.PuffadorConstants)
local ArenaService = require(script.Parent.ArenaService)
local CombatantRegistry = require(script.Parent.CombatantRegistry)

type BlockDestructionContext = ArenaService.BlockDestructionContext
type Combatant = CombatantRegistry.Combatant

-- Chamado quando um projétil acerta o personagem de outro combatente
-- (jogador ou bot). Quem decide o efeito (empurrão, regra do cofre) são os
-- serviços registrados.
export type CharacterHitHandler = (shooter: Combatant, victim: Combatant, position: Vector3, direction: Vector3, power: number) -> ()
-- Chamado quando o projétil acerta algo que não é bloco nem personagem
-- (ex.: um quadro na parede). `distance` vai do cano, no instante do
-- disparo (validado pelo servidor perto do personagem), até o impacto: não
-- depende de onde o personagem está agora nem da câmera.
export type SurfaceHitHandler = (shooter: Combatant, instance: Instance, position: Vector3, distance: number) -> ()

local GENERATED_BY_ATTRIBUTE = "GeneratedBy"
local SERVICE_NAME = "ProjectileService"

type ProjectileRecord = {
	owner: Combatant,
	roundId: number,
	projectileId: number,
	direction: Vector3,
	-- Posição autoritativa, que percorre o raio da mira (câmera → alvo).
	logicPosition: Vector3,
	-- Cano no instante do disparo (distância do tiro para os handlers).
	muzzle: Vector3,
	raycastParams: RaycastParams,
	spawnClock: number,
	distanceTraveled: number,
	onBlockHit: (() -> ())?,
	-- Blocos quebrados por acerto: 1 no Puffador comum, 2 no Super.
	power: number,
	-- Disparo da área de treino do lobby (4.5): não quebra bloco nem
	-- acerta personagem; só avisa os handlers de superfície (alvos).
	training: boolean,
}

local ProjectileService = {}

local projectileContainer: Folder? = nil
local shotsRemote: RemoteEvent? = nil
local activeProjectiles: { ProjectileRecord } = {}
local nextProjectileSequence = 0
local heartbeatConnection: RBXScriptConnection? = nil
local characterHitHandlers: { [string]: CharacterHitHandler } = {}
local surfaceHitHandlers: { [string]: SurfaceHitHandler } = {}

local function isOwned(instance: Instance): boolean
	return instance:GetAttribute(GENERATED_BY_ATTRIBUTE) == SERVICE_NAME
end

local function broadcast(...: any)
	local remote = shotsRemote
	if remote ~= nil then
		remote:FireAllClients(...)
	end
end

-- Tira o disparo da simulação e avisa os clientes onde ele parou
-- (`distance` studs da origem da mira) e, se acertou algo, o ponto e a
-- normal do impacto (é lá que o cliente mostra a explosão).
local function removeProjectileAt(index: number, distance: number?, impactPosition: Vector3?, impactNormal: Vector3?)
	local record = activeProjectiles[index]
	if record == nil then
		return
	end

	table.remove(activeProjectiles, index)
	broadcast("Ended", record.projectileId, distance or record.distanceTraveled, impactPosition, impactNormal)
end

-- Avisa os handlers do que foi atingido: personagem de outro combatente
-- ou, se não for personagem, a superfície.
local function notifyHit(record: ProjectileRecord, hitInstance: Instance, position: Vector3, distance: number)
	local model = hitInstance:FindFirstAncestorOfClass("Model")
	while model ~= nil do
		local victim = CombatantRegistry.fromCharacter(model)
		if victim ~= nil then
			if victim ~= record.owner then
				for _, handler in pairs(characterHitHandlers) do
					task.spawn(handler, record.owner, victim, position, record.direction, record.power)
				end
			end
			return
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	for _, handler in pairs(surfaceHitHandlers) do
		task.spawn(handler, record.owner, hitInstance, position, distance)
	end
end

local function updateProjectiles(deltaTime: number)
	if #activeProjectiles == 0 then
		return
	end

	local config = GameConfig.Puffador

	for index = #activeProjectiles, 1, -1 do
		local record = activeProjectiles[index]

		-- Onde o disparo acertou (para a explosão no cliente).
		local impactPosition: Vector3? = nil
		local impactNormal: Vector3? = nil
		local impactDistance: number? = nil

		local ok, keepAlive = pcall(function(): boolean
			local displacement = record.direction * config.ProjectileSpeed * deltaTime
			local previousPosition = record.logicPosition

			local raycastResult = Workspace:Raycast(previousPosition, displacement, record.raycastParams)
			if raycastResult ~= nil then
				impactPosition = raycastResult.Position
				impactNormal = raycastResult.Normal
				local context: BlockDestructionContext = {
					position = raycastResult.Position,
					normal = raycastResult.Normal,
					owner = record.owner,
					roundId = record.roundId,
					projectileId = record.projectileId,
				}
				local hitInstance = raycastResult.Instance
				impactDistance = record.distanceTraveled + (raycastResult.Position - previousPosition).Magnitude
				local hitDistance = (raycastResult.Position - record.muzzle).Magnitude
				if record.training then
					for _, handler in pairs(surfaceHitHandlers) do
						task.spawn(handler, record.owner, hitInstance, raycastResult.Position, hitDistance)
					end
					return false
				end
				local destroyedBlock = ArenaService.tryDestroyBlock(hitInstance, context)
				if destroyedBlock then
					if record.onBlockHit ~= nil then
						record.onBlockHit()
					end
					for _ = 2, record.power do
						local neighbor = ArenaService.getNeighborBlock(hitInstance, raycastResult.Position)
						if neighbor == nil or not ArenaService.tryDestroyBlock(neighbor, context) then
							break
						end
						if record.onBlockHit ~= nil then
							record.onBlockHit()
						end
					end
				else
					notifyHit(record, hitInstance, raycastResult.Position, hitDistance)
				end
				return false
			end

			local newDistance = record.distanceTraveled + displacement.Magnitude
			if newDistance >= config.MaximumRange then
				return false
			end

			if os.clock() - record.spawnClock >= config.ProjectileLifetime then
				return false
			end

			record.distanceTraveled = newDistance
			record.logicPosition = previousPosition + displacement
			return true
		end)

		if not ok then
			warn(`[BlocoPuff] Projectile {record.projectileId} failed: {keepAlive}`)
			removeProjectileAt(index)
		elseif keepAlive ~= true then
			removeProjectileAt(index, impactDistance, impactPosition, impactNormal)
		end
	end
end

function ProjectileService.start(worldRoot: Model, remotesFolder: Folder)
	if projectileContainer ~= nil then
		return
	end

	local existing = worldRoot:FindFirstChild(PuffadorConstants.ProjectilesContainerName)
	if existing ~= nil then
		if not isOwned(existing) then
			error(`Cannot replace {existing:GetFullName()} because it is not owned by {SERVICE_NAME}`)
		end
		existing:Destroy()
	end

	local container = Instance.new("Folder")
	container.Name = PuffadorConstants.ProjectilesContainerName
	container:SetAttribute(GENERATED_BY_ATTRIBUTE, SERVICE_NAME)
	container.Parent = worldRoot

	local remote = Instance.new("RemoteEvent")
	remote.Name = PuffadorConstants.PuffShotsRemoteName
	remote.Parent = remotesFolder

	projectileContainer = container
	shotsRemote = remote
	nextProjectileSequence = 0
	table.clear(activeProjectiles)

	heartbeatConnection = RunService.Heartbeat:Connect(updateProjectiles)
end

-- `origin` é o cano (onde o disparo aparece); `aimOrigin` é a origem
-- validada do raio da mira, por onde o acerto é decidido. `puffId` (Puff
-- equipado) e `color` só mudam o desenho no cliente: tamanho, velocidade,
-- alcance e acerto são iguais para todos.
function ProjectileService.spawn(
	owner: Combatant,
	origin: Vector3,
	aimOrigin: Vector3,
	direction: Vector3,
	roundId: number,
	onBlockHit: (() -> ())?,
	power: number?,
	color: Color3?,
	puffId: string?,
	training: boolean?
)
	local container = projectileContainer
	if container == nil then
		return
	end

	nextProjectileSequence += 1
	local projectileId = nextProjectileSequence

	local filterInstances: { Instance } = { container }
	local character = CombatantRegistry.getCharacter(owner)
	if character ~= nil then
		table.insert(filterInstances, character)
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = filterInstances
	raycastParams.IgnoreWater = true

	local record: ProjectileRecord = {
		owner = owner,
		roundId = roundId,
		projectileId = projectileId,
		direction = direction,
		logicPosition = aimOrigin,
		muzzle = origin,
		raycastParams = raycastParams,
		spawnClock = os.clock(),
		distanceTraveled = 0,
		onBlockHit = onBlockHit,
		power = math.clamp(math.floor(power or 1), 1, 4),
		training = training == true,
	}

	table.insert(activeProjectiles, record)
	local definition = PuffCatalog.get(puffId)
	broadcast(
		"Fired",
		projectileId,
		owner.id,
		origin,
		aimOrigin,
		direction,
		if definition ~= nil then definition.id else PuffCatalog.DefaultId,
		color or PuffadorConstants.ProjectileColor
	)
end

-- Registra (ou remove, com nil) um handler de acerto em personagem por chave.
-- Os handlers de superfície recebem acertos de TODOS os disparos (partida e
-- treino): cada um deve conferir se a peça é dele (atributo/tag) antes de agir.
function ProjectileService.setCharacterHitHandler(key: string, handler: CharacterHitHandler?)
	characterHitHandlers[key] = handler
end

function ProjectileService.setSurfaceHitHandler(key: string, handler: SurfaceHitHandler?)
	surfaceHitHandlers[key] = handler
end

function ProjectileService.clearAll()
	if #activeProjectiles == 0 then
		return
	end
	table.clear(activeProjectiles)
	broadcast("Clear")
end

function ProjectileService.clearFor(owner: Combatant)
	for index = #activeProjectiles, 1, -1 do
		local record = activeProjectiles[index]
		if record.owner == owner then
			removeProjectileAt(index)
		end
	end
end

function ProjectileService.stop()
	table.clear(characterHitHandlers)
	table.clear(surfaceHitHandlers)
	if heartbeatConnection ~= nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	ProjectileService.clearAll()

	if shotsRemote ~= nil then
		shotsRemote:Destroy()
		shotsRemote = nil
	end
	if projectileContainer ~= nil and projectileContainer.Parent ~= nil and isOwned(projectileContainer) then
		projectileContainer:Destroy()
	end
	projectileContainer = nil
end

return table.freeze(ProjectileService)
