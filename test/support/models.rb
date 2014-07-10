ActiveRecord::Schema.define do

  ActiveRecord::Base.connection.tables.each{|table_name| ActiveRecord::Base.connection.drop_table table_name}

  create_table :parent_models do |t|
    t.integer :child_id
    t.string  :name
  end

  create_table :child_models do |t|
    t.string  :name
    t.string  :extra
  end

  create_table :other_models do |t|
    t.string :a
    t.string :b
  end

end

class ParentModel < ActiveRecord::Base

  belongs_to :child,class_name: 'ChildModel'

  attr_accessible :name,:child,:child_id

end

class ChildModel < ActiveRecord::Base

  include Batchit::BatchingSupport

  attr_accessible :name,:extra
  
  attr_reader :before_create_counter,:after_create_counter

  before_create :before_create_placeholder
  def before_create_placeholder
    @before_create_counter += 1
  end

  after_create :after_create_placeholder
  def after_create_placeholder; @after_create_counter += 1; end

  attr_reader :before_update_counter,:after_update_counter

  before_update :before_update_placeholder
  def before_update_placeholder; @before_update_counter += 1; end

  after_update :after_update_placeholder
  def after_update_placeholder; @after_update_counter += 1; end

  attr_reader :before_save_counter,:after_save_counter

  before_save :before_save_placeholder
  def before_save_placeholder; @before_save_counter += 1; end

  after_save :after_save_placeholder
  def after_save_placeholder; @after_save_counter += 1; end
  
  def initialize(*args)
    super(*args)
    @before_create_counter,@after_create_counter  = 0,0
    @before_update_counter,@after_update_counter  = 0,0
    @before_save_counter,@after_save_counter      = 0,0
  end

end

class OtherModel < ActiveRecord::Base

  include Batchit::BatchingSupport

end