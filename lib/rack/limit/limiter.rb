require 'rack'

module Rack
  module Limit
    class Limiter

      class Request < Rack::Request
        attr_accessor :rule
        attr_accessor :identifier

        def initialize(env, rules)
          super env
          @rule = rules.find { |rule| paths_matched?(rule) && restrict_on_domain?(rule) }
        end

        def blacklisted?
          in_list?('blacklist')
        end

        def whitelisted?
          in_list?('whitelist')
        end

        def paths_matched?(rule)
          rule['regex'] ? path =~ rule['path'] : path == rule['path']
        end

        def restrict_on_domain?(rule)
          domain = env['server_name']
          rule['domain'] ? domain == rule['domain'] : true
        end

        def in_list?(list)
          limit_source, limit_identifier = get_limit_params
          if limit_source == 'params'
            value = params[limit_identifier]
          elsif limit_source == 'path'
            value = path
          else
            value = ''
          end
          (rule[list] || []).include?(value)
        end

        def get_limit_params
          limit_source = limit_by = rule && rule['limit_by']

          if limit_by
            if limit_by.is_a?(Hash)
              limit_source = limit_by.keys.first
              limit_identifier = limit_by[limit_source]
              [limit_source, limit_identifier]
            else
              [limit_source]
            end
          end
        end

        def client_identifier
          limit_source, limit_identifier = get_limit_params
          if limit_source == 'params'
            [limit_identifier, params[limit_identifier]].join(':')
          elsif limit_source == 'path'
            path 
          else
            ip.to_s
          end
        end

        def identifier
          @identifier ||= client_identifier
        end
      end

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

      def allowed?(request)
        count = cache_get(request)
        allowed = count < (limit(request) || options[:max] || 1000).to_i
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
        if request.rule['prefix']
          begin
            cache.get("#{request.rule['prefix']}:#{request.identifier}").to_i
          rescue
          end
        end || request.rule['max']
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
