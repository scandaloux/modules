local TweenService = game:GetService("TweenService")
local owner = owner
local NLS = NLS

--[[
Tool.lua

Pretty messily put together, may be redone a lot.
]]

return function(Config)
	local Object = {}
	Object.Tracks = Tracks

	local CameraPitch = Instance.new("Part")
	CameraPitch.Transparency = 1
	CameraPitch.CanCollide = false
	CameraPitch.CanQuery = false
	CameraPitch.CanTouch = false
	CameraPitch.Size = Vector3.zero
	CameraPitch.Parent = owner.Character

	local Attachment = Instance.new("Attachment", CameraPitch)
	local Linear = Instance.new("LinearVelocity")
	Linear.VectorVelocity = Vector3.zero
	Linear.MaxForce = math.huge
	Linear.Attachment0 = Attachment
	Linear.Parent = Attachment

	CameraPitch:SetNetworkOwner(owner)

	NLS([[while true do
		task.wait()
		local Character = owner.Character
		if Character then
			local Root = Character:FindFirstChild("HumanoidRootPart")
			if Root then
				local X = workspace.CurrentCamera.CFrame:ToEulerAnglesYXZ()
				script.Parent.CFrame = Root.CFrame * CFrame.Angles(X, 0,0)
			end
		end
	end]], CameraPitch)

	local Model = Config.Model
	local Tool = Instance.new("Tool", owner.Backpack)
	Tool.Name = Config.Name or "Tool"
	Tool.RequiresHandle = false
	Tool.Equipped:Connect(function()
		if Model then
			Model.Parent = Tool.Parent
			local Motor = Instance.new("Motor6D", Model)
			Motor.C0 = Config.MotorGrip or CFrame.identity
			Motor.Part0 = Tool.Parent:WaitForChild("Right Arm")
			Motor.Part1 = Model
			Object.Motor = Motor
		end
	end)
	Tool.Unequipped:Connect(function()
		if Model then
			Object.Motor:Destroy()
			Model.Parent = nil
		end

		local Character = owner.Character
		local Neck = Character:FindFirstChild("Neck", true)
		local LS = Character:FindFirstChild("Left Shoulder", true)
		local RS = Character:FindFirstChild("Right Shoulder", true)
		local RJ = Character:FindFirstChild("RootJoint", true)

		local FadeIn = TweenInfo.new(0.3, Enum.EasingStyle.Cubic)

		if RJ then
			TweenService:Create(RJ, FadeIn, {C0 = CFrame.new(0, 0, 0, -1, -0, -0, 0, 0, 1, 0, 1, 0)}):Play()
		end
		if Neck then
			TweenService:Create(Neck, FadeIn, {C0 = CFrame.new(0, 1, 0, -1, -0, -0, 0, 0, 1, 0, 1, 0)}):Play()
		end
		if LS then
			TweenService:Create(LS, FadeIn, {C0 = CFrame.new(-1, 0.5, 0, -0, -0, -1, 0, 1, 0, 1, 0, 0)}):Play()
		end
		if RS then
			TweenService:Create(RS, FadeIn, {C0 = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, -0, -0)}):Play()
		end
	end)

	game:GetService("RunService").PreAnimation:Connect(function(DeltaTime)
		if Tool.Parent == owner.Character then
			local Character = owner.Character
			local Neck = Character:FindFirstChild("Neck", true)
			local LS = Character:FindFirstChild("Left Shoulder", true)
			local RS = Character:FindFirstChild("Right Shoulder", true)
			local Humanoid = Character:FindFirstChild("Humanoid")
			local RJ = Character:FindFirstChild("RootJoint", true)

			local Alpha = 1 - (0.00001 ^ DeltaTime)

			local MovementOffset = CFrame.identity

			if Humanoid then
				if RJ then
					local MoveDirection = RJ.Parent.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
					MovementOffset = CFrame.new(0, -1, -3) * CFrame.Angles(math.rad(-MoveDirection.Z * (Humanoid.WalkSpeed * 0.2)), math.rad(-MoveDirection.X * (Humanoid.WalkSpeed * 0.2)), math.rad(MoveDirection.X * (Humanoid.WalkSpeed * 0.6))) * CFrame.new(0, 1, 3)
					RJ.C0 = RJ.C0:Lerp(CFrame.new(0, 0, 0, -1, -0, -0, 0, 0, 1, 0, 1, 0) * MovementOffset, Alpha * 0.5)
				end
			end

			local X = CameraPitch.CFrame:ToEulerAnglesYXZ()

			local OX, OY, OZ = MovementOffset:Inverse():ToEulerAnglesYXZ()

			if Neck then
				Neck.C0 = Neck.C0:Lerp(CFrame.new(0, 1, 0, -1, -0, -0, 0, 0, 1, 0, 1, 0) * CFrame.Angles(-X + OX, -OZ * 0.3, OY), Alpha * 2)
			end
			if LS then
				LS.C0 = LS.C0:Lerp(CFrame.new(-1.5, 0, 0) * CFrame.Angles(-OX, OY + OZ, 0) * CFrame.new(1.5, 0, 0) * CFrame.new(-1, 0.5, 0, -0, -0, -1, 0, 1, 0, 1, 0, 0) * CFrame.Angles(0, 0, -X), Alpha)
			end
			if RS then
				RS.C0 = RS.C0:Lerp(CFrame.new(-1.5, 0, 0) * CFrame.Angles(-OX, OY + OZ, 0) * CFrame.new(1.5, 0, 0) * CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, -0, -0) * CFrame.Angles(0, 0, X), Alpha)
			end
		end
	end)

	return setmetatable({}, {
		__index = function(_, Index: string)
			local Root = Object
			local Value = Root[Index]
			if not Value then
				Value = Tool[Index]
				Root = Tool
			end
			if typeof(Value) == "function" then
				return function(_, ...)
					return Value(Root, ...)
				end
			end
			return Value
		end,
		__newindex = function(_, Index: string, Value: any)
			Tool[Index] = Value
		end,
	})
end
