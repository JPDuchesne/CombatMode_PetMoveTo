require "dev/deps"
require_relative "lib/wow_curseforge_integration"
require_relative "lib/curseforge_repository"

Dev::Deps.define do
  lua_version "5.1"

  register :wow_curseforge, WoWCurseforgeIntegration

  group :app do
    wow_curseforge "CombatMode", version: ">=1.0", game_version: "12.0.5"
  end

  group :test do
    luarocks "luaunit", ">=3.5"
  end
end
