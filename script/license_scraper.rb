#!/usr/bin/env ruby

require 'yaml'

puts "Updating submodules..."

`git submodule init`
`git submodule update --recursive`

puts "Fetching licenses..."

root = File.join(File.dirname(__FILE__), "..")
license_dir = File.join(root, "deps", "choosealicense.com", "licenses")
licenses = Dir.new(license_dir).select { |f| f !~ /^\./ }

puts "Replacing junk..."

license_array = []
licenses.each do |license|
  license_file = File.read(File.join(license_dir, license))
  first_empty_line = license_file.index(/^\s*$/) 

  license_metadata = license_file[4..first_empty_line]

  title = license_metadata.match(/title:\s+(.+)\n/)[1].strip
  link = license_metadata.match(/permalink:\s+\/licenses\/(.+)\n/)[1][0..-2].strip.sub(/licenses\/\//, "")
  filename = license_metadata.match(/filename:\s+(.+)\n/)[1][0..-1].strip if license_metadata.match(/filename: (.+)\n/)

  s = StringScanner.new(license_file)
  s.scan(/\-{3}/)
  s.scan_until(/\-{3}/)
  
  File.open(File.join(root, "deps", "licenses", "#{link}.txt"), "w") do |f|
    # this ensures licenses like GPL still have centered text
    content = s.post_match().sub(/^\n+/, "")

    # remove unnecessary information
    s.skip_until(/END OF TERMS AND CONDITIONS/)
    content = content.sub(s.rest(), "") if s.rest()

    f.write(content)
  end

  license_array << { :title => title, :link => link, :filename => filename }
end

File.open(File.join(root, "deps", "licenses.yml"), "w") do |f|
  f.write(Psych.dump(license_array))
end