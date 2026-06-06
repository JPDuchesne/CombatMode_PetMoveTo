# frozen_string_literal: true

require "digest"
require "json"
require "net/http"
require "tempfile"
require "dev/deps"

# CurseForge API repository — resolves WoW addon version constraints.
#
# Requires CF_API_KEY environment variable (https://console.curseforge.com).
# Queries the CurseForge v1 API for mod files, selects best version match,
# downloads to compute SHA256, and caches the artifact.
class CurseForgeRepository < Dev::Deps::Repository
  class ApiKeyMissingError < StandardError; end
  class ModNotFoundError < StandardError; end
  class NoFilesError < StandardError; end
  class ApiError < StandardError; end

  CURSEFORGE_API = "https://api.curseforge.com"
  WOW_GAME_ID = 1

  # Fetch a CurseForge mod by identifier.
  #
  # @param id [Hash] identifier with "name", "integration", "group", "constraint"
  # @return [Dev::Deps::Dependency]
  # @raise [ApiKeyMissingError] if CF_API_KEY is not set
  # @raise [ModNotFoundError] if the mod cannot be found
  # @raise [NoFilesError] if no files match the constraint
  # @raise [ApiError] if the CurseForge API returns an error
  def fetch(id)
    api_key = ENV.fetch("CF_API_KEY") do
      raise ApiKeyMissingError, "CF_API_KEY required — get one at https://console.curseforge.com"
    end

    name = id["name"]
    constraint = id["constraint"] || {}
    mod = search_mod(name, api_key)
    file = find_best_file(mod, constraint, api_key)
    download_url = file["downloadUrl"] || build_download_url(file)
    version = file["displayName"]

    hash = download_and_hash(download_url, api_key)

    Dev::Deps::Dependency.new(
      name: name,
      integration: id["integration"].to_sym,
      group: (id["group"] || :app).to_sym,
      version: version,
      hash: hash,
      metadata: { "url" => download_url, "mod_id" => mod["id"], "file_id" => file["id"] },
    )
  end

  private

  # @param name [String] mod name to search for
  # @param api_key [String]
  # @return [Hash] mod data from CurseForge API
  # @raise [ModNotFoundError]
  def search_mod(name, api_key)
    uri = URI("#{CURSEFORGE_API}/v1/mods/search")
    uri.query = URI.encode_www_form(gameId: WOW_GAME_ID, searchFilter: name, pageSize: 5)
    response = api_get(uri, api_key)
    results = JSON.parse(response.body)["data"]

    results.find { |m| m["name"].casecmp?(name) } ||
      results.first ||
      raise(ModNotFoundError, "CurseForge: mod '#{name}' not found")
  end

  # @param mod [Hash] mod data
  # @param constraint [Hash] with optional :game_version
  # @param api_key [String]
  # @return [Hash] file data
  # @raise [NoFilesError]
  def find_best_file(mod, constraint, api_key)
    game_version = constraint[:game_version] || constraint["game_version"]

    uri = URI("#{CURSEFORGE_API}/v1/mods/#{mod["id"]}/files")
    params = { pageSize: 20 }
    params[:gameVersion] = game_version if game_version
    uri.query = URI.encode_www_form(params)

    response = api_get(uri, api_key)
    files = JSON.parse(response.body)["data"]

    raise NoFilesError, "CurseForge: no files for '#{mod["name"]}'" if files.empty?

    files.sort_by { |f| f["fileDate"] }.last
  end

  def build_download_url(file)
    id = file["id"]
    "https://edge.forgecdn.net/files/#{id / 1000}/#{id % 1000}/#{file["fileName"]}"
  end

  # @param url [String] download URL
  # @param api_key [String]
  # @return [String] integrity hash ("SHA256=...")
  def download_and_hash(url, api_key)
    tmpfile = Tempfile.new("curseforge")
    begin
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        request = Net::HTTP::Get.new(uri)
        request["x-api-key"] = api_key
        http.request(request) do |response|
          response.read_body { |chunk| tmpfile.write(chunk) }
        end
      end
      tmpfile.close

      sha256 = Digest::SHA256.file(tmpfile.path).hexdigest
      "SHA256=#{sha256}"
    ensure
      tmpfile.close!
    end
  end

  # @param uri [URI] API endpoint
  # @param api_key [String]
  # @return [Net::HTTPResponse]
  # @raise [ApiError]
  def api_get(uri, api_key)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      request = Net::HTTP::Get.new(uri)
      request["x-api-key"] = api_key
      request["Accept"] = "application/json"
      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise ApiError, "CurseForge API error: #{response.code} #{response.message} for #{uri}"
      end

      response
    end
  end
end
