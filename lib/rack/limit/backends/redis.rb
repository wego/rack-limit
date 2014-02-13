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
          cache.expire(key, expiry(request.strategy)) if count == 1
          count
        end

        def cache_key(request)
          [request.rule['count_prefix'] || 'ratelimit:count', request.identifier].join(':')
        end

        def set_cached_limit(request, value)
          begin
            key = [request.rule['limit_prefix'] || 'ratelimit:limit', request.identifier].compact.join(':')
            cache.set(key, value)
            cache.expire(key, expiry('hourly'))
          rescue
          end
          value
        end
      end
    end
  end
end
