require 'rack'

module Rack
  module Limit
    class Limiter

      class Request < Rack::Request; attr_accessor :rule; end

      attr_accessor :app, :options

      def initialize(app, options = {})
        @app = app
        @options = { max: 2, message: "rate limit exceeded" }.merge(options)
      end

      def rules
        @cached_rules ||= options[:rules].map do |rule|
          rule['path'] = Regexp.new(rule['path']) if rule['regex']

          # just making sure we compare the same thing.
          rule['whitelist'] = rule['whitelist'].map(&:to_s) if rule['whitelist']
          rule['blacklist'] = rule['blacklist'].map(&:to_s) if rule['blacklist']
          rule
        end
      end

      def call(env)
        request = Request.new(env)

        if rule = get_rule(request)
          params = request.params
          required = rule['required']
          required['params'].each_pair { |param, message| return http_error(403, message) unless params[param] } if required

          request.rule = rule

          if blacklisted?(request)
            return rate_limit_exceeded(request)
          end

          unless whitelisted?(request)
            return rate_limit_exceeded(request) unless allowed?(request)
          end
        end

        app.call(env)
      end

      def get_rule(request)
        rules.find { |rule| paths_matched?(request, rule) && restrict_on_domain?(request, rule) }
      end

      def whitelisted?(request)
        in_list?(request, 'whitelist')
      end

      def blacklisted?(request)
        in_list?(request, 'blacklist')
      end

      def in_list?(request, list)
        limit_source, limit_identifier = get_limit_params(request)
        if limit_source == 'params'
          value = request.params[limit_identifier]
        elsif limit_source == 'path'
          value = request.path
        else
          value = ''
        end
        (request.rule[list] || []).include?(value)
      end

      def paths_matched?(request, rule)
        path = request.path
        rule['regex'] ? path =~ rule['path'] : path == rule['path']
      end

      def restrict_on_domain?(request, rule)
        domain = request.env['server_name']
        rule['domain'] ? domain == rule['domain'] : true
      end

      def allowed?(request)
        count = cache_get(request)
        allowed = count < (request.rule['max'] || options[:max] || 1000).to_i
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

      def expiry(strategy = 'daily')
        case strategy
        when 'hourly'
          60 * 60
        else
          60 * 60 * 24
        end
      end

      def client_identifier(request)
        limit_source, limit_identifier = get_limit_params(request)
        return [limit_identifier, request.params[limit_identifier]].join(':') if limit_source == 'params'
        return request.path if limit_source == 'path'
        request.ip.to_s
      end

      def get_limit_params(request)
        rule = request.rule
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

      def cache_key(request)
        [options[:key_prefix] || options[:prefix] || 'throttle', request.rule['prefix'], client_identifier(request)].join(':')
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
