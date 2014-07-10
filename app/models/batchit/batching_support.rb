module Batchit
  module BatchingSupport
    extend ActiveSupport::Concern

    included do

      Context.instance.add_infile(self)
      Context.instance.add_shadow(self)

      validate :validate_batching_changes

    end

    module ClassMethods

      def infile
        Context.instance.model_infile_map[self]
      end

      def shadow
        Context.instance.model_shadow_map[self]
      end

      def capture_saves?
        @@capture_saves ||= false
      end

      def is_batching?
        capture_saves? && infile.is_batching?
      end

      def start_batching
        start_capturing_saves
        infile.limit_columns(batching_attributes) if batching_attributes.any?
        infile.start_batching
      end

      def stop_batching
        stop_capturing_saves
        infile.stop_batching
      end

      def batching_attributes
        (@@batching_attributes ||= []).dup
      end

      def reset_batching_attributes
        @@batching_attributes = []
      end

      def batching_attribute(*args)
        args = args.collect(&:to_s)
        raise 'no batching attributes defined' if args.compact.empty?
        raise "duplicate batching attributes -- #{args & batching_attributes}" if (args & batching_attributes).any?
        raise "invalid batching attributes -- #{args - self.column_names}" if (args - self.column_names).any?
        raise 'primary key is implied and not a valid limit column' if args.include?(self.primary_key)
        @@batching_attributes += args
      end

      private

      def start_capturing_saves
        @@capture_saves = true
      end

      def stop_capturing_saves
        @@capture_saves = false
      end

    end

    def create
      self.id ||= self.class.shadow.next_id if self.class.primary_key
      if self.class.capture_saves?
        run_callbacks(:create) do
          self.class.infile.add_create(self)

          # NOTE -- the following is mirrored from ActiveRecord::Persistence
          ActiveRecord::IdentityMap.add(self) if ActiveRecord::IdentityMap.enabled?
          @new_record = false
          self.id
        end
      else
        super
      end
    end

    def update(attribute_names = @attributes.keys)
      if self.class.capture_saves?
        run_callbacks(:update) do
          self.class.infile.add_update(self)
        end
      else
        super(attribute_names)
      end
    end

    private

    def validate_batching_changes
      return unless self.class.is_batching? and (restrictions = self.class.batching_attributes).any?

      (changes.keys - restrictions).each{|problem| errors.add(problem,'can not be updated while batching')}
    end

  end

end