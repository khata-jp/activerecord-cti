require "activerecord/cti/railtie"

module ActiveRecord
  module Cti
    module BaseClass
      extend ActiveSupport::Concern

      class_methods do
        #cattr_accessor :cti_superclass
        #attr_writer :is_cti_base_class
        #def is_cti_base_class?
        #  @is_cti_base_class == true
        #end
        #def is_cti_base_class=(boolean)
        #  @is_cti_base_class = boolean
        #  puts "abc"
        #  puts self
        #  puts ""
        #  class << self
        #  #self.class_eval do
        #    include ActiveRecord::Cti::BaseClass
        #  end
        #end

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
      #class_methods do
        def _create_base_class_record(attributes)
          attribute_names = attributes_for_create(attribute_names)

          new_id = self.class._insert_record(
            attributes_with_values(attribute_names)
          )

          #self.id ||= new_id if @primary_key

          #@new_record = false

          #yield(self) if block_given?

          #id
        end

        def create(attributes, &block)
          #base_class = superclass
          #if superklass.is_cti_superclass?
            #base_class_new_id = base_class._insert_record(attributes).id
            #base_class_new_id = base_class._create_record(attributes).id
            #base_class_new_id = _create_base_class_record(attributes)
            #base_class_new_id = base_class.create(attributes)
            #superclass_new_id = base_class? ? super(attributes) : superclass.create(attributes)
            superclass_new_id = superclass.create(attributes).id
            #puts base_class?
            #super(attributes) if base_class?
            #self.class._insert_record({
            #self.class._create_record({
            #  "#{superclass.to_s.foreign_key.to_sym}": base_class_new_id
            #})
            create_subclass(
              "#{superclass.to_s.foreign_key.to_sym}": superclass_new_id
            )
            #n.create_or_update

            #super(
            #  {
            #    "#{superclass.to_s.foreign_key.to_sym}": superclass_new_id
            #  },
            #  &block
            #)
          #else
          #  super
          #end
        end
      #end

      #todo: how to overwrite 'save'
      #def save(*args, &block)
      #  superclass_new_id = create_or_update(*args, &block).id
      #  c = Class.new(ApplicationRecord)
      #  c.table_name = self.to_s.underscore.pluralize
      #  c.create_or_update(
      #    "#{superclass.to_s.foreign_key.to_sym}": superclass_new_id
      #  )
      #rescue ActiveRecord::RecordInvalid
      #  false
      #end

      def create_subclass(attributes)
        #table_name = self.to_s.underscore.pluralize
        #puts "table_name"
        #puts table_name
        puts attributes
        c = Class.new(ApplicationRecord)
        c.table_name = self.to_s.underscore.pluralize
        c.new(
          attributes
        ).save
      end
        
      def load_schema!
        puts "zzz_ggg"
        @columns_hash_1 = base_class? ? {} : connection.schema_cache.columns_hash(self.superclass.to_s.underscore.pluralize).except(*ignored_columns)
        puts "zzz_hhh"
        @columns_hash_2 = connection.schema_cache.columns_hash(self.to_s.underscore.pluralize).except(*ignored_columns)
        puts "zzz_iii"
        @columns_hash = @columns_hash_1.merge(@columns_hash_2)
        @columns_hash.each do |name, column|
          define_attribute(
            name,
            connection.lookup_cast_type_from_column(column),
            default: column.default,
            user_provided_default: false
          )
        end
      end

      # Generates all the attribute related methods for columns in the database
      # accessors, mutators and query methods.
      def define_attribute_methods # :nodoc:
        puts "zzz_1"
        return false if @attribute_methods_generated
        puts "zzz_2"
        # Use a mutex; we don't want two threads simultaneously trying to define
        # attribute methods.
        generated_attribute_methods.synchronize do
          puts "zzz_3"
          return false if @attribute_methods_generated
          puts "zzz_4"
          #superclass.define_attribute_methods unless base_class?
          puts "zzz_5"
          puts superclass
          #super(attribute_names)
          puts "zzz_6"
          @attribute_methods_generated = true
        end
      end
    end

    #module ConnectionAdapters
    #  module SchemaCache
    #    # Get the columns for a table as a hash, key is the column name
    #    # value is the column object.
    #    def columns_hash(model)
    #      @columns_hash[model.to_s] ||= Hash[columns(model.superclass.to_s.underscore.pluralize).map { |col|
    #        [col.name, col]
    #      }].merge(Hash[columns(model.to_s.underscore.pluralize).map { |col|
    #        [col.name, col]
    #      }])
    #    end
    #  end
    #end
  end

  #module Inheritance
  #  class_methods do
  #    def create(attributes, &block)
  #      superklass = superclass
  #      if superklass.is_cti_superclass?
  #        superclass_new_id = superklass.create(attributes).id
  #        super(
  #          {
  #            "#{superclass.to_s.foreign_key.to_sym}": superclass_new_id
  #          },
  #          &block
  #        )
  #      else
  #        super
  #      end
  #    end
  #  end
  #end
end
