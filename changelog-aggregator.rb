#! /usr/bin/env ruby
# aggregate changelogs for RPMs: either -q --changelog or (TODO) SUSE .changes
# license: http://en.wikipedia.org/wiki/MIT_License

require "date"
# require "pp"

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

  def to_s
    "----\n" + "#{object} @#{timestamp} #{author}\n" + description.to_s
  end
end

# parses an IO object
# returns a list of Changes (where :object is nil)
# TODO optionally yield them instead
def parse_rpm_changelog(io, object = nil)
  items = []
  item = nil
  io.each_line do |line|
    next if line =~ /^\S*$/
    # author can contain space :-/
    # heuristic: date ends in a 4-digit year
    if line =~ /^\* (.*\d\d\d\d) (.*)/
      # finish previous item
      items << item unless item.nil?
      # new item
      item = Change.new
      begin
        item.timestamp = Date::parse $1
      rescue ArgumentError
        $stderr.puts " HUH #{object}: #{line}"
        item.timestamp = Date.today
        # TODO recover better
      end
      item.author = $2
      item.lineno = io.lineno
      item.object = object
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

def main
  all = []
  rpmnames = `rpm -qa`.split    # TODO replace -a by ARGV
  $stderr.puts "#{rpmnames.size} packages"
  ENV["LANG"] = "C"             # parse C dates
  # TODO paralellize the popens?
  rpmnames.each do |rpm|
    io = IO.popen("rpm -q --changelog #{rpm}")
    all += parse_rpm_changelog(io, rpm)
    io.close
    $stderr.print "."
    $stderr.flush
  end
  $stderr.print "\n"
  $stderr.puts "#{all.size} changes"
  # negate: bigger lineno means smaller timestamp
  sorted = all.sort_by {|e| [e.timestamp, -e.lineno] }
  sorted.reverse_each {|e| print e }
end

main

# TODO take examples of (weird) changelogs, make tests
