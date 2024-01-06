require 'active_support/concern'

module ActiveRecord
  module Cti
    module BaseClass
      extend ActiveSupport::Concern

      class_methods do
        def inherited(subclass)
          super
          subclass.include(ActiveRecord::Cti::SubClass)
        end
      end
    end
  end
end
