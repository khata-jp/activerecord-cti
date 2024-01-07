module ActiveRecord
  module Cti
    module SubClass
      extend ActiveSupport::Concern

      included do
        self.table_name = subclass_table_name
        default_scope {
          from("#{subclass_table_name},#{superclass_table_name}")
          .where("#{subclass_table_name}.#{foreign_key_name} = #{superclass_table_name}.id")
          .select(default_select_columns) }

        # Define dinamically to_* methods, which convert self to other subclass has same CTI superclass.
        models_dir_path = defined?(Rails) ? "#{Rails.root}/app/models" : ENV['APP_MODELS_DIR_PATH']
        Pathname.glob("#{models_dir_path}/*").collect do
          |path| path.basename.to_s.split('.').first.classify.safe_constantize
        end.compact.delete_if do |model|
          model.superclass != self.superclass
        end.each do |model|
          define_method("to_#{model.to_s.underscore}") do |args = {}|
            model_instance = model.new(args)
            model_instance.attributes = attributes.slice(*super_table_model.column_names - [@primary_key])
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
          to_s.tableize
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

        def where(*args)
          if args.first.is_a?(Hash)
            hash = {}
            args.first.each do |key, value|
              unless subclass_column_names.include?(key)
                hash["#{superclass_table_name}.#{key}".to_sym] = value
              end
            end
            *args = hash
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
        _super_table_model_instance = super_table_model_instance
        _sub_table_model_instance = sub_table_model_instance
        ActiveRecord::Base.transaction do
          _super_table_model_instance.send(:create_or_update)
          _sub_table_model_instance.send("#{foreign_key_name}=", _super_table_model_instance.id)
          _sub_table_model_instance.send(:create_or_update)
        end
        self.id = _sub_table_model_instance.id
        _super_table_model_instance.id.present? and _sub_table_model_instance.id.present?
      rescue ActiveRecord::RecordInvalid
        false
      end

      private
        def super_table_model_instance(*args, &block)
          if foreign_key_value.present?
            super_table_model_instance = super_table_model.find(foreign_key_value)
            super_table_model_instance.attributes = attributes.slice(*super_table_model.column_names - [@primary_key])
            super_table_model_instance
          else
            super_table_model.new(attributes.slice(*super_table_model.column_names), &block)
          end
        end

        def sub_table_model_instance(*args, &block)
          if self.id.present?
            sub_table_model_instance = sub_table_model.find(self.id)
            sub_table_model_instance.attributes = attributes.except(*super_table_model.column_names)
            sub_table_model_instance
          else
            sub_table_model.new(attributes.except(*super_table_model.column_names), &block)
          end
        end

        def foreign_key_name
          self.class.foreign_key_name
        end

        def foreign_key_value
          return @foreign_key_value if @foreign_key_value.present?
          return nil if self.id.nil?
          @foreign_key = sub_table_model.find(self.id)&.send(foreign_key_name)
        end

        def foreign_key_value=(value)
          @foreign_key_value = value
        end

        def super_table_model
          table_name = self.class.superclass_table_name
          @super_table_model || @super_table_model = Class.new(ActiveRecord::Base) do
            self.table_name = table_name
          end
        end

        def sub_table_model
          table_name = self.class.subclass_table_name
          @sub_table_model || @sub_table_model = Class.new(ActiveRecord::Base) do
            self.table_name = table_name
          end
        end
    end
  end
end
