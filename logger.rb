require 'ffi-rzmq'
require 'securerandom'
require 'json'
require 'colorize'

@producer_host = ARGV.pop

Thread.abort_on_exception = true

jobs_mutex = Mutex.new

jobs_to_run = []
job_statii = {}
jobs_running = []
shutdown_workers = false

Signal.trap("USR1") do
  STDERR.puts <<-EOF
#{jobs_to_run.size} jobs in queue
#{jobs_running.size} jobs running
#{jobs_to_run.first} is next job

EOF
end

context = ZMQ::Context.new

logger = Thread.new do
  STDOUT.sync = true
  incoming_results = context.socket(ZMQ::PULL)
  ARGV.each do |worker_host|
    incoming_results.connect("tcp://#{worker_host}:3555")
  end

  msg = ''
  while incoming_results.recv_string(msg)
    next if '' == msg
    payload = JSON.parse(msg)
    jobs_mutex.synchronize do
      unless -1 == payload['id']
        next unless jobs_running.include?(payload['id'])
        jobs_running.delete(payload['id'])
        job_statii[payload['id']][:finished_at] = Time.now
        payload[:run_time_hrs] = (job_statii[payload['id']][:finished_at] - job_statii[payload['id']][:started_at])/3600
      end
    end
    color = if payload && payload[:status] && payload[:status][:exit_status] && 0 != payload[:status][:exit_status]
              :red
            else
              :default
            end
    puts payload.to_json.to_s.colorize(color)
    msg = ''
  end
end

job_receiver = Thread.new do
  incoming_job = context.socket(ZMQ::PULL)
  incoming_job.connect("tcp://#{@producer_host}")

  msg = ''
  while incoming_job.recv_string(msg)
    next if '' == msg
    payload = {:priority=>0}.merge(JSON.parse(msg))
    if 'quit' == payload['payload'] then
      shutdown_workers = true
      break
    end
    jobs_mutex.synchronize do
      if !jobs_running.include?(payload['id']) && !jobs_to_run.find{|j| j[:id] == payload['id']}
        jobs_to_run << {:id => payload['id'], :priority => payload[:priority]}
        jobs_to_run.sort! {|a,b| b[:priority] <=> a[:priority]}
        job_statii[payload['id']] = {:payload => payload, :received_at => Time.now}
      end
    end
  end
end

job_controller = context.socket(ZMQ::REP)
job_controller.bind('tcp://*:3557')

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
      jobs_running << work_to_do[:id]
      job_statii[work_to_do[:id]][:started_at] = Time.now
      work_to_do = job_statii[work_to_do[:id]][:payload]
    else
      work_to_do = {'id' => nil}
    end
  end
  job_controller.send_string(work_to_do.to_json)
end
