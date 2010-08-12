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

TERMINATOR = "changelog-aggregator-terminator\n"
QUERYFORMAT = "[%{NAME}\n%{CHANGELOGTIME}\n%{CHANGELOGNAME}\n%{CHANGELOGTEXT}\n#{TERMINATOR}]"

# parses an IO object
# yields each Change
def parse_custom_rpm_changelog(io)
  item = nil
  expect = :name
  io.each_line do |line|
    case expect
    when :name
      item = Change.new
      item.object = line.chomp
      item.lineno = io.lineno
      item.description = ""
      expect = :timestamp
    when :timestamp
      item.timestamp = Time.at(line.to_i)
      expect = :author
    when :author
      item.author = line.chomp
      expect = :description
    when :description
      if line == TERMINATOR
        yield item
        expect = :name
      else
        item.description += line
      end
    end
  end
end

# yields Changes
def query_rpm_changelog(rpm, &block)
  io = IO.popen("rpm -q --qf \"#{QUERYFORMAT}\" #{rpm}")
  parse_custom_rpm_changelog(io, &block)
  io.close
  $stderr.print "."
  $stderr.flush
end

# return an unsorted list of all changes
def collect_in_sequence(rpmnames)
  all = []
  rpmnames.each do |rpm|
    query_rpm_changelog(rpm) do |item|
      all << item
    end
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
