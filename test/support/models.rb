ActiveRecord::Schema.define do

  ActiveRecord::Base.connection.tables.each{|table_name| ActiveRecord::Base.connection.drop_table table_name}

  create_table :parent_models do |t|
    t.integer :child_id
    t.string  :name
  end

  create_table :child_models do |t|
    t.string  :name
  end

end

class ParentModel < ActiveRecord::Base

  belongs_to :child,class_name: 'ChildModel'

  attr_accessible :name,:child,:child_id

end

class ChildModel < ActiveRecord::Base

  include Batchit::BatchingSupport

  attr_accessible :name

end