Gem::Specification.new do |s|
  s.name = 'rack-limit'
  s.version = '0.0.0'
  s.date = '2013-10-31'
  s.summary = 'Rack Rate limit'
  s.description = 'Rate limit FTW'
  s.authors = ['Kates Gasis']
  s.email = 'katesgasis@gmail.com'
  s.files = ['lib/rack/limit.rb']
  s.homepage = 'http://rubygems.org/gems/rack-limit'
  s.license = 'MIT'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'fakeredis'
end
