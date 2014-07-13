require 'test_helper'

class ContextTest < ActiveSupport::TestCase

  test 'previous models can be restored' do

    assert Batchit::Context.ensure_no_auto_increment(PreviousModel,true)

    puts
    assert ActiveRecord::Base.connection.tables.include?('previous_model_shadows')
    Batchit::Context.cleanup_unused_shadows
    assert !ActiveRecord::Base.connection.tables.include?('previous_model_shadows')

    assert Batchit::Context.ensure_auto_increment(PreviousModel)

  end

  test 'ensure auto-increment works on either side of shadow creation' do

    assert_equal [1,2,3],AutoIncrementer.all.collect(&:id)
    assert_equal %w(A B C),AutoIncrementer.all.collect(&:name)

    AutoIncrementer.create!(name: 'D')
    assert_equal [1,2,3,5],AutoIncrementer.all.collect(&:id)
    assert_equal %w(A B C D),AutoIncrementer.all.collect(&:name)

  end

end