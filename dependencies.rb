require "dev/deps"
require_relative "lib/wow_curseforge_integration"

Dev::Deps.define do
  lua_version "5.1"

  register_integration :wow_curseforge, WoWCurseforgeIntegration
  register_method :wow_curseforge

  group :app do
    wow_curseforge "CombatMode", version: ">=1.0", game_version: "12.0.5"
  end

  group :test do
    luarocks "luaunit", ">=3.5"
  end
end
