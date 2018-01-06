require 'simplecov'
require 'codecov'
require 'simplecov-console'

SimpleCov.start do
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
        SimpleCov::Formatter::Codecov,
        SimpleCov::Formatter::Console
    ])
    add_filter ".git/"
    add_filter "run_docker_test.bash"
end
