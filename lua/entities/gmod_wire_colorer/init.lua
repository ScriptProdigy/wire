
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include('shared.lua')

ENT.WireDebugName = "Colorer"


function ENT:Initialize()
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self.Inputs = WireLib.CreateSpecialInputs(self, { "Fire", "R", "G", "B", "A", "RGB" }, {"NORMAL", "NORMAL", "NORMAL", "NORMAL", "NORMAL", "VECTOR"})
	self.Outputs = Wire_CreateOutputs(self, {"Out"})
	self.InColor = Color(255, 255, 255, 255)
	self:SetBeamLength(2048)
end

function ENT:OnRemove()
	Wire_Remove(self)
end

function ENT:Setup(outColor,Range)
	--Msg("setup\n")
	if(outColor)then
		local onames = {}
		table.insert(onames, "R")
		table.insert(onames, "G")
		table.insert(onames, "B")
		table.insert(onames, "A")
		Wire_AdjustOutputs(self, onames)
	end
	self:SetBeamLength(Range)
	self:ShowOutput()
end

local function CheckPP(ply, ent)
	if !IsValid(ply) or !IsValid(ent) then return false end
	if CPPI then
		-- Temporary, done this way due to certain PP implementations not always returning a value for CPPICanTool
		if ent == ply then return true end
		if ent:CPPICanTool( ply, "colour" ) == false then return false end
	end
	return true
end

function ENT:TriggerInput(iname, value)
	if iname == "Fire" then
		if value ~= 0 then
			local vStart = self:GetPos()
			local vForward = self:GetUp()

			local trace = {}
				trace.start = vStart
				trace.endpos = vStart + (vForward * self:GetBeamLength())
				trace.filter = { self }
			local trace = util.TraceLine( trace )

			if !CheckPP( self.pl, trace.Entity ) then return end
			if trace.Entity:IsPlayer() then
				trace.Entity:SetColor12( self.InColor.r, self.InColor.g, self.InColor.b, 255 )
			else
				trace.Entity:SetColor12( self.InColor.r, self.InColor.g, self.InColor.b, self.InColor.a )
			end
		end
	elseif iname == "R" then
		self.InColor.r = math.Clamp(value, 0, 255)
	elseif iname == "G" then
		self.InColor.g = math.Clamp(value, 0, 255)
	elseif iname == "B" then
		self.InColor.b = math.Clamp(value, 0, 255)
	elseif iname == "A" then
		self.InColor.a = math.Clamp(value, 0, 255)
	elseif iname == "RGB" then
		self.InColor = Color( value[1], value[2], value[3], self.InColor.a )
	end
end

function ENT:ShowOutput()
	local text = "Colorer"
	if self.Outputs["R"] then
		text = text .. "\nColor = "
		.. math.Round(self.Outputs["R"].Value*1000)/1000 .. ", "
		.. math.Round(self.Outputs["G"].Value*1000)/1000 .. ", "
		.. math.Round(self.Outputs["B"].Value*1000)/1000 .. ", "
		.. math.Round(self.Outputs["A"].Value*1000)/1000
	end
	self:SetOverlayText( text )
end

function ENT:OnRestore()
	Wire_Restored(self)
end

function ENT:Think()
	self.BaseClass.Think(self)
	if self.Outputs["R"]then
		local vStart = self:GetPos()
		local vForward = self:GetUp()

		local trace = {}
			trace.start = vStart
			trace.endpos = vStart + (vForward * self:GetBeamLength())
			trace.filter = { self }
		local trace = util.TraceLine( trace )

		if !IsValid( trace.Entity ) then return end
		local r,g,b,a = trace.Entity:GetColor12()

		Wire_TriggerOutput(self,"R", r)
		Wire_TriggerOutput(self,"G", g)
		Wire_TriggerOutput(self,"B", b)
		Wire_TriggerOutput(self,"A", a)

		self:ShowOutput()
	end
	self:NextThink(CurTime() + 0.05)
	return true
end
