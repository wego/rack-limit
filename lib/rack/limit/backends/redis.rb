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
          [options[:key_prefix] || options[:prefix] || 'ratelimit', request.client_identifier].join(':')
        end
      end
    end
  end
end
