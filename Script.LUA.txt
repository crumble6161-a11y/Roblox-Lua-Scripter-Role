--// Core Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Player Reference
local LOCAL_PLAYER = Players.LocalPlayer

--// Ability Class (OOP using metatables)
local Ability = {}
Ability.__index = Ability

-- Constructor
function Ability.new(player)
	local self = setmetatable({}, Ability)

	self.Player = player
	self.Character = player.Character or player.CharacterAdded:Wait()
	self.Humanoid = self.Character:WaitForChild("Humanoid")
	self.Root = self.Character:WaitForChild("HumanoidRootPart")

	-- Cooldowns for abilities
	self.Cooldowns = {
		Dash = false,
		Shockwave = false,
		JumpSmash = false,
		HealingAura = false
	}

	-- Settings for abilities
	self.Settings = {
		DashSpeed = 80,
		DashDamage = 20,
		ShockwaveRadius = 15,
		ShockwaveDamage = 30,
		JumpSmashRadius = 10,
		JumpSmashDamage = 35,
		HealingAmount = 20,
		HealingRadius = 12
	}

	return self
end

--// Utility: Create visual effect
function Ability:createEffect(position, size, color, duration)
	duration = duration or 0.5
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(1,1,1)
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Parent = workspace

	local tween = TweenService:Create(part, TweenInfo.new(duration), {
		Size = size,
		Transparency = 1
	})
	tween:Play()

	Debris:AddItem(part, duration + 0.1)
end

--// Utility: Damage nearby enemies using magnitude
function Ability:damageNearby(radius, damage)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= self.Player then
			local char = player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local dist = (char.HumanoidRootPart.Position - self.Root.Position).Magnitude
				if dist <= radius then
					local humanoid = char:FindFirstChild("Humanoid")
					if humanoid and humanoid.Health > 0 then
						humanoid:TakeDamage(damage)
					end
				end
			end
		end
	end
end

--// DASH ABILITY
function Ability:Dash()
	if self.Cooldowns.Dash then return end
	self.Cooldowns.Dash = true

	-- Apply forward velocity
	local velocity = Instance.new("BodyVelocity")
	velocity.MaxForce = Vector3.new(100000, 0, 100000)
	velocity.Velocity = self.Root.CFrame.LookVector * self.Settings.DashSpeed
	velocity.Parent = self.Root

	-- Raycast to detect enemies
	local ray = workspace:Raycast(self.Root.Position, self.Root.CFrame.LookVector * 10)
	if ray and ray.Instance then
		local humanoid = ray.Instance.Parent:FindFirstChild("Humanoid")
		if humanoid then
			humanoid:TakeDamage(self.Settings.DashDamage)
		end
	end

	-- Visual effect
	self:createEffect(self.Root.Position, Vector3.new(6,6,6), Color3.fromRGB(0, 170, 255))

	-- Remove velocity after short delay
	task.delay(0.2, function()
		velocity:Destroy()
	end)

	-- Cooldown reset
	task.delay(3, function()
		self.Cooldowns.Dash = false
	end)
end

--// SHOCKWAVE ABILITY
function Ability:Shockwave()
	if self.Cooldowns.Shockwave then return end
	self.Cooldowns.Shockwave = true

	local shockwave = Instance.new("Part")
	shockwave.Shape = Enum.PartType.Ball
	shockwave.Anchored = true
	shockwave.CanCollide = false
	shockwave.Size = Vector3.new(2,2,2)
	shockwave.Position = self.Root.Position
	shockwave.Material = Enum.Material.Neon
	shockwave.Color = Color3.fromRGB(255, 85, 0)
	shockwave.Parent = workspace

	-- Expand shockwave
	local tween = TweenService:Create(shockwave, TweenInfo.new(0.6), {
		Size = Vector3.new(25,25,25),
		Transparency = 1
	})
	tween:Play()

	-- Damage nearby enemies
	self:damageNearby(self.Settings.ShockwaveRadius, self.Settings.ShockwaveDamage)

	Debris:AddItem(shockwave, 0.7)

	-- Cooldown reset
	task.delay(5, function()
		self.Cooldowns.Shockwave = false
	end)
end

--// JUMP SMASH ABILITY
function Ability:JumpSmash()
	if self.Cooldowns.JumpSmash then return end
	self.Cooldowns.JumpSmash = true

	-- Launch player upward
	self.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	self.Root.Velocity = Vector3.new(0, 70, 0)

	-- Wait and slam down
	task.delay(0.6, function()
		local impactPos = self.Root.Position
		self:createEffect(impactPos, Vector3.new(10,10,10), Color3.fromRGB(255, 0, 0))
		self:damageNearby(self.Settings.JumpSmashRadius, self.Settings.JumpSmashDamage)
	end)

	-- Cooldown reset
	task.delay(6, function()
		self.Cooldowns.JumpSmash = false
	end)
end

--// HEALING AURA ABILITY
function Ability:HealingAura()
	if self.Cooldowns.HealingAura then return end
	self.Cooldowns.HealingAura = true

	local aura = Instance.new("Part")
	aura.Shape = Enum.PartType.Ball
	aura.Anchored = true
	aura.CanCollide = false
	aura.Size = Vector3.new(2,2,2)
	aura.Position = self.Root.Position
	aura.Material = Enum.Material.Neon
	aura.Color = Color3.fromRGB(0, 255, 85)
	aura.Transparency = 0.5
	aura.Parent = workspace

	-- Expand aura
	local tween = TweenService:Create(aura, TweenInfo.new(1), {
		Size = Vector3.new(self.Settings.HealingRadius*2, 5, self.Settings.HealingRadius*2),
		Transparency = 1
	})
	tween:Play()

	-- Heal nearby allies
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local dist = (char.HumanoidRootPart.Position - self.Root.Position).Magnitude
			if dist <= self.Settings.HealingRadius then
				local humanoid = char:FindFirstChild("Humanoid")
				if humanoid then
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + self.Settings.HealingAmount)
				end
			end
		end
	end

	Debris:AddItem(aura, 1.1)

	-- Cooldown reset
	task.delay(8, function()
		self.Cooldowns.HealingAura = false
	end)
end

--// Initialize ability manager
local ability = Ability.new(LOCAL_PLAYER)

--// Handle player input
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.KeyCode == Enum.KeyCode.Q then
		ability:Dash()
	elseif input.KeyCode == Enum.KeyCode.E then
		ability:Shockwave()
	elseif input.KeyCode == Enum.KeyCode.R then
		ability:JumpSmash()
	elseif input.KeyCode == Enum.KeyCode.F then
		ability:HealingAura()
	end
end)

--// Character Respawn Handling
LOCAL_PLAYER.CharacterAdded:Connect(function(char)
	ability.Character = char
	ability.Humanoid = char:WaitForChild("Humanoid")
	ability.Root = char:WaitForChild("HumanoidRootPart")
end)

--// Debug Info
print([[ 
Advanced Combat Ability System Loaded
Q = Dash (Forward Attack)
E = Shockwave (AoE Damage)
R = Jump Smash (Slam AoE)
F = Healing Aura (Ally Heal)
Includes:
- OOP (Metatables)
- Raycasting & Physics
- Tween Effects
- Cooldowns & Settings
- Damage & Healing System
]])