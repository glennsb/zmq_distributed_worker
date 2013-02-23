require 'ffi-rzmq'
#require 'omrf/logged_external_command'
require 'securerandom'
require 'json'

Thread.abort_on_exception = true

@context     = ZMQ::Context.new
@sema = Mutex.new
@keep_working = true
@runners_to_have = 9
@runners = []

def error_check(rc)
  if ZMQ::Util.resultcode_ok?(rc)
    false
  else
    STDERR.puts "Operation failed, errno [#{ZMQ::Util.errno}] description [#{ZMQ::Util.error_string}]"
    caller(1).each { |callstack| STDERR.puts(callstack) }
    true
  end
end

def reply(msg)
  @sema.synchronize do
    @push.send_string msg
  end
end

@push        = @context.socket(ZMQ::PUSH)
error_check @push.bind 'tcp://127.0.0.1:5555'

@runners_to_have.times do |i|
  @runners << Thread.new do
    pull        = @context.socket(ZMQ::PULL)
    rc = pull.connect 'tcp://127.0.0.1:5556'
    error_check(rc)
    poller = ZMQ::Poller.new
    poller.register(pull, ZMQ::POLLIN)
    while @keep_working do
      msg = ''
      rc = 0
      poller.poll(30000)
      #puts "Done poll"
      poller.readables.each do |socket|
        rc = socket.recv_string(msg)
        error_check(rc)
        next if nil == msg || '' == msg
        #puts msg
        reply_msg = "#{i} Start: #{msg}"
        reply(reply_msg)
        if "quit" == JSON.parse(msg)['payload']
          @keep_working = false
          reply("#{i} Will shutdown soon")
        else
          sleep rand(10)*2
          reply_msg = "#{i} Finish: #{msg}"
          reply(reply_msg)
        end
        msg = ''
      end #end poller
      #sleep 10
    end #@keep_workinging
  end #Thread
end

puts "There are #{Thread.list.size} threads listening, #{@runners.size}/#{@runners_to_have} runners"

puts "Waiting for runner threads"
@runners.each do |r|
  puts "Waiting for #{r.inspect}"
  r.join
end

#@context.terminate

