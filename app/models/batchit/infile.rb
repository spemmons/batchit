module Batchit
  class Infile

    attr_reader :model,:file,:path,:record_count,:start_time,:stop_time

    def initialize(model)
      @model = model
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
      @path = Context.infile_root + Time.zone.now.strftime("tmp/#{@model.to_s.underscore}_#{Process.pid}_%Y%m%d%H%M%S.tsv")
      FileUtils.mkdir_p(File.dirname(@path))
      @file = File.open(@path,'w')
    end

    def add_record(object)
      case object
        when Hash   then add_attributes(object.inject({}){|hash,pair| hash[pair.first.name.to_s] = pair.last; hash})
        when @model then add_attributes(object.attributes)
        else raise "invalid object type: #{object.class}"
      end
    end

    def add_attributes(attributes)
      @record_count += 1
      @file.puts build_output_line(attributes)
    end

    def stop_batching
      flush_infile
      Rails.logger.info "#{(@stop_time = Time.zone.now).to_s(:db)} - INFILE #{@model} records: #{@record_count} duration: #{(@stop_time - @start_time).to_i}s"
    end

    def build_output_line(attributes)
      @model.column_names.collect{|key| value = attributes[key]; value ? value.to_s.gsub(/\t/,' ').gsub(/\\/,'\\\\') : '\\N'}.join("\t")
    end

    def flush_infile
      @file.close
      @file = nil
      @model.connection.execute load_infile_statement
      File.delete(@path)

    ensure
      @file.close if @file
      @file = nil
    end

    def load_infile_statement
      "load data infile '#{@path}' into table #{@model.table_name} fields terminated by '\\t' escaped by '\\\\'"
    end

  end
end