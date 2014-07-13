module Batchit
  module Model
    extend ActiveSupport::Concern

    included do

      Context.instance.add_infile(self)
      Context.instance.add_shadow(self)

    end

    module ClassMethods

      def infile
        Context.instance.model_infile_map[self]
      end

      def shadow
        Context.instance.model_shadow_map[self]
      end

      def is_batching?
        infile.is_batching?
      end

      def start_batching
        Context.instance.model_updates_map[self] = {}
        infile.start_batching
      end

      def stop_batching
        infile.stop_batching
        Context.instance.model_updates_map[self].each do |key,attributes|
          update_statement = unscoped.where(arel_table[primary_key].eq(key)).arel.compile_update(attributes)
          connection.update update_statement
        end
        Context.instance.model_updates_map[self] = nil
      end

    end
    
    def infile
      @infile ||= self.class.infile
    end

    def create
      self.id ||= self.class.shadow.next_id
      super
    end

    def update(attribute_names = @attributes.keys)
      @hijack_update = infile && infile.is_batching?
      super(attribute_names)
    ensure
      @hijack_update = false
    end

    def arel_attributes_values(include_primary_key = true, include_readonly_attributes = true, attribute_names = @attributes.keys)
      attribute_values = super(include_primary_key,include_readonly_attributes,attribute_names)
      if @hijack_update and (update_cache = Context.instance.model_updates_map[self.class])
        update_cache[self.id] = (update_cache[self.id] || {}).merge(attribute_values)
        attribute_values = []
      end
      attribute_values
    end

  end

end