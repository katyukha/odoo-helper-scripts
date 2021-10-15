require 'simplecov'
require 'simplecov-console'

SimpleCov.start do
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
        SimpleCov::Formatter::HTMLFormatter,
        SimpleCov::Formatter::Console
    ])
    add_filter ".git/"
    add_filter "/tmp/odoo-helper-tests/"
    add_filter "run_docker_test.bash"
    add_filter "scripts/"
    add_filter "tests/ci.bash"
    add_filter "tools/virtualenv"
end
