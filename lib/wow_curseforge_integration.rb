# frozen_string_literal: true

require "fileutils"
require "pathname"
require "tmpdir"
require "dev/deps"

# WoW addon integration — installs CurseForge addon deps into deps/addons/.
#
# Each dependency's zip is extracted to deps/addons/<name>/, available for
# test helpers to load alongside the addon under test.
class WoWCurseforgeIntegration < Dev::Deps::Integration
  class CacheMissError < StandardError; end
  class ExtractError < StandardError; end

  DEPS_DIR = "deps/addons"

  # @param repository    [Repository] source adapter for CurseForge deps
  # @param cache         [Cache]      shared download cache
  # @param project_root  [Pathname]   project root directory
  def initialize(repository:, cache:, project_root:)
    super(repository:, cache:)
    @project_root = Pathname(project_root)
  end

  # Install all CurseForge addon dependencies.
  #
  # @param dependencies [Array<Dependency>] addon deps to install
  def install_all(dependencies)
    deps_dir = @project_root / DEPS_DIR
    FileUtils.mkdir_p(deps_dir.to_s)

    dependencies.each do |dep|
      install_dep(dep, deps_dir)
    end
  end

  private

  # @param dep [Dependency]
  # @param deps_dir [Pathname]
  # @raise [CacheMissError] if the artifact isn't cached
  # @raise [ExtractError] if unzip fails
  def install_dep(dep, deps_dir)
    target = deps_dir / dep.name
    return if target.directory?

    cached_path = cache.fetch(dep.hash)
    unless cached_path
      raise CacheMissError, "Cache miss for #{dep.name} (#{dep.hash}) — run `dev update-deps` first"
    end

    Dir.mktmpdir do |tmpdir|
      unless Kernel.system("unzip", "-q", "-o", cached_path, "-d", tmpdir)
        raise ExtractError, "Failed to extract #{dep.name} from #{cached_path}"
      end

      extracted = Dir.children(tmpdir)

      source = if extracted.length == 1 && File.directory?(File.join(tmpdir, extracted.first))
        File.join(tmpdir, extracted.first)
      else
        tmpdir
      end

      FileUtils.mv(source, target.to_s)
    end
  end
end
