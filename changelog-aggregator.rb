#! /usr/bin/env ruby
# aggregate changelogs for RPMs: either -q --changelog or (TODO) SUSE .changes
# license: http://en.wikipedia.org/wiki/MIT_License

require "date"
require "optparse"
require "thread"
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
# returns a list of Changes (where :object is supplied from outside)
# if a block is given, returns [] and instead yields each Change
def parse_rpm_changelog(io, object = nil)
  items = []
  item = nil
  io.each_line do |line|
    next if line =~ /^\S*$/
    # author can contain space :-/
    # heuristic: date ends in a 4-digit year
    if line =~ /^\* (.*\d\d\d\d) (.*)/
      # finish previous item
      if block_given?
        yield item unless item.nil?
      else
        items << item unless item.nil?
      end
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
  if block_given?
    yield item unless item.nil?
  else
    items << item unless item.nil?
  end
  items
end

# yields Changes
def query_rpm_changelog(rpm, &block)
  io = IO.popen("rpm -q --changelog #{rpm}")
  one_log = parse_rpm_changelog(io, rpm, &block)
  io.close
  $stderr.print "."
  $stderr.flush
  one_log
end

# return an unsorted list of all changes
def collect_in_sequence(rpmnames)
  all = []
  rpmnames.each do |rpm|
    all += query_rpm_changelog(rpm)
  end
  all
end

# return an unsorted list of all changes
def collect_in_parallel(rpmnames)
  all = []
  jobs = []
  mutex = Mutex.new
  rpmnames.each do |rpm|
    jobs << Thread.new do
      query_rpm_changelog(rpm) do |item|
        mutex.synchronize do
          all << item
        end
      end
    end
  end
  jobs.each do |thread| thread.join end
  all
end

def main
  query = nil
  threads = true
  OptionParser.new do |opts|
    opts.on "-w" do query = "'*yast*' '*ruby*'" end
    opts.on "-n" do threads = false end
  end.parse!
  query ||= ARGV.join ' '
  description = query.empty? ? "all packages" : query
  puts "RPM ChangeLog for #{description}"
  rpmnames = `rpm -qa #{query}`.split
  $stderr.puts "#{rpmnames.size} packages"
  ENV["LANG"] = "C"             # parse C dates
  if threads
    all = collect_in_parallel(rpmnames)
  else
    all = collect_in_sequence(rpmnames)
  end
  $stderr.print "\n"
  $stderr.puts "#{all.size} changes"
  # negate: bigger lineno means smaller timestamp
  sorted = all.sort_by {|e| [e.timestamp, e.object, -e.lineno] }
  sorted.reverse_each {|e| print e }
end

main

# TODO take examples of (weird) changelogs, make tests
