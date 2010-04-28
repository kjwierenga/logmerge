$TESTING = defined? $TESTING

require 'logmerge'

##
# Merges multiple Apache log files by date.

class LogMerge::Merger

  ##
  # Merges +files+ into +output+.  If +files+ is nil, ARGV is used.

  def self.merge(output = STDOUT, *files)
    files = ARGV if files.empty?
    merger = LogMerge::Merger.new files.map { |file| File.open file }
    merger.merge output
  end

  ##
  # Creates a new Merger that will operate on an array of IO-like objects
  # +streams+.

  def initialize(streams)
    @streams = streams
    @buf = []

    @streams.each_index { |slot| buf_fill slot }

    @all_closed = @streams.empty?
  end

  ##
  # Are all the streams closed?

  def all_closed?
    @all_closed
  end

  ##
  # Adds a line to the buffer from input strem +slot+.

  def buf_fill(slot)
    line = @streams[slot].gets

    if line.nil? and @streams[slot].eof? then
      @streams.delete_at slot
      @buf.delete_at slot
    elsif line.nil? then
      raise "WTF? line.nil? and not eof?"
    else
      line =~ / \[(.+?)\] /
      time = Time.parse($1.sub(':', ' ').gsub('/', '-')).to_i
      @buf[slot] = [time, line]
    end
  end

  ##
  # Merges streams into +out_stream+.

  def merge(out_stream)
    index, min, line = nil

    until @streams.empty? do
      min = @buf.min { |a,b| a.first <=> b.first}
      slot = @buf.index min
      buf_fill slot
      out_stream.puts min.last
    end

    @all_closed = true
  end

end
