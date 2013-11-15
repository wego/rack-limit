require 'rack'

module Rack
  module Limit
    class Request < Rack::Request
      attr_accessor :rule, :identifier, :count, :limit, :missing_requirement

      def initialize(env, rules)
        super env
        @rule = rules.find { |rule| paths_matched?(rule) && restrict_on_domain?(rule) }
        check_required
      end

      def check_required
        requirements = rule && rule['required']
        return unless requirements

        @missing_requirement = if requirements['params'].is_a?(Hash)
          requirements['params'].find { |param, message| !params[param] }
        else
          requirements['params'] unless params[requirements['params']]
        end
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
        rule['domain'] ? host == rule['domain'] : true
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

      def limits
        key = identifier.split(':').last
        (rule['limits'] || {}).reduce({}) { |a,c| a[c.first.to_s] = c.last; a}[key] || rule['max']
      end

      def strategy
        @strategy ||= rule['strategy']
      end
    end
  end
end
