gemfile_contents = File.readlines('./Gemfile')
missing_gems = ENV['GEMS_REQUIRES'].split(',').map(&:strip).map { |gem_name| gemfile_contents.join(' ').scan(/gem '#{gem_name}'/).empty? ? gem_name : nil }.compact

if missing_gems.any?
  puts "Missing gems: #{missing_gems.join(', ')}. Please run again!"
  File.open('Gemfile_', 'w') do |f|
    gemfile_contents.each { |line| f.write line }

    f.write "\n\n# The gems for development environment"
    missing_gems.each do |gem_name|
      f.write "\ngem '#{gem_name}'"
    end
    f.write "\n# End the gems for development environment\n"
  end

  FileUtils.mv('Gemfile_', 'Gemfile')
end