module Rack
  module Limit
    class Limiter
      attr_accessor :app, :options

      def initialize(app, options = {})
        @app = app
        @options = { max: 2, message: "rate limit exceeded" }.merge(options)
      end

      def rules
        @cached_rules ||= options[:rules].map do |rule|
          rule['path'] = Regexp.new(rule['path']) if rule['regex']

          # just making sure we compare the same thing.
          ['whitelist', 'blacklist'].each do |list|
            rule[list] = rule[list].map(&:to_s) if rule[list]
          end

          rule
        end
      end

      def call(env)
        puts env.inspect
        request = Request.new(env, rules)
        if rule = request.rule
          params = request.params
          required = rule['required']
          required['params'].each_pair { |param, message| return http_error(403, message) unless params[param] } if required

          return rate_limit_exceeded(request) if request.blacklisted?

          unless request.whitelisted?
            return rate_limit_exceeded(request) unless allowed?(request)
          end
        end

        app.call(env)
      end

      def update_header(env)
        status, header, body = app.call(env)
        header['X-RackLimit-Limit'] = request.limit
        header['X-RackLimit-Remaining'] = request.limit - request.count
        [status, header, body]
      end

      def allowed?(request)
        count = cache_get(request)
        allowed = count < limit(request)
        begin
          cache_set(request, count + 1)
          allowed
        rescue
          allowed = true
        end
      end

      def cache_get(request)
        key = cache_key(request)
        begin
          cache.get(key).to_i
        rescue
          0
        end
      end

      def cache_set(request, value)
        key = cache_key(request)
        begin
          cache.set(key, value)
        rescue
        end
      end

      def limit(request)
        request.limit = if request.rule['prefix']
                          begin
                            cache.get("#{request.rule['prefix']}:#{request.identifier}")
                          rescue
                          end
                        else
                          request.rule['max'] || options[:max] || 1000
                        end.to_i
      end

      def expiry(strategy = 'daily')
        case strategy
        when 'hourly'
          60 * 60
        else
          60 * 60 * 24
        end
      end


      def cache_key(request)
        [options[:key_prefix] || options[:prefix] || 'throttle', request.rule['prefix'], request.client_identifier].join(':')
      end

      def cache
        options[:cache]
      end

      def http_error(code, message = nil, headers = {})
        [code, {'Content-Type' => 'text/plain; charset=utf-8'}.merge(headers), message.nil? ? [http_status(code) + "\n"] : [message + "\n"]]
      end

      def rate_limit_exceeded(request)
        http_error(request.rule['code'] || 403, request.rule['message'])
      end

      def http_status(code)
        [code, Rack::Utils::HTTP_STATUS_CODES[code]].join(' ')
      end
    end
  end
end
