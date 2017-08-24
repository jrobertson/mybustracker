Gem::Specification.new do |s|
  s.name = 'mybustracker'
  s.version = '0.1.0'
  s.summary = '*Currently under development*. An unoficial gem to query the mybustracker.co.uk web service for bus times etc. #edinburgh'
  s.authors = ['James Robertson']
  s.files = Dir['lib/mybustracker.rb']
  s.add_runtime_dependency('savon', '~> 2.11', '>=2.11.2')
  s.signing_key = '../privatekeys/mybustracker.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/mybustracker'
end
