module Batchit
  class Infile

    attr_reader :model,:file,:path,:ignore,:record_count,:start_time,:stop_time

    def initialize(model,ignore = true)
      @model,@ignore = model,ignore
      @update_cache = {}
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

    def add_create(object)
      @record_count += 1
      @file.puts build_output_line(object)

    rescue
      #:nocov: remove when clear testable scenarios are clear...
      log_error($!,$@)
      #:nocov:
    end

    def add_update(object)
      @update_cache[object.to_param] = build_output_line(object)
    end

    def stop_batching
      flush_update_cache
      @file.close
      @file = nil
      @model.connection.execute "load data infile '#{@path}' #{@ignore ? 'ignore' : 'replace'} into table #{@model.table_name} fields terminated by '\\t' escaped by '\\\\'"
      File.delete(@path)
      Rails.logger.info "#{(@stop_time = Time.zone.now).to_s(:db)} - #{@model} records: #{@record_count} duration: #{(@stop_time - @start_time).to_i}s"

    rescue
      #:nocov: remove when clear testable scenarios are clear...
      log_error($!,$@)
      #:nocov:

    ensure
      @file.close if @file
      @file = nil
    end

    def log_error(error,backtrace)
      #:nocov: remove when clear testable scenarios are clear...
      Rails.logger.error %(#{Time.zone.now.to_s(:db)} - #{@model} ERROR: #{error}\n#{backtrace.join("\n")})
      nil
      #:nocov:
    end

    def build_output_line(object)
      object.attributes.values.collect{|value| value ? value.to_s.gsub(/\t/,' ').gsub(/\\/,'\\\\') : '\\N'}.join("\t")
    end

    def flush_update_cache
      @update_cache.values.each do |line|
        @file.puts line
        @record_count += 1
      end
      @update_cache = {}
    end

  end
end