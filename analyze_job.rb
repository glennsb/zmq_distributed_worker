require 'omrf/logged_external_command'
require 'omrf/fstream_logger'

class AnalyzeJob
  def initialize(base_dir,sample)
    @sample_id = sample
    @base_dir = base_dir
  end
  def execute()
    if "noop" == @sample_id
      return {:exit_status => 0}
    end
    begin
      log_file = File.open(File.join(@base_dir,"logs","#{@sample_id}_full_worker.txt"),"w+")
      log_file.sync = true
      logger = OMRF::FstreamLogger.new(log_file,log_file)
      conf_file = File.join(@base_dir,"..","..","metadata","analysis_config.yml")
      cmd = "analyze_sequence_to_snps.rb -d 0 --local -o #{@base_dir} -c  #{conf_file} #{@sample_id}"
      c = OMRF::LoggedExternalCommand.new(cmd,logger)
      if c.run
        return {:exit_status => 0}
      else
        return {:exit_status => c.exit_status}
      end
      return {:exit_status => -1}
    rescue => err
      return {:exit_status => -1, :trace=>err.backtrace}
    end
  end
end
