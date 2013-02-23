require 'ffi-rzmq'
#require 'omrf/logged_external_command'
require 'securerandom'

context     = ZMQ::Context.new
pull        = context.socket(ZMQ::PULL)
pull.connect 'tcp://127.0.0.1:5555'
 
msg = ''
while pull.recv_string(msg)
  puts msg
  msg = ''
end
