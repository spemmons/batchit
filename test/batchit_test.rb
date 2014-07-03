require 'test_helper'

class BatchitTest < ActiveSupport::TestCase
  test 'module exists' do
    assert_kind_of Module, Batchit
  end

  test 'parent-child relationship' do
    parent = ParentModel.create!(name: 'A')
    child = ChildModel.create!(name: 'B')
    parent.child = child
    parent.save!

    assert_equal 1,ParentModel.count
    assert_equal 1,ChildModel.count
    assert_equal 1,ParentModel.where(child_id: child.id).count
  end
end
