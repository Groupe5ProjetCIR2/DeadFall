local RobloxMaxImageSize = 1024

local function AnimateGif(ImageLabel:ImageLabel,ImageWidth,ImageHeight,Rows,Columns,NumberOfFrames,ImageId,FPS)
	if ImageId then
		ImageLabel.Image = "http://www.roblox.com/asset/?id=" .. ImageId
	end

	local RealWidth, RealHeight
	if math.max(ImageWidth,ImageHeight) > RobloxMaxImageSize then
		-- Compensate roblox size
		local Longest = ImageWidth > ImageHeight and "Width" or "Height"
		if Longest == "Width" then
			RealWidth = RobloxMaxImageSize
			RealHeight = (RealWidth / ImageWidth) * ImageHeight
		elseif Longest == "Height" then
			RealHeight = RobloxMaxImageSize
			RealWidth = (RealHeight / ImageHeight) * ImageWidth
		end
	else
		RealWidth,RealHeight = ImageWidth,ImageHeight
	end

	local FrameSize = Vector2.new(RealWidth/Columns,RealHeight/Rows)

	-- Redimensionner par 8
	local ScaleFactor = 2
	ImageLabel.Size = UDim2.new(0, FrameSize.X * ScaleFactor, 0, FrameSize.Y * ScaleFactor)

	-- Centrer sur l'écran
	ImageLabel.Position = UDim2.new(0.5, - (FrameSize.X * ScaleFactor)/2, 0.5, - (FrameSize.Y * ScaleFactor)/2)
	ImageLabel.AnchorPoint = Vector2.new(0, 0) -- S'assurer que l'AnchorPoint est en haut à gauche

	ImageLabel.ImageRectSize = FrameSize

	local CurrentRow, CurrentColumn = 0,0
	local Offsets = {}

	for i = 1,NumberOfFrames do
		local CurrentX = CurrentColumn * FrameSize.X
		local CurrentY = CurrentRow * FrameSize.Y
		table.insert(Offsets,Vector2.new(CurrentX,CurrentY))

		CurrentColumn += 1
		if CurrentColumn >= Columns then
			CurrentColumn = 0
			CurrentRow += 1
		end
	end

	local TimeInterval = FPS and 1/FPS or 0.1
	local Index = 0

	task.spawn(function()
		while task.wait(TimeInterval) and ImageLabel:IsDescendantOf(game) do
			Index += 1
			ImageLabel.ImageRectOffset = Offsets[Index]
			if Index >= NumberOfFrames then
				Index = 0
			end
		end
	end)
end

-- Paramètres pour 60 images :
AnimateGif(script.Parent, 1000, 2400, 12, 5, 60, 115707950257642, 60)