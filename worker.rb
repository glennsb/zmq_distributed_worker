require 'ffi-rzmq'
require 'securerandom'
require 'json'
require 'analyze_job'
require 'frfast_job'

Thread.abort_on_exception = true

ENV.each do |name,val|
  if name =~ /.*(ruby|gem|irb|bundle|rvm).*/i
    ENV.delete(name)
  end
end
@context = ZMQ::Context.new
@sema = Mutex.new
@keep_working = true
@runners_to_have = ARGV.shift || 30
@runners_to_have = @runners_to_have.to_i
@runners = []

@hostname = `uname -n`.chomp.sub(/\..*/,'')

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
    @push_to_logger.send_string msg.merge({:host=>@hostname}).to_json
  end
end

@push_to_logger = @context.socket(ZMQ::PUSH)
error_check @push_to_logger.bind 'tcp://*:3555'

@runners_to_have.times do |i|
  @runners << Thread.new do
    request_work = @context.socket(ZMQ::REQ)
    rc = request_work.connect 'tcp://oak.shells.ngs.omrf.in:3557'
    error_check(rc)
    while @keep_working do
      msg = ''
      rc = 0
      request_work.send_string("WORK PLEASE")
      rc = request_work.recv_string(msg)
      error_check(rc)
      next if nil == msg || '' == msg

      payload = JSON.parse(msg)
      if nil == payload['id'] then
        #no work
        sleep 10
        next
      end
      if "quit" == payload['payload']
        @keep_working = false
        reply({:id =>  payload['id'], :msg => "#{i} Will shutdown soon"})
      else
        wd = payload['payload']['cwd']
        sample_id = payload['payload']['sample_id']
        job_name = payload['payload']['job_type']
        job = nil
        if "analyze" == job_name
          job = AnalyzeJob.new(wd,sample_id)
        elsif "frfast" == job_name
          port = payload['payload']['port'].to_i
          job = FrfastJob.new(wd,sample_id,port)
        end
        reply_msg = {:id => payload['id'], :sample_id => sample_id}
        if nil != job
          reply_msg[:status] = job.execute()
        else
          reply_msg[:status] = {:exit_status => -1, :trace=>"no such job type: #{job_name}"}
        end
        reply(reply_msg)
      end
      msg = ''
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

