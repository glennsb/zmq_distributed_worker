require 'ffi-rzmq'
require 'securerandom'
require 'json'

def error_check(rc)
  if ZMQ::Util.resultcode_ok?(rc)
    false
  else
    STDERR.puts "Operation failed, errno [#{ZMQ::Util.errno}] description [#{ZMQ::Util.error_string}]"
    caller(1).each { |callstack| STDERR.puts(callstack) }
    true
  end
end

context = ZMQ::Context.new
push = context.socket(ZMQ::PUSH)
#error_check(push.setsockopt(ZMQ::LINGER, 0))
error_check push.bind 'tcp://127.0.0.1:5556'
 
cwd = ARGV.shift
raise "Missing cwd param" unless cwd
if "quit" == cwd
  id = SecureRandom.uuid
  msg = {:payload=>'quit',:id=>id}.to_json
  error_check push.send_string(msg)
else
  ARGV.each do |id|
    msg_id = SecureRandom.uuid
    msg = {:payload=>{:sample_id=>id,:cwd=>cwd},:id=>msg_id}.to_json
    error_check push.send_string(msg)
    puts "Sent #{msg}"
  end
end
push.close
context.terminate