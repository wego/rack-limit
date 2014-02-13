require 'rack'

module Rack
  module Limit
    class Request < Rack::Request
      attr_accessor :rule, :identifier, :count, :limit, :missing_requirement, :limit_param, :limit_value, :limit_source

      def initialize(env, rules)
        super env
        @rule = rules.find { |rule| paths_matched?(rule) && restrict_on_domain?(rule) }
        check_requirement
      end

      def check_requirement
        requirements = rule && rule['limit_by']
        return unless requirements
        @missing_requirement = (rule['missing'] || '{"error": "required params not found"}') unless found_requirements?(requirements)
      end

      def found_requirements?(requirements)
        requirements.find do |source, values|
          key = source == 'params' ? found_param(values) : found_header(values)
          if key
            @limit_source = source
            @limit_value = source == 'params' ? params[key] : header(key)
            @limit_param = key
          end
        end
      end

      def found_param(keys)
        keys.is_a?(Array) ? keys.find { |k| params[k] } : (params[keys] && keys)
      end

      def found_header(keys)
        keys.is_a?(Array) ? keys.find { |k| header(k) } : (header(keys) && keys)
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
        (rule[list] || []).include?(limit_value)
      end

      def identifier
        limit_value
      end

      def limits
        key = identifier.split(':').last
        (rule['limits'] || {}).reduce({}) { |a,c| a[c.first.to_s] = c.last; a}[key] || rule['max']
      end

      def strategy
        @strategy ||= rule['strategy']
      end

      def header(key)
        env['HTTP_' + key.upcase.gsub('-', '_')]
      end
    end
  end
end
