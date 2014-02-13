module Rack
  module Limit
    module Backends
      module Memcache
        def allowed?(request)
          begin
            count = cache_get(request)
            count <= limit(request)
          rescue => e
            puts e
            true
          end
        end

        def cache_key(request)
          [request.rule['count_prefix'] || 'ratelimit:count', request.identifier].join(':')
        end

        def cached_limit(request)
          begin
            cache.get([request.rule['limit_prefix'] || 'ratelimit:limit', request.identifier].compact.join(':'), true)
          rescue
          end
        end
      end
    end
  end
end
