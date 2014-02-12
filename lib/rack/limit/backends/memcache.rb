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
          [options[:key_prefix] || options[:prefix] || 'ratelimit', request.client_identifier].join(':')
        end

        def cached_limit(request)
          begin
            cache.get([request.rule['prefix'], request.identifier].compact.join(':'), true)
          rescue
          end
        end
      end
    end
  end
end
