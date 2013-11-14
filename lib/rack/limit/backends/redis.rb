module Rack
  module Limit
    module Backends
      class Redis < Limiter
        def cache_get(request)
          key = cache_key(request)
          count = cache.incr(key)
          cache.expire(key, expiry(request.rule['strategy'])) if count == 1
          count
        end
      end
    end
  end
end
