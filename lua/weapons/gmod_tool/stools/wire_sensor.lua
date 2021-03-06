TOOL.Category		= "Wire - Beacon"
TOOL.Name			= "Beacon Sensor"
TOOL.Command		= nil
TOOL.ConfigName		= ""
TOOL.Tab			= "Wire"

if ( CLIENT ) then
	language12.Add( "Tool_wire_sensor_name", "Beacon Sensor Tool (Wire)" )
	language12.Add( "Tool_wire_sensor_desc", "Returns distance and/or bearing to a beacon" )
	language12.Add( "Tool_wire_sensor_0", "Primary: Create Sensor    Secondary: Link Sensor" )
	language12.Add( "Tool_wire_sensor_1", "Click on the beacon to link to." )
	language12.Add( "WireSensorTool_xyz_mode", "Split X,Y,Z" )
	language12.Add( "WireSensorTool_outdist", "Output distance" )
	language12.Add( "WireSensorTool_outbrng", "Output bearing" )
	language12.Add( "WireSensorTool_gpscord", "Output world position (gps cords)" )
	language12.Add( "WireSensorTool_direction_vector", "Output direction Vector" )
	language12.Add( "WireSensorTool_direction_normalized", "Normalize direction Vector" )
	language12.Add( "WireSensorTool_target_velocity", "Output target's velocity" )
	language12.Add( "WireSensorTool_velocity_normalized", "Normalize velocity" )
	language12.Add( "WireSensorTool_vector_in", "Vector Input Instead" )
	--language12.Add( "WireSensorTool_swapyz", "Swap Y and Z cords:" )
	language12.Add( "sboxlimit_wire_sensors", "You've hit sensors limit!" )
	language12.Add( "undone_wiresensor", "Undone Wire Sensor" )
end

if (SERVER) then
	CreateConVar('sbox_maxwire_sensors',30)
end

TOOL.ClientConVar[ "xyz_mode" ] = "0"
TOOL.ClientConVar[ "outdist" ] = "1"
TOOL.ClientConVar[ "outbrng" ] = "0"
TOOL.ClientConVar[ "gpscord" ] = "0"
TOOL.ClientConVar[ "SwapYZ" ] = "0"
TOOL.ClientConVar[ "direction_vector" ] = "0"
TOOL.ClientConVar[ "direction_normalized" ] = "0"
TOOL.ClientConVar[ "target_velocity" ] = "0"
TOOL.ClientConVar[ "velocity_normalized" ] = "0"
TOOL.ClientConVar[ "vector_in" ] = "0"

TOOL.Model = "models/props_lab/huladoll.mdl"

TOOL.SelectingPeer = false
TOOL.FirstPeer = nil

cleanup.Register( "wire_sensors" )

function TOOL:LeftClick(trace)
	if (!trace.HitPos) then return false end
	if (trace.Entity:IsPlayer()) then return false end
	if ( CLIENT ) then return true end
	if not util.IsValidPhysicsObject( trace.Entity, trace.PhysicsBone ) then return false end

	local ply = self:GetOwner()

	local xyz_mode = (self:GetClientNumber("xyz_mode") ~= 0)
	local outdist = (self:GetClientNumber("outdist") ~= 0)
	local outbrng = (self:GetClientNumber("outbrng") ~= 0)
	local gpscord = (self:GetClientNumber("gpscord") ~= 0)
	local swapyz = (self:GetClientNumber("SwapYZ") ~= 0)
	local direction_vector = (self:GetClientNumber("direction_vector") ~= 0)
	local direction_normalized = (self:GetClientNumber("direction_normalized") ~= 0)
	local target_velocity = (self:GetClientNumber("target_velocity") ~= 0)
	local velocity_normalized = (self:GetClientNumber("velocity_normalized") ~= 0)
	local vector_in = (self:GetClientNumber("vector_in") ~= 0)

	if (self:GetStage() == 1) then
		if ( trace.Entity:IsValid() && trace.Entity.GetBeaconPos ) then
			self.Sensor:SetBeacon(trace.Entity)
			self:SetStage(0)
			return true
		end

		return
	end

	-- Update a beacon
	if (trace.Entity:IsValid() and trace.Entity:GetClass() == "gmod_wire_sensor" and trace.Entity.pl == ply ) then
		trace.Entity.xyz_mode				= xyz_mode
		trace.Entity.outdist				= outdist
		trace.Entity.outbrng				= outbrng
		trace.Entity.gpscord				= gpscord
		trace.Entity.swapyz					= swapyz
		trace.Entity.direction_vector		= direction_vector
		trace.Entity.direction_normalized	= direction_normalized
		trace.Entity.target_velocity		= target_velocity
		trace.Entity.velocity_normalized	= velocity_normalized
		trace.Entity.vector_in				= vector_in
		trace.Entity:Setup(xyz_mode, outdist, outbrng, gpscord, swapyz, direction_vector, direction_normalized, target_velocity, velocity_normalized, vector_in)
		return true
	end

	if ( !self:GetSWEP():CheckLimit( "wire_sensors" ) ) then return false end

	local Ang = trace.HitNormal:Angle()
	Ang.pitch = Ang.pitch + 90

	local wire_sensor = MakeWireSensor( ply, trace.HitPos, Ang, self.Model, xyz_mode, outdist, outbrng, gpscord, swapyz, direction_vector, direction_normalized, target_velocity,velocity_normalized, vector_in )

	local min = wire_sensor:OBBMins()
	wire_sensor:SetPos( trace.HitPos - trace.HitNormal * min.z )

	local const = WireLib.Weld(wire_sensor, trace.Entity, trace.PhysicsBone, true)

	undo.Create("WireSensor")
		undo.AddEntity( wire_sensor )
		undo.AddEntity( const )
		undo.SetPlayer( ply )
	undo.Finish()

	ply:AddCleanup( "wire_sensors", wire_sensor )

	return true
end

function TOOL:RightClick(trace)
	if (self:GetStage() ~= 0) then return self:LeftClick(trace) end

	if (trace.Entity:IsValid()) and (trace.Entity:GetClass() == "gmod_wire_sensor") and (trace.Entity.pl == self:GetOwner()) then
		self:SetStage(1)
		self.Sensor = trace.Entity
		return true
	end
end

if SERVER then

	function MakeWireSensor(pl, Pos, Ang, model, xyz_mode, outdist, outbrng, gpscord, swapyz, direction_vector, direction_normalized, target_velocity, velocity_normalized, vector_in)
		if ( !pl:CheckLimit( "wire_sensors" ) ) then return nil end

		local wire_sensor = ents.Create( "gmod_wire_sensor" )
		wire_sensor:SetPos( Pos )
		wire_sensor:SetAngles( Ang )
		wire_sensor:SetModel( Model(model or "models/props_lab/huladoll.mdl") )
		wire_sensor:Spawn()
		wire_sensor:Activate()

		wire_sensor:Setup( xyz_mode, outdist, outbrng, gpscord, swapyz, direction_vector, direction_normalized, target_velocity, velocity_normalized, vector_in )
		wire_sensor:SetPlayer( pl )

		local ttable = {
			xyz_mode             = xyz_mode,
			outdist              = outdist,
			outbrng              = outbrng,
			gpscord              = gpscord,
			swapyz               = swapyz,
			direction_vector     = direction_vector,
			direction_normalized = direction_normalized,
			target_velocity      = target_velocity,
			velocity_normalized  = velocity_normalized,
			vector_in            = vector_in,
			pl                   = pl,
		}
		table.Merge( wire_sensor:GetTable(), ttable )

		pl:AddCount( "wire_sensors", wire_sensor )

		return wire_sensor
	end

	duplicator.RegisterEntityClass("gmod_wire_sensor", MakeWireSensor, "Pos", "Ang", "Model", "xyz_mode", "outdist", "outbrng", "gpscord", "swapyz", "direction_vector", "direction_normalized", "target_velocity", "velocity_normalized", "vector_in")

end

function TOOL:UpdateGhostWireSensor( ent, player )

	if ( !ent || !ent:IsValid() ) then return end

	local trace = player:GetEyeTrace()

	if (!trace.Hit || trace.Entity:IsPlayer() || trace.Entity:GetClass() == "gmod_wire_sensor" || trace.Entity:GetClass() == "gmod_wire_beacon" ) then
		ent:SetNoDraw( true )
		return
	end

	local Ang = trace.HitNormal:Angle()
	Ang.pitch = Ang.pitch + 90

	local min = ent:OBBMins()
	ent:SetPos( trace.HitPos - trace.HitNormal * min.z )
	ent:SetAngles( Ang )

	ent:SetNoDraw( false )

end

function TOOL:Think()

	if (!self.GhostEntity || !self.GhostEntity:IsValid() || self.GhostEntity:GetModel() != self.Model ) then
		self:MakeGhostEntity( self.Model, Vector(0,0,0), Angle(0,0,0) )
	end

	self:UpdateGhostWireSensor( self.GhostEntity, self:GetOwner() )

end

function TOOL.BuildCPanel( panel )
	panel:AddControl( "Header", { Text = "#Tool_wire_sensor_name", Description	= "#Tool_wire_sensor_desc" }  )

	panel:AddControl("CheckBox", {
		Label = "#WireSensorTool_xyz_mode",
		Command = "wire_sensor_xyz_mode"
	})

	panel:AddControl("CheckBox", {
		Label = "#WireSensorTool_outdist",
		Command = "wire_sensor_outdist"
	})

	panel:AddControl("CheckBox", {
		Label = "#WireSensorTool_outbrng",
		Command = "wire_sensor_outbrng"
	})

	panel:AddControl("CheckBox", {
		Label = "#WireSensorTool_gpscord",
		Command = "wire_sensor_gpscord"
	})

	panel:AddControl("CheckBox", {
		Label = "#WireSensorTool_direction_vector",
		Command = "wire_sensor_direction_vector"
	})

	panel:AddControl("CheckBox", {
		Label = "#WireSensorTool_direction_normalized",
		Command = "wire_sensor_direction_normalized"
	})

	panel:AddControl("CheckBox", {
		Label = "#WireSensorTool_target_velocity",
		Command = "wire_sensor_target_velocity"
	})

	panel:AddControl("CheckBox", {
		Label = "#WireSensorTool_velocity_normalized",
		Command = "wire_sensor_velocity_normalized"
	})

	panel:AddControl("CheckBox", {
		Label = "#WireSensorTool_vector_in",
		Command = "wire_sensor_vector_in"
	})
end
