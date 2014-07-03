module Batchit
  class Infile

    attr_reader :model,:file,:path,:ignore,:record_count,:start_time,:stop_time

    def initialize(model,ignore = true)
      @model,@ignore = model,ignore
    end

    def is_batching?
      !!@file
    end

    def start_batching
      raise 'infile already started' if @file
      @record_count = 0
      @start_time = Time.zone.now
      @stop_time = nil
      @path = Context.instance.infile_root + Time.zone.now.strftime("tmp/#{@model.to_s.underscore}_#{Process.pid}_%Y%m%d%H%M%S.tsv")
      FileUtils.mkdir_p(File.dirname(@path))
      @file = File.open(@path,'w')
    end

    def add_to_infile(object)
      @record_count += 1
      @file.puts object.attributes.values.collect{|value| value ? value.to_s.gsub(/\t/,' ').gsub(/\\/,'\\\\') : '\\N'}.join("\t")

    rescue
      log_error($!,$@)
    end

    def stop_batching
      @file.close
      @file = nil
      @model.connection.execute "load data infile '#{@path}' #{@ignore ? 'ignore' : 'replace'} into table #{@model.table_name} fields terminated by '\\t' escaped by '\\\\'"
      File.delete(@path)
      Rails.logger.info "#{(@stop_time = Time.zone.now).to_s(:db)} - #{@model} records: #{@record_count} duration: #{(@stop_time - @start_time).to_i}s"

    rescue
      log_error($!,$@)

    ensure
      @file.close if @file
      @file = nil
    end

    def log_error(error,backtrace)
      Rails.logger.error %(#{Time.zone.now.to_s(:db)} - #{@model} ERROR: #{error}\n#{backtrace.join("\n")})
      nil
    end

  end
end