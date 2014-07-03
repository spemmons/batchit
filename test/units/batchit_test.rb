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
    assert_equal [ChildModel],Batchit::Context.instance.model_infile_map.keys
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
      assert_equal ["#{@child.id}\tD\n"],File.readlines(ChildModel.infile.path)

      Batchit::Context.instance.stop_batching_all_infiles
      assert !File.exist?(ChildModel.infile.path)
    end

    assert_no_difference 'ChildModel.count' do
      @child.update_attributes!(name: 'E')
      assert_equal ({'id' => @child.id,'name' => 'E'}),ChildModel.find(@child.id).attributes

      ChildModel.start_batching

      @child.update_attributes!(name: 'F')
      assert_equal ({'id' => @child.id,'name' => 'E'}),ChildModel.find(@child.id).attributes

      ChildModel.stop_batching
      assert_equal ({'id' => @child.id,'name' => 'F'}),ChildModel.find(@child.id).attributes
    end

  end

end
