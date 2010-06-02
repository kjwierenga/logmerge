require 'stringio'
require 'test/unit'

$TESTING = true

require 'logmerge/resolver'

class LogMerge::IPResolver

  attr_accessor :cache
  attr_accessor :failures
  attr_accessor :buf
  attr_accessor :output
  attr_accessor :cur
  attr_accessor :start_time
  attr_accessor :queue

end

class TestResolver < Test::Unit::TestCase

  def setup
    @resolver = LogMerge::IPResolver.new
  end

  def test_class_create
    File.unlink 'test/.name_cache' if File.exist? 'test/.name_cache'

    assert_equal false, File.exist?('test/.name_cache')

    Dir.chdir 'test' do
      LogMerge::IPResolver.create do |res|
        assert_equal({}, res.cache)
      end
    end

    assert_equal true, File.exist?('test/.name_cache')

  ensure
    begin File.unlink 'test/.name_cache' rescue Errno::ENOENT; end
  end

  def test_class_create_with_cache
    File.open 'test/.name_cache', 'w' do |fp|
      fp.write util_dumped_resolver
    end
    
    Dir.chdir 'test' do
      LogMerge::IPResolver.create do |res|
        assert_equal({'65.61.137.68' => ['brain.43things.com', 500]}, res.cache)
      end
    end

    assert_equal true, File.exist?('test/.name_cache')

  ensure
    begin File.unlink 'test/.name_cache' rescue Errno::ENOENT; end
  end

  def test_expire_entries_age
    @resolver.cache = {
      '65.61.137.68' => ['brain.43things.com', 500]
    }

    @resolver.expire_entries Time.now - 250

    assert_equal ['65.61.137.68'], @resolver.cache.keys
    assert_equal ['brain.43things.com', 250], @resolver.cache['65.61.137.68']
  end

  def test_expire_entries_delete
    @resolver.cache = {
      '65.61.137.68' => ['brain.43things.com', 500]
    }

    @resolver.expire_entries Time.now - 501

    assert_equal true, @resolver.cache.empty?
  end

  def test_expire_entries_now
    @resolver.cache = {
      '65.61.137.68' => ['brain.43things.com', 500]
    }

    @resolver.expire_entries Time.now

    assert_equal ['65.61.137.68'], @resolver.cache.keys
    assert_equal ['brain.43things.com', 500], @resolver.cache['65.61.137.68']
  end

  def test_flush
    @resolver.buf[0] = "one"
    @resolver.buf[1] = "two"
    @resolver.buf[2] = "three"
    @resolver.buf[3] = "four"

    @resolver.output = StringIO.new
    @resolver.flush
    assert_equal "one\ntwo\nthree\nfour\n", @resolver.output.string
  end

  def test_marshal_dump
    dumped = @resolver.marshal_dump

    assert_instance_of Array, dumped
    assert_equal 0, dumped[0]
    assert_equal({}, dumped[1])
    assert_instance_of Time, dumped[2]
  end

  def test_marshal_dump_with_cache
    @resolver.cache['65.61.137.68'] = ['brain.43things.com', 500]
    dumped = @resolver.marshal_dump

    assert_instance_of Array, dumped
    assert_equal 0, dumped[0]
    assert_equal({'65.61.137.68' => ['brain.43things.com', 500]}, dumped[1])
    assert_instance_of Time, dumped[2]
  end

  def test_marshal_load
    data = "\004\010U:\031LogMerge::IPResolver[\010i\000{\000u:\tTime\rw\202\032\200\032\027\253\037"
    resolver = Marshal.load data

    assert_instance_of LogMerge::IPResolver, resolver
    assert_equal({}, resolver.cache)
    assert_equal [], resolver.failures, "Make sure it was init'd properly"
  end

  def test_marshal_load_with_cache
    resolver = Marshal.load util_dumped_resolver

    assert_instance_of LogMerge::IPResolver, resolver
    assert_equal({'65.61.137.68' => ["brain.43things.com", 500]},
                 resolver.cache)
  end

  def test_resolve
    assert_equal 'www.43things.com', @resolver.resolve('65.61.137.67')
    assert_equal '0.0.0.0', @resolver.resolve('0.0.0.0')

    assert_equal ['0.0.0.0'], @resolver.failures

    assert_equal ['0.0.0.0', '65.61.137.67'].sort, @resolver.cache.keys.sort
    assert_equal 0, @resolver.cache['0.0.0.0'].last
    assert_operator 0, :<, @resolver.cache['65.61.137.67'].last
  end

  def test_resolve_from_cache
    @resolver.cache['65.61.137.68'] = ['brain.43things.com', 0]

    assert_equal 'www.43things.com', @resolver.resolve('65.61.137.67')
    assert_equal 'brain.43things.com', @resolver.resolve('65.61.137.68')
    assert_equal '0.0.0.0', @resolver.resolve('0.0.0.0')

    assert_equal ['0.0.0.0'], @resolver.failures

    assert_equal ['0.0.0.0', '65.61.137.67', '65.61.137.68'].sort, @resolver.cache.keys.sort
    assert_equal 0, @resolver.cache['0.0.0.0'].last
    assert_operator 0, :<, @resolver.cache['65.61.137.67'].last
    assert_equal 0, @resolver.cache['65.61.137.68'].last
  end

  def test_resolve_bad_ip
    assert_equal '0.0.0.256', @resolver.resolve('0.0.0.256')
  end

  def test_run
    input = StringIO.new <<-EOF
138.217.248.136 - - [17/Jan/2006:00:00:00 -0800] "GET /javascripts/prototype.js HTTP/1.1" 200 7358 "http://www.43things.com/things/view/16508" "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8) Gecko/20051111 Firefox/1.5"
68.142.250.78 - - [17/Jan/2006:00:00:01 -0800] "GET /things/view/123841 HTTP/1.0" 200 9146 "-" "Mozilla/5.0 (compatible; Yahoo! Slurp; http://help.yahoo.com/help/us/ysearch/slurp)"
138.217.248.136 - - [17/Jan/2006:00:00:02 -0800] "GET /javascripts/enumerable.js HTTP/1.1" 200 1084 "http://www.43things.com/things/view/16508" "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8) Gecko/20051111 Firefox/1.5"
202.160.180.40 - - [17/Jan/2006:00:00:03 -0800] "GET /teams/progress/1147887 HTTP/1.0" 302 128 "-" "Mozilla/5.0 (compatible; Yahoo! Slurp China; http://misc.yahoo.com.cn/help.html)"
138.217.248.136 - - [17/Jan/2006:00:00:04 -0800] "GET /javascripts/effects.js HTTP/1.1" 200 5319 "http://www.43things.com/things/view/16508" "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8) Gecko/20051111 Firefox/1.5"
68.189.40.2 - - [17/Jan/2006:00:00:05 -0800] "GET /entries/view/139942 HTTP/1.1" 200 2975 "-" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) AppleWebKit/312.5.1 (KHTML, like Gecko) Safari/312.3.1"
202.160.180.40 - - [17/Jan/2006:00:00:06 -0800] "GET /people/progress/princessauddie/1147887 HTTP/1.0" 200 7511 "-" "Mozilla/5.0 (compatible; Yahoo! Slurp China; http://misc.yahoo.com.cn/help.html)"
138.217.248.136 - - [17/Jan/2006:00:00:07 -0800] "GET /javascripts/dragdrop.js HTTP/1.1" 200 5279 "http://www.43things.com/things/view/16508" "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8) Gecko/20051111 Firefox/1.5"
192.168.1.254 - - [17/Jan/2006:00:00:08 -0800] "HEAD / HTTP/1.0" 200 0 "-" "-"
216.109.121.70 - - [17/Jan/2006:00:00:09 -0800] "GET /rss/uber/author?username=twilightpumpkin HTTP/1.0" 200 15482 "-" "YahooFeedSeeker/2.0 (compatible; Mozilla 4.0; MSIE 5.5; http://publisher.yahoo.com/rssguide; users 0; views 0)"
    EOF
    output = StringIO.new

    @resolver.cache = {
      '216.109.121.70'  => ['oc31.my.dcn.yahoo.net',                 94],
      '68.142.250.78'   => ['lj2268.inktomisearch.com',              90],
      '138.217.248.136' => ['CPE-138-217-248-136.wa.bigpond.net.au', 167760],
      '68.189.40.2'     => ['68-189-40-2.dhcp.rdng.ca.charter.com',  81360],
      '202.160.180.40'  => ['lj9027.inktomisearch.com',              90],
      '192.168.1.254'   => ['dhcp-254.coop.robotcoop.com',           7200]
    }

    @resolver.run output, input

    assert_equal true, input.eof?, "Input empty."
    assert_equal true, @resolver.queue.empty?, "Queue empty"
    assert_equal 10, output.string.scan("\n").length

    expected = <<-EOF
CPE-138-217-248-136.wa.bigpond.net.au - - [17/Jan/2006:00:00:00 -0800] "GET /javascripts/prototype.js HTTP/1.1" 200 7358 "http://www.43things.com/things/view/16508" "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8) Gecko/20051111 Firefox/1.5"
lj2268.inktomisearch.com - - [17/Jan/2006:00:00:01 -0800] "GET /things/view/123841 HTTP/1.0" 200 9146 "-" "Mozilla/5.0 (compatible; Yahoo! Slurp; http://help.yahoo.com/help/us/ysearch/slurp)"
CPE-138-217-248-136.wa.bigpond.net.au - - [17/Jan/2006:00:00:02 -0800] "GET /javascripts/enumerable.js HTTP/1.1" 200 1084 "http://www.43things.com/things/view/16508" "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8) Gecko/20051111 Firefox/1.5"
lj9027.inktomisearch.com - - [17/Jan/2006:00:00:03 -0800] "GET /teams/progress/1147887 HTTP/1.0" 302 128 "-" "Mozilla/5.0 (compatible; Yahoo! Slurp China; http://misc.yahoo.com.cn/help.html)"
CPE-138-217-248-136.wa.bigpond.net.au - - [17/Jan/2006:00:00:04 -0800] "GET /javascripts/effects.js HTTP/1.1" 200 5319 "http://www.43things.com/things/view/16508" "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8) Gecko/20051111 Firefox/1.5"
68-189-40-2.dhcp.rdng.ca.charter.com - - [17/Jan/2006:00:00:05 -0800] "GET /entries/view/139942 HTTP/1.1" 200 2975 "-" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) AppleWebKit/312.5.1 (KHTML, like Gecko) Safari/312.3.1"
lj9027.inktomisearch.com - - [17/Jan/2006:00:00:06 -0800] "GET /people/progress/princessauddie/1147887 HTTP/1.0" 200 7511 "-" "Mozilla/5.0 (compatible; Yahoo! Slurp China; http://misc.yahoo.com.cn/help.html)"
CPE-138-217-248-136.wa.bigpond.net.au - - [17/Jan/2006:00:00:07 -0800] "GET /javascripts/dragdrop.js HTTP/1.1" 200 5279 "http://www.43things.com/things/view/16508" "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8) Gecko/20051111 Firefox/1.5"
dhcp-254.coop.robotcoop.com - - [17/Jan/2006:00:00:08 -0800] "HEAD / HTTP/1.0" 200 0 "-" "-"
oc31.my.dcn.yahoo.net - - [17/Jan/2006:00:00:09 -0800] "GET /rss/uber/author?username=twilightpumpkin HTTP/1.0" 200 15482 "-" "YahooFeedSeeker/2.0 (compatible; Mozilla 4.0; MSIE 5.5; http://publisher.yahoo.com/rssguide; users 0; views 0)"
    EOF

    assert_equal expected, output.string
  end

  def test_start_threads
    threads = Thread.list.length

    @resolver.start_threads

    assert_operator threads, :<, Thread.list.length
  end

  ##
  # HACK don't like this method since it is Time.now dependent.

  def util_dumped_resolver
    resolver = LogMerge::IPResolver.new
    resolver.cache['65.61.137.68'] = ['brain.43things.com', 500]
    resolver.start_time = Time.now
    return Marshal.dump(resolver)
  end
end

