module Rack
  module Limit
    module Backends
      class Dalli < Limiter
        include Memcache

        def cache_get(request)
          key = cache_key(request)
          request.count = count = cache.incr(key) || 1
          cache.set(key, count, expiry(request.strategy), raw: true) if count == 1
          count
        end

        def set_cached_limit(request, value)
          begin
            key = [request.rule['limit_prefix'] || 'ratelimit:limit', request.identifier].compact.join(':')
            cache.set(key, value, expiry('hourly'), raw: true)
          rescue
          end
          value
        end
      end
    end
  end
end
