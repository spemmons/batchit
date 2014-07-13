require 'singleton'

module Batchit
  class Context
    include Singleton

    attr_reader :model_infile_map,:model_shadow_map,:model_updates_map

    def initialize
      @model_infile_map,@model_shadow_map,@model_updates_map = {},{},{}
    end

    # INFILE methods

    def infile_root
      Rails.root
    end

    def add_infile(model)
      raise "infile already exists for #{model}" if @model_infile_map[model]
      @model_infile_map[model] = Infile.new(model)
    end

    def start_batching_all_models
      @model_infile_map.keys.collect(&:start_batching)
    end

    def stop_batching_all_models
      @model_infile_map.keys.collect(&:stop_batching)
    end

    # SHADOW methods

    def add_shadow(model)
      raise "shadow already exists for #{model}" if @model_shadow_map[model]
      ensure_shadow_table_exists(model)
      ensure_no_auto_increment(model)
      @model_shadow_map[model] = instantiate_shadow_class(model)
    end

    def ensure_shadow_table_exists(model)
      return if model.connection.table_exists?(shadow_table_name = "#{model.table_name.singularize}_shadows")
      ActiveRecord::Schema.define{create_table shadow_table_name}
    end

    def ensure_no_auto_increment(model)
      return unless row = model.connection.select_rows("show columns from #{model.table_name} where extra = 'auto_increment'").detect{|row| row[0] == model.primary_key}
      model.connection.execute "alter table #{model.table_name} change #{row[0]} #{row[0]} #{row[1]} not null"
    end

    def instantiate_shadow_class(model)
      eval %(class ::#{model}Shadow < ActiveRecord::Base; def self.next_id; result = unscoped.insert({}); where(id: result).delete_all; result; end; end)
      eval %(::#{model}Shadow)
    end

  end
end
