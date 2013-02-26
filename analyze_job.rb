require 'omrf/logged_external_command'
require 'omrf/fstream_logger'

class AnalyzeJob
  def initialize(base_dir,sample)
    @sample_id = sample
    @base_dir = base_dir
  end
  def execute()
    begin
      Dir.chdir(File.join(@base_dir,@sample_id)) do
        log_file = File.open(File.join("logs","#{@sample_id}_full_worker.txt"),"w+")
        log_file.sync = true
        logger = OMRF::FstreamLogger.new(log_file,log_file)
        cmd = "./analyze.sh"
        c = OMRF::LoggedExternalCommand.new(cmd,logger)
        if c.run
          return {:exit_status => 0}
        else
          return {:exit_status => c.exit_status}
        end
      end
      return {:exit_status => -1}
    rescue => err
      return {:exit_status => -1, :trace=>err.backtrace}
    end
  end
end
