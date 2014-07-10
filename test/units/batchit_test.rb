require 'test_helper'

class BatchitTest < ActiveSupport::TestCase

  test 'module exists' do
    assert_kind_of Module, Batchit
  end

  test 'parent-child relationship' do
    assert_difference 'ParentModel.count' do
      assert_difference 'ChildModel.count' do
        parent = ParentModel.create!(name: 'A')
        child = ChildModel.create!(name: 'B')
        parent.child = child
        parent.save!
        assert_equal 1,ParentModel.where(child_id: child.id).count
      end
    end
  end

  test 'batching support' do
    assert_equal Batchit::Infile,ChildModel.infile.class
    assert_equal [ChildModel,OtherModel],Batchit::Context.instance.model_infile_map.keys
  end

  test 'infile attributes' do
    assert_equal false,ParentModel.respond_to?(:infile)

    infile = Batchit::Infile.new(ParentModel)
    assert_equal ParentModel,infile.model
    assert_nil infile.file
    assert_nil infile.path
    assert_nil infile.record_count
    assert_nil infile.start_time
    assert_nil infile.stop_time
    assert_equal false,infile.is_batching?

    infile.start_batching
    assert_equal File,infile.file.class
    assert_match /\.tsv$/,infile.path.to_s
    assert_equal 0,infile.record_count
    assert_match /\d\d\d\-\d\d\-\d\d \d\d:\d\d:\d\d/,infile.start_time.to_s(:db)
    assert_nil infile.stop_time
    assert_equal true,infile.is_batching?

    infile.stop_batching
    assert_nil infile.file
    assert_match /\.tsv$/,infile.path.to_s
    assert_equal 0,infile.record_count
    assert_match /\d\d\d\-\d\d\-\d\d \d\d:\d\d:\d\d/,infile.start_time.to_s(:db)
    assert_match /\d\d\d\-\d\d\-\d\d \d\d:\d\d:\d\d/,infile.stop_time.to_s(:db)
    assert_equal false,infile.is_batching?
  end

  test 'batching context' do

    assert_difference 'ChildModel.count' do
      ChildModel.create!(name: 'C')
    end

    assert_no_difference 'ChildModel.count' do
      Batchit::Context.instance.start_batching_all_infiles

      @child = ChildModel.create!(name: 'D')
    end

    assert ChildModel.is_batching?

    assert_difference 'ChildModel.count' do
      ChildModel.infile.file.flush
      assert_equal ["#{@child.id}\tD\t\\N\n"],File.readlines(ChildModel.infile.path)

      Batchit::Context.instance.stop_batching_all_infiles
      assert !File.exist?(ChildModel.infile.path)
    end

    assert_no_difference 'ChildModel.count' do
      @child.update_attributes!(name: 'E')
      assert_equal ({'id' => @child.id,'name' => 'E','extra' => nil}),ChildModel.find(@child.id).attributes

      ChildModel.start_batching

      @child.update_attributes!(name: 'F')
      assert_equal ({'id' => @child.id,'name' => 'E','extra' => nil}),ChildModel.find(@child.id).attributes

      ChildModel.stop_batching
      assert_equal ({'id' => @child.id,'name' => 'F','extra' => nil}),ChildModel.find(@child.id).attributes
    end

  end

  test 'ensure valid batch update attributes' do
    assert_equal [],ChildModel.batching_attributes

    assert_raises_string 'primary key is implied and not a valid limit column' do
      ChildModel.batching_attribute :id
    end

    ChildModel.batching_attribute :name
    assert_equal %w(name),ChildModel.batching_attributes

    assert_no_difference 'ChildModel.count' do
      ChildModel.start_batching
      assert_raises_string('Validation failed: Extra can not be updated while batching') do
        ChildModel.create!(name: 'test',extra: 'skip')
      end
      @child = ChildModel.create!(name: 'test')
    end
    assert_difference 'ChildModel.count' do
      ChildModel.infile.file.flush
      assert_equal ["#{@child.id}\ttest\n"],File.readlines(ChildModel.infile.path)
      ChildModel.stop_batching
    end
    child = ChildModel.last
    assert_equal @child.id,child.id

    ChildModel.batching_attribute 'extra'
    assert_equal %w(name extra),ChildModel.batching_attributes

    assert_raises_string('duplicate batching attributes -- ["name", "extra"]') do
      ChildModel.batching_attribute *ChildModel.column_names
    end

    ChildModel.reset_batching_attributes
    assert_equal [],ChildModel.batching_attributes

    assert_raises_string('invalid batching attributes -- ["wrong"]') do
      ChildModel.batching_attribute 'wrong'
    end

    ChildModel.reset_batching_attributes
  end

  test 'ensure callbacks are called' do
    assert !ChildModel.is_batching?

    child1 = ChildModel.new(name: 'A1')
    check_callback_counters(child1,1,0,1) do
      child1.save!
    end
    check_callback_counters(child1,0,1,1) {child1.update_attributes(name: 'A2')}

    ChildModel.start_batching

    child2 = ChildModel.new(name: 'B1')
    check_callback_counters(child2,1,0,1) {child2.save!}
    check_callback_counters(child2,0,1,1) {child2.update_attributes(name: 'B2')}
    check_callback_counters(child1,0,1,1) {child1.update_attributes(name: 'A3')}

    ChildModel.stop_batching
  end
  
  def check_callback_counters(object,create_change,update_change,save_change,&block)
    assert_difference 'object.before_create_counter',create_change do
      assert_difference 'object.after_create_counter',create_change do
        assert_difference 'object.before_update_counter',update_change do
          assert_difference 'object.after_update_counter',update_change do
            assert_difference 'object.before_save_counter',save_change do
              assert_difference 'object.after_save_counter',save_change do
                block.call
              end
            end
          end
        end
      end
    end
  end

end
