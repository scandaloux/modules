local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

function BindToRenderStep(Name, Priority, Callback)
	if RunService:IsClient() then
		RunService:BindToRenderStep(Name, Priority, Callback)
	else 
		RunService.Heartbeat:Connect(function(DeltaTime)
			Callback(DeltaTime)
		end)
	end
end

local Fusion = {}
Fusion.Utility = {}
Fusion.Animation = {}
Fusion.Colour = {}
Fusion.Dependencies = {}
Fusion.Instances = {}
Fusion.Logging = {}
Fusion.State = {}

-- Logging

Fusion.Logging.parseError = function(err: string)
	return {
		type = "Error",
		raw = err,
		message = err:gsub("^.+:%d+:%s*", ""),
		trace = debug.traceback(nil, 2)
	}
end

Fusion.Logging.logWarn = function(messageID, ...)
	local formatString: string

	if Fusion.Logging.messages[messageID] ~= nil then
		formatString = Fusion.Logging.messages[messageID]
	else
		messageID = "unknownMessage"
		formatString = Fusion.Logging.messages[messageID]
	end

	warn(string.format("[Fusion] " .. formatString .. "\n(ID: " .. messageID .. ")", ...))
end

Fusion.Logging.logErrorNonFatal = (function()

--[[
	Utility function to log a Fusion-specific error, without halting execution.
]]

	local messages = (Fusion.Logging.messages)

	local function logErrorNonFatal(messageID: string, errObj, ...)
		local formatString: string

		if messages[messageID] ~= nil then
			formatString = messages[messageID]
		else
			messageID = "unknownMessage"
			formatString = messages[messageID]
		end

		local errorString
		if errObj == nil then
			errorString = string.format("[Fusion] " .. formatString .. "\n(ID: " .. messageID .. ")", ...)
		else
			formatString = formatString:gsub("ERROR_MESSAGE", errObj.message)
			errorString = string.format("[Fusion] " .. formatString .. "\n(ID: " .. messageID .. ")\n---- Stack trace ----\n" .. errObj.trace, ...)
		end

		task.spawn(function(...)
			error(errorString:gsub("\n", "\n    "), 0)
		end, ...)
	end

	return logErrorNonFatal
end)()

Fusion.Logging.logError = (function()

--[[
	Utility function to log a Fusion-specific error.
]]

	local messages = (Fusion.Logging.messages)

	local function logError(messageID: string, errObj, ...)
		local formatString: string

		if messages[messageID] ~= nil then
			formatString = messages[messageID]
		else
			messageID = "unknownMessage"
			formatString = messages[messageID]
		end

		local errorString
		if errObj == nil then
			errorString = string.format("[Fusion] " .. formatString .. "\n(ID: " .. messageID .. ")", ...)
		else
			formatString = formatString:gsub("ERROR_MESSAGE", errObj.message)
			errorString = string.format("[Fusion] " .. formatString .. "\n(ID: " .. messageID .. ")\n---- Stack trace ----\n" .. errObj.trace, ...)
		end

		error(errorString:gsub("\n", "\n    "), 0)
	end

	return logError
end)()

Fusion.Logging.messages = {
	cannotAssignProperty = "The class type '%s' has no assignable property '%s'.",
	cannotConnectChange = "The %s class doesn't have a property called '%s'.",
	cannotConnectEvent = "The %s class doesn't have an event called '%s'.",
	cannotCreateClass = "Can't create a new instance of class '%s'.",
	computedCallbackError = "Computed callback error: ERROR_MESSAGE",
	destructorNeededValue = "To save instances into Values, provide a destructor function. This will be an error soon - see discussion #183 on GitHub.",
	destructorNeededComputed = "To return instances from Computeds, provide a destructor function. This will be an error soon - see discussion #183 on GitHub.",
	multiReturnComputed = "Returning multiple values from Computeds is discouraged, as behaviour will change soon - see discussion #189 on GitHub.",
	destructorNeededForKeys = "To return instances from ForKeys, provide a destructor function. This will be an error soon - see discussion #183 on GitHub.",
	destructorNeededForValues = "To return instances from ForValues, provide a destructor function. This will be an error soon - see discussion #183 on GitHub.",
	destructorNeededForPairs = "To return instances from ForPairs, provide a destructor function. This will be an error soon - see discussion #183 on GitHub.",
	duplicatePropertyKey = "",
	forKeysProcessorError = "ForKeys callback error: ERROR_MESSAGE",
	forKeysKeyCollision = "ForKeys should only write to output key '%s' once when processing key changes, but it wrote to it twice. Previously input key: '%s'; New input key: '%s'",
	forKeysDestructorError = "ForKeys destructor error: ERROR_MESSAGE",
	forPairsDestructorError = "ForPairs destructor error: ERROR_MESSAGE",
	forPairsKeyCollision = "ForPairs should only write to output key '%s' once when processing key changes, but it wrote to it twice. Previous input pair: '[%s] = %s'; New input pair: '[%s] = %s'",
	forPairsProcessorError = "ForPairs callback error: ERROR_MESSAGE",
	forValuesProcessorError = "ForValues callback error: ERROR_MESSAGE",
	forValuesDestructorError = "ForValues destructor error: ERROR_MESSAGE",
	invalidChangeHandler = "The change handler for the '%s' property must be a function.",
	invalidEventHandler = "The handler for the '%s' event must be a function.",
	invalidPropertyType = "'%s.%s' expected a '%s' type, but got a '%s' type.",
	invalidRefType = "Instance refs must be Value objects.",
	invalidOutType = "[Out] properties must be given Value objects.",
	invalidOutProperty = "The %s class doesn't have a property called '%s'.",
	invalidSpringDamping = "The damping ratio for a spring must be >= 0. (damping was %.2f)",
	invalidSpringSpeed = "The speed of a spring must be >= 0. (speed was %.2f)",
	mistypedSpringDamping = "The damping ratio for a spring must be a number. (got a %s)",
	mistypedSpringSpeed = "The speed of a spring must be a number. (got a %s)",
	mistypedTweenInfo = "The tween info of a tween must be a TweenInfo. (got a %s)",
	springTypeMismatch = "The type '%s' doesn't match the spring's type '%s'.",
	strictReadError = "'%s' is not a valid member of '%s'.",
	unknownMessage = "Unknown error: ERROR_MESSAGE",
	unrecognisedChildType = "'%s' type children aren't accepted by `[Children]`.",
	unrecognisedPropertyKey = "'%s' keys aren't accepted in property tables.",
	unrecognisedPropertyStage = "'%s' isn't a valid stage for a special key to be applied at."
}


-- Utility

Fusion.Utility.xtypeof = function(x: any)
	local typeString = typeof(x)

	if typeString == "table" and typeof(x.type) == "string" then
		return x.type
	else
		return typeString
	end
end

Fusion.Utility.restrictRead = (function()
	--[[
		Restricts the reading of missing members for a table.
	]]

	local logError = Fusion.Logging.logError

	type table = {[any]: any}

	local function restrictRead(tableName: string, strictTable: table): table
		-- FIXME: Typed Luau doesn't recognise this correctly yet
		local metatable = getmetatable(strictTable :: any)

		if metatable == nil then
			metatable = {}
			setmetatable(strictTable, metatable)
		end

		function metatable:__index(memberName)
			logError("strictReadError", nil, tostring(memberName), tableName)
		end

		return strictTable
	end

	return restrictRead
end)()

Fusion.Utility.needsDestruction = function(x: any): boolean
	return typeof(x) == "Instance"
end

Fusion.Utility.isSimilar = function(a: any, b: any): boolean
	-- HACK: because tables are mutable data structures, don't make assumptions
	-- about similarity from equality for now (see issue #44)
	if typeof(a) == "table" then
		return false
	else
		return a == b
	end
end

Fusion.Utility.doNothing = function() end

Fusion.Utility.cleanup = (function()
	--[[
		Cleans up the tasks passed in as the arguments.
		A task can be any of the following:

		- an Instance - will be destroyed
		- an RBXScriptConnection - will be disconnected
		- a function - will be run
		- a table with a `Destroy` or `destroy` function - will be called
		- an array - `cleanup` will be called on each item
	]]

	local function cleanupOne(task: any)
		local taskType = typeof(task)

		-- case 1: Instance
		if taskType == "Instance" then
			task:Destroy()

			-- case 2: RBXScriptConnection
		elseif taskType == "RBXScriptConnection" then
			task:Disconnect()

			-- case 3: callback
		elseif taskType == "function" then
			task()

		elseif taskType == "table" then
			-- case 4: destroy() function
			if typeof(task.destroy) == "function" then
				task:destroy()

				-- case 5: Destroy() function
			elseif typeof(task.Destroy) == "function" then
				task:Destroy()

				-- case 6: array of tasks
			elseif task[1] ~= nil then
				for _, subtask in ipairs(task) do
					cleanupOne(subtask)
				end
			end
		end
	end

	local function cleanup(...: any)
		for index = 1, select("#", ...) do
			cleanupOne(select(index, ...))
		end
	end

	return cleanup
end)()

Fusion.Utility.None =  {
	type = "Symbol",
	name = "None"
} 

-- Animation

Fusion.Animation.unpackType = (function()
	

--[[
	Unpacks an animatable type into an array of numbers.
	If the type is not animatable, an empty array will be returned.

	FIXME: This function uses a lot of redefinitions to suppress false positives
	from the Luau typechecker - ideally these wouldn't be d

	FUTURE: When Luau supports singleton types, those could be used in
	conjunction with intersection types to make this function fully statically
	type checkable.
]]

	
	local Oklab = (Fusion.Colour.Oklab)

	local function unpackType(value: any, typeString: string): {number}
		if typeString == "number" then
			local value = value :: number
			return {value}

		elseif typeString == "CFrame" then
			-- FUTURE: is there a better way of doing this? doing distance
			-- calculations on `angle` may be incorrect
			local axis, angle = value:ToAxisAngle()
			return {value.X, value.Y, value.Z, axis.X, axis.Y, axis.Z, angle}

		elseif typeString == "Color3" then
			local lab = Oklab.to(value)
			return {lab.X, lab.Y, lab.Z}

		elseif typeString == "ColorSequenceKeypoint" then
			local lab = Oklab.to(value.Value)
			return {lab.X, lab.Y, lab.Z, value.Time}

		elseif typeString == "DateTime" then
			return {value.UnixTimestampMillis}

		elseif typeString == "NumberRange" then
			return {value.Min, value.Max}

		elseif typeString == "NumberSequenceKeypoint" then
			return {value.Value, value.Time, value.Envelope}

		elseif typeString == "PhysicalProperties" then
			return {value.Density, value.Friction, value.Elasticity, value.FrictionWeight, value.ElasticityWeight}

		elseif typeString == "Ray" then
			return {value.Origin.X, value.Origin.Y, value.Origin.Z, value.Direction.X, value.Direction.Y, value.Direction.Z}

		elseif typeString == "Rect" then
			return {value.Min.X, value.Min.Y, value.Max.X, value.Max.Y}

		elseif typeString == "Region3" then
			-- FUTURE: support rotated Region3s if/when they become constructable
			return {
				value.CFrame.X, value.CFrame.Y, value.CFrame.Z,
				value.Size.X, value.Size.Y, value.Size.Z
			}

		elseif typeString == "Region3int16" then
			return {value.Min.X, value.Min.Y, value.Min.Z, value.Max.X, value.Max.Y, value.Max.Z}

		elseif typeString == "UDim" then
			return {value.Scale, value.Offset}

		elseif typeString == "UDim2" then
			return {value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset}

		elseif typeString == "Vector2" then
			return {value.X, value.Y}

		elseif typeString == "Vector2int16" then
			return {value.X, value.Y}

		elseif typeString == "Vector3" then
			return {value.X, value.Y, value.Z}

		elseif typeString == "Vector3int16" then
			return {value.X, value.Y, value.Z}
		else
			return {}
		end
	end

	return unpackType
end)()

Fusion.Animation.springCoefficients = function(time: number, damping: number, speed: number): (number, number, number, number)
	-- if time or speed is 0, then the spring won't move
	if time == 0 or speed == 0 then
		return 1, 0, 0, 1
	end
	local posPos, posVel, velPos, velVel

	if damping > 1 then
		-- overdamped spring
		-- solution to the characteristic equation:
		-- z = -ζω ± Sqrt[ζ^2 - 1] ω
		-- x[t] -> x0(e^(t z2) z1 - e^(t z1) z2)/(z1 - z2)
		--		 + v0(e^(t z1) - e^(t z2))/(z1 - z2)
		-- v[t] -> x0(z1 z2(-e^(t z1) + e^(t z2)))/(z1 - z2)
		--		 + v0(z1 e^(t z1) - z2 e^(t z2))/(z1 - z2)

		local scaledTime = time * speed
		local alpha = math.sqrt(damping^2 - 1)
		local scaledInvAlpha = -0.5 / alpha
		local z1 = -alpha - damping
		local z2 = 1 / z1
		local expZ1 = math.exp(scaledTime * z1)
		local expZ2 = math.exp(scaledTime * z2)

		posPos = (expZ2*z1 - expZ1*z2) * scaledInvAlpha
		posVel = (expZ1 - expZ2) * scaledInvAlpha / speed
		velPos = (expZ2 - expZ1) * scaledInvAlpha * speed
		velVel = (expZ1*z1 - expZ2*z2) * scaledInvAlpha

	elseif damping == 1 then
		-- critically damped spring
		-- x[t] -> x0(e^-tω)(1+tω) + v0(e^-tω)t
		-- v[t] -> x0(t ω^2)(-e^-tω) + v0(1 - tω)(e^-tω)

		local scaledTime = time * speed
		local expTerm = math.exp(-scaledTime)

		posPos = expTerm * (1 + scaledTime)
		posVel = expTerm * time
		velPos = expTerm * (-scaledTime*speed)
		velVel = expTerm * (1 - scaledTime)

	else
		-- underdamped spring
		-- factored out of the solutions to the characteristic equation:
		-- α = Sqrt[1 - ζ^2]
		-- x[t] -> x0(e^-tζω)(α Cos[tα] + ζω Sin[tα])/α
		--       + v0(e^-tζω)(Sin[tα])/α
		-- v[t] -> x0(-e^-tζω)(α^2 + ζ^2 ω^2)(Sin[tα])/α
		--       + v0(e^-tζω)(α Cos[tα] - ζω Sin[tα])/α

		local scaledTime = time * speed
		local alpha = math.sqrt(1 - damping^2)
		local invAlpha = 1 / alpha
		local alphaTime = alpha * scaledTime
		local expTerm = math.exp(-scaledTime*damping)
		local sinTerm = expTerm * math.sin(alphaTime)
		local cosTerm = expTerm * math.cos(alphaTime)
		local sinInvAlpha = sinTerm*invAlpha
		local sinInvAlphaDamp = sinInvAlpha*damping

		posPos = sinInvAlphaDamp + cosTerm
		posVel = sinInvAlpha
		velPos = -(sinInvAlphaDamp*damping + sinTerm*alpha)
		velVel = cosTerm - sinInvAlphaDamp
	end

	return posPos, posVel, velPos, velVel
end

Fusion.Animation.packType = (function()
	

--[[
	Packs an array of numbers into a given animatable data type.
	If the type is not animatable, nil will be returned.

	FUTURE: When Luau supports singleton types, those could be used in
	conjunction with intersection types to make this function fully statically
	type checkable.
]]

	
	local Oklab = (Fusion.Colour.Oklab)

	local function packType(numbers: {number}, typeString: string)
		if typeString == "number" then
			return numbers[1]

		elseif typeString == "CFrame" then
			return
				CFrame.new(numbers[1], numbers[2], numbers[3]) *
				CFrame.fromAxisAngle(
					Vector3.new(numbers[4], numbers[5], numbers[6]).Unit,
					numbers[7]
				)

		elseif typeString == "Color3" then
			return Oklab.from(
				Vector3.new(numbers[1], numbers[2], numbers[3]),
				false
			)

		elseif typeString == "ColorSequenceKeypoint" then
			return ColorSequenceKeypoint.new(
				numbers[4],
				Oklab.from(
					Vector3.new(numbers[1], numbers[2], numbers[3]),
					false
				)
			)

		elseif typeString == "DateTime" then
			return DateTime.fromUnixTimestampMillis(numbers[1])

		elseif typeString == "NumberRange" then
			return NumberRange.new(numbers[1], numbers[2])

		elseif typeString == "NumberSequenceKeypoint" then
			return NumberSequenceKeypoint.new(numbers[2], numbers[1], numbers[3])

		elseif typeString == "PhysicalProperties" then
			return PhysicalProperties.new(numbers[1], numbers[2], numbers[3], numbers[4], numbers[5])

		elseif typeString == "Ray" then
			return Ray.new(
				Vector3.new(numbers[1], numbers[2], numbers[3]),
				Vector3.new(numbers[4], numbers[5], numbers[6])
			)

		elseif typeString == "Rect" then
			return Rect.new(numbers[1], numbers[2], numbers[3], numbers[4])

		elseif typeString == "Region3" then
			-- FUTURE: support rotated Region3s if/when they become constructable
			local position = Vector3.new(numbers[1], numbers[2], numbers[3])
			local halfSize = Vector3.new(numbers[4] / 2, numbers[5] / 2, numbers[6] / 2)
			return Region3.new(position - halfSize, position + halfSize)

		elseif typeString == "Region3int16" then
			return Region3int16.new(
				Vector3int16.new(numbers[1], numbers[2], numbers[3]),
				Vector3int16.new(numbers[4], numbers[5], numbers[6])
			)

		elseif typeString == "UDim" then
			return UDim.new(numbers[1], numbers[2])

		elseif typeString == "UDim2" then
			return UDim2.new(numbers[1], numbers[2], numbers[3], numbers[4])

		elseif typeString == "Vector2" then
			return Vector2.new(numbers[1], numbers[2])

		elseif typeString == "Vector2int16" then
			return Vector2int16.new(numbers[1], numbers[2])

		elseif typeString == "Vector3" then
			return Vector3.new(numbers[1], numbers[2], numbers[3])

		elseif typeString == "Vector3int16" then
			return Vector3int16.new(numbers[1], numbers[2], numbers[3])
		else
			return nil
		end
	end

	return packType
end)()

Fusion.Animation.lerpType = (function()

--[[
	Linearly interpolates the given animatable types by a ratio.
	If the types are different or not animatable, then the first value will be
	returned for ratios below 0.5, and the second value for 0.5 and above.

	FIXME: This function uses a lot of redefinitions to suppress false positives
	from the Luau typechecker - ideally these wouldn't be d
]]

	local Oklab = (Fusion.Colour.Oklab)

	local function lerpType(from: any, to: any, ratio: number): any
		local typeString = typeof(from)

		if typeof(to) == typeString then
			-- both types must match for interpolation to make sense
			if typeString == "number" then
				local to, from = to :: number, from :: number
				return (to - from) * ratio + from

			elseif typeString == "CFrame" then
				local to, from = to :: CFrame, from :: CFrame
				return from:Lerp(to, ratio)

			elseif typeString == "Color3" then
				local to, from = to :: Color3, from :: Color3
				local fromLab = Oklab.to(from)
				local toLab = Oklab.to(to)
				return Oklab.from(
					fromLab:Lerp(toLab, ratio),
					false
				)

			elseif typeString == "ColorSequenceKeypoint" then
				local to, from = to :: ColorSequenceKeypoint, from :: ColorSequenceKeypoint
				local fromLab = Oklab.to(from.Value)
				local toLab = Oklab.to(to.Value)
				return ColorSequenceKeypoint.new(
					(to.Time - from.Time) * ratio + from.Time,
					Oklab.from(
						fromLab:Lerp(toLab, ratio),
						false
					)
				)

			elseif typeString == "DateTime" then
				local to, from = to :: DateTime, from :: DateTime
				return DateTime.fromUnixTimestampMillis(
					(to.UnixTimestampMillis - from.UnixTimestampMillis) * ratio + from.UnixTimestampMillis
				)

			elseif typeString == "NumberRange" then
				local to, from = to :: NumberRange, from :: NumberRange
				return NumberRange.new(
					(to.Min - from.Min) * ratio + from.Min,
					(to.Max - from.Max) * ratio + from.Max
				)

			elseif typeString == "NumberSequenceKeypoint" then
				local to, from = to :: NumberSequenceKeypoint, from :: NumberSequenceKeypoint
				return NumberSequenceKeypoint.new(
					(to.Time - from.Time) * ratio + from.Time,
					(to.Value - from.Value) * ratio + from.Value,
					(to.Envelope - from.Envelope) * ratio + from.Envelope
				)

			elseif typeString == "PhysicalProperties" then
				local to, from = to :: PhysicalProperties, from :: PhysicalProperties
				return PhysicalProperties.new(
					(to.Density - from.Density) * ratio + from.Density,
					(to.Friction - from.Friction) * ratio + from.Friction,
					(to.Elasticity - from.Elasticity) * ratio + from.Elasticity,
					(to.FrictionWeight - from.FrictionWeight) * ratio + from.FrictionWeight,
					(to.ElasticityWeight - from.ElasticityWeight) * ratio + from.ElasticityWeight
				)

			elseif typeString == "Ray" then
				local to, from = to :: Ray, from :: Ray
				return Ray.new(
					from.Origin:Lerp(to.Origin, ratio),
					from.Direction:Lerp(to.Direction, ratio)
				)

			elseif typeString == "Rect" then
				local to, from = to :: Rect, from :: Rect
				return Rect.new(
					from.Min:Lerp(to.Min, ratio),
					from.Max:Lerp(to.Max, ratio)
				)

			elseif typeString == "Region3" then
				local to, from = to :: Region3, from :: Region3
				-- FUTURE: support rotated Region3s if/when they become constructable
				local position = from.CFrame.Position:Lerp(to.CFrame.Position, ratio)
				local halfSize = from.Size:Lerp(to.Size, ratio) / 2
				return Region3.new(position - halfSize, position + halfSize)

			elseif typeString == "Region3int16" then
				local to, from = to :: Region3int16, from :: Region3int16
				return Region3int16.new(
					Vector3int16.new(
						(to.Min.X - from.Min.X) * ratio + from.Min.X,
						(to.Min.Y - from.Min.Y) * ratio + from.Min.Y,
						(to.Min.Z - from.Min.Z) * ratio + from.Min.Z
					),
					Vector3int16.new(
						(to.Max.X - from.Max.X) * ratio + from.Max.X,
						(to.Max.Y - from.Max.Y) * ratio + from.Max.Y,
						(to.Max.Z - from.Max.Z) * ratio + from.Max.Z
					)
				)

			elseif typeString == "UDim" then
				local to, from = to :: UDim, from :: UDim
				return UDim.new(
					(to.Scale - from.Scale) * ratio + from.Scale,
					(to.Offset - from.Offset) * ratio + from.Offset
				)

			elseif typeString == "UDim2" then
				local to, from = to :: UDim2, from :: UDim2
				return from:Lerp(to, ratio)

			elseif typeString == "Vector2" then
				local to, from = to :: Vector2, from :: Vector2
				return from:Lerp(to, ratio)

			elseif typeString == "Vector2int16" then
				local to, from = to :: Vector2int16, from :: Vector2int16
				return Vector2int16.new(
					(to.X - from.X) * ratio + from.X,
					(to.Y - from.Y) * ratio + from.Y
				)

			elseif typeString == "Vector3" then
				local to, from = to :: Vector3, from :: Vector3
				return from:Lerp(to, ratio)

			elseif typeString == "Vector3int16" then
				local to, from = to :: Vector3int16, from :: Vector3int16
				return Vector3int16.new(
					(to.X - from.X) * ratio + from.X,
					(to.Y - from.Y) * ratio + from.Y,
					(to.Z - from.Z) * ratio + from.Z
				)
			end
		end

		-- fallback case: the types are different or not animatable
		if ratio < 0.5 then
			return from
		else
			return to
		end
	end

	return lerpType	
end)()

Fusion.Animation.getTweenRatio = function(tweenInfo: TweenInfo, currentTime: number): number
	local delay = tweenInfo.DelayTime
	local duration = tweenInfo.Time
	local reverses = tweenInfo.Reverses
	local numCycles = 1 + tweenInfo.RepeatCount
	local easeStyle = tweenInfo.EasingStyle
	local easeDirection = tweenInfo.EasingDirection

	local cycleDuration = delay + duration
	if reverses then
		cycleDuration += duration
	end

	if currentTime >= cycleDuration * numCycles then
		return 1
	end

	local cycleTime = currentTime % cycleDuration

	if cycleTime <= delay then
		return 0
	end

	local tweenProgress = (cycleTime - delay) / duration
	if tweenProgress > 1 then
		tweenProgress = 2 - tweenProgress
	end

	local ratio = TweenService:GetValue(tweenProgress, easeStyle, easeDirection)
	return ratio
end


Fusion.Animation.TweenScheduler = (function()
	

--[[
	Manages batch updating of tween objects.
]]

	local lerpType = (Fusion.Animation.lerpType)
	local getTweenRatio = (Fusion.Animation.getTweenRatio)
	local updateAll = (Fusion.Dependencies.updateAll)

	local TweenScheduler = {}

	local WEAK_KEYS_METATABLE = {__mode = "k"}

	-- all the tweens currently being updated
	local allTweens = {}
	setmetatable(allTweens, WEAK_KEYS_METATABLE)

--[[
	Adds a Tween to be updated every render step.
]]
	function TweenScheduler.add(tween)
		allTweens[tween] = true
	end

--[[
	Removes a Tween from the scheduler.
]]
	function TweenScheduler.remove(tween)
		allTweens[tween] = nil
	end

--[[
	Updates all Tween objects.
]]
	local function updateAllTweens()
		local now = os.clock()
		-- FIXME: Typed Luau doesn't understand this loop yet
		for tween in pairs(allTweens :: any) do
			local currentTime = now - tween._currentTweenStartTime

			if currentTime > tween._currentTweenDuration then
				if tween._currentTweenInfo.Reverses then
					tween._currentValue = tween._prevValue
				else
					tween._currentValue = tween._nextValue
				end
				tween._currentlyAnimating = false
				updateAll(tween)
				TweenScheduler.remove(tween)
			else
				local ratio = getTweenRatio(tween._currentTweenInfo, currentTime)
				local currentValue = lerpType(tween._prevValue, tween._nextValue, ratio)
				tween._currentValue = currentValue
				tween._currentlyAnimating = true
				updateAll(tween)
			end
		end
	end
	
	BindToRenderStep(
		"__FusionTweenScheduler",
		Enum.RenderPriority.First.Value,
		updateAllTweens
	)

	return TweenScheduler
end)()

Fusion.Animation.Tween = (function()

--[[
	Constructs a new computed state object, which follows the value of another
	state object using a tween.
]]

	
	local TweenScheduler = (Fusion.Animation.TweenScheduler)
	local useDependency = (Fusion.Dependencies.useDependency)
	local initDependency = (Fusion.Dependencies.initDependency)
	local logError = (Fusion.Logging.logError)
	local logErrorNonFatal = (Fusion.Logging.logErrorNonFatal)
	local xtypeof = (Fusion.Utility.xtypeof)

	local class = {}

	local CLASS_METATABLE = {__index = class}
	local WEAK_KEYS_METATABLE = {__mode = "k"}

--[[
	Returns the current value of this Tween object.
	The object will be registered as a dependency unless `asDependency` is false.
]]
	function class:get(asDependency: boolean?): any
		if asDependency ~= false then
			useDependency(self)
		end
		return self._currentValue
	end

--[[
	Called when the goal state changes value; this will initiate a new tween.
	Returns false as the current value doesn't change right away.
]]
	function class:update(): boolean
		local goalValue = self._goalState:get(false)

		-- if the goal hasn't changed, then this is a TweenInfo change.
		-- in that case, if we're not currently animating, we can skip everything
		if goalValue == self._nextValue and not self._currentlyAnimating then
			return false
		end

		local tweenInfo = self._tweenInfo
		if self._tweenInfoIsState then
			tweenInfo = tweenInfo:get()
		end

		-- if we receive a bad TweenInfo, then error and stop the update
		if typeof(tweenInfo) ~= "TweenInfo" then
			logErrorNonFatal("mistypedTweenInfo", nil, typeof(tweenInfo))
			return false
		end

		self._prevValue = self._currentValue
		self._nextValue = goalValue

		self._currentTweenStartTime = os.clock()
		self._currentTweenInfo = tweenInfo

		local tweenDuration = tweenInfo.DelayTime + tweenInfo.Time
		if tweenInfo.Reverses then
			tweenDuration += tweenInfo.Time
		end
		tweenDuration *= tweenInfo.RepeatCount + 1
		self._currentTweenDuration = tweenDuration

		-- start animating this tween
		TweenScheduler.add(self)

		return false
	end

	local function Tween<T>(
		goalState,
		tweenInfo
	)
		local currentValue = goalState:get(false)

		-- apply defaults for tween info
		if tweenInfo == nil then
			tweenInfo = TweenInfo.new()
		end

		local dependencySet = {[goalState] = true}
		local tweenInfoIsState = xtypeof(tweenInfo) == "State"

		if tweenInfoIsState then
			dependencySet[tweenInfo] = true
		end

		local startingTweenInfo = tweenInfo
		if tweenInfoIsState then
			startingTweenInfo = startingTweenInfo:get()
		end

		-- If we start with a bad TweenInfo, then we don't want to construct a Tween
		if typeof(startingTweenInfo) ~= "TweenInfo" then
			logError("mistypedTweenInfo", nil, typeof(startingTweenInfo))
		end

		local self = setmetatable({
			type = "State",
			kind = "Tween",
			dependencySet = dependencySet,
			-- if we held strong references to the dependents, then they wouldn't be
			-- able to get garbage collected when they fall out of scope
			dependentSet = setmetatable({}, WEAK_KEYS_METATABLE),
			_goalState = goalState,
			_tweenInfo = tweenInfo,
			_tweenInfoIsState = tweenInfoIsState,

			_prevValue = currentValue,
			_nextValue = currentValue,
			_currentValue = currentValue,

			-- store current tween into separately from 'real' tween into, so it
			-- isn't affected by :setTweenInfo() until next change
			_currentTweenInfo = tweenInfo,
			_currentTweenDuration = 0,
			_currentTweenStartTime = 0,
			_currentlyAnimating = false
		}, CLASS_METATABLE)

		initDependency(self)
		-- add this object to the goal state's dependent set
		goalState.dependentSet[self] = true

		return self
	end

	return Tween
end)

Fusion.Animation.SpringScheduler = (function()
	

--[[
	Manages batch updating of spring objects.
]]

	
	local packType = (Fusion.Animation.packType)
	local springCoefficients = (Fusion.Animation.springCoefficients)
	local updateAll = (Fusion.Dependencies.updateAll)

	local SpringScheduler = {}

	local EPSILON = 0.0001
	local activeSprings = {}
	local lastUpdateTime = os.clock()

	function SpringScheduler.add(spring)
		-- we don't necessarily want to use the most accurate time - here we snap to
		-- the last update time so that springs started within the same frame have
		-- identical time steps
		spring._lastSchedule = lastUpdateTime
		spring._startDisplacements = {}
		spring._startVelocities = {}
		for index, goal in ipairs(spring._springGoals) do
			spring._startDisplacements[index] = spring._springPositions[index] - goal
			spring._startVelocities[index] = spring._springVelocities[index]
		end

		activeSprings[spring] = true
	end

	function SpringScheduler.remove(spring)
		activeSprings[spring] = nil
	end


	local function updateAllSprings()
		local springsToSleep = {}
		lastUpdateTime = os.clock()

		for spring in pairs(activeSprings) do
			local posPos, posVel, velPos, velVel = springCoefficients(lastUpdateTime - spring._lastSchedule, spring._currentDamping, spring._currentSpeed)

			local positions = spring._springPositions
			local velocities = spring._springVelocities
			local startDisplacements = spring._startDisplacements
			local startVelocities = spring._startVelocities
			local isMoving = false

			for index, goal in ipairs(spring._springGoals) do
				local oldDisplacement = startDisplacements[index]
				local oldVelocity = startVelocities[index]
				local newDisplacement = oldDisplacement * posPos + oldVelocity * posVel
				local newVelocity = oldDisplacement * velPos + oldVelocity * velVel

				if math.abs(newDisplacement) > EPSILON or math.abs(newVelocity) > EPSILON then
					isMoving = true
				end

				positions[index] = newDisplacement + goal
				velocities[index] = newVelocity
			end

			if not isMoving then
				springsToSleep[spring] = true
			end
		end

		for spring in pairs(activeSprings) do
			spring._currentValue = packType(spring._springPositions, spring._currentType)
			updateAll(spring)
		end

		for spring in pairs(springsToSleep) do
			activeSprings[spring] = nil
		end
	end

	BindToRenderStep(
		"__FusionSpringScheduler",
		Enum.RenderPriority.First.Value,
		updateAllSprings
	)

	return SpringScheduler
end)()

Fusion.Animation.Spring = (function()

--[[
	Constructs a new computed state object, which follows the value of another
	state object using a spring simulation.
]]

	local logError = (Fusion.Logging.logError)
	local logErrorNonFatal = (Fusion.Logging.logErrorNonFatal)
	local unpackType = (Fusion.Animation.unpackType)
	local SpringScheduler = (Fusion.Animation.SpringScheduler)
	local useDependency = (Fusion.Dependencies.useDependency)
	local initDependency = (Fusion.Dependencies.initDependency)
	local updateAll = (Fusion.Dependencies.updateAll)
	local xtypeof = (Fusion.Utility.xtypeof)
	local unwrap = (Fusion.State.unwrap)

	local class = {}

	local CLASS_METATABLE = {__index = class}
	local WEAK_KEYS_METATABLE = {__mode = "k"}

--[[
	Returns the current value of this Spring object.
	The object will be registered as a dependency unless `asDependency` is false.
]]
	function class:get(asDependency: boolean?): any
		if asDependency ~= false then
			useDependency(self)
		end
		return self._currentValue
	end

--[[
	Sets the position of the internal springs, meaning the value of this
	Spring will jump to the given value. This doesn't affect velocity.

	If the type doesn't match the current type of the spring, an error will be
	thrown.
]]
	function class:setPosition(newValue)
		local newType = typeof(newValue)
		if newType ~= self._currentType then
			logError("springTypeMismatch", nil, newType, self._currentType)
		end

		self._springPositions = unpackType(newValue, newType)
		self._currentValue = newValue
		SpringScheduler.add(self)
		updateAll(self)
	end

--[[
	Sets the velocity of the internal springs, overwriting the existing velocity
	of this Spring. This doesn't affect position.

	If the type doesn't match the current type of the spring, an error will be
	thrown.
]]
	function class:setVelocity(newValue)
		local newType = typeof(newValue)
		if newType ~= self._currentType then
			logError("springTypeMismatch", nil, newType, self._currentType)
		end

		self._springVelocities = unpackType(newValue, newType)
		SpringScheduler.add(self)
	end

--[[
	Adds to the velocity of the internal springs, on top of the existing
	velocity of this Spring. This doesn't affect position.

	If the type doesn't match the current type of the spring, an error will be
	thrown.
]]
	function class:addVelocity(deltaValue)
		local deltaType = typeof(deltaValue)
		if deltaType ~= self._currentType then
			logError("springTypeMismatch", nil, deltaType, self._currentType)
		end

		local springDeltas = unpackType(deltaValue, deltaType)
		for index, delta in ipairs(springDeltas) do
			self._springVelocities[index] += delta
		end
		SpringScheduler.add(self)
	end

--[[
	Called when the goal state changes value, or when the speed or damping has
	changed.
]]
	function class:update(): boolean
		local goalValue = self._goalState:get(false)

		-- figure out if this was a goal change or a speed/damping change
		if goalValue == self._goalValue then
			-- speed/damping change
			local damping = unwrap(self._damping)
			if typeof(damping) ~= "number" then
				logErrorNonFatal("mistypedSpringDamping", nil, typeof(damping))
			elseif damping < 0 then
				logErrorNonFatal("invalidSpringDamping", nil, damping)
			else
				self._currentDamping = damping
			end

			local speed = unwrap(self._speed)
			if typeof(speed) ~= "number" then
				logErrorNonFatal("mistypedSpringSpeed", nil, typeof(speed))
			elseif speed < 0 then
				logErrorNonFatal("invalidSpringSpeed", nil, speed)
			else
				self._currentSpeed = speed
			end

			return false
		else
			-- goal change - reconfigure spring to target new goal
			self._goalValue = goalValue

			local oldType = self._currentType
			local newType = typeof(goalValue)
			self._currentType = newType

			local springGoals = unpackType(goalValue, newType)
			local numSprings = #springGoals
			self._springGoals = springGoals

			if newType ~= oldType then
				-- if the type changed, snap to the new value and rebuild the
				-- position and velocity tables
				self._currentValue = self._goalValue

				local springPositions = table.create(numSprings, 0)
				local springVelocities = table.create(numSprings, 0)
				for index, springGoal in ipairs(springGoals) do
					springPositions[index] = springGoal
				end
				self._springPositions = springPositions
				self._springVelocities = springVelocities

				-- the spring may have been animating before, so stop that
				SpringScheduler.remove(self)
				return true

				-- otherwise, the type hasn't changed, just the goal...
			elseif numSprings == 0 then
				-- if the type isn't animatable, snap to the new value
				self._currentValue = self._goalValue
				return true

			else
				-- if it's animatable, let it animate to the goal
				SpringScheduler.add(self)
				return false
			end
		end
	end

	local function Spring<T>(
		goalState,
		speed,
		damping
	)
		-- apply defaults for speed and damping
		if speed == nil then
			speed = 10
		end
		if damping == nil then
			damping = 1
		end

		local dependencySet = {[goalState] = true}
		if xtypeof(speed) == "State" then
			dependencySet[speed] = true
		end
		if xtypeof(damping) == "State" then
			dependencySet[damping] = true
		end

		local self = setmetatable({
			type = "State",
			kind = "Spring",
			dependencySet = dependencySet,
			-- if we held strong references to the dependents, then they wouldn't be
			-- able to get garbage collected when they fall out of scope
			dependentSet = setmetatable({}, WEAK_KEYS_METATABLE),
			_speed = speed,
			_damping = damping,

			_goalState = goalState,
			_goalValue = nil,

			_currentType = nil,
			_currentValue = nil,
			_currentSpeed = unwrap(speed),
			_currentDamping = unwrap(damping),

			_springPositions = nil,
			_springGoals = nil,
			_springVelocities = nil
		}, CLASS_METATABLE)

		initDependency(self)
		-- add this object to the goal state's dependent set
		goalState.dependentSet[self] = true
		self:update()

		return self
	end

	return Spring
end)()

-- Colour

Fusion.Colour.Oklab = (function()
--[[
	Provides functions for converting Color3s into Oklab space, for more
	perceptually uniform colour blending.

	See: https://bottosson.github.io/posts/oklab/
]]

	local Oklab = {}

	-- Converts a Color3 in RGB space to a Vector3 in Oklab space.
	function Oklab.to(rgb: Color3): Vector3
		local l = rgb.R * 0.4122214708 + rgb.G * 0.5363325363 + rgb.B * 0.0514459929
		local m = rgb.R * 0.2119034982 + rgb.G * 0.6806995451 + rgb.B * 0.1073969566
		local s = rgb.R * 0.0883024619 + rgb.G * 0.2817188376 + rgb.B * 0.6299787005

		local lRoot = l ^ (1/3)
		local mRoot = m ^ (1/3)
		local sRoot = s ^ (1/3)

		return Vector3.new(
			lRoot * 0.2104542553 + mRoot * 0.7936177850 - sRoot * 0.0040720468,
			lRoot * 1.9779984951 - mRoot * 2.4285922050 + sRoot * 0.4505937099,
			lRoot * 0.0259040371 + mRoot * 0.7827717662 - sRoot * 0.8086757660
		)
	end

	-- Converts a Vector3 in CIELAB space to a Color3 in RGB space.
	-- The Color3 will be clamped by default unless specified otherwise.
	function Oklab.from(lab: Vector3, unclamped: boolean?): Color3
		local lRoot = lab.X + lab.Y * 0.3963377774 + lab.Z * 0.2158037573
		local mRoot = lab.X - lab.Y * 0.1055613458 - lab.Z * 0.0638541728
		local sRoot = lab.X - lab.Y * 0.0894841775 - lab.Z * 1.2914855480

		local l = lRoot ^ 3
		local m = mRoot ^ 3
		local s = sRoot ^ 3

		local red = l * 4.0767416621 - m * 3.3077115913 + s * 0.2309699292
		local green = l * -1.2684380046 + m * 2.6097574011 - s * 0.3413193965
		local blue = l * -0.0041960863 - m * 0.7034186147 + s * 1.7076147010

		if not unclamped then
			red = math.clamp(red, 0, 1)
			green = math.clamp(green, 0, 1)
			blue = math.clamp(blue, 0, 1)
		end

		return Color3.new(red, green, blue)
	end

	return Oklab
end)()

-- Dependencies

Fusion.Dependencies.sharedState = {
	dependencySet = nil,
	initialisedStack = {},
	initialisedStackSize = 0
}

Fusion.Dependencies.useDependency = (function()
	

--[[
	If a target set was specified by captureDependencies(), this will add the
	given dependency to the target set.
]]

	local sharedState = (Fusion.Dependencies.sharedState)

	local initialisedStack = sharedState.initialisedStack

	local function useDependency(dependency)
		local dependencySet = sharedState.dependencySet

		if dependencySet ~= nil then
			local initialisedStackSize = sharedState.initialisedStackSize
			if initialisedStackSize > 0 then
				local initialisedSet = initialisedStack[initialisedStackSize]
				if initialisedSet[dependency] ~= nil then
					return
				end
			end
			dependencySet[dependency] = true
		end
	end

	return useDependency
end)()

Fusion.Dependencies.updateAll = (function()
	

--[[
	Given a reactive object, updates all dependent reactive objects.
	Objects are only ever updated after all of their dependencies are updated,
	are only ever updated once, and won't be updated if their dependencies are
	unchanged.
]]

	
	-- Credit: https://blog.elttob.uk/2022/11/07/sets-efficient-topological-search.html
	local function updateAll(root)
		local counters = {}
		local flags = {}
		local queue = {}
		local queueSize = 0
		local queuePos = 1

		for object in root.dependentSet do
			queueSize += 1
			queue[queueSize] = object
			flags[object] = true
		end

		-- Pass 1: counting up
		while queuePos <= queueSize do
			local next = queue[queuePos]
			local counter = counters[next]
			counters[next] = if counter == nil then 1 else counter + 1
			if (next :: any).dependentSet ~= nil then
				for object in (next :: any).dependentSet do
					queueSize += 1
					queue[queueSize] = object
				end
			end
			queuePos += 1
		end

		-- Pass 2: counting down + processing
		queuePos = 1
		while queuePos <= queueSize do
			local next = queue[queuePos]
			local counter = counters[next] - 1
			counters[next] = counter
			if counter == 0 and flags[next] and next:update() and (next :: any).dependentSet ~= nil then
				for object in (next :: any).dependentSet do
					flags[object] = true
				end
			end
			queuePos += 1
		end
	end

	return updateAll
end)()

Fusion.Dependencies.initDependency = (function()
	

--[[
	Registers the creation of an object which can be used as a dependency.

	This is used to make sure objects don't capture dependencies originating
	from inside of themselves.
]]

	
	local sharedState = (Fusion.Dependencies.sharedState)

	local initialisedStack = sharedState.initialisedStack

	local function initDependency(dependency)
		local initialisedStackSize = sharedState.initialisedStackSize

		for index, initialisedSet in ipairs(initialisedStack) do
			if index > initialisedStackSize then
				return
			end

			initialisedSet[dependency] = true
		end
	end

	return initDependency
end)()

Fusion.Dependencies.captureDependencies = (function()
	

--[[
	Calls the given callback, and stores any used external dependencies.
	Arguments can be passed in after the callback.
	If the callback completed successfully, returns true and the returned value,
	otherwise returns false and the error thrown.
	The callback shouldn't yield or run asynchronously.

	NOTE: any calls to useDependency() inside the callback (even if inside any
	nested captureDependencies() call) will not be included in the set, to avoid
	self-dependencies.
]]

	
	local parseError = (Fusion.Logging.parseError)
	local sharedState = (Fusion.Dependencies.sharedState)

	local initialisedStack = sharedState.initialisedStack
	local initialisedStackCapacity = 0

	local function captureDependencies(
		saveToSet,
		callback: (...any) -> any,
		...
	): (boolean, any)

		local prevDependencySet = sharedState.dependencySet
		sharedState.dependencySet = saveToSet

		sharedState.initialisedStackSize += 1
		local initialisedStackSize = sharedState.initialisedStackSize

		local initialisedSet
		if initialisedStackSize > initialisedStackCapacity then
			initialisedSet = {}
			initialisedStack[initialisedStackSize] = initialisedSet
			initialisedStackCapacity = initialisedStackSize
		else
			initialisedSet = initialisedStack[initialisedStackSize]
			table.clear(initialisedSet)
		end

		local data = table.pack(xpcall(callback, parseError, ...))

		sharedState.dependencySet = prevDependencySet
		sharedState.initialisedStackSize -= 1

		return table.unpack(data, 1, data.n)
	end

	return captureDependencies
end)()

-- Instances

Fusion.Instances.defaultProps = {
	ScreenGui = {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	},

	BillboardGui = {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	},

	SurfaceGui = {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50
	},

	Frame = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0
	},

	ScrollingFrame = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,

		ScrollBarImageColor3 = Color3.new(0, 0, 0)
	},

	TextLabel = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,

		Font = Enum.Font.SourceSans,
		Text = "",
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 14
	},

	TextButton = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,

		AutoButtonColor = false,

		Font = Enum.Font.SourceSans,
		Text = "",
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 14
	},

	TextBox = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,

		ClearTextOnFocus = false,

		Font = Enum.Font.SourceSans,
		Text = "",
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 14
	},

	ImageLabel = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0
	},

	ImageButton = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,

		AutoButtonColor = false
	},

	ViewportFrame = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0
	},

	VideoFrame = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0
	},

	CanvasGroup = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0
	}
}


Fusion.Instances.applyInstanceProps = (function()
	

--[[
	Applies a table of properties to an instance, including binding to any
	given state objects and applying any special keys.

	No strong reference is kept by default - special keys should take care not
	to accidentally hold strong references to instances forever.

	If a key is used twice, an error will be thrown. This is done to avoid
	double assignments or double bindings. However, some special keys may want
	to enable such assignments - in which case unique keys should be used for
	each occurence.
]]

	
	local cleanup = (Fusion.Utility.cleanup)
	local xtypeof = (Fusion.Utility.xtypeof)
	local logError = (Fusion.Logging.logError)
	local Observer = (Fusion.State.Observer)

	local function setProperty_unsafe(instance: Instance, property: string, value: any)
		(instance :: any)[property] = value
	end

	local function testPropertyAssignable(instance: Instance, property: string)
		(instance :: any)[property] = (instance :: any)[property]
	end

	local function setProperty(instance: Instance, property: string, value: any)
		if not pcall(setProperty_unsafe, instance, property, value) then
			if not pcall(testPropertyAssignable, instance, property) then
				if instance == nil then
					-- reference has been lost
					logError("setPropertyNilRef", nil, property, tostring(value))
				else
					-- property is not assignable
					logError("cannotAssignProperty", nil, instance.ClassName, property)
				end
			else
				-- property is assignable, but this specific assignment failed
				-- this typically implies the wrong type was received
				local givenType = typeof(value)
				local expectedType = typeof((instance :: any)[property])
				logError("invalidPropertyType", nil, instance.ClassName, property, expectedType, givenType)
			end
		end
	end

	local function bindProperty(instance: Instance, property: string, value, cleanupTasks)
		if xtypeof(value) == "State" then
			-- value is a state object - assign and observe for changes
			local willUpdate = false
			local function updateLater()
				if not willUpdate then
					willUpdate = true
					task.defer(function()
						willUpdate = false
						setProperty(instance, property, value:get(false))
					end)
				end
			end

			setProperty(instance, property, value:get(false))
			table.insert(cleanupTasks, Observer(value :: any):onChange(updateLater))
		else
			-- value is a constant - assign once only
			setProperty(instance, property, value)
		end
	end

	local function applyInstanceProps(props, applyTo: Instance)
		local specialKeys = {
			self = {},
			descendants = {},
			ancestor = {} ,
			observer = {}
		}
		local cleanupTasks = {}

		for key, value in pairs(props) do
			local keyType = xtypeof(key)

			if keyType == "string" then
				if key ~= "Parent" then
					bindProperty(applyTo, key :: string, value, cleanupTasks)
				end
			elseif keyType == "SpecialKey" then
				local stage = (key).stage
				local keys = specialKeys[stage]
				if keys == nil then
					logError("unrecognisedPropertyStage", nil, stage)
				else
					keys[key] = value
				end
			else
				-- we don't recognise what this key is supposed to be
				logError("unrecognisedPropertyKey", nil, xtypeof(key))
			end
		end

		for key, value in pairs(specialKeys.self) do
			key:apply(value, applyTo, cleanupTasks)
		end
		for key, value in pairs(specialKeys.descendants) do
			key:apply(value, applyTo, cleanupTasks)
		end

		if props.Parent ~= nil then
			bindProperty(applyTo, "Parent", props.Parent, cleanupTasks)
		end

		for key, value in pairs(specialKeys.ancestor) do
			key:apply(value, applyTo, cleanupTasks)
		end
		for key, value in pairs(specialKeys.observer) do
			key:apply(value, applyTo, cleanupTasks)
		end

		applyTo.Destroying:Connect(function()
			cleanup(cleanupTasks)
		end)
	end

	return applyInstanceProps
end)()

Fusion.Instances.Ref = (function()
	

--[[
	A special key for property tables, which stores a reference to the instance
	in a user-provided Value object.
]]

	local logError = (Fusion.Logging.logError)
	local xtypeof = (Fusion.Utility.xtypeof)

	local Ref = {}
	Ref.type = "SpecialKey"
	Ref.kind = "Ref"
	Ref.stage = "observer"

	function Ref:apply(refState: any, applyTo: Instance, cleanupTasks)
		if xtypeof(refState) ~= "State" or refState.kind ~= "Value" then
			logError("invalidRefType")
		else
			refState:set(applyTo)
			table.insert(cleanupTasks, function()
				refState:set(nil)
			end)
		end
	end

	return Ref
end)()

Fusion.Instances.Out = (function()

--[[
	A special key for property tables, which allows users to extract values from
	an instance into an automatically-updated Value object.
]]

	local logError = (Fusion.Logging.logError)
	local xtypeof = (Fusion.Utility.xtypeof)

	local function Out(propertyName: string)
		local outKey = {}
		outKey.type = "SpecialKey"
		outKey.kind = "Out"
		outKey.stage = "observer"

		function outKey:apply(outState: any, applyTo: Instance, cleanupTasks)
			local ok, event = pcall(applyTo.GetPropertyChangedSignal, applyTo, propertyName)
			if not ok then
				logError("invalidOutProperty", nil, applyTo.ClassName, propertyName)
			elseif xtypeof(outState) ~= "State" or outState.kind ~= "Value" then
				logError("invalidOutType")
			else
				outState:set((applyTo :: any)[propertyName])
				table.insert(
					cleanupTasks,
					event:Connect(function()
						outState:set((applyTo :: any)[propertyName])
					end)
				)
				table.insert(cleanupTasks, function()
					outState:set(nil)
				end)
			end
		end

		return outKey
	end

	return Out
end)()

Fusion.Instances.OnEvent = (function()

--[[
	Constructs special keys for property tables which connect event listeners to
	an instance.
]]

	local logError = (Fusion.Logging.logError)

	local function getProperty_unsafe(instance: Instance, property: string)
		return (instance :: any)[property]
	end

	local function OnEvent(eventName: string)
		local eventKey = {}
		eventKey.type = "SpecialKey"
		eventKey.kind = "OnEvent"
		eventKey.stage = "observer"

		function eventKey:apply(callback: any, applyTo: Instance, cleanupTasks)
			local ok, event = pcall(getProperty_unsafe, applyTo, eventName)
			if not ok or typeof(event) ~= "RBXScriptSignal" then
				logError("cannotConnectEvent", nil, applyTo.ClassName, eventName)
			elseif typeof(callback) ~= "function" then
				logError("invalidEventHandler", nil, eventName)
			else
				table.insert(cleanupTasks, event:Connect(callback))
			end
		end

		return eventKey
	end

	return OnEvent
end)()

Fusion.Instances.OnChange = (function()

--[[
	Constructs special keys for property tables which connect property change
	listeners to an instance.
]]

	local logError = (Fusion.Logging.logError)

	local function OnChange(propertyName: string)
		local changeKey = {}
		changeKey.type = "SpecialKey"
		changeKey.kind = "OnChange"
		changeKey.stage = "observer"

		function changeKey:apply(callback: any, applyTo: Instance, cleanupTasks)
			local ok, event = pcall(applyTo.GetPropertyChangedSignal, applyTo, propertyName)
			if not ok then
				logError("cannotConnectChange", nil, applyTo.ClassName, propertyName)
			elseif typeof(callback) ~= "function" then
				logError("invalidChangeHandler", nil, propertyName)
			else
				table.insert(cleanupTasks, event:Connect(function()
					callback((applyTo :: any)[propertyName])
				end))
			end
		end

		return changeKey
	end

	return OnChange
end)()

Fusion.Instances.New = (function()
--[[
	Constructs and returns a new instance, with options for setting properties,
	event handlers and other attributes on the instance right away.
]]

	local defaultProps = (Fusion.Instances.defaultProps)
	local applyInstanceProps = (Fusion.Instances.applyInstanceProps)
	local logError= (Fusion.Logging.logError)

	local function New(className: string)
		return function(props): Instance
			local ok, instance = pcall(Instance.new, className)

			if not ok then
				logError("cannotCreateClass", nil, className)
			end

			local classDefaults = defaultProps[className]
			if classDefaults ~= nil then
				for defaultProp, defaultValue in pairs(classDefaults) do
					instance[defaultProp] = defaultValue
				end
			end

			applyInstanceProps(props, instance)

			return instance
		end
	end

	return New
end)()

Fusion.Instances.Hydrate = (function()

--[[
	Processes and returns an existing instance, with options for setting
	properties, event handlers and other attributes on the instance.
]]

	local applyInstanceProps = (Fusion.Instances.applyInstanceProps)

	local function Hydrate(target: Instance)
		return function(props): Instance
			applyInstanceProps(props, target)
			return target
		end
	end

	return Hydrate
end)()

Fusion.Instances.Cleanup = (function()

--[[
	A special key for property tables, which adds user-specified tasks to be run
	when the instance is destroyed.
]]

	local Cleanup = {}
	Cleanup.type = "SpecialKey"
	Cleanup.kind = "Cleanup"
	Cleanup.stage = "observer"

	function Cleanup:apply(userTask: any, applyTo: Instance, cleanupTasks)
		table.insert(cleanupTasks, userTask)
	end

	return Cleanup
end)()

Fusion.Instances.Children = (function()

--[[
	A special key for property tables, which parents any given descendants into
	an instance.
]]

	local logWarn = (Fusion.Logging.logWarn)
	local Observer = (Fusion.State.Observer)
	local xtypeof = (Fusion.Utility.xtypeof)

	-- Experimental flag: name children based on the key used in the [Children] table
	local EXPERIMENTAL_AUTO_NAMING = false

	local Children = {}
	Children.type = "SpecialKey"
	Children.kind = "Children"
	Children.stage = "descendants"

	function Children:apply(propValue, applyTo, cleanupTasks)
		local newParented = {}
		local oldParented = {}

		-- save disconnection functions for state object observers
		local newDisconnects = {}
		local oldDisconnects = {}

		local updateQueued = false
		local queueUpdate

		-- Rescans this key's value to find new instances to parent and state objects
		-- to observe for changes; then unparents instances no longer found and
		-- disconnects observers for state objects no longer present.
		local function updateChildren()
			if not updateQueued then
				return -- this update may have been canceled by destruction, etc.
			end
			updateQueued = false

			oldParented, newParented = newParented, oldParented
			oldDisconnects, newDisconnects = newDisconnects, oldDisconnects
			table.clear(newParented)
			table.clear(newDisconnects)

			local function processChild(child: any, autoName: string?)
				local kind = xtypeof(child)

				if kind == "Instance" then
					-- case 1; single instance

					newParented[child] = true
					if oldParented[child] == nil then
						-- wasn't previously present

						-- TODO: check for ancestry conflicts here
						child.Parent = applyTo
					else
						-- previously here; we want to reuse, so remove from old
						-- set so we don't encounter it during unparenting
						oldParented[child] = nil
					end

					if EXPERIMENTAL_AUTO_NAMING and autoName ~= nil then
						child.Name = autoName
					end

				elseif kind == "State" then
					-- case 2; state object

					local value = child:get(false)
					-- allow nil to represent the absence of a child
					if value ~= nil then
						processChild(value, autoName)
					end

					local disconnect = oldDisconnects[child]
					if disconnect == nil then
						-- wasn't previously present
						disconnect = Observer(child):onChange(queueUpdate)
					else
						-- previously here; we want to reuse, so remove from old
						-- set so we don't encounter it during unparenting
						oldDisconnects[child] = nil
					end

					newDisconnects[child] = disconnect

				elseif kind == "table" then
					-- case 3; table of objects

					for key, subChild in pairs(child) do
						local keyType = typeof(key)
						local subAutoName: string? = nil

						if keyType == "string" then
							subAutoName = key
						elseif keyType == "number" and autoName ~= nil then
							subAutoName = autoName .. "_" .. key
						end

						processChild(subChild, subAutoName)
					end

				else
					logWarn("unrecognisedChildType", kind)
				end
			end

			if propValue ~= nil then
				-- `propValue` is set to nil on cleanup, so we don't process children
				-- in that case
				processChild(propValue)
			end

			-- unparent any children that are no longer present
			for oldInstance in pairs(oldParented) do
				oldInstance.Parent = nil
			end

			-- disconnect observers which weren't reused
			for oldState, disconnect in pairs(oldDisconnects) do
				disconnect()
			end
		end

		queueUpdate = function()
			if not updateQueued then
				updateQueued = true
				task.defer(updateChildren)
			end
		end

		table.insert(cleanupTasks, function()
			propValue = nil
			updateQueued = true
			updateChildren()
		end)

		-- perform initial child parenting
		updateQueued = true
		updateChildren()
	end

	return Children
end)()

-- State

Fusion.State.unwrap = function(item, useDependency: boolean?)
	return if Fusion.Utility.xtypeof(item) == "State" then item:get(useDependency) else item
end

Fusion.State.Value = (function()

--[[
	Constructs and returns objects which can be used to model independent
	reactive state.
]]

	local useDependency = (Fusion.Dependencies.useDependency)
	local initDependency = (Fusion.Dependencies.initDependency)
	local updateAll = (Fusion.Dependencies.updateAll)
	local isSimilar = (Fusion.Utility.isSimilar)

	local class = {}

	local CLASS_METATABLE = {__index = class}
	local WEAK_KEYS_METATABLE = {__mode = "k"}

--[[
	Returns the value currently stored in this State object.
	The state object will be registered as a dependency unless `asDependency` is
	false.
]]
	function class:get(asDependency: boolean?): any
		if asDependency ~= false then
			useDependency(self)
		end
		return self._value
	end

--[[
	Updates the value stored in this State object.

	If `force` is enabled, this will skip equality checks and always update the
	state object and any dependents - use this with care as this can lead to
	unnecessary updates.
]]
	function class:set(newValue: any, force: boolean?)
		local oldValue = self._value
		if force or not isSimilar(oldValue, newValue) then
			self._value = newValue
			updateAll(self)
		end
	end

	local function Value<T>(initialValue: T)
		local self = setmetatable({
			type = "State",
			kind = "Value",
			-- if we held strong references to the dependents, then they wouldn't be
			-- able to get garbage collected when they fall out of scope
			dependentSet = setmetatable({}, WEAK_KEYS_METATABLE),
			_value = initialValue
		}, CLASS_METATABLE)

		initDependency(self)

		return self
	end

	return Value
end)()

Fusion.State.Observer = (function()

--[[
	Constructs a new state object which can listen for updates on another state
	object.

	FIXME: enabling strict types here causes free types to leak
]]

	local initDependency = (Fusion.Dependencies.initDependency)

	type Set<T> = {[T]: any}

	local class = {}
	local CLASS_METATABLE = {__index = class}

	-- Table used to hold Observer objects in memory.
	local strongRefs = {}

--[[
	Called when the watched state changes value.
]]
	function class:update(): boolean
		for _, callback in pairs(self._changeListeners) do
			task.spawn(callback)
		end
		return false
	end

--[[
	Adds a change listener. When the watched state changes value, the listener
	will be fired.

	Returns a function which, when called, will disconnect the change listener.
	As long as there is at least one active change listener, this Observer
	will be held in memory, preventing GC, so disconnecting is important.
]]
	function class:onChange(callback: () -> ()): () -> ()
		local uniqueIdentifier = {}

		self._numChangeListeners += 1
		self._changeListeners[uniqueIdentifier] = callback

		-- disallow gc (this is important to make sure changes are received)
		strongRefs[self] = true

		local disconnected = false
		return function()
			if disconnected then
				return
			end
			disconnected = true
			self._changeListeners[uniqueIdentifier] = nil
			self._numChangeListeners -= 1

			if self._numChangeListeners == 0 then
				-- allow gc if all listeners are disconnected
				strongRefs[self] = nil
			end
		end
	end

	local function Observer(watchedState)
		local self = setmetatable({
			type = "State",
			kind = "Observer",
			dependencySet = {[watchedState] = true},
			dependentSet = {},
			_changeListeners = {},
			_numChangeListeners = 0,
		}, CLASS_METATABLE)

		initDependency(self)
		-- add this object to the watched state's dependent set
		watchedState.dependentSet[self] = true

		return self
	end

	return Observer
end)()

Fusion.State.ForValues = (function()

--[[
	Constructs a new ForValues object which maps values of a table using
	a `processor` function.

	Optionally, a `destructor` function can be specified for cleaning up values.
	If omitted, the default cleanup function will be used instead.

	Additionally, a `meta` table/value can optionally be returned to pass data created
	when running the processor to the destructor when the created object is cleaned up.
]]
	local captureDependencies = (Fusion.Dependencies.captureDependencies)
	local initDependency = (Fusion.Dependencies.initDependency)
	local useDependency = (Fusion.Dependencies.useDependency)
	local parseError = (Fusion.Logging.parseError)
	local logErrorNonFatal = (Fusion.Logging.logErrorNonFatal)
	local logWarn = (Fusion.Logging.logWarn)
	local cleanup = (Fusion.Utility.cleanup)
	local needsDestruction = (Fusion.Utility.needsDestruction)

	local class = {}

	local CLASS_METATABLE = { __index = class }
	local WEAK_KEYS_METATABLE = { __mode = "k" }

--[[
	Returns the current value of this ForValues object.
	The object will be registered as a dependency unless `asDependency` is false.
]]
	function class:get(asDependency: boolean?): any
		if asDependency ~= false then
			useDependency(self)
		end
		return self._outputTable
	end

--[[
	Called when the original table is changed.

	This will firstly find any values meeting any of the following criteria:

	- they were not previously present
	- a dependency used during generation of this value has changed

	It will recalculate those values, storing information about any dependencies
	used in the processor callback during value generation, and save the new value
	to the output array with the same key. If it is overwriting an older value,
	that older value will be passed to the destructor for cleanup.

	Finally, this function will find values that are no longer present, and remove
	their values from the output table and pass them to the destructor. You can re-use
	the same value multiple times and this will function will update them as little as
	possible; reusing the same values where possible.
]]
	function class:update(): boolean
		local inputIsState = self._inputIsState
		local inputTable = if inputIsState then self._inputTable:get(false) else self._inputTable
		local outputValues = {}

		local didChange = false

		-- clean out value cache
		self._oldValueCache, self._valueCache = self._valueCache, self._oldValueCache
		local newValueCache = self._valueCache
		local oldValueCache = self._oldValueCache
		table.clear(newValueCache)

		-- clean out main dependency set
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = nil
		end
		self._oldDependencySet, self.dependencySet = self.dependencySet, self._oldDependencySet
		table.clear(self.dependencySet)

		-- if the input table is a state object, add it as a dependency
		if inputIsState then
			self._inputTable.dependentSet[self] = true
			self.dependencySet[self._inputTable] = true
		end


		-- STEP 1: find values that changed or were not previously present
		for inKey, inValue in pairs(inputTable) do
			-- check if the value is new or changed
			local oldCachedValues = oldValueCache[inValue]
			local shouldRecalculate = oldCachedValues == nil

			-- get a cached value and its dependency/meta data if available
			local value, valueData, meta

			if type(oldCachedValues) == "table" and #oldCachedValues > 0 then
				local valueInfo = table.remove(oldCachedValues, #oldCachedValues)
				value = valueInfo.value
				valueData = valueInfo.valueData
				meta = valueInfo.meta

				if #oldCachedValues <= 0 then
					oldValueCache[inValue] = nil
				end
			elseif oldCachedValues ~= nil then
				oldValueCache[inValue] = nil
				shouldRecalculate = true
			end

			if valueData == nil then
				valueData = {
					dependencySet = setmetatable({}, WEAK_KEYS_METATABLE),
					oldDependencySet = setmetatable({}, WEAK_KEYS_METATABLE),
					dependencyValues = setmetatable({}, WEAK_KEYS_METATABLE),
				}
			end

			-- check if the value's dependencies have changed
			if shouldRecalculate == false then
				for dependency, oldValue in pairs(valueData.dependencyValues) do
					if oldValue ~= dependency:get(false) then
						shouldRecalculate = true
						break
					end
				end
			end

			-- recalculate the output value if necessary
			if shouldRecalculate then
				valueData.oldDependencySet, valueData.dependencySet = valueData.dependencySet, valueData.oldDependencySet
				table.clear(valueData.dependencySet)

				local processOK, newOutValue, newMetaValue = captureDependencies(
					valueData.dependencySet,
					self._processor,
					inValue
				)

				if processOK then
					if self._destructor == nil and (needsDestruction(newOutValue) or needsDestruction(newMetaValue)) then
						logWarn("destructorNeededForValues")
					end

					-- pass the old value to the destructor if it exists
					if value ~= nil then
						local destructOK, err = xpcall(self._destructor or cleanup, parseError, value, meta)
						if not destructOK then
							logErrorNonFatal("forValuesDestructorError", err)
						end
					end

					-- store the new value and meta data
					value = newOutValue
					meta = newMetaValue
					didChange = true
				else
					-- restore old dependencies, because the new dependencies may be corrupt
					valueData.oldDependencySet, valueData.dependencySet = valueData.dependencySet, valueData.oldDependencySet

					logErrorNonFatal("forValuesProcessorError", newOutValue)
				end
			end


			-- store the value and its dependency/meta data
			local newCachedValues = newValueCache[inValue]
			if newCachedValues == nil then
				newCachedValues = {}
				newValueCache[inValue] = newCachedValues
			end

			table.insert(newCachedValues, {
				value = value,
				valueData = valueData,
				meta = meta,
			})

			outputValues[inKey] = value


			-- save dependency values and add to main dependency set
			for dependency in pairs(valueData.dependencySet) do
				valueData.dependencyValues[dependency] = dependency:get(false)

				self.dependencySet[dependency] = true
				dependency.dependentSet[self] = true
			end
		end


		-- STEP 2: find values that were removed
		-- for tables of data, we just need to check if it's still in the cache
		for _oldInValue, oldCachedValueInfo in pairs(oldValueCache) do
			for _, valueInfo in ipairs(oldCachedValueInfo) do
				local oldValue = valueInfo.value
				local oldMetaValue = valueInfo.meta

				local destructOK, err = xpcall(self._destructor or cleanup, parseError, oldValue, oldMetaValue)
				if not destructOK then
					logErrorNonFatal("forValuesDestructorError", err)
				end

				didChange = true
			end

			table.clear(oldCachedValueInfo)
		end

		self._outputTable = outputValues

		return didChange
	end

	local function ForValues<VI, VO, M>(
		inputTable,
		processor: (VI) -> (VO, M?),
		destructor: (VO, M?) -> ()?
	)

		local inputIsState = inputTable.type == "State" and typeof(inputTable.get) == "function"

		local self = setmetatable({
			type = "State",
			kind = "ForValues",
			dependencySet = {},
			-- if we held strong references to the dependents, then they wouldn't be
			-- able to get garbage collected when they fall out of scope
			dependentSet = setmetatable({}, WEAK_KEYS_METATABLE),
			_oldDependencySet = {},

			_processor = processor,
			_destructor = destructor,
			_inputIsState = inputIsState,

			_inputTable = inputTable,
			_outputTable = {},
			_valueCache = {},
			_oldValueCache = {},
		}, CLASS_METATABLE)

		initDependency(self)
		self:update()

		return self
	end

	return ForValues
end)()

Fusion.State.ForPairs = (function()

--[[
	Constructs a new ForPairs object which maps pairs of a table using
	a `processor` function.

	Optionally, a `destructor` function can be specified for cleaning up values.
	If omitted, the default cleanup function will be used instead.

	Additionally, a `meta` table/value can optionally be returned to pass data created
	when running the processor to the destructor when the created object is cleaned up.
]]

	local captureDependencies = Fusion.Dependencies.captureDependencies
	local initDependency = Fusion.Dependencies.initDependency
	local useDependency = Fusion.Dependencies.useDependency
	local parseError = Fusion.Logging.parseError
	local logErrorNonFatal = Fusion.Logging.logErrorNonFatal
	local logError = Fusion.Logging.logError
	local logWarn = Fusion.Logging.logWarn
	local cleanup = Fusion.Utility.cleanup
	local needsDestruction = Fusion.Utility.needsDestruction

	local class = {}

	local CLASS_METATABLE = { __index = class }
	local WEAK_KEYS_METATABLE = { __mode = "k" }

--[[
	Returns the current value of this ForPairs object.
	The object will be registered as a dependency unless `asDependency` is false.
]]
	function class:get(asDependency: boolean?): any
		if asDependency ~= false then
			useDependency(self)
		end
		return self._outputTable
	end

--[[
	Called when the original table is changed.

	This will firstly find any keys meeting any of the following criteria:

	- they were not previously present
	- their associated value has changed
	- a dependency used during generation of this value has changed

	It will recalculate those key/value pairs, storing information about any
	dependencies used in the processor callback during value generation, and
	save the new key/value pair to the output array. If it is overwriting an
	older key/value pair, that older pair will be passed to the destructor
	for cleanup.

	Finally, this function will find keys that are no longer present, and remove
	their key/value pairs from the output table and pass them to the destructor.
]]
	function class:update(): boolean
		local inputIsState = self._inputIsState
		local newInputTable = if inputIsState then self._inputTable:get(false) else self._inputTable
		local oldInputTable = self._oldInputTable

		local keyIOMap = self._keyIOMap
		local meta = self._meta

		local didChange = false


		-- clean out main dependency set
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = nil
		end

		self._oldDependencySet, self.dependencySet = self.dependencySet, self._oldDependencySet
		table.clear(self.dependencySet)

		-- if the input table is a state object, add it as a dependency
		if inputIsState then
			self._inputTable.dependentSet[self] = true
			self.dependencySet[self._inputTable] = true
		end

		-- clean out output table
		self._oldOutputTable, self._outputTable = self._outputTable, self._oldOutputTable

		local oldOutputTable = self._oldOutputTable
		local newOutputTable = self._outputTable
		table.clear(newOutputTable)

		-- Step 1: find key/value pairs that changed or were not previously present

		for newInKey, newInValue in pairs(newInputTable) do
			-- get or create key data
			local keyData = self._keyData[newInKey]

			if keyData == nil then
				keyData = {
					dependencySet = setmetatable({}, WEAK_KEYS_METATABLE),
					oldDependencySet = setmetatable({}, WEAK_KEYS_METATABLE),
					dependencyValues = setmetatable({}, WEAK_KEYS_METATABLE),
				}
				self._keyData[newInKey] = keyData
			end


			-- check if the pair is new or changed
			local shouldRecalculate = oldInputTable[newInKey] ~= newInValue

			-- check if the pair's dependencies have changed
			if shouldRecalculate == false then
				for dependency, oldValue in pairs(keyData.dependencyValues) do
					if oldValue ~= dependency:get(false) then
						shouldRecalculate = true
						break
					end
				end
			end


			-- recalculate the output pair if necessary
			if shouldRecalculate then
				keyData.oldDependencySet, keyData.dependencySet = keyData.dependencySet, keyData.oldDependencySet
				table.clear(keyData.dependencySet)

				local processOK, newOutKey, newOutValue, newMetaValue = captureDependencies(
					keyData.dependencySet,
					self._processor,
					newInKey,
					newInValue
				)

				if processOK then
					if self._destructor == nil and (needsDestruction(newOutKey) or needsDestruction(newOutValue) or needsDestruction(newMetaValue)) then
						logWarn("destructorNeededForPairs")
					end

					-- if this key was already written to on this run-through, throw a fatal error.
					if newOutputTable[newOutKey] ~= nil then
						-- figure out which key/value pair previously wrote to this key
						local previousNewKey, previousNewValue
						for inKey, outKey in pairs(keyIOMap) do
							if outKey == newOutKey then
								previousNewValue = newInputTable[inKey]
								if previousNewValue ~= nil then
									previousNewKey = inKey
									break
								end
							end
						end

						if previousNewKey ~= nil then
							logError(
								"forPairsKeyCollision",
								nil,
								tostring(newOutKey),
								tostring(previousNewKey),
								tostring(previousNewValue),
								tostring(newInKey),
								tostring(newInValue)
							)
						end
					end

					local oldOutValue = oldOutputTable[newOutKey]

					if oldOutValue ~= newOutValue then
						local oldMetaValue = meta[newOutKey]
						if oldOutValue ~= nil then
							local destructOK, err = xpcall(self._destructor or cleanup, parseError, newOutKey, oldOutValue, oldMetaValue)
							if not destructOK then
								logErrorNonFatal("forPairsDestructorError", err)
							end
						end

						oldOutputTable[newOutKey] = nil
					end

					-- update the stored data for this key/value pair
					oldInputTable[newInKey] = newInValue
					keyIOMap[newInKey] = newOutKey
					meta[newOutKey] = newMetaValue
					newOutputTable[newOutKey] = newOutValue

					-- if we had to recalculate the output, then we did change
					didChange = true
				else
					-- restore old dependencies, because the new dependencies may be corrupt
					keyData.oldDependencySet, keyData.dependencySet = keyData.dependencySet, keyData.oldDependencySet

					logErrorNonFatal("forPairsProcessorError", newOutKey)
				end
			else
				local storedOutKey = keyIOMap[newInKey]

				-- check for key collision
				if newOutputTable[storedOutKey] ~= nil then
					-- figure out which key/value pair previously wrote to this key
					local previousNewKey, previousNewValue
					for inKey, outKey in pairs(keyIOMap) do
						if storedOutKey == outKey then
							previousNewValue = newInputTable[inKey]

							if previousNewValue ~= nil then
								previousNewKey = inKey
								break
							end
						end
					end

					if previousNewKey ~= nil then
						logError(
							"forPairsKeyCollision",
							nil,
							tostring(storedOutKey),
							tostring(previousNewKey),
							tostring(previousNewValue),
							tostring(newInKey),
							tostring(newInValue)
						)
					end
				end

				-- copy the stored key/value pair into the new output table
				newOutputTable[storedOutKey] = oldOutputTable[storedOutKey]
			end


			-- save dependency values and add to main dependency set
			for dependency in pairs(keyData.dependencySet) do
				keyData.dependencyValues[dependency] = dependency:get(false)

				self.dependencySet[dependency] = true
				dependency.dependentSet[self] = true
			end
		end

		-- STEP 2: find keys that were removed
		for oldOutKey, oldOutValue in pairs(oldOutputTable) do
			-- check if this key/value pair is in the new output table
			if newOutputTable[oldOutKey] ~= oldOutValue then
				-- clean up the old output pair
				local oldMetaValue = meta[oldOutKey]
				if oldOutValue ~= nil then
					local destructOK, err = xpcall(self._destructor or cleanup, parseError, oldOutKey, oldOutValue, oldMetaValue)
					if not destructOK then
						logErrorNonFatal("forPairsDestructorError", err)
					end
				end

				-- check if the key was completely removed from the output table
				if newOutputTable[oldOutKey] == nil then
					meta[oldOutKey] = nil
					self._keyData[oldOutKey] = nil
				end

				didChange = true
			end
		end

		for key in pairs(oldInputTable) do
			if newInputTable[key] == nil then
				oldInputTable[key] = nil
				keyIOMap[key] = nil
			end
		end

		return didChange
	end

	local function ForPairs<KI, VI, KO, VO, M>(
		inputTable,
		processor: (KI, VI) -> (KO, VO, M?),
		destructor: (KO, VO, M?) -> ()?
	)

		local inputIsState = inputTable.type == "State" and typeof(inputTable.get) == "function"

		local self = setmetatable({
			type = "State",
			kind = "ForPairs",
			dependencySet = {},
			-- if we held strong references to the dependents, then they wouldn't be
			-- able to get garbage collected when they fall out of scope
			dependentSet = setmetatable({}, WEAK_KEYS_METATABLE),
			_oldDependencySet = {},

			_processor = processor,
			_destructor = destructor,
			_inputIsState = inputIsState,

			_inputTable = inputTable,
			_oldInputTable = {},
			_outputTable = {},
			_oldOutputTable = {},
			_keyIOMap = {},
			_keyData = {},
			_meta = {},
		}, CLASS_METATABLE)

		initDependency(self)
		self:update()

		return self
	end

	return ForPairs
end)()

Fusion.State.ForKeys = (function()

--[[
	Constructs a new ForKeys state object which maps keys of an array using
	a `processor` function.

	Optionally, a `destructor` function can be specified for cleaning up
	calculated keys. If omitted, the default cleanup function will be used instead.

	Optionally, a `meta` value can be returned in the processor function as the
	second value to pass data from the processor to the destructor.
]]

	local captureDependencies = Fusion.Dependencies.captureDependencies
	local initDependency = Fusion.Dependencies.initDependency
	local useDependency = Fusion.Dependencies.useDependency
	local parseError = Fusion.Logging.parseError
	local logErrorNonFatal = Fusion.Logging.logErrorNonFatal
	local logError = Fusion.Logging.logError
	local logWarn = Fusion.Logging.logWarn
	local cleanup = Fusion.Utility.cleanup
	local needsDestruction = Fusion.Utility.needsDestruction

	local class = {}

	local CLASS_METATABLE = { __index = class }
	local WEAK_KEYS_METATABLE = { __mode = "k" }

--[[
	Returns the current value of this ForKeys object.
	The object will be registered as a dependency unless `asDependency` is false.
]]
	function class:get(asDependency: boolean?): any
		if asDependency ~= false then
			useDependency(self)
		end
		return self._outputTable
	end


--[[
	Called when the original table is changed.

	This will firstly find any keys meeting any of the following criteria:

	- they were not previously present
	- a dependency used during generation of this value has changed

	It will recalculate those key pairs, storing information about any
	dependencies used in the processor callback during output key generation,
	and save the new key to the output array with the same value. If it is
	overwriting an older value, that older value will be passed to the
	destructor for cleanup.

	Finally, this function will find keys that are no longer present, and remove
	their output keys from the output table and pass them to the destructor.
]]

	function class:update(): boolean
		local inputIsState = self._inputIsState
		local newInputTable = if inputIsState then self._inputTable:get(false) else self._inputTable
		local oldInputTable = self._oldInputTable
		local outputTable = self._outputTable

		local keyOIMap = self._keyOIMap
		local keyIOMap = self._keyIOMap
		local meta = self._meta

		local didChange = false


		-- clean out main dependency set
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = nil
		end

		self._oldDependencySet, self.dependencySet = self.dependencySet, self._oldDependencySet
		table.clear(self.dependencySet)

		-- if the input table is a state object, add it as a dependency
		if inputIsState then
			self._inputTable.dependentSet[self] = true
			self.dependencySet[self._inputTable] = true
		end


		-- STEP 1: find keys that changed or were not previously present
		for newInKey, value in pairs(newInputTable) do
			-- get or create key data
			local keyData = self._keyData[newInKey]

			if keyData == nil then
				keyData = {
					dependencySet = setmetatable({}, WEAK_KEYS_METATABLE),
					oldDependencySet = setmetatable({}, WEAK_KEYS_METATABLE),
					dependencyValues = setmetatable({}, WEAK_KEYS_METATABLE),
				}
				self._keyData[newInKey] = keyData
			end

			-- check if the key is new
			local shouldRecalculate = oldInputTable[newInKey] == nil

			-- check if the key's dependencies have changed
			if shouldRecalculate == false then
				for dependency, oldValue in pairs(keyData.dependencyValues) do
					if oldValue ~= dependency:get(false) then
						shouldRecalculate = true
						break
					end
				end
			end


			-- recalculate the output key if necessary
			if shouldRecalculate then
				keyData.oldDependencySet, keyData.dependencySet = keyData.dependencySet, keyData.oldDependencySet
				table.clear(keyData.dependencySet)

				local processOK, newOutKey, newMetaValue = captureDependencies(
					keyData.dependencySet,
					self._processor,
					newInKey
				)

				if processOK then
					if self._destructor == nil and (needsDestruction(newOutKey) or needsDestruction(newMetaValue)) then
						logWarn("destructorNeededForKeys")
					end

					local oldInKey = keyOIMap[newOutKey]
					local oldOutKey = keyIOMap[newInKey]

					-- check for key collision
					if oldInKey ~= newInKey and newInputTable[oldInKey] ~= nil then
						logError("forKeysKeyCollision", nil, tostring(newOutKey), tostring(oldInKey), tostring(newOutKey))
					end

					-- check for a changed output key
					if oldOutKey ~= newOutKey and keyOIMap[oldOutKey] == newInKey then
						-- clean up the old calculated value
						local oldMetaValue = meta[oldOutKey]

						local destructOK, err = xpcall(self._destructor or cleanup, parseError, oldOutKey, oldMetaValue)
						if not destructOK then
							logErrorNonFatal("forKeysDestructorError", err)
						end

						keyOIMap[oldOutKey] = nil
						outputTable[oldOutKey] = nil
						meta[oldOutKey] = nil
					end

					-- update the stored data for this key
					oldInputTable[newInKey] = value
					meta[newOutKey] = newMetaValue
					keyOIMap[newOutKey] = newInKey
					keyIOMap[newInKey] = newOutKey
					outputTable[newOutKey] = value

					-- if we had to recalculate the output, then we did change
					didChange = true
				else
					-- restore old dependencies, because the new dependencies may be corrupt
					keyData.oldDependencySet, keyData.dependencySet = keyData.dependencySet, keyData.oldDependencySet

					logErrorNonFatal("forKeysProcessorError", newOutKey)
				end
			end


			-- save dependency values and add to main dependency set
			for dependency in pairs(keyData.dependencySet) do
				keyData.dependencyValues[dependency] = dependency:get(false)

				self.dependencySet[dependency] = true
				dependency.dependentSet[self] = true
			end
		end


		-- STEP 2: find keys that were removed
		for outputKey, inputKey in pairs(keyOIMap) do
			if newInputTable[inputKey] == nil then
				-- clean up the old calculated value
				local oldMetaValue = meta[outputKey]

				local destructOK, err = xpcall(self._destructor or cleanup, parseError, outputKey, oldMetaValue)
				if not destructOK then
					logErrorNonFatal("forKeysDestructorError", err)
				end

				-- remove data
				oldInputTable[inputKey] = nil
				meta[outputKey] = nil
				keyOIMap[outputKey] = nil
				keyIOMap[inputKey] = nil
				outputTable[outputKey] = nil
				self._keyData[inputKey] = nil

				-- if we removed a key, then the table/state changed
				didChange = true
			end
		end

		return didChange
	end

	local function ForKeys<KI, KO, M>(
		inputTable,
		processor: (KI) -> (KO, M?),
		destructor: (KO, M?) -> ()?
	)

		local inputIsState = inputTable.type == "State" and typeof(inputTable.get) == "function"

		local self = setmetatable({
			type = "State",
			kind = "ForKeys",
			dependencySet = {},
			-- if we held strong references to the dependents, then they wouldn't be
			-- able to get garbage collected when they fall out of scope
			dependentSet = setmetatable({}, WEAK_KEYS_METATABLE),
			_oldDependencySet = {},

			_processor = processor,
			_destructor = destructor,
			_inputIsState = inputIsState,

			_inputTable = inputTable,
			_oldInputTable = {},
			_outputTable = {},
			_keyOIMap = {},
			_keyIOMap = {},
			_keyData = {},
			_meta = {},
		}, CLASS_METATABLE)

		initDependency(self)
		self:update()

		return self
	end

	return ForKeys
end)()

Fusion.State.Computed = (function()

--[[
	Constructs and returns objects which can be used to model derived reactive
	state.
]]

	local captureDependencies = Fusion.Dependencies.captureDependencies
	local initDependency = Fusion.Dependencies.initDependency
	local useDependency = Fusion.Dependencies.useDependency
	local logErrorNonFatal = Fusion.Logging.logErrorNonFatal
	local logWarn = Fusion.Logging.logWarn
	local isSimilar = Fusion.Utility.isSimilar
	local needsDestruction = Fusion.Utility.needsDestruction

	local class = {}

	local CLASS_METATABLE = {__index = class}
	local WEAK_KEYS_METATABLE = {__mode = "k"}

--[[
	Returns the last cached value calculated by this Computed object.
	The computed object will be registered as a dependency unless `asDependency`
	is false.
]]
	function class:get(asDependency: boolean?): any
		if asDependency ~= false then
			useDependency(self)
		end
		return self._value
	end

--[[
	Recalculates this Computed's cached value and dependencies.
	Returns true if it changed, or false if it's identical.
]]
	function class:update(): boolean
		-- remove this object from its dependencies' dependent sets
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = nil
		end

		-- we need to create a new, empty dependency set to capture dependencies
		-- into, but in case there's an error, we want to restore our old set of
		-- dependencies. by using this table-swapping solution, we can avoid the
		-- overhead of allocating new tables each update.
		self._oldDependencySet, self.dependencySet = self.dependencySet, self._oldDependencySet
		table.clear(self.dependencySet)

		local ok, newValue, newMetaValue = captureDependencies(self.dependencySet, self._processor)

		if ok then
			if self._destructor == nil and needsDestruction(newValue) then
				logWarn("destructorNeededComputed")
			end

			if newMetaValue ~= nil then
				logWarn("multiReturnComputed")
			end

			local oldValue = self._value
			local similar = isSimilar(oldValue, newValue)
			if self._destructor ~= nil then
				self._destructor(oldValue)
			end
			self._value = newValue

			-- add this object to the dependencies' dependent sets
			for dependency in pairs(self.dependencySet) do
				dependency.dependentSet[self] = true
			end

			return not similar
		else
			-- this needs to be non-fatal, because otherwise it'd disrupt the
			-- update process
			logErrorNonFatal("computedCallbackError", newValue)

			-- restore old dependencies, because the new dependencies may be corrupt
			self._oldDependencySet, self.dependencySet = self.dependencySet, self._oldDependencySet

			-- restore this object in the dependencies' dependent sets
			for dependency in pairs(self.dependencySet) do
				dependency.dependentSet[self] = true
			end

			return false
		end
	end

	local function Computed<T>(processor: () -> T, destructor: ((T) -> ())?)
		local self = setmetatable({
			type = "State",
			kind = "Computed",
			dependencySet = {},
			-- if we held strong references to the dependents, then they wouldn't be
			-- able to get garbage collected when they fall out of scope
			dependentSet = setmetatable({}, WEAK_KEYS_METATABLE),
			_oldDependencySet = {},
			_processor = processor,
			_destructor = destructor,
			_value = nil,
		}, CLASS_METATABLE)

		initDependency(self)
		self:update()

		return self
	end

	return Computed
end)()


return Fusion.Utility.restrictRead("Fusion", {
	version = {major = 0, minor = 2, isRelease = true},

	New = Fusion.Instances.New,
	Hydrate = Fusion.Instances.Hydrate,
	Ref = Fusion.Instances.Ref,
	Out = Fusion.Instances.Out,
	Cleanup = Fusion.Instances.Cleanup,
	Children = Fusion.Instances.Children,
	OnEvent = Fusion.Instances.OnEvent,
	OnChange = Fusion.Instances.OnChange,

	Value = Fusion.State.Value,
	Computed = Fusion.State.Computed,
	ForPairs = Fusion.State.ForPairs,
	ForKeys = Fusion.State.ForKeys,
	ForValues = Fusion.State.ForValues,
	Observer = Fusion.State.Observer,

	Tween = Fusion.Animation.Tween,
	Spring = Fusion.Animation.Spring,

	cleanup = Fusion.Utility.cleanup,
	doNothing = Fusion.Utility.doNothing
}) 
