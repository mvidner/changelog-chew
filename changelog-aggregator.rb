#! /usr/bin/env ruby
require "date"
require "pp"

class Change
  # what is being changed (usu. String)
  attr_accessor :object
  # who changed it (string, email)
  attr_accessor :author
  # when it changed. datetime, or date
  attr_accessor :timestamp
  # to preserve order of items with the same timestamp
  attr_accessor :lineno
  # how it changed, the message, single string (including trailing \n)
  attr_accessor :description

end

# parses an IO object
# returns a list of Changes (where :object is nil)
# TODO optionally yield them instead
def parse_rpm_changelog(io)
  items = []
  item = nil
  io.each_line do |line|
    next if line =~ /^\S*$/
    if line =~ /^\* (.*) (\S*)/
      # finish previous item
      items << item unless item.nil?
      # new item
      item = Change.new
      item.timestamp = Date::parse $1
      item.author = $2
      item.lineno = io.lineno
    elsif not item.nil?
      # add to description of current item
      item.description ||= ""
      item.description += line
    end
  end
  # flush
  items << item unless item.nil?
  items
end


# usage: LANG=C rpm -q --changelog foo | ruby changelog-aggregator.rb
changes = parse_rpm_changelog $stdin
changes.each do |i|
  puts "----"
  puts "#{i.author}: #{i.timestamp} L#{i.lineno}"
  printf "%s", i.description    # no trailing \n
end
