module Rack
  module Limit
    module Backends
      class Dalli < Limiter
        def allowed?(request)
          begin
            count = cache_get(request)
            count <= (limit(request) || request.rule['max'] || options[:max] || 1000).to_i
          rescue => e
            puts e
            true
          end
        end

        def cache_get(request)
          key = cache_key(request)
          count = cache.incr(key) || 1
          cache.set(key, count, expiry(request.rule['strategy']), raw: true) if count == 1
          count
        end
      end
    end
  end
end
