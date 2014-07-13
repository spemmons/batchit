module Batchit
  module Relation

    def insert(values)
      return @klass.infile.add_record(values) if @klass.respond_to?(:is_batching?) and @klass.is_batching?
      super
    end

  end

end

class ActiveRecord::Relation

 prepend Batchit::Relation

end