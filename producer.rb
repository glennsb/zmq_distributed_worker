require 'ffi-rzmq'
require 'securerandom'
require 'json'
require 'optparse'

def error_check(rc)
  if ZMQ::Util.resultcode_ok?(rc)
    false
  else
    STDERR.puts "Operation failed, errno [#{ZMQ::Util.errno}] description [#{ZMQ::Util.error_string}]"
    caller(1).each { |callstack| STDERR.puts(callstack) }
    true
  end
end

def already_finished?(dir,sample)
  File.exists? File.join( dir, sample, "finished.txt")
end

context = ZMQ::Context.new
push = context.socket(ZMQ::PUSH)
#error_check(push.setsockopt(ZMQ::LINGER, 0))
error_check push.bind 'tcp://*:3556'

options = {:priority => 1, :delay => 0, :length => 1, :group_size => 1}
opts = OptionParser.new()
opts.banner = "Usage: #{File.basename(__FILE__)} -t TYPE -w DIR [-d DELAY] [-p PRIORITY] job [job...]"
opts.on("-t","--type TYPE","Type of analysis job/worker") do |type|
  options[:job_type] = type
end
opts.on("-w","--working-dir DIR","Set the working directory from which the job will be run") do |dir|
  options[:cwd] = dir
end
opts.on("-p","--priority [INT]","Set priority of jobs (1 is default, 0 is lowest, higher is more important)") do |i|
  options[:priority] = i.to_i
end
opts.on("-d","--delay [DELAY]","Delay submitting jobs by DELAY minutes at a time") do |delay|
  options[:delay] = delay.to_i
end
opts.on("-g","--group [SIZE]","Submits groups of jobs in SIZEed hunks") do |size|
  options[:group_size] = size.to_i
end
opts.on("-l","--queue [LENGTH]","How many jobs to put into queue until we stop delaying") do |length|
  options[:length] = length.to_i
end
opts.on("-q","Send quit command to workers") do
  id = SecureRandom.uuid
  msg = {:payload=>'quit',:id=>id}.to_json
  error_check push.send_string(msg)
  push.close
  context.terminate
  exit(0)
end
opts.parse!
unless options[:job_type] && options[:cwd]
  STDERR.puts opts.help()
  exit(1)
end

  start_port = 5100
  num_submitted = 0
  ARGV.each do |id|
    next if already_finished?(options[:cwd],id)
    msg_id = SecureRandom.uuid
    payload = {
      :sample_id=>id,
      :cwd=>options[:cwd],
      :port=>start_port,
      :job_type=>options[:job_type]
    }
    msg = {:payload=>payload, :id=>msg_id, :priority=>options[:priority]}.to_json
    error_check push.send_string(msg)
    num_submitted+=1
    puts "Sent #{msg}"
    start_port += 25
    if options[:delay] > 0 && options[:length] > 0 && (num_submitted % options[:group_size]) == 0
      sleep(60*options[:delay]) unless num_submitted == ARGV.size
    end
    options[:length]-=1
  end
  puts "Submitted #{num_submitted} jobs"
push.close
context.terminate
