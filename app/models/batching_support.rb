module Batchit
  module BatchingSupport
    extend ActiveSupport::Concern

    included do

      cattr_reader :infile,:shadow
      @@infile = Context.instance.add_infile(self)
      @@shadow = Context.instance.add_shadow(self)

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
        infile.start_batching
      end

      def stop_batching
        stop_capturing_saves
        infile.stop_batching
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

  end

end