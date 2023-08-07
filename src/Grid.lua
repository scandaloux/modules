--[[
Grid.lua

Simple module for storing information in a grid.
Create a new Grid object by using Grid.new(CellSize: number)

Grid:Insert(Position: Vector3, Iden: any)
Grid:Get(Position: Vector3)
Grid:GetSurrounding(Position: Vector3, Normals: {Enum.NormalId}?)
]]

local Round = math.round

local Grid = {}
Grid.__index = Grid

function Grid.new(CELL_SIZE)
	local self = setmetatable({}, Grid)
	self.CellSize = CELL_SIZE or 6
	self.Grid = {}
	
	return self
end

local function SnapVectorToGrid(Vector: Vector3, CELL_SIZE: number)
	return Vector3.new(Round(Vector.X / CELL_SIZE), Round(Vector.Y / CELL_SIZE), Round(Vector.Z / CELL_SIZE)) * CELL_SIZE
end

function Grid:Insert(Position: Vector3, Iden: any)
	local CellPosition = SnapVectorToGrid(Position, self.CellSize)
	if not self.Grid[CellPosition.X] then
		self.Grid[CellPosition.X] = {}
		if not self.Grid[CellPosition.X][CellPosition.Y] then
			self.Grid[CellPosition.X][CellPosition.Y] = {}
		end
	end
	self.Grid[CellPosition.X][CellPosition.Y][CellPosition.Z] = Iden
end

function Grid:Get(Position: Vector3)
	local CellPosition = SnapVectorToGrid(Position, self.CellSize)
	if self.Grid[CellPosition.X] then
		if self.Grid[CellPosition.X][CellPosition.Y] then
			return self.Grid[CellPosition.X][CellPosition.Y][CellPosition.Z]
		end
	end
end

local DEFAULT_NORMALS = Enum.NormalId:GetEnumItems()

function Grid:GetSurrounding(Position: Vector3, Normals: {Enum.NormalId}?)
	Normals = Normals or DEFAULT_NORMALS
	local CellPosition = SnapVectorToGrid(Position, self.CellSize)
	local Values = {}
	for _, Face: Enum.NormalId in ipairs(Normals :: {Enum.NormalId}) do
		local Direction = Vector3.FromNormalId(Face)

		local Position = CellPosition + (Direction * self.CellSize)
		local Iden = self:Get(Position)
		if Iden then
			Values[Face] = {
				Iden = Iden,
				Position = Position
			}
		end
	end

	return Values
end

return Grid
