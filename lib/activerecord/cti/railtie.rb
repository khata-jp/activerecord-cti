module Activerecord
  module Cti
    if defined?(Rails)
      class Railtie < ::Rails::Railtie
      end
    end
  end
end
