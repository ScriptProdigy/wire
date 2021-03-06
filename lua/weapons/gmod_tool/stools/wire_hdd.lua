TOOL.Category		= "Wire - Advanced"
TOOL.Name			= "Memory - Flash EEPROM"
TOOL.Command		= nil
TOOL.ConfigName		= ""
TOOL.Tab			= "Wire"

if ( CLIENT ) then
	language12.Add( "Tool_wire_hdd_name", "Flash (EEPROM) tool (Wire)" )
	language12.Add( "Tool_wire_hdd_desc", "Spawns flash memory. It is used for permanent storage of data (carried over sessions)" )
	language12.Add( "Tool_wire_hdd_0", "Primary: Create/Update flash memory" )
	language12.Add( "sboxlimit_wire_hdds", "You've hit flash memory limit!" )
	language12.Add( "undone_wiredigitalscreen", "Undone Flash (EEPROM)" )
end

if (SERVER) then
	CreateConVar('sbox_maxwire_hdds', 20)
end

TOOL.ClientConVar[ "model" ] = "models/jaanus/wiretool/wiretool_gate.mdl"
TOOL.ClientConVar[ "driveid" ] = 0
TOOL.ClientConVar[ "client_driveid" ] = 0
TOOL.ClientConVar[ "drivecap" ] = 128

TOOL.ClientConVar[ "packet_bandwidth" ] = 100
TOOL.ClientConVar[ "packet_rate" ] = 0.4

cleanup.Register( "wire_hdds" )

function TOOL:GetModel()
	local model = self:GetClientInfo( "model" )
	if (!util.IsValidModel( model ) or !util.IsValidProp( model )) then return "models/jaanus/wiretool/wiretool_gate.mdl" end
	return model
end

function TOOL:LeftClick( trace )
	if trace.Entity:IsPlayer() then return false end
	if (CLIENT) then return true end
	if not util.IsValidPhysicsObject( trace.Entity, trace.PhysicsBone ) then return false end

	local ply = self:GetOwner()

	if ( trace.Entity:IsValid() && trace.Entity:GetClass() == "gmod_wire_hdd" && trace.Entity.pl == ply ) then
		trace.Entity.DriveID = tonumber(self:GetClientInfo( "driveid" ))
		trace.Entity.DriveCap = tonumber(self:GetClientInfo( "drivecap" ))
		trace.Entity:UpdateCap()
		return true
	end

	if ( !self:GetSWEP():CheckLimit( "wire_hdds" ) ) then return false end

	if (not util.IsValidModel(self:GetClientInfo( "model" ))) then return false end
	if (not util.IsValidProp(self:GetClientInfo( "model" ))) then return false end

	local ply = self:GetOwner()
	local Ang = trace.HitNormal:Angle()
	local model = self:GetModel()
	Ang.pitch = Ang.pitch + 90

	local wire_hdd = MakeWirehdd( ply, trace.HitPos, Ang, model, self:GetClientInfo( "driveid" ), self:GetClientInfo( "drivecap" ) )
	local min = wire_hdd:OBBMins()
	wire_hdd:SetPos( trace.HitPos - trace.HitNormal * min.z )

	wire_hdd.DriveID = tonumber(self:GetClientInfo( "driveid" ))
	wire_hdd.DriveCap = tonumber(self:GetClientInfo( "drivecap" ))

	local const = WireLib.Weld(wire_hdd, trace.Entity, trace.PhysicsBone, true)

	undo.Create("Wirehdd")
		undo.AddEntity( wire_hdd )
		undo.SetPlayer( ply )
	undo.Finish()

	ply:AddCleanup( "wire_hdds", wire_hdd )

	return true
end

if (SERVER) then

	function MakeWirehdd( pl, Pos, Ang, model, DriveID, DriveCap)

		if ( !pl:CheckLimit( "wire_hdds" ) ) then return false end

		local wire_hdd = ents.Create( "gmod_wire_hdd" )
		if (!wire_hdd:IsValid()) then return false end
		wire_hdd:SetModel(model)

		wire_hdd:SetAngles( Ang )
		wire_hdd:SetPos( Pos )
		wire_hdd:Spawn()

		wire_hdd:SetPlayer(pl)

		local ttable = {
			pl = pl,
			model = model,
			DriveID = DriveID,
			DriveCap = DriveCap,
		}

		table.Merge(wire_hdd:GetTable(), ttable )

		pl:AddCount( "wire_hdds", wire_hdd )

		return wire_hdd

	end

	duplicator.RegisterEntityClass("gmod_wire_hdd", MakeWirehdd, "Pos", "Ang", "Model", "DriveID", "DriveCap")

end

function TOOL:UpdateGhostWirehdd( ent, player )

	if ( !ent ) then return end
	if ( !ent:IsValid() ) then return end

	local trace = player:GetEyeTrace()
	if (!trace.Hit) then return end

	if (trace.Entity && trace.Entity:GetClass() == "gmod_wire_hdd" || trace.Entity:IsPlayer()) then
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
	if (!self.GhostEntity || !self.GhostEntity:IsValid() || self.GhostEntity:GetModel() != self:GetModel() || (not self.GhostEntity:GetModel()) ) then
		self:MakeGhostEntity( self:GetModel(), Vector(0,0,0), Angle(0,0,0) )
	end

	self:UpdateGhostWirehdd( self.GhostEntity, self:GetOwner() )
end

local function GetStructName(steamID,HDD,name)
	return "WireFlash\\"..(steamID or "UNKNOWN").."\\HDD"..HDD.."\\"..name..".txt"
end

local function ParseFormatData(formatData)
	local driveCap = 0
	local blockSize = 16
	if tonumber(formatData) then
		driveCap = tonumber(formatData)
	else
		local formatInfo = string.Explode("\n",formatData)
		if formatInfo[1] == "FLASH1" then
			driveCap = tonumber(formatInfo[2]) or 0
			blockSize = 32
		end
	end
	return driveCap,blockSize
end

local function GetFloatTable(Text)
	local text = Text
	local tbl = {}
	local ptr = 0
	while (string.len(text) > 0) do
		local value = string.sub(text,1,24)
		text = string.sub(text,24,string.len(text))
		tbl[ptr] = tonumber(value)
		ptr = ptr + 1
	end
	return tbl
end

local function MakeFloatTable(Table)
	local text = ""
	for i=0,#Table-1 do
		--Clamp size to 24 chars
		local floatstr = string.sub(tostring(Table[i]),1,24)
		--Make a string, and append missing spaces
		floatstr = floatstr .. string.rep(" ",24-string.len(floatstr))

		text = text..floatstr
	end

	return text
end
--[[
if SERVER then
	-- Concommand to send a single stream of bytes
	local buffer = {}
	local bufferBlock = nil
	concommand.Add("wire_hdd_uploaddata", function(player, command, args)
		local HDDID = tonumber(args[1])
		if (not HDDID) or (HDDID < 0) or (HDDID > 3) then return end
		HDDID = math.floor(HDDID)
		local STEAMID = player:SteamID()
		STEAMID = string.gsub(STEAMID, ":", "_")
		if (STEAMID == "UNKNOWN") or (STEAMID == "STEAM_0_0_0") then
			STEAMID = "SINGLEPLAYER"
		end

		local address = tonumber(args[2]) or 0
		local value = tonumber(args[3]) or 0

		local block = math.floor(address / 32)
		if block == bufferBlock then
			buffer[address % 32] = value
		else
			if bufferBlock then
				file.Write(GetStructName(STEAMID,HDDID,bufferBlock),MakeFloatTable(buffer))
				file.Write(GetStructName(STEAMID,HDDID,"drive"),
				  "FLASH1\n"..GetConVarNumber("wire_hdd_drivecap").."\n"..(address+31))
			end

			bufferBlock = block
			buffer = {}
			buffer[address % 32] = value
		end
	end)

	concommand.Add("wire_hdd_uploadend", function(player, command, args)
		local HDDID = tonumber(args[1])
		if (not HDDID) or (HDDID < 0) or (HDDID > 3) then return end
		HDDID = math.floor(HDDID)
		local STEAMID = player:SteamID()
		STEAMID = string.gsub(STEAMID, ":", "_")
		if (STEAMID == "UNKNOWN") or (STEAMID == "STEAM_0_0_0") then
			STEAMID = "SINGLEPLAYER"
		end

		if bufferBlock then
			file.Write(GetStructName(STEAMID,HDDID,block),MakeFloatTable(buffer))
			file.Write(GetStructName(STEAMID,HDDID,"drive"),
			  "FLASH1\n"..GetConVarNumber("wire_hdd_drivecap").."\n"..(address))
		end

		bufferBlock = nil
		buffer = {}
	end)

	-- Download from server to client
	local downloadPointer = {}
	concommand.Add("wire_hdd_download", function(player, command, args)
		local HDDID = tonumber(args[1])
		if (not HDDID) or (HDDID < 0) or (HDDID > 3) then return end
		HDDID = math.floor(HDDID)
		local STEAMID = player:SteamID()
		STEAMID = string.gsub(STEAMID, ":", "_")
		if (STEAMID == "UNKNOWN") or (STEAMID == "STEAM_0_0_0") then
			STEAMID = "SINGLEPLAYER"
		end

		local formatData = file.Read(GetStructName(STEAMID,HDDID,"drive")) or ""
		local driveCap,blockSize = ParseFormatData(formatData)

		-- Download code
		downloadPointer[player:UserID()] = 0
		timer.Destroy("flash_download"..player:UserID())
		timer.Create("flash_download"..player:UserID(),1/60,0,function()
			local umsgrp = RecipientFilter()
			umsgrp:AddPlayer(player)

			if file.Exists(GetStructName(STEAMID,HDDID,downloadPointer[player:UserID()])) then
				local dataTable = GetFloatTable(file.Read(GetStructName(STEAMID,HDDID,downloadPointer[player:UserID()])))
				umsg.Start("flash_downloaddata", umsgrp)
				umsg.Long(downloadPointer[player:UserID()]*blockSize)
				umsg.Long(blockSize)
				for i=1,blockSize do
					umsg.Float(dataTable[i-1])
				end
				umsg.End()
			end

			downloadPointer[player:UserID()] = downloadPointer[player:UserID()] + 1
			if downloadPointer[player:UserID()] >= driveCap*1024/blockSize then
				timer.Destroy("flash_download"..player:UserID())
			end
		end)
	end)

	-- Clear hard drive
	concommand.Add("wire_hdd_clearhdd", function(player, command, args)
		local HDDID = tonumber(args[1])
		if (not HDDID) or (HDDID < 0) or (HDDID > 3) then return end
		local STEAMID = player:SteamID()
		STEAMID = string.gsub(STEAMID or "UNKNOWN", ":", "_")
		if (STEAMID == "UNKNOWN") or (STEAMID == "STEAM_0_0_0") then
			STEAMID = "SINGLEPLAYER"
		end

		local formatData = file.Read(GetStructName(STEAMID,HDDID,"drive")) or ""
		local driveCap,blockSize = ParseFormatData(formatData)

		-- FIXME: have to limit this to 2 kb until I add a timer
		driveCap = math.min(driveCap,2)
		file.Delete(GetStructName(STEAMID,HDDID,"drive"))
		for block = 0,math.floor(driveCap*1024/blockSize) do
			if file.Exists(GetStructName(STEAMID,HDDID,block)) then
				file.Delete(GetStructName(STEAMID,HDDID,block))
			end
		end
	end)
else
	function CPULib.OnDownloadData(um)
		local HDDID = GetConVarNumber("wire_hdd_client_driveid")

		local offset,size = um:ReadLong(),um:ReadLong()
		local dataTable = {}
		for address=1,size do
			dataTable[address] = um:ReadFloat()
		end
		file.Write(GetStructName("SINGLEPLAYER",HDDID,math.floor(offset/size)),MakeFloatTable(dataTable))
		file.Write(GetStructName("SINGLEPLAYER",HDDID,"drive"),
		  "FLASH1\n"..GetConVarNumber("wire_hdd_drivecap").."\n"..(offset+size-1))
	end
	usermessage.Hook("flash_downloaddata", CPULib.OnDownloadData)

	concommand.Add("wire_hdd_clearhdd_client", function(player, command, args)
		local HDDID = GetConVarNumber("wire_hdd_client_driveid")
		local formatData = file.Read(GetStructName("SINGLEPLAYER",HDDID,"drive")) or ""
		local driveCap,blockSize = ParseFormatData(formatData)

		-- FIXME: have to limit this to 2 kb until I add a timer
		driveCap = math.min(driveCap,2)
		file.Delete(GetStructName("SINGLEPLAYER",HDDID,"drive"))
		for block = 0,math.floor(driveCap*1024/blockSize) do
			if file.Exists(GetStructName("SINGLEPLAYER",HDDID,block)) then
				file.Delete(GetStructName("SINGLEPLAYER",HDDID,block))
			end
		end
	end)

	-- Upload from client to server
	local uploadPointer = 0
	concommand.Add("wire_hdd_upload", function(player, command, args)
		local HDDID = GetConVarNumber("wire_hdd_client_driveid")
		local TGTHDDID = GetConVarNumber("wire_hdd_driveid")
		local formatData = file.Read(GetStructName("SINGLEPLAYER",HDDID,"drive")) or ""
		local driveCap,blockSize = ParseFormatData(formatData)

		-- Upload code
		uploadPointer = 0
		timer.Destroy("flash_upload")
		timer.Create("flash_upload",1/10,0,function()
			if file.Exists(GetStructName("SINGLEPLAYER",HDDID,uploadPointer)) then
				local dataTable = GetFloatTable(file.Read(GetStructName("SINGLEPLAYER",HDDID,uploadPointer)))
				for i=0,blockSize-1 do
					RunConsoleCommand("wire_hdd_uploaddata",TGTHDDID,i+uploadPointer*blockSize,dataTable[i])
				end
			end

			uploadPointer = uploadPointer + 1
			if uploadPointer >= driveCap*1024/blockSize then
				RunConsoleCommand("wire_hdd_uploadend",TGTHDDID)
			end
		end)
	end)
end
]]--
function TOOL.BuildCPanel(panel)
	panel:AddControl("Header", { Text = "#Tool_wire_hdd_name", Description = "#Tool_wire_hdd_desc" })

	local mdl = vgui.Create("DWireModelSelect")
	mdl:SetModelList( list.Get("Wire_gate_Models"), "wire_hdd_model" )
	mdl:SetHeight( 5 )
	panel:AddItem( mdl )

	panel:AddControl("Slider", {
		Label = "Drive ID",
		Type = "Integer",
		Min = "0",
		Max = "3",
		Command = "wire_hdd_driveid"
	})

	panel:AddControl("Slider", {
		Label = "Capacity (KB)",
		Type = "Integer",
		Min = "0",
		Max = "128",
		Command = "wire_hdd_drivecap"
	})

	panel:AddControl("Label", { Text = "" })
	panel:AddControl("Label", { Text = "Flash memory manager" })

	panel:AddControl("Slider", {
		Label = "Server drive ID",
		Type = "Integer",
		Min = "0",
		Max = "3",
		Command = "wire_hdd_driveid"
	})

	panel:AddControl("Slider", {
		Label = "Client drive ID",
		Type = "Integer",
		Min = "0",
		Max = "3",
		Command = "wire_hdd_client_driveid"
	})

	local Button = vgui.Create("DButton", panel)
	panel:AddPanel(Button)
	Button:SetText("Download server drive to client drive")
	Button.DoClick = function()
			RunConsoleCommand("wire_hdd_download",GetConVarNumber("wire_hdd_driveid"))
	end

	panel:AddControl("Button", {
		Text = "Upload client drive to server drive",
		Command = "wire_hdd_upload"
	})

	local Button = vgui.Create("DButton", panel)
	panel:AddPanel(Button)
	Button:SetText("Clear server drive")
	Button.DoClick = function()
		RunConsoleCommand("wire_hdd_clearhdd",GetConVarNumber("wire_hdd_driveid"))
	end

	panel:AddControl("Button", {
		Text = "Clear client drive",
		Command = "wire_hdd_clearhdd_client"
	})

end

