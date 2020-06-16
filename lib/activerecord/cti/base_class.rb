module ActiveRecord
  module Cti
    module BaseClass
      extend ActiveSupport::Concern

      included do
        self.abstract_class = true
      end

      class_methods do
        def inherited(subclass)
          super
          subclass.include(ActiveRecord::Cti::SubClass)
        end
      end
    end
  end
end
