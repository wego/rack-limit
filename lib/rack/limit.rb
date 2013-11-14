require 'rack'

module Rack
  module Limit
    autoload :Request, 'rack/limit/request'
    autoload :Limiter, 'rack/limit/limiter'
    module Backends
      autoload :Redis, 'rack/limit/backends/redis'
      autoload :Dalli, 'rack/limit/backends/dalli'
    end
  end
end
