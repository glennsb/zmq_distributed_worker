require 'omrf/logged_external_command'
require 'omrf/fstream_logger'

class FrfastJob
  def initialize(base_dir,sample,base_port)
    @sample_id = sample
    @base_dir = base_dir
    @base_port = base_port
  end
  def execute()
    if File.exists?("#{@base_dir}/read_depth/#{@sample_id}.hdf5")
      return {:exit_status => 0}
    end
    begin
      log_dir = File.join(@base_dir,"logs",@sample_id)
      unless File.exists?(log_dir)
        Dir.mkdir(log_dir)
      end
      log_file = File.open(File.join(log_dir,"#{@sample_id}_full_worker.txt"),"w+")
      log_file.sync = true
      logger = OMRF::FstreamLogger.new(log_file,log_file)
      cmd = <<-EOF
python2.7 \\
        ~/tmp/20121011_conifer_cnv_test/conifer_cnv_pipeline/controller.py \\
        --source=#{@base_dir}/unaligned_bams/#{@sample_id}/#{@sample_id}.bam \\
        --output=#{@base_dir}/read_depth/#{@sample_id}.hdf5 \\
        --index_dir=/home/glennsb/Downloads/frfast/frfastindex \\
        --index=concatenated.fasta \\
        --translate_table=/home/glennsb/Downloads/frfast/humanseq/targets.translate.txt \\
        --sampleID=#{@sample_id} \\
        --port #{@base_port} \\
        --disable_port_scan \\
        --disable_gui \\
        --timeout 4800 \\
        --log_dir=#{@base_dir}/logs/#{@sample_id}/ \\
        --error_log=#{@base_dir}/logs/#{@sample_id}/mrfast_errorlog.txt
      EOF
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
