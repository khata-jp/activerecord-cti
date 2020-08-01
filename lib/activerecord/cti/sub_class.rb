module ActiveRecord
  module Cti
    module SubClass
      extend ActiveSupport::Concern

      included do
        default_scope { joins("INNER JOIN #{superclass_table_name} ON #{table_name}.#{foreign_key_name} = #{superclass_table_name}.id").select(default_select_columns) }

        # Define dinamically to_* methods, which convert self to other subclass has same CTI superclass.
        Pathname.glob("#{Rails.root}/app/models/*").collect do
          |path| path.basename.to_s.split('.').first.classify.safe_constantize
        end.compact.delete_if do |model|
          !model.superclass.include?(ActiveRecord::Cti::BaseClass) or model == self
        end.each do |model|
          define_method("to_#{model.to_s.underscore}") do |args = {}|
            model_instance = model.new(args)
            model_instance.attributes = attributes.slice(*superclass_for_rw.column_names - [@primary_key])
            model_instance.send(:foreign_key_value=, foreign_key_value)
            model_instance
          end
        end
      end

      class_methods do
        # Generates all the attribute related methods for columns in the database
        # accessors, mutators and query methods.
        def define_attribute_methods # :nodoc:
          return false if @attribute_methods_generated
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

        def foreign_key_name
          superclass.to_s.foreign_key
        end

        # Get columns to pass +joins+ while calling +default_scope+.
        def default_select_columns
          ((superclass_column_names - [primary_key]).collect do |key|
            "#{superclass_table_name}.#{key}"
          end + subclass_column_names.collect do |key|
            "#{subclass_table_name}.#{key}"
          end).join(',')
        end

        def find_by(*args)
          unless subclass_column_names.include?(args.first.keys.first.to_s)
            args = [{"#{superclass_table_name}.#{args.first.keys.first.to_s}": args.first.values.first}]
          end
          super
        end

        def where(opts = :chain, *rest)
          unless subclass_column_names.include?(opts.keys.first.to_s)
            opts = {"#{superclass_table_name}.#{opts.keys.first.to_s}": opts.values.first}
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
            [foreign_key_name]
          end
      end #end of class_methods

      # To save into two related tables while inserting.
      def save(*args, &block)
        _superclass_instance_for_rw = superclass_instance_for_rw
        _subclass_instance_for_rw = subclass_instance_for_rw
        ActiveRecord::Base.transaction do
          _superclass_instance_for_rw.send(:create_or_update)
          _subclass_instance_for_rw.send("#{foreign_key_name}=", _superclass_instance_for_rw.id)
          _subclass_instance_for_rw.send(:create_or_update)
        end
        self.id = _subclass_instance_for_rw.id
        _superclass_instance_for_rw.id.present? and _subclass_instance_for_rw.id.present?
      rescue ActiveRecord::RecordInvalid
        false
      end

      private
        def superclass_instance_for_rw(*args, &block)
          if foreign_key_value.present?
            superclass_instance_for_rw = superclass_for_rw.find(foreign_key_value)
            superclass_instance_for_rw.attributes = attributes.slice(*superclass_for_rw.column_names - [@primary_key])
            superclass_instance_for_rw
          else
            superclass_for_rw.new(attributes.slice(*superclass_for_rw.column_names), &block)
          end
        end

        def subclass_instance_for_rw(*args, &block)
          if self.id.present?
            subclass_instance_for_rw = subclass_for_rw.find(self.id)
            subclass_instance_for_rw.attributes = attributes.except(*superclass_for_rw.column_names)
            subclass_instance_for_rw
          else
            subclass_for_rw.new(attributes.except(*superclass_for_rw.column_names), &block)
          end
        end

        def foreign_key_name
          self.class.foreign_key_name
        end

        def foreign_key_value
          return @foreign_key_value if @foreign_key_value.present?
          return nil if self.id.nil?
          @foreign_key = subclass_for_rw.find(self.id)&.send(foreign_key_name)
        end

        def foreign_key_value=(value)
          @foreign_key_value = value
        end

        def superclass_for_rw
          table_name = self.class.superclass_table_name
          @superclass_for_rw || @superclass_for_rw = Class.new(ActiveRecord::Base) do
            self.table_name = table_name
          end
        end

        def subclass_for_rw
          table_name = self.class.subclass_table_name
          @subclass_for_rw || @subclass_for_rw = Class.new(ActiveRecord::Base) do
            self.table_name = table_name
          end
        end
    end
  end
end
