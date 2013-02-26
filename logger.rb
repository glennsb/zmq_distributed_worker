require 'ffi-rzmq'
#require 'omrf/logged_external_command'
require 'securerandom'
require 'json'

Thread.abort_on_exception = true

jobs_mutex = Mutex.new

jobs_to_run = []
job_statii = {}
jobs_running = []
shutdown_workers = false

context = ZMQ::Context.new

logger = Thread.new do
  incoming_results = context.socket(ZMQ::PULL)
  incoming_results.connect 'tcp://127.0.0.1:5555'
 
  msg = ''
  while incoming_results.recv_string(msg)
    next if '' == msg
    payload = JSON.parse(msg)
    run_time = nil
    jobs_mutex.synchronize do
      unless -1 == payload['id']
        jobs_running.delete(payload['id'])
        job_statii[payload['id']][:finished_at] = Time.now
        run_time = job_statii[payload['id']][:finished_at] - job_statii[payload['id']][:started_at]
      end
    end
    puts "LOG: #{payload['id']}/#{payload['msg']} done took #{run_time}"
    msg = ''
  end
end

job_receiver = Thread.new do
  incoming_job = context.socket(ZMQ::PULL)
  incoming_job.connect('tcp://127.0.0.1:5556')

  msg = ''
  while incoming_job.recv_string(msg)
    next if '' == msg
    payload = JSON.parse(msg)
    if 'quit' == payload['payload'] then
      shutdown_workers = true
      break
    end
    jobs_mutex.synchronize do
      jobs_to_run << payload['id']
      job_statii[payload['id']] = {:payload => payload, :received_at => Time.now}
    end
  end
end

job_controller = context.socket(ZMQ::REP)
job_controller.bind('tcp://127.0.0.1:5557')

while true
  msg = ''
  job_controller.recv_string(msg)
  if shutdown_workers && jobs_to_run.empty? then
    job_controller.send_string({:payload => 'quit', :id=>-1}.to_json)
    next
  end
  work_to_do = nil
  jobs_mutex.synchronize do
    work_to_do = jobs_to_run.shift
    if nil != work_to_do
      jobs_running << work_to_do
      job_statii[work_to_do][:started_at] = Time.now
      work_to_do = job_statii[work_to_do][:payload]
    else
      work_to_do = {'id' => nil}
    end
  end
  job_controller.send_string(work_to_do.to_json)
end
