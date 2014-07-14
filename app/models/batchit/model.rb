module Batchit
  module Model
    extend ActiveSupport::Concern

    included do

      Context.add_model(self)

    end

    module ClassMethods

      def infile
        Context.model_infile_map[self]
      end

      def shadow
        Context.model_shadow_map[self]
      end

      def is_batching?
        !!infile && infile.is_batching?
      end

      def start_batching
        Context.model_updates_map[self] = {}
        infile && infile.start_batching
      end

      def stop_batching
        infile.stop_batching
        Context.model_updates_map[self].each do |key,attributes|
          update_statement = unscoped.where(arel_table[primary_key].eq(key)).arel.compile_update(attributes)
          connection.update update_statement
        end
        Context.model_updates_map[self] = nil
      end

      def ensure_shadow
        Context.sync_model(self)
      end

    end

    def create
      self.id ||= self.class.shadow.next_id if self.class.shadow
      super
    end

    def update(attribute_names = @attributes.keys)
      @hijack_update = self.class.infile && self.class.infile.is_batching?
      super(attribute_names)
    ensure
      @hijack_update = false
    end

    def arel_attributes_values(include_primary_key = true, include_readonly_attributes = true, attribute_names = @attributes.keys)
      attribute_values = super(include_primary_key,include_readonly_attributes,attribute_names)
      if @hijack_update and attribute_values.any? and (update_cache = Context.model_updates_map[self.class])
        update_cache[self.id] = (update_cache[self.id] || {}).merge(attribute_values)
        attribute_values = []
      end
      attribute_values
    end

  end

end