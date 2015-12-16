print("Loaded!")

if CLIENT then

	local percent = 100

	local PlayerEffects = {}

	function StatusDraw()

		local BaseX = ScrW()*0.1
		local BaseY = ScrH()*0.9
		
		--[[
		if percent < 0 then
			percent = 100
		else
			percent = percent - FrameTime()*25
		end
		--]]
		
		local EffectCount = 0
		
		for k,v in pairs(PlayerEffects) do
			EffectCount = EffectCount + 1

			local TimePercent = (v["effect_duration_current"]/v["effect_duration_max"])*100
			local Logo = v["effect_icon"]

			StatusDrawStatusBox(BaseX + 72*EffectCount,BaseY, TimePercent,v,Logo)
		end
		
	end

	hook.Add("HUDPaint","Status Effects Draw",StatusDraw)
	
	function StatusDrawStatusBox(xpos,ypos,percent,data,icon)

		local size = 64
		
		local BaseX =  xpos - size/2
		local BaseY = ypos - size/2
		
		local Paint = Color(0,255,0,255)
		local PaintBack = Color(0,100,0,255)
		
		--PrintTable(data)
		
		
		if data["effect_negative"] == true then
			Paint = Color(255,0,0,255)
			PaintBack = Color(100,0,0,255)
		end
		
		
		
		-- Empty
		draw.RoundedBox( 0, BaseX, BaseY, size, size, PaintBack )

		-- Base
		--draw.RoundedBox( 0, BaseX + size*0.1, BaseY + size*0.1, size*0.8, size*0.8, Color(255,255,255,255) )
		
		surface.SetDrawColor(Color(255,255,255,255))
		surface.SetMaterial(Material(icon))
		surface.DrawTexturedRect( BaseX + size*0.1, BaseY + size*0.1, size*0.8, size*0.8 )
		
	
		local Mul = 0

		if percent >= (700/8) then
			-- Top Right
			Mul = StatusGenerateSegmentMath(percent,700/8,800/8)
			draw.RoundedBox( 0, BaseX + size - size*0.5*Mul, BaseY, size*0.5*Mul, size*0.1, Paint )
		end	
			
		if percent >= 500/8 then
			-- Right
			Mul = StatusGenerateSegmentMath(percent,500/8,700/8)
			draw.RoundedBox( 0, BaseX + size*0.9, BaseY - size*Mul + size, size*0.1, size*Mul, Paint )
		end
		
		if percent >= 300/8 then
			-- Bottom
			Mul = StatusGenerateSegmentMath(percent,300/8,500/8)
			draw.RoundedBox( 0, BaseX, BaseY + size*0.9, size*Mul, size*0.1, Paint )
		end
		
		if percent >= 00/8 then
			-- Left
			Mul = StatusGenerateSegmentMath(percent,100/8,300/8)
			draw.RoundedBox( 0, BaseX, BaseY, size*0.1, size*Mul, Paint )
		end
		
		if percent >= 000/8 then
			-- Top Left
			Mul = StatusGenerateSegmentMath(percent,000/8,100/8)
			draw.RoundedBox( 0, BaseX - size*0.5*Mul + size*0.5, BaseY, size*0.5*Mul, size*0.1, Paint )
		end

	end

	function StatusGenerateSegmentMath(percent,min,max)
		return math.Clamp((percent - min) / (max - min),0,1)
	end

	function StatusClientThink()
		for k,v in pairs(PlayerEffects) do
		

			if v["effect_duration_current"] <= 0 then
				PlayerEffects[k] = nil
			else
				PlayerEffects[k]["effect_duration_current"] = v["effect_duration_current"] - FrameTime()
			end
			
		end
	end
	
	hook.Add("Think","Status Client Think",StatusClientThink)
	
	net.Receive("StatusEffectToPlayer",function(len)
		local Table = net.ReadTable()
		local Name = Table["effect_name"]
		PlayerEffects[Name] = Table
	end)

end

if SERVER then

	function StatusSuicideEffect(ply)
		
		local Effect = {}
		Effect["effect_name"] = "Suicide"
		Effect["effect_attribute"] = "health"
		Effect["effect_negative"] = true
		Effect["effect_recover"] = false
		Effect["effect_limit"] = true
		Effect["effect_magnitude"] = 10
		Effect["effect_duration_current"] = 10
		Effect["effect_duration_max"] = 10
		Effect["effect_icon"] = "vgui/face/angry_eyebrows"
		Effect["effect_owner"] = ply
		
		StatusAddEffect(ply,Effect)
		
		
		return false
	end

	hook.Add("CanPlayerSuicide","Status Suicide Effect",StatusSuicideEffect)


	function StatusFakeEffect(ply,cmd,args,argStr)
		
		local Effect = {}
		Effect["effect_name"] = "FakeEffect"
		Effect["effect_attribute"] = "health"
		Effect["effect_negative"] = true
		Effect["effect_recover"] = false
		Effect["effect_limit"] = false
		Effect["effect_magnitude"] = 1
		Effect["effect_duration_current"] = 5
		Effect["effect_duration_max"] = 5
		Effect["effect_icon"] = "vgui/logos/spray"
		Effect["effect_owner"] = ply
		
		StatusAddEffect(ply,Effect)
		
	end

	concommand.Add( "addeffect", StatusFakeEffect)

	function StatusAddEffect(ply,data)

		if not ply.ActiveEffects then 
			ply.ActiveEffects = {}
		end
		
		local Name = data["effect_name"]
		
		--if ply.ActiveEffects[Name] then
		--	print("ALREADY HAVE THIS EFFECT")
		--else
		
			ply.ActiveEffects[Name] = data
		
			net.Start("StatusEffectToPlayer")
				net.WriteTable(data)
			net.Send(ply)
		--end

	end


	util.AddNetworkString( "StatusEffectToPlayer" )
	
	local ThinkTime = 1
	local NextThink = 0

	function StatusServerThink()
		
		if NextThink <= math.ceil(CurTime()) then
			for k,v in pairs(player.GetAll()) do
			
				if not v.ActiveEffects then
					v.ActiveEffects = {}
				end
			
			
				for l,b in pairs(v.ActiveEffects) do
					if b["effect_duration_current"] <= 0 then
						v.ActiveEffects[l] = nil
					else
						
						v.ActiveEffects[l]["effect_duration_current"] = v.ActiveEffects[l]["effect_duration_current"] - ThinkTime
						print(v.ActiveEffects[l]["effect_duration_current"])
						StatusHandleEffect(v,b,ThinkTime)
						
					end
				end
			end
			
			NextThink = math.ceil(CurTime() + ThinkTime)
			
		end

	end
	
	hook.Add("Think","Status Server Think",StatusServerThink)
	
	
	function StatusHandleEffect(ply,data,tick)

		local Attribute = data["effect_attribute"]
		local Magnitude = data["effect_magnitude"]
		local Source = data["effect_owner"]
		local IsNegative = data["effect_negative"]

		if Attribute == "health" then
			if IsNegative then
				ply:TakeDamage(Magnitude*tick,Source,Source)
			else
				ply:SetHealth(math.Clamp(ply:Health() + Magnitude*tick,1,ply:GetMaxHealth()))
			end
		end

	end
	
	
	
	
	
end