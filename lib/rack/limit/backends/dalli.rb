module Rack
  module Limit
    module Backends
      class Dalli < Limiter
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
          request.count = count = cache.incr(key) || 1
          cache.set(key, count, expiry(request.rule['strategy']), raw: true) if count == 1
          count
        end
      end
    end
  end
end
