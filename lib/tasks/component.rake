namespace :component do

  desc "Converts given bower component to Gem"
  task :convert, [:name, :version] => [:environment] do |t, args|
    # Remove component to force rebuild
    component, version = Component.get(args[:name], args[:version])
    version.destroy if version.present?

    puts Build::Converter.run!(args[:name], args[:version]).inspect
  end

  desc "Removes given component from database and index"
  task :destroy, [:name, :version] => [:environment] do |t, args|
    component, version = Component.get(args[:name], args[:version])

    if args[:version] && version.present?
      puts "Removing #{version.gem_path}..."
      File.delete(version.gem_path) rescue nil
      version.destroy
      Reindex.new.perform
    elsif args[:version].blank?
      component.versions.map(&:gem_path).each do |path|
        puts "Removing #{path}"
        File.delete(path) rescue nil
      end
      component.destroy
      Reindex.new.perform
    end
  end

  desc "Removes all components from database and index"
  task :destroy_all => [:environment] do
    STDOUT.print "Are you sure? (y/n) "
    input = STDIN.gets.strip
    if input == 'y'
      FileUtils.rm_rf(Rails.root.join('public', 'gems'))
      Component.destroy_all
      Reindex.new.perform

      STDOUT.puts "All gems have been removed..."
    else
      STDOUT.puts "No action has been performed..."
    end
  end

  desc "Removes all .gem files with no matching db entry"
  task :clean_gems => [:environment] do
    to_remove = []

    Dir[Rails.root.join('public', 'gems', '*.gem')].each do |path|
      filename = File.basename(path).sub('.gem', '').sub(GEM_PREFIX, '')
      gem_name, gem_version = filename.split(/\-(?=\d)/)
      if component = Component.find_by(name: gem_name)
        version = component.versions.find_by(string: gem_version)

        if version.blank?
          to_remove << path
        end
      end
    end

    STDOUT.puts "This will delete:"
    STDOUT.puts to_remove.map { |p| " * #{p}\n" }
    STDOUT.print "Are you sure? (y/n) "
    input = STDIN.gets.strip
    if input == 'y'
      to_remove.each do |path|
        File.delete(path)
      end

      STDOUT.puts "#{to_remove.size} gems deleted from filesystem"
    end
  end

  desc "Reindex"
  task :reindex => [:environment] do
    Version.all.load.each do |version|
      version.update_attributes(:rebuild => true)
      UpdateScheduler.perform_async
    end
  end

  desc "Updates version.bower_version field"
  task :update_bower_version => [:environment] do
    Component.all.load.each do |component|
      puts "Processing #{component.bower_name}..."

      versions = Build::Utils.bower('/tmp', 'info', component.bower_name)['versions'] || []

      versions.each do |version|
        if model = Version.find_by(string: Build::Utils.fix_version_string(version))
          model.update_attributes(:bower_version => version)
          puts "SUCCESS: updated #{component.bower_name}##{version}"
        else
          puts "WARNING: no matching version for #{component.bower_name}##{version}"
        end
      end
    end
  end
end
