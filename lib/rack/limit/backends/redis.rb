module Rack
  module Limit
    module Backends
      class Redis < Limiter
        def allowed?(request)
          begin
            count = cache_get(request)
            count <= limit(request)
          rescue => e
            puts e
            true
          end
        end

        def cache_get(request)
          key = cache_key(request)
          request.count = count = cache.incr(key)
          cache.expire(key, expiry(request.rule['strategy'])) if count == 1
          count
        end
      end
    end
  end
end
