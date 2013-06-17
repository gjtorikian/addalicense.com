#!/usr/bin/env ruby

require 'yaml'

#{}`git submodule init`
#{}`git submodule update --recursive`

root = File.join(File.dirname(__FILE__), "..")
license_dir = File.join(root, "deps", "choosealicense.com", "licenses")
licenses = Dir.new(license_dir).select { |f| f !~ /^\./ }

license_array = []
licenses.each do |license|
  license_file = File.read(File.join(license_dir, license))
  first_empty_line = license_file.index(/^\s*$/) 

  license_metadata = license_file[4..first_empty_line]
  title = license_metadata.match(/title: (.+)\n/)[1].strip
  link = license_metadata.match(/permalink: (.+)\n/)[1][0..-2].strip

  s = StringScanner.new(license_file)
  s.scan(/\-{3}/)
  s.scan_until(/\-{3}/)
  
  File.open(File.join(root, "deps", "licenses", "#{link}.txt"), "w") do |f|
    f.write(s.post_match())
  end

  license_array << { :title => title, :link => link}
end

File.open(File.join(root, "deps", "licenses.yml"), "w") do |f|
  f.write(Psych.dump(license_array))
end