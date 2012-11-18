require 'rdoc/ri'

##
# The directories where ri data lives.  Paths can be enumerated via ::each, or
# queried individually via ::system_dir, ::site_dir, ::home_dir and ::gem_dir.

module RDoc::RI::Paths

  #:stopdoc:
  require 'rbconfig'

  version = RbConfig::CONFIG['ruby_version']

  BASE    = if RbConfig::CONFIG.key? 'ridir' then
              File.join RbConfig::CONFIG['ridir'], version
            else
              File.join RbConfig::CONFIG['datadir'], 'ri', version
            end

  homedir = begin
              File.expand_path('~')
            rescue ArgumentError
            end

  homedir ||= ENV['HOME'] ||
              ENV['USERPROFILE'] || ENV['HOMEPATH'] # for 1.8 compatibility

  HOMEDIR = if homedir then
              File.join homedir, ".rdoc"
            end
  #:startdoc:

  ##
  # Iterates over each selected path yielding the directory and type.
  #
  # Yielded types:
  # :system:: Where Ruby's ri data is stored.  Yielded when +system+ is
  #           true
  # :site:: Where ri for installed libraries are stored.  Yielded when
  #         +site+ is true.  Normally no ri data is stored here.
  # :home:: ~/.rdoc.  Yielded when +home+ is true.
  # :gem:: ri data for an installed gem.  Yielded when +gems+ is true.
  # :extra:: ri data directory from the command line.  Yielded for each
  #          entry in +extra_dirs+

  def self.each system = true, site = true, home = true, gems = :latest, *extra_dirs # :yields: directory, type
    return enum_for __method__, system, site, home, gems, *extra_dirs unless
      block_given?

    extra_dirs.each do |dir|
      yield dir, :extra
    end

    yield system_dir,  :system if system
    yield site_dir,    :site   if site
    yield home_dir,    :home   if home and HOMEDIR

    gemdirs(gems).each do |dir|
      yield dir, :gem
    end if gems

    nil
  end

  ##
  # The ri directory for the gem with +gem_name+.

  def self.gem_dir name, version
    req = Gem::Requirement.new "= #{version}"

    spec = Gem::Specification.find_by_name name, req

    File.join spec.doc_dir, 'ri'
  end

  ##
  # The latest installed gems' ri directories.  +filter+ can be :all or
  # :latest.

  def self.gemdirs filter = :latest, gem_path = Gem.path
    require 'rubygems' unless defined?(Gem)

    all_paths = gem_path.map do |dir|
      Dir[File.join(dir, 'doc', '*', 'ri')]
    end.flatten

    ri_paths = {}

    all = all_paths.map do |dir|
      base = File.basename File.dirname dir

      next unless base =~ /(.*)-((\d+\.)*\d+)/

      [dir, $1, Gem::Version.new($2)]
    end.compact

    if filter == :all then
      gemdirs = []

      all.group_by do |_, name, _|
        name
      end.sort_by do |group, _|
        group
      end.map do |group, items|
        items.sort_by do |_, _, version|
          version
        end.reverse_each do |dir,|
          gemdirs << dir
        end
      end

      return gemdirs
    end

    all.each do |dir, name, ver|
      if ri_paths[name].nil? or ver > ri_paths[name].first then
        ri_paths[name] = [ver, name, dir]
      end
    end

    ri_paths.sort_by { |_, (_, name, _)| name }.map { |k, v| v.last }
  rescue LoadError
    []
  end

  ##
  # The location of the rdoc data in the user's home directory.
  #
  # Like ::system, ri data in the user's home directory is rare and predates
  # libraries distributed via RubyGems.  ri data is rarely generated into this
  # directory.

  def self.home_dir
    HOMEDIR
  end

  ##
  # Returns existing directories from the selected documentation directories
  # as an Array.
  #
  # See also ::each

  def self.path(system = true, site = true, home = true, gems = :latest, *extra_dirs)
    path = raw_path system, site, home, gems, *extra_dirs

    path.select { |directory| File.directory? directory }
  end

  ##
  # Returns selected documentation directories including nonexistent
  # directories.
  #
  # See also ::each

  def self.raw_path(system, site, home, gems, *extra_dirs)
    path = []

    each(system, site, home, gems, *extra_dirs) do |dir, type|
      path << dir
    end

    path.compact
  end

  ##
  # The location of ri data installed into the site dir.
  #
  # Historically this was available for documentation installed by ruby
  # libraries predating RubyGems.  It is unlikely to contain any content for
  # modern ruby installations.

  def self.site_dir
    File.join BASE, 'site'
  end

  ##
  # The location of the built-in ri data.
  #
  # This data is built automatically when `make` is run when ruby is
  # installed.  If you did not install ruby by hand you may need to install
  # the documentation yourself.  Please consult the documentation for your
  # package manager or ruby installer for details.  You can also use the
  # rdoc-data gem to install system ri data for common versions of ruby.

  def self.system_dir
    File.join BASE, 'system'
  end

end

