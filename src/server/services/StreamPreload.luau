--!strict

-- Carrega no cliente o mapa em volta de onde cada jogador vai nascer antes
-- do teletransporte. O jogo usa StreamingEnabled e alguns mapas ficam longe
-- do lobby (o Casarão do Assassino): sem isso, o personagem (física do
-- cliente) chega antes do chão, cai do andar ou para fora do mapa e é
-- eliminado.

local StreamPreload = {}

-- Espera no máximo `timeout` segundos no total (os pedidos correm juntos).
function StreamPreload.around(requests: { { player: Player, position: Vector3 } }, timeout: number)
	local pending = 0
	for _, request in ipairs(requests) do
		pending += 1
		task.spawn(function()
			local ok, failure = pcall(function()
				request.player:RequestStreamAroundAsync(request.position, timeout)
			end)
			if not ok then
				warn(`[BlocoPuff] Stream preload failed for {request.player.Name}: {failure}`)
			end
			pending -= 1
		end)
	end
	local deadline = os.clock() + timeout
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

return table.freeze(StreamPreload)
