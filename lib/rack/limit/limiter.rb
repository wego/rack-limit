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

          ['whitelist', 'blacklist'].each do |list|
            rule[list] = rule[list].map(&:to_s) if rule[list]
          end

          rule
        end
      end

      def call(env)
        request = Request.new(env, rules)

        if request.rule
          message = request.missing_requirement
          return http_error(403, message) if message

          api_limit = limit(request)
          return invalid_api_key(request) if api_limit == 0
          return rate_limit_exceeded(request) if request.blacklisted?

          unless request.whitelisted?
            return api_key_expired(request, update_headers(request)) if api_limit == -1

            if allowed?(request)
              status, headers, body = app.call(env)
              return [status, headers.merge(update_headers(request)), body]
            else
              return rate_limit_exceeded(request, update_headers(request))
            end
          end
        end

        app.call(env)
      end

      def update_headers(request)
        headers = {}
        headers['X-RackLimit-Limit'] = request.limit.to_s if request.limit
        if request.limit && request.count
          remaining = request.limit - request.count
          headers['X-RackLimit-Remaining'] = (remaining > 0 ? remaining : 0).to_s
        end
        headers
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
        request.limit = (lookup_limit(request) || request.limits || options[:max] || 1000).to_i
      end

      def cached_limit(request)
        begin
          cache.get([request.rule['prefix'], request.identifier].compact.join(':'))
        rescue
        end
      end

      def set_cached_limit(request, value)
        begin
          cache.set([request.rule['prefix'], expiry('hourly'), request.identifier].compact.join(':'), value)
        rescue
        end
        value
      end

      def lookup_limit(request)
        lim = cached_limit(request)
        unless lim
          lim = options[:lookup] && options[:lookup].call(request.limit_value)
          set_cached_limit(request, lim) if lim
        end
        lim
      end

      def expiry(strategy = 'daily')
        case strategy
        when 'hourly'
          60 * 60
        else
          60 * 60 * 24
        end
      end

      def timestamp(strategy = 'daily')
        case strategy
        when 'hourly'
          Time.now.strftime("%Y%m%d%H00")
        else
          Time.now.strftime("%Y%m%d")
        end
      end

      def cache_key(request)
        [options[:key_prefix] || options[:prefix] || 'ratelimit', timestamp(request.strategy) , request.client_identifier].compact.join(':')
      end

      def cache
        options[:cache]
      end

      def http_error(code, message = nil, headers = {})
        [code, {'Content-Type' => 'application/json; charset=utf-8'}.merge(headers), message.nil? ? [http_status(code) + "\n"] : [message + "\n"]]
      end

      def rate_limit_exceeded(request, headers = {})
        http_error(request.rule['code'] || 403, request.rule['message'] || http_status(403), headers)
      end

      def api_key_expired(request, headers = {})
        http_error(request.rule['code'] || 403, request.rule['expired'] || http_status(403), headers)
      end

      def invalid_api_key(request, headers = {})
        http_error(request.rule['code'] || 403, request.rule['invalid'] || http_status(403), headers)
      end

      def http_status(code)
        [code, Rack::Utils::HTTP_STATUS_CODES[code]].join(' ')
      end
    end
  end
end
