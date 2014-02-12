require 'rack'

module Rack
  module Limit
    autoload :Request, 'rack/limit/request'
    autoload :Limiter, 'rack/limit/limiter'
    module Backends
      autoload :Redis, 'rack/limit/backends/redis'
      autoload :Memcache, 'rack/limit/backends/memcache'
      autoload :Dalli, 'rack/limit/backends/dalli'
      autoload :MemcacheClient, 'rack/limit/backends/memcache_client'
    end
  end
end
