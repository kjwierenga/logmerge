$TESTING = defined? $TESTING

require 'logmerge'

class LogMerge::IPResolver

  ##
  # Marshal format version number.

  FORMAT = 0

  ##
  # Default number of threads.

  THREADS = $TESTING ? 2 : 100 

  def self.create
    resolver = nil

    if File.exists? '.name_cache' then
      data = File.read '.name_cache'
      begin
        resolver = Marshal.load data
      rescue ArgumentError
      end
    end

    resolver ||= self.new

    yield resolver

  ensure
    begin
      File.open '.name_cache', 'w' do |fp|
        Marshal.dump resolver, fp
      end
    rescue Errno::EACCES
      # ignore
    end
  end

  def self.resolve(output = STDOUT, input = ARGF)
    create do |resolver|
      resolver.run output, input
    end
  end

  def initialize(cache = {})
    @cache = cache
    @failures = []
    @start_time = Time.now
    @dns = Resolv::DNS.new

    @output = nil
    @done = false
    @queue = SizedQueue.new THREADS
    @threads = ThreadGroup.new
    @buf = {}
    @cur = 0
  end

  def expire_entries(start_time)
    elapsed = (Time.now - start_time).to_i
    @cache.each { |ip, (name, ttl)| @cache[ip][1] = ttl - elapsed }
    @cache.delete_if { |ip, (name, ttl)| ttl <= 0 }
    return nil
  end

  def flush
    while @buf.has_key? @cur do
      @output.puts @buf.delete(@cur)
      @cur += 1
    end
  end

  def marshal_dump
    @failures.each { |ip| @cache.delete ip }

    expire_entries @start_time # compact

    return [FORMAT, @cache, @start_time]
  end

  def marshal_load(dumped)
    format, cache, start_time = dumped

    case format
    when 0 then
      send :initialize, cache
      expire_entries start_time # expire
    end
  end

  def resolve(ip)
    name, = @cache[ip]

    return name unless name.nil?

    begin
      dns_name = Resolv::IPv4.create(ip).to_name
    rescue ArgumentError
      return ip
    end

    @dns.each_resource dns_name, Resolv::DNS::Resource::IN::PTR do |res|
      @cache[ip] = [res.name.to_s, res.ttl * 2]
      return res.name.to_s
    end

    @cache[ip] = [ip, 0]
    @failures << ip

    return ip
  end

  def run(output, input)
    start_threads
    line_no = 0
    @output = output

    input.each_line do |line|
      ip, rest = line.split ' ', 2
      record = [line_no, ip, rest]
      line_no += 1
      @queue << record
      flush if line_no % LogMerge::MAX_INFLIGHT == 0
    end

    @done = true

    Thread.pass until @queue.empty?

    @threads.enclose
    until @threads.list.empty? do
      @threads.list.first.join
    end

    flush
  end

  def start_threads
    THREADS.times do
      Thread.start do
        @threads.add Thread.current
        loop do
          begin
            line_no, ip, rest = @queue.pop true
          rescue ThreadError
            break if @done
            Thread.pass
            retry
          end

          name = resolve ip
          @buf[line_no] = "#{name} #{rest}"
        end
      end
    end
  end

end

