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
  
  def test_empty_files
    require 'tempfile'
    tf = Tempfile.new('test_empty_file')
    tf.flush

    stream1 = File.open(tf.path) # empty file1
    stream2 = File.open(tf.path) # empty file2
    stream3 = File.open(tf.path) # empty file3

    merger = LogMerge::Merger.new [stream1, stream2, stream3]

    output = StringIO.new

    merger.merge output

    expected = ""

    assert_equal true, merger.all_closed?
    assert_equal expected, output.string
  end
  
  def test_merge_files
    require 'tempfile'
    file1 = Tempfile.open('gzip_file1')
    file1.puts " [17/Jan/2006:00:00:02 -0800] "
    file1.close
    
    file2 = Tempfile.open('gzip_file2')
    file2.puts " [17/Jan/2006:00:00:01 -0800] "
    file2.close
    
    # puts file1.path, file2.path
    # STDOUT.flush
    
    output = StringIO.new
    LogMerge::Merger.merge output, *[file1.path, file2.path]
    
    expected = <<-EOF
 [17/Jan/2006:00:00:01 -0800] 
 [17/Jan/2006:00:00:02 -0800] 
EOF

    assert_equal expected, output.string
  end

  def test_merge_gzip_files
    begin
      require 'tempfile'
      file1 = Tempfile.new('logmerge_test1')
      gzipped_file1 = file1.path + '.gz'
      Zlib::GzipWriter.open(gzipped_file1) do |gz|
        gz.write " [17/Jan/2006:00:00:02 -0800] \n"
      end

      file2 = Tempfile.new('logmerge_test2')
      gzipped_file2 = file2.path + '.gz'
      Zlib::GzipWriter.open(gzipped_file2) do |gz|
        gz.write " [17/Jan/2006:00:00:01 -0800] \n"
      end
    
      gzipped_files = [ gzipped_file1, gzipped_file2 ]
    
      output = StringIO.new
      LogMerge::Merger.merge output, *gzipped_files
    
      expected = <<-EOF
 [17/Jan/2006:00:00:01 -0800] 
 [17/Jan/2006:00:00:02 -0800] 
EOF

      assert_equal expected, output.string
    ensure
      File.unlink(*gzipped_files)
    end
  end

end

