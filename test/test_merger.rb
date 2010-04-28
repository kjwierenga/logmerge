require 'stringio'
require 'test/unit'

$TESTING = true

require 'logmerge/merger'

class LogMerge::Merger

  attr_accessor :streams
  attr_accessor :buf

end

class TestMerger < Test::Unit::TestCase

  def test_all_closed_eh_closed
    merger = LogMerge::Merger.new []
    assert_equal true, merger.all_closed?
  end

  def test_all_closed_eh_not_closed
    merger = LogMerge::Merger.new [StringIO.new]
    assert_equal true, merger.all_closed?
  end

  def test_buf_fill_fill
    stream = StringIO.new <<-EOF
 [17/Jan/2006:00:00:01 -0800] 
 [17/Jan/2006:00:00:02 -0800] 
    EOF
    merger = LogMerge::Merger.new [stream]

    assert_equal [1137484801, " [17/Jan/2006:00:00:01 -0800] \n"], merger.buf[0]

    merger.buf_fill 0

    assert_equal [1137484802, " [17/Jan/2006:00:00:02 -0800] \n"], merger.buf[0]
  end

  def test_buf_fill_empty
    stream = StringIO.new <<-EOF
 [17/Jan/2006:00:00:01 -0800] 
    EOF
    merger = LogMerge::Merger.new [stream]

    assert_equal [1137484801, " [17/Jan/2006:00:00:01 -0800] \n"], merger.buf[0]

    merger.buf_fill 0

    assert_equal true, merger.buf.empty?
    assert_equal true, merger.streams.empty?
  end

  def test_initialize
    stream1 = StringIO.new " [17/Jan/2006:00:00:01 -0800] \n"
    stream2 = StringIO.new " [17/Jan/2006:00:00:02 -0800] \n"

    merger = LogMerge::Merger.new [stream1, stream2]

    assert_equal false, merger.all_closed?
    assert_equal [1137484801, " [17/Jan/2006:00:00:01 -0800] \n"], merger.buf[0]
    assert_equal [1137484802, " [17/Jan/2006:00:00:02 -0800] \n"], merger.buf[1]
   end

  def test_merge
    stream1 = StringIO.new " [17/Jan/2006:00:00:02 -0800] \n"
    stream2 = StringIO.new " [17/Jan/2006:00:00:01 -0800] \n"

    merger = LogMerge::Merger.new [stream1, stream2]

    output = StringIO.new

    merger.merge output

    expected = <<-EOF
 [17/Jan/2006:00:00:01 -0800] 
 [17/Jan/2006:00:00:02 -0800] 
    EOF

    assert_equal true, merger.all_closed?
    assert_equal expected, output.string
  end

end

