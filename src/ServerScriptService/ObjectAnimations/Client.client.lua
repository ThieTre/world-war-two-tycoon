local character = script.Parent
local humanoid = character:FindFirstChild("Humanoid")
local animation = Instance.new("Animation")

animation.AnimationId = character:GetAttribute("AnimationId")

local animationTrack = humanoid:LoadAnimation(animation)
animationTrack.Looped = true

animationTrack:Play()
