require 'test_helper'

class InfileTest < ActiveSupport::TestCase

  test 'support infile on non-batching class' do
    ParentModel.delete_all

    infile = Batchit::Infile.new(ParentModel)

    assert_no_difference 'ParentModel.count' do
      infile.start_batching

      infile.add_record(ParentModel.new(name: 'A'))
      infile.add_record(ParentModel.new(name: 'B'))
      infile.add_record(ParentModel.new(name: 'C'))
      infile.add_record(ParentModel.new(name: 'D'))
    end

    assert_difference 'ParentModel.count',4 do
      infile.stop_batching
    end

    assert_equal %w(A B C D),ParentModel.all.collect(&:name)
  end

end