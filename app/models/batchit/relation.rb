module Batchit
  module Relation

    def insert(values)
      return @klass.infile.add_record(values) if @klass.respond_to?(:infile) and @klass.infile.is_batching?
      super
    end

  end

end

class ActiveRecord::Relation

 prepend Batchit::Relation

end