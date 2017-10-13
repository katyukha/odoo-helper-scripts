require 'simplecov'
#require 'coveralls'
require 'codecov'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
#  Coveralls::SimpleCov::Formatter,
  SimpleCov::Formatter::Codecov
]
