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

    ActiveRecord::Base.connection.execute 'insert into auto_incrementers (id,name) values (10,"E")'
    assert_equal [1,2,3,5,10],AutoIncrementer.all.collect(&:id)
    assert_equal %w(A B C D E),AutoIncrementer.all.collect(&:name)

    # TODO figure out how to test this... ActiveRecord::StatementInvalid: Mysql2::Error: SAVEPOINT active_record_1 does not exist: ROLLBACK TO SAVEPOINT active_record_1
    #Batchit::Context.model_shadow_map[AutoIncrementer] = nil
    #Batchit::Context.model_infile_map[AutoIncrementer] = nil
    #AutoIncrementer.ensure_shadow
    #AutoIncrementer.create!(name: 'F')
    #assert_equal [1,2,3,5,10,12],AutoIncrementer.all.collect(&:id)
    #assert_equal %w(A B C D E F),AutoIncrementer.all.collect(&:name)

  end

end