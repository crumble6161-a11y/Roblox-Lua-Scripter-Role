-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

-- Player
local LOCAL_PLAYER = Players.LocalPlayer

-- Class
local AbilitySystem = {}
AbilitySystem.__index = AbilitySystem

-- Constructor
function AbilitySystem.new(player)
	local self = setmetatable({}, AbilitySystem)

	self.Player = player
	self.Character = player.Character or player.CharacterAdded:Wait()
	self.Humanoid = self.Character:WaitForChild("Humanoid")
	self.Root = self.Character:WaitForChild("HumanoidRootPart")

	self.Cooldowns = {Dash=false,Hook=false,Shockwave=false}

	self.Stamina = 100
	self.MaxStamina = 100
	self.Sprinting = false

	self.Combo = 0
	self.LastHit = 0

	return self
end

-- Update character
function AbilitySystem:updateCharacter(char)
	self.Character = char
	self.Humanoid = char:WaitForChild("Humanoid")
	self.Root = char:WaitForChild("HumanoidRootPart")
end

-- Visual sphere
function AbilitySystem:createSphere(pos,color,size)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.new(1,1,1)
	p.Position = pos
	p.Parent = workspace

	local t = TweenService:Create(p,TweenInfo.new(0.4),{
		Size=size,
		Transparency=1
	})
	t:Play()
	Debris:AddItem(p,0.5)
end

-- AoE damage
function AbilitySystem:damageNearby(radius,damage)
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr==self.Player then continue end
		local char=plr.Character
		if not char then continue end
		local root=char:FindFirstChild("HumanoidRootPart")
		local hum=char:FindFirstChild("Humanoid")
		if not root or not hum then continue end
		local dist=(root.Position-self.Root.Position).Magnitude
		if dist<=radius then
			hum:TakeDamage(damage)
		end
	end
end

-- Combo
function AbilitySystem:addCombo()
	local now=tick()
	if now-self.LastHit>2 then
		self.Combo=0
	end
	self.Combo+=1
	self.LastHit=now
end

-- Camera shake
function AbilitySystem:cameraShake(power,duration)
	local cam=workspace.CurrentCamera
	local start=tick()
	local conn
	conn=RunService.RenderStepped:Connect(function()
		local elapsed=tick()-start
		if elapsed>duration then
			conn:Disconnect()
			return
		end
		local offset=Vector3.new(
			math.random(-power,power)/10,
			math.random(-power,power)/10,
			0
		)
		cam.CFrame=cam.CFrame*CFrame.new(offset)
	end)
end

-- Dash
function AbilitySystem:Dash()
	if self.Cooldowns.Dash then return end
	self.Cooldowns.Dash=true

	local att=Instance.new("Attachment",self.Root)
	local force=Instance.new("VectorForce")
	force.Attachment0=att
	force.RelativeTo=Enum.ActuatorRelativeTo.World
	force.Force=self.Root.CFrame.LookVector*8000
	force.Parent=self.Root

	self:createSphere(self.Root.Position,Color3.fromRGB(0,170,255),Vector3.new(6,6,6))
	self:cameraShake(2,0.2)
	self:addCombo()

	task.delay(0.2,function()
		force:Destroy()
		att:Destroy()
	end)

	task.delay(3,function()
		self.Cooldowns.Dash=false
	end)
end

-- Hook
function AbilitySystem:Hook()
	if self.Cooldowns.Hook then return end
	self.Cooldowns.Hook=true

	local dir=self.Root.CFrame.LookVector*60

	local params=RaycastParams.new()
	params.FilterDescendantsInstances={self.Character}
	params.FilterType=Enum.RaycastFilterType.Blacklist

	local result=workspace:Raycast(self.Root.Position,dir,params)
	if not result then
		self.Cooldowns.Hook=false
		return
	end

	local model=result.Instance:FindFirstAncestorOfClass("Model")
	if not model then
		self.Cooldowns.Hook=false
		return
	end

	local hum=model:FindFirstChild("Humanoid")
	local root=model:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		self.Cooldowns.Hook=false
		return
	end

	local att=Instance.new("Attachment",root)
	local force=Instance.new("VectorForce")
	force.Attachment0=att
	force.RelativeTo=Enum.ActuatorRelativeTo.World
	force.Force=(self.Root.Position-root.Position).Unit*9000
	force.Parent=root

	self:createSphere(root.Position,Color3.fromRGB(255,0,0),Vector3.new(4,4,4))
	self:cameraShake(3,0.2)
	self:addCombo()

	hum:TakeDamage(15)

	task.delay(0.25,function()
		force:Destroy()
		att:Destroy()
	end)

	task.delay(4,function()
		self.Cooldowns.Hook=false
	end)
end

-- Shockwave
function AbilitySystem:Shockwave()
	if self.Cooldowns.Shockwave then return end
	self.Cooldowns.Shockwave=true

	local part=Instance.new("Part")
	part.Shape=Enum.PartType.Ball
	part.Anchored=true
	part.CanCollide=false
	part.Material=Enum.Material.Neon
	part.Color=Color3.fromRGB(255,85,0)
	part.Size=Vector3.new(2,2,2)
	part.Position=self.Root.Position
	part.Parent=workspace

	local tween=TweenService:Create(part,TweenInfo.new(0.5),{
		Size=Vector3.new(25,25,25),
		Transparency=1
	})
	tween:Play()

	self:damageNearby(15,25)
	self:cameraShake(4,0.3)
	self:addCombo()

	Debris:AddItem(part,0.6)

	task.delay(5,function()
		self.Cooldowns.Shockwave=false
	end)
end

-- Create system
local system=AbilitySystem.new(LOCAL_PLAYER)

-- Sprint stamina
RunService.Heartbeat:Connect(function(dt)
	if not system.Humanoid then return end

	if system.Sprinting then
		system.Stamina-=20*dt
		if system.Stamina<=0 then
			system.Stamina=0
			system.Sprinting=false
		end
	else
		system.Stamina+=10*dt
		if system.Stamina>system.MaxStamina then
			system.Stamina=system.MaxStamina
		end
	end
end)

-- Input
UserInputService.InputBegan:Connect(function(input,processed)
	if processed then return end
	if input.UserInputType~=Enum.UserInputType.Keyboard then return end

	if input.KeyCode==Enum.KeyCode.Q then
		system:Dash()
		return
	end

	if input.KeyCode==Enum.KeyCode.E then
		system:Hook()
		return
	end

	if input.KeyCode==Enum.KeyCode.R then
		system:Shockwave()
		return
	end

	if input.KeyCode==Enum.KeyCode.LeftShift then
		if system.Stamina<=0 then return end
		system.Sprinting=true
		system.Humanoid.WalkSpeed=24
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode==Enum.KeyCode.LeftShift then
		system.Sprinting=false
		system.Humanoid.WalkSpeed=16
	end
end)

-- Respawn
LOCAL_PLAYER.CharacterAdded:Connect(function(char)
	system:updateCharacter(char)
end)

-- Heartbeat reference
RunService.Heartbeat:Connect(function()
	if not system.Root then return end
	local _=system.Root.Position
end)

print("Loaded: Q Dash | E Hook | R Shockwave | Shift Sprint")
