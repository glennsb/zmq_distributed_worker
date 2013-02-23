require 'ffi-rzmq'
#require 'omrf/logged_external_command'
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

context     = ZMQ::Context.new
push        = context.socket(ZMQ::PUSH)
#error_check(push.setsockopt(ZMQ::LINGER, 0))
error_check push.bind 'tcp://127.0.0.1:5556'
 
msg = ARGV.shift if ARGV.size > 0

id = SecureRandom.uuid
msg = {:payload=>msg,:id=>id}.to_json
error_check push.send_string(msg)
puts "Sent #{msg}"
push.close
context.terminate
