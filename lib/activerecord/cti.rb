require "activerecord/cti/railtie"

module ActiveRecord
  module Cti
    module BaseClass
      extend ActiveSupport::Concern

      class_methods do

        def inherited(obj)
          super
          puts "inherited"
          puts self
          puts obj
          #if obj.is_cti_base_class?
            class << obj
              include ActiveRecord::Cti::SubClass
            end

            obj.class_eval do
              def save(*args, &block)
                save_superclass(*args, &block)
                save_subclass({
                  "#{self.class.superclass.to_s.foreign_key}": id
                }, &block)
              rescue ActiveRecord::RecordInvalid
                false
              end

              private
              def save_superclass(*args, &block)
                create_or_update(*args, &block)
              end

              def save_subclass(*args, &block)
                table_name = self.class.to_s.underscore.pluralize
                Class.new(ApplicationRecord) do
                  self.table_name = table_name
                end.new(*args, &block).save
              end
            end

            #class << obj.connection.schema_cache
            #  include ActiveRecord::Cti::ConnectionAdapters::SchemaCache
            #end
          #else
          #  puts "is not cti base class"
          #end
        end

      end
    end

    module SubClass

      # Generates all the attribute related methods for columns in the database
      # accessors, mutators and query methods.
      def define_attribute_methods # :nodoc:
        return false if @attribute_methods_generated
        # Use a mutex; we don't want two threads simultaneously trying to define
        # attribute methods.
        generated_attribute_methods.synchronize do
          return false if @attribute_methods_generated
          @attribute_methods_generated = true
        end
      end
        
      private

      def load_schema!
        @columns_hash = superclass_columns_hash.merge(subclass_columns_hash)
        @columns_hash.each do |name, column|
          define_attribute(
            name,
            connection.lookup_cast_type_from_column(column),
            default: column.default,
            user_provided_default: false
          )
        end
      end

      def superclass_columns_hash
        base_class? ? {} : connection.schema_cache.columns_hash(superclass.to_s.underscore.pluralize).except(*superclass_ignored_columns)
      end

      def subclass_columns_hash
        connection.schema_cache.columns_hash(self.to_s.underscore.pluralize).except(*subclass_ignored_columns)
      end

      def superclass_ignored_columns
        ["created_at", "updated_at"]
      end

      def subclass_ignored_columns
        [superclass.to_s.foreign_key]
      end

    end

  end

end
