module Batchit
  module BatchingSupport
    extend ActiveSupport::Concern

    included do

      cattr_reader :infile,:shadow
      @@infile = Context.instance.add_infile(self)
      @@shadow = Context.instance.add_shadow(self)

      validate :validate_batching_changes

    end

    module ClassMethods

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
      self.id ||= shadow.next_id if self.class.primary_key
      if self.class.capture_saves?
        run_callbacks(:create) do
          infile.add_create(self)

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
          infile.add_update(self)
        end
      else
        super(attribute_names)
      end
    end

    private

    def validate_batching_changes
      return unless (restrictions = self.class.batching_attributes).any?

      (changes.keys - restrictions).each{|problem| errors.add(problem,'can not be updated while batching')}
    end

  end

end