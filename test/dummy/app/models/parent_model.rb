class ParentModel < ActiveRecord::Base

  belongs_to :child,class_name: ChildModel.to_s

  attr_accessible :name,:child,:child_id

end