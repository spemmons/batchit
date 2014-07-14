require 'singleton'

module Batchit
  module Context

    mattr_reader :model_infile_map,:model_shadow_map,:model_updates_map
    @@model_infile_map,@@model_shadow_map,@@model_updates_map = {},{},{}

    def self.add_model(model)
      add_infile(model) if add_shadow(model)
    end

    # INFILE methods

    def self.infile_root
      Rails.root
    end

    def self.add_infile(model)
      raise "infile already exists for #{model}" if @@model_infile_map[model]
      @@model_infile_map[model] = Infile.new(model)
    end

    def self.start_batching_all_models
      @@model_infile_map.keys.collect(&:start_batching)
    end

    def self.stop_batching_all_models
      @@model_infile_map.keys.collect(&:stop_batching)
    end

    # SHADOW methods

    def self.sync_all_models
      #:nocov: this cannot be tested since the setup for the other tests means NOT insisting on a fully-synced environment
      ensure_shadow_for_all_models
      cleanup_unused_shadows
      #:nocov:
    end

    def self.ensure_shadow_for_all_models
      #:nocov: this cannot be tested since the setup for the other tests means NOT insisting on a fully-synced environment
      ActiveRecord::Base.connection.tables.each do |table_name|
        next unless model_class = eval("defined?(#{model_class_name}) ? #{model_class_name} : nil")

        model_class.ensure_shadow if model_class.respond_to?(:ensure_shadow)
      end
      #:nocov:
    end

    def self.cleanup_unused_shadows
      ActiveRecord::Base.connection.tables.each do |shadow_table_name|
        next unless shadow_table_name =~ /^(.*)_shadows$/

        model_name_part = $1
        model_table_name = model_name_part.pluralize
        model_class_name = model_name_part.classify
        shadow_class_name = shadow_table_name.singularize.classify
        if not (model_class = eval("defined?(#{model_class_name}) ? #{model_class_name} : nil"))
          puts "WARNING: Shadow table #{shadow_table_name} exists but no model class #{model_class_name} exists; drop this table yourself, just in case!"
        elsif not @@model_shadow_map.keys.include?(model_class)
          puts "NOTE: Dropping shadow table #{shadow_table_name} and resetting auto-increment for #{model_table_name}"
          puts "WARNING: Could not reset auto-increment for #{model_table_name}; please investigate!" unless ensure_auto_increment(model_class,true)
          ActiveRecord::Base.connection.drop_table(shadow_table_name) rescue puts "WARNING: could not drop #{shadow_table_name}; please investigate!"
        elsif not @@model_shadow_map[model_class]
          puts "WARNING: Shadow class #{shadow_class_name} should exist for #{model_class}, but is missing; please investigate!"
        end
      end
    end

    def self.sync_model(model)
      if not @@model_shadow_map[model] and ensure_shadow_table_exists(model,true) and ensure_no_auto_increment(model,true)
        add_model(model)

        if model.shadow.nil?
          #:nocov: remove when we can figure out how to test; see TODO
          puts "WARNING: Unable to ensure shadow class for #{model}; please investigate!"
          #:nocov:
        elsif (max_id = model.maximum(model.primary_key)) and max_id >= (shadow_id = model.shadow.next_id)
          #:nocov: remove when we can figure out how to test; see TODO
          puts "NOTE: For #{model}, the shadow class had next_id of #{shadow_id} but the model has max_id of #{max_id}, updating..."
          set_auto_increment_for_table(model,model.shadow.table_name)
          #:nocov:
        end

        puts "NOTE: Batching now enabled for #{model}"
      end
    end

    def self.add_shadow(model)
      raise "shadow already exists for #{model}" if @@model_shadow_map[model]
      if not ensure_shadow_table_exists(model)
        puts "WARNING: Batchit model #{model} has no shadow class; batching is disabled"
      elsif not ensure_no_auto_increment(model)
        puts "WARNING: Batchit model #{model} is still auto-increment; batching is disabled"
      else
        shadow_class = instantiate_shadow_class(model)
      end
      @@model_shadow_map[model] = shadow_class
    end

    def self.ensure_shadow_table_exists(model,force = false)
      return true if shadow_table_exists?(model)
      return false unless force

      shadow_table_name = shadow_table_name_for_model(model)
      ActiveRecord::Schema.define{create_table(shadow_table_name)}
      set_auto_increment_for_table(model,shadow_table_name)
      true
    end

    def self.ensure_no_auto_increment(model,force = false)
      return true unless row = detect_primary_key(model,true)
      return false unless force

      model.connection.execute "alter table #{model.table_name} change #{row[0]} #{row[0]} #{row[1]} not null"
      true
    end

    def self.ensure_auto_increment(model,force = false)
      return true unless row = detect_primary_key(model,false)
      return false unless force

      model.connection.execute "alter table #{model.table_name} change #{row[0]} #{row[0]} #{row[1]} not null auto_increment"
      set_auto_increment_for_table(model,model.table_name)
      true
    end

    def self.instantiate_shadow_class(model)
      eval %(class ::#{model}Shadow < ActiveRecord::Base; def self.next_id; result = unscoped.insert({}); where(id: result).delete_all; result; end; end)
      eval %(::#{model}Shadow)
    end

    def self.shadow_table_exists?(model)
      model.connection.table_exists?(shadow_table_name_for_model(model))
    end

    def self.detect_primary_key(model,equal)
      model.connection.select_rows("show columns from #{model.table_name} where extra #{equal ? '=' : '!='} 'auto_increment'").detect{|row| row[0] == model.primary_key}
    end

    def self.shadow_table_name_for_model(model)
      "#{model.table_name.singularize}_shadows"
    end

    def self.set_auto_increment_for_table(model,table_name)
      model.connection.execute "alter table #{table_name} auto_increment = #{(model.maximum(model.primary_key) || 0) + 1}"
    end

  end
end
