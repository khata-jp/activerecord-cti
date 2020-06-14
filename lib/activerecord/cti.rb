require "activerecord/cti/railtie"

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
          subclass.send(:default_scope, lambda{ joins("INNER JOIN #{superclass_table_name} ON #{table_name}.#{superclass_foreign_key} = #{superclass_table_name}.id").select(default_select_columns) })
        end
      end
    end

    module SubClass
      extend ActiveSupport::Concern

      class_methods do
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

        def superclass_name
          superclass.to_s
        end

        def superclass_table_name
          superclass_name.tableize
        end

        def subclass_table_name
          table_name
        end

        def superclass_foreign_key
          superclass.to_s.foreign_key
        end

        def default_select_columns
          ((superclass_column_names - [primary_key]).collect do |key|
            "#{superclass_table_name}.#{key}"
          end + subclass_column_names.collect do |key|
            "#{subclass_table_name}.#{key}"
          end).join(',')
        end

        def find_by(*args)
          unless subclass_column_names.include?(args.first.keys.first)
            args = [{"#{superclass_table_name}.#{args.first.keys.first.to_s}": args.first.values.first}]
          end
          super
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
            connection.schema_cache.columns_hash(superclass_table_name).except(*superclass_ignored_columns)
          end

          def superclass_column_names
            superclass_columns_hash.keys
          end

          def subclass_columns_hash
            connection.schema_cache.columns_hash(subclass_table_name).except(*subclass_ignored_columns)
          end

          def subclass_column_names
            subclass_columns_hash.keys
          end

          def superclass_ignored_columns
            ["created_at", "updated_at"]
          end

          def subclass_ignored_columns
            [superclass_foreign_key]
          end
      end #end of class_methods

      def save(*args, &block)
        superclass_instance_for_write = superclass_for_write.new(
          attributes.slice(*superclass_for_write.column_names), &block
        )
        subclass_instance_for_write = subclass_for_write.new(
          attributes.except(*superclass_for_write.column_names), &block
        )
        ActiveRecord::Base.transaction do
          superclass_instance_for_write.save
          subclass_instance_for_write.send("#{self.class.superclass_foreign_key}=", superclass_instance_for_write.id)
          subclass_instance_for_write.save
        end

        self.id = subclass_instance_for_write.id

        superclass_instance_for_write.id.present? and subclass_instance_for_write.id.present?
      rescue ActiveRecord::RecordInvalid
        false
      end

      private
        def superclass_for_write
          table_name = self.class.superclass_table_name
          @superclass_for_write || @superclass_for_write = Class.new(ActiveRecord::Base) do
            self.table_name = table_name
          end
        end

        def subclass_for_write
          table_name = self.class.subclass_table_name
          @subclass_for_write || @subclass_for_write = Class.new(ActiveRecord::Base) do
            self.table_name = table_name
          end
        end
    end
  end
end
