Gem::Specification.new do |s|
  s.name = 'mybustracker'
  s.version = '0.2.0'
  s.summary = '*Currently under development*. An unofficial gem to query the mybustracker.co.uk web service for bus times etc. #edinburgh'
  s.authors = ['James Robertson']
  s.files = Dir['lib/mybustracker.rb']
  s.add_runtime_dependency('savon', '~> 2.11', '>=2.11.2')
  s.add_runtime_dependency('subunit', '~> 0.2', '>=0.2.7')
  s.add_runtime_dependency('geocoder', '~> 1.4', '>=1.4.4')
  s.add_runtime_dependency('geodesic', '~> 1.0', '>=1.0.1')
  s.signing_key = '../privatekeys/mybustracker.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/mybustracker'
end
