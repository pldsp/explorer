local Input = game:GetService("UserInputService")
local Drag = {}

function Drag.Attach(frame, title, grip, janitor, bounds, enabled)
	local mode, origin, original, touch
	local function begin(input, kind)
		if enabled and not enabled() then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		mode, origin = kind, input.Position
		original = kind == "move" and frame.Position or frame.Size
		touch = input.UserInputType == Enum.UserInputType.Touch and input or nil
	end
	janitor:Add(title.InputBegan:Connect(function(input) begin(input, "move") end))
	janitor:Add(grip.InputBegan:Connect(function(input) begin(input, "resize") end))
	janitor:Add(Input.InputEnded:Connect(function(input)
		if input == touch or input.UserInputType == Enum.UserInputType.MouseButton1 then mode = nil end
	end))
	janitor:Add(Input.InputChanged:Connect(function(input)
		if not mode then return end
		if touch then if input ~= touch then return end
		elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local delta, available = input.Position - origin, bounds.AbsoluteSize
		if mode == "resize" then
			frame.Size = UDim2.fromOffset(math.clamp(original.X.Offset + delta.X, math.min(300, available.X), available.X), math.clamp(original.Y.Offset + delta.Y, math.min(180, available.Y), available.Y))
		else
			local width, height = frame.AbsoluteSize.X, frame.AbsoluteSize.Y
			local x = available.X * original.X.Scale + original.X.Offset + delta.X
			local y = available.Y * original.Y.Scale + original.Y.Offset + delta.Y
			frame.Position = UDim2.fromOffset(math.clamp(x, 0, math.max(0, available.X - width)), math.clamp(y, 0, math.max(0, available.Y - height)))
		end
	end))
end

return Drag
