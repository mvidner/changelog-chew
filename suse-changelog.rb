#! /usr/bin/env ruby
# aggregate changelogs for RPMs: either -q --changelog or (TODO) SUSE .changes
# license: http://en.wikipedia.org/wiki/MIT_License

require "date"
require "optparse"
# require "pp"
require "time"

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

class SUSEChange < Change
  HEADER = "-" * 67
  HEADER_NEWLINE = HEADER + "\n"

  def to_s
    HEADER_NEWLINE +
      # `vc` calls `date` and this is the default timestamp format:
      # https://www.gnu.org/software/coreutils/manual/html_node/date-invocation.html
      "#{timestamp.strftime '%a %b %e %H:%M:%S %Z %Y'} - #{author}\n" +
      description
  end
end

class SUSEChangeLog

  attr_accessor :items          #

  def self.new_from_filename(filename)
    cl = self.new
    File.open(filename) do |f|
      cl.parse_io(f)
    end
    cl
  end

  def initialize
    @items = []
  end

  def parse_io(io)
    parse_io_yield(io) do |item|
      items << item
    end
  end

  def parse_io_yield(io)
    # parses an IO object
    # yields each Change
    item = nil
    expect = :header
    io.each_line do |line|
      case expect
      when :header
        if line != SUSEChange::HEADER_NEWLINE
          raise "Garbage before 1st header: #{line}"
        end
        expect = :timestamp_author
      when :timestamp_author
        if line =~ /^([^-]*) - (.*)/
          item = SUSEChange.new
          item.lineno = io.lineno
          item.description = ""
          item.timestamp = Time.parse($1)
          item.author = $2
          expect = :description
        else
          raise "Not in 'TIMESTAMP - AUTHOR' format: #{line}"
        end
      when :description
        if line == SUSEChange::HEADER_NEWLINE
          yield item
          expect = :timestamp_author
        else
          item.description += line
        end
      end
    end
    yield item unless item.nil?
  end

  # ugh, pattern for sending to IO instead?
  def to_s
    s = ""
    items.each do |i|
      s << i.to_s
    end
    s
  end
end

cl = SUSEChangeLog.new_from_filename ARGV[0]
print cl
