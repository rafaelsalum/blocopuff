--!strict

-- Grade de uma fachada (sem serviços, para rodar no Lune). Cada célula guarda
-- a profundidade arredondada da parede naquele ponto, ou 0 quando ali não
-- tem parede (janela, porta, vão). Serve para revestir as paredes de fora do
-- Casarão de pedra sem tampar nenhuma abertura, e para achar trechos de
-- parede cheia onde cabem contrafortes e janelas de enfeite.

export type Grid = {
	cols: number,
	rows: number,
	-- keys[row][col]: 0 = sem parede; outro valor = profundidade.
	keys: { { number } },
}

export type Rect = { col0: number, col1: number, row0: number, row1: number, key: number }

local FacadeGrid = {}

function FacadeGrid.new(cols: number, rows: number, sample: (col: number, row: number) -> number): Grid
	local keys: { { number } } = {}
	for row = 1, rows do
		local line: { number } = {}
		for col = 1, cols do
			line[col] = sample(col, row)
		end
		keys[row] = line
	end
	return { cols = cols, rows = rows, keys = keys }
end

-- Junta as células cheias em retângulos de mesma profundidade (guloso:
-- faixas de cada linha, esticadas para baixo enquanto a faixa se repete).
function FacadeGrid.rects(grid: Grid): { Rect }
	local used: { { boolean } } = {}
	for row = 1, grid.rows do
		used[row] = {}
	end
	local rects: { Rect } = {}
	for row = 1, grid.rows do
		local col = 1
		while col <= grid.cols do
			local key = grid.keys[row][col]
			if key == 0 or used[row][col] then
				col += 1
				continue
			end
			local last = col
			while last + 1 <= grid.cols and grid.keys[row][last + 1] == key and not used[row][last + 1] do
				last += 1
			end
			local bottom = row
			while bottom + 1 <= grid.rows do
				local nextRow = bottom + 1
				local same = true
				for check = col, last do
					if grid.keys[nextRow][check] ~= key or used[nextRow][check] then
						same = false
						break
					end
				end
				if not same then
					break
				end
				bottom = nextRow
			end
			for fill = row, bottom do
				for check = col, last do
					used[fill][check] = true
				end
			end
			table.insert(rects, { col0 = col, col1 = last, row0 = row, row1 = bottom, key = key })
			col = last + 1
		end
	end
	return rects
end

-- O bloco de colunas col0..col1 e linhas row0..row1 é parede cheia, toda na
-- mesma profundidade?
function FacadeGrid.solid(grid: Grid, col0: number, col1: number, row0: number, row1: number): boolean
	if col0 < 1 or row0 < 1 or col1 > grid.cols or row1 > grid.rows then
		return false
	end
	local key = grid.keys[row0][col0]
	if key == 0 then
		return false
	end
	for row = row0, row1 do
		for col = col0, col1 do
			if grid.keys[row][col] ~= key then
				return false
			end
		end
	end
	return true
end

-- Colunas (a primeira de cada bloco) onde cabe um enfeite de `width`
-- colunas nas linhas row0..row1, a cada `spacing` colunas, começando em
-- `offset`, e só onde o bloco todo é parede cheia.
function FacadeGrid.spots(grid: Grid, width: number, row0: number, row1: number, spacing: number, offset: number): { number }
	local found: { number } = {}
	local col = offset
	while col + width - 1 <= grid.cols do
		if FacadeGrid.solid(grid, col, col + width - 1, row0, row1) then
			table.insert(found, col)
		end
		col += spacing
	end
	return found
end

return table.freeze(FacadeGrid)
