local PhysicsService = game:GetService("PhysicsService")

PhysicsService:RegisterCollisionGroup("BaseOre")
PhysicsService:RegisterCollisionGroup("Player")
PhysicsService:CollisionGroupSetCollidable("BaseOre", "BaseOre", false)
PhysicsService:CollisionGroupSetCollidable("BaseOre", "Player", false)

for _, ore: BasePart in
	game.ReplicatedStorage.Assets.Tycoons.DropTemplates:GetChildren()
do
	ore.CollisionGroup = "BaseOre"
end
