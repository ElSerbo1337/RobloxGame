-- Client entry point (StarterPlayerScripts.Client)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local AdminPanel = require(script.AdminPanel)
local Barriers = require(script.Barriers)
local BonusPills = require(script.BonusPills)
local WeatherFx = require(script.WeatherFx)
local DeliveryMenu = require(script.DeliveryMenu)
local EggAnimation = require(script.EggAnimation)
local EggPreview = require(script.EggPreview)
local GiftMenu = require(script.GiftMenu)
local GoldenGlitter = require(script.GoldenGlitter)
local GraphicsQuality = require(script.GraphicsQuality)
local Hud = require(script.Hud)
local IndexMenu = require(script.IndexMenu)
local ProfileMenu = require(script.ProfileMenu)
local TitleTags = require(script.TitleTags)
local Juice = require(script.Juice)
local Lang = require(script.Lang)
local LoginCalendarMenu = require(script.LoginCalendarMenu)
local PetFollow = require(script.PetFollow)
local PetMenu = require(script.PetMenu)
local PortalMenu = require(script.PortalMenu)
local PotionMenu = require(script.PotionMenu)
local QuestMenu = require(script.QuestMenu)
local RebirthMenu = require(script.RebirthMenu)
local SecretBanner = require(script.SecretBanner)
local SellAnimation = require(script.SellAnimation)
local SettingsMenu = require(script.SettingsMenu)
local SignCulling = require(script.SignCulling)
local SignTexts = require(script.SignTexts)
local ShopMenu = require(script.ShopMenu)
local Sounds = require(script.Sounds)
local ToppingInput = require(script.ToppingInput)
local Tutorial = require(script.Tutorial)
local WheelMenu = require(script.WheelMenu)
local MerchantMenu = require(script.MerchantMenu)
local WhatsNewMenu = require(script.WhatsNewMenu)
local WorldAmbience = require(script.WorldAmbience)
local WorldIntro = require(script.WorldIntro)

task.spawn(Lang.stopAutoTranslate)
SignTexts.start()
local coinsCounter = Hud.start()
Sounds.start()
task.spawn(WorldAmbience.start)
SellAnimation.start(coinsCounter)
-- Juice (#110): sale numbers, portal swirls, delivery van drive.
Juice.start()
ToppingInput.start()
Barriers.start()
ShopMenu.start()
PetMenu.start()
PotionMenu.start()
RebirthMenu.start()
GiftMenu.start()
LoginCalendarMenu.start()
-- Lucky wheel (#98): side bar tile, menu and the spin animation of the 3D wheel.
WheelMenu.start()
-- Travelling merchant (#107): announcement banner and the trade menu at the stand.
MerchantMenu.start()
-- Daily and weekly quests (#97): side bar tile with a red dot when a quest is done.
QuestMenu.start()
-- Pet index and topping index (#95): side bar tile, one menu with two tabs.
IndexMenu.start()
-- Profile (#103): side bar tile, stats/badges/titles; tap another player for theirs.
ProfileMenu.start()
-- Titles over the head with the rebirth level (#103).
task.spawn(TitleTags.start)
-- "What's new" window (#106): once per player, after the tutorial and the calendar.
WhatsNewMenu.start()
DeliveryMenu.start()
-- Active bonuses top right (#102: friends on the server).
BonusPills.start()
-- Weather and night (#105): particles, weather pill, lightning, lanterns, fireflies.
task.spawn(WeatherFx.start)
-- Settings menu (#76): side bar tile; graphics Low = fewer particles, hidden decoration.
SettingsMenu.start()
task.spawn(GraphicsQuality.start)
PortalMenu.start()
EggAnimation.start()
task.spawn(EggPreview.start)
task.spawn(PetFollow.start)
task.spawn(SignCulling.start)
task.spawn(Tutorial.start)
-- Camera flight on the first visit of a world (#79).
task.spawn(WorldIntro.start)
-- Golden toppings (#94): glitter on toppings that are golden for this player.
if Features.new(GameConfig.features).enabled("goldenToppings") then
	GoldenGlitter.start()
end
-- Secret pets (#81): banner when anyone on any server hatches one.
if Features.new(GameConfig.features).enabled("secretAnnouncement") then
	task.spawn(SecretBanner.start)
end
-- Admin panel (#74): builds nothing unless this is an admin (GameConfig.admin.userIds).
task.spawn(AdminPanel.start)

print(`[{Constants.GAME_NAME}] Client gestartet`)
