# frozen_string_literal: true

require "json"
require "net/http"
require "digest"
require "fileutils"
require "dev/deps"

# CurseForge API repository — resolves WoW addon version constraints.
#
# Requires CF_API_KEY environment variable (https://console.curseforge.com).
# Queries the CurseForge v1 API for mod files, selects best version match,
# downloads to compute SHA256, and caches the artifact.
class CurseForgeRepository < Dev::Deps::Repository
  CURSEFORGE_API = "https://api.curseforge.com"
  WOW_GAME_ID = 1

  def resolve(name, constraint, cache:)
    api_key = ENV.fetch("CF_API_KEY") do
      raise "CF_API_KEY required — get one at https://console.curseforge.com"
    end

    mod = search_mod(name, api_key)
    file = find_best_file(mod, constraint, api_key)
    download_url = file["downloadUrl"] || build_download_url(file)
    version = file["displayName"]

    hash = download_and_hash(download_url, api_key, cache)

    Dev::Deps::Pin.new(
      name: name,
      integration: "wow_curseforge",
      group: constraint.fetch(:group, :app),
      version: version,
      hash: hash,
      metadata: { url: download_url, mod_id: mod["id"], file_id: file["id"] },
    )
  end

  def dependencies(pin)
    api_key = ENV.fetch("CF_API_KEY", nil)
    return [] unless api_key

    mod_id = pin.metadata[:mod_id] || pin.metadata["mod_id"]
    file_id = pin.metadata[:file_id] || pin.metadata["file_id"]
    return [] unless mod_id && file_id

    uri = URI("#{CURSEFORGE_API}/v1/mods/#{mod_id}/files/#{file_id}")
    response = api_get(uri, api_key)
    data = JSON.parse(response.body)["data"]
    return [] unless data

    (data["dependencies"] || [])
      .select { |d| d["relationType"] == 3 } # required dependency
      .map { |d| { name: d["modId"].to_s, constraint: {} } }
  end

  private

  def search_mod(name, api_key)
    uri = URI("#{CURSEFORGE_API}/v1/mods/search")
    uri.query = URI.encode_www_form(gameId: WOW_GAME_ID, searchFilter: name, pageSize: 5)
    response = api_get(uri, api_key)
    results = JSON.parse(response.body)["data"]

    results.find { |m| m["name"].casecmp?(name) } ||
      results.first ||
      raise("CurseForge: mod '#{name}' not found")
  end

  def find_best_file(mod, constraint, api_key)
    game_version = constraint[:game_version]

    uri = URI("#{CURSEFORGE_API}/v1/mods/#{mod["id"]}/files")
    params = { pageSize: 20 }
    params[:gameVersion] = game_version if game_version
    uri.query = URI.encode_www_form(params)

    response = api_get(uri, api_key)
    files = JSON.parse(response.body)["data"]

    raise "CurseForge: no files for '#{mod["name"]}'" if files.empty?

    # Latest file first (sorted by fileDate descending)
    files.sort_by { |f| f["fileDate"] }.last
  end

  def build_download_url(file)
    id = file["id"]
    "https://edge.forgecdn.net/files/#{id / 1000}/#{id % 1000}/#{file["fileName"]}"
  end

  def download_and_hash(url, api_key, cache)
    require "tempfile"

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
      hash = "SHA256=#{sha256}"
      cache.store(hash, tmpfile.path)
      hash
    ensure
      tmpfile.close!
    end
  end

  def api_get(uri, api_key)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      request = Net::HTTP::Get.new(uri)
      request["x-api-key"] = api_key
      request["Accept"] = "application/json"
      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise "CurseForge API error: #{response.code} #{response.message} for #{uri}"
      end

      response
    end
  end
end

# WoW addon integration — installs CurseForge addon deps into deps/addons/.
#
# Each pin's zip is extracted to deps/addons/<name>/, available for test
# helpers to load alongside the addon under test.
class WoWCurseforgeIntegration < Dev::Deps::Integration
  DEPS_DIR = "deps/addons"

  def install_all(pins, root:)
    deps_dir = File.join(root, DEPS_DIR)
    FileUtils.mkdir_p(deps_dir)

    pins.each do |pin|
      install_pin(pin, deps_dir)
    end
  end

  private

  def install_pin(pin, deps_dir)
    target = File.join(deps_dir, pin.name)
    return if File.directory?(target)

    cached_path = cache.fetch(pin.hash)
    unless cached_path
      raise "Cache miss for #{pin.name} (#{pin.hash}) — run `dev update-deps` first"
    end

    require "tmpdir"
    Dir.mktmpdir do |tmpdir|
      system("unzip", "-q", "-o", cached_path, "-d", tmpdir, exception: true)
      extracted = Dir.children(tmpdir)

      # Zips may contain a single top-level directory or files directly
      source = if extracted.length == 1 && File.directory?(File.join(tmpdir, extracted.first))
        File.join(tmpdir, extracted.first)
      else
        tmpdir
      end

      FileUtils.mv(source, target)
    end
  end
end
