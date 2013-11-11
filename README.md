rack-limit
==========

## Rails

In `config/initializers/rack_limit.rb`:

```ruby
require 'redis'

Rails.application.config.middleware.use Rack::Limit::Backends::Dalli, rules: YAML.load_file(File.join(Rails.root, 'config', 'rate_limit.yml')), cache: Dalli::Client.new
```

In `config/rack_limit.yml`:

```yaml
-
  path: /api
  #domain: 'api.domain.com' # will rate limit only at this domain if given
  limit_by:
    params: api_key
  whitelist: # based on the limit_by params above
    - 567
    - 678
  blacklist:
    - 999
    - 777
  required:
    params:
      api_key: "API KEY REQUIRED"
        #code: 500
        #message: '{"message": "API Key is required"}'
        #content_type: 'application/json'

  strategy: hourly
  max: 2

-
  path: ^\/flights\/?
  regex: true
  strategy: hourly
  limit_by: path
  max: 2

-
  path: ^\/users\/?
  regex: true
  strategy: hourly
  max: 2
```
