module Batchit
  class Infile

    attr_reader :model,:file,:path,:ignore,:collumn_limits,:record_count,:start_time,:stop_time

    def initialize(model,ignore = true)
      @model,@ignore = model,ignore
      @update_cache,@column_limits = {},[]
    end

    def is_batching?
      !!@file
    end

    def limit_columns(column_limits)
      raise 'cannot set limit columns while batching' if is_batching?
      raise "invalid columns -- #{column_limits - @model.column_names}" if column_limits.any? and (column_limits - @model.column_names).any?
      raise 'primary key is implied and not a valid limit column' if column_limits.include?(@model.primary_key)
      @column_limits = column_limits
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
      @model.connection.execute load_infile_statement
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
      values = @column_limits.any? ? object.attributes.values_at(*([@model.primary_key] + @column_limits)) : object.attributes.values
      values.collect{|value| value ? value.to_s.gsub(/\t/,' ').gsub(/\\/,'\\\\') : '\\N'}.join("\t")
    end

    def flush_update_cache
      @update_cache.values.each do |line|
        @file.puts line
        @record_count += 1
      end
      @update_cache = {}
    end

    def load_infile_statement
      "load data infile '#{@path}' #{ignore_clause} into table #{@model.table_name} fields terminated by '\\t' escaped by '\\\\'#{column_limit_clause}"
    end

    def ignore_clause
      @ignore ? 'ignore' : 'replace'
    end

    def column_limit_clause
      " (#{@model.primary_key},#{@column_limits.join(',')})" if @column_limits.any?
    end

  end
end