require 'rack'

module Rack
  module Limit
    autoload :Limiter, 'rack/limit/limiter'
    module Backends
      autoload :Redis, 'rack/limit/backends/redis'
      autoload :Dalli, 'rack/limit/backends/dalli'
    end
  end
end
