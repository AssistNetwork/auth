ENV['RACK_ENV'] = 'test'

dir = File.dirname(File.expand_path(__FILE__))
$LOAD_PATH.unshift dir + '../lib'

require 'minitest/autorun'
require 'rack/test'
require_relative '../lib/auth'

#
# make sure we can run redis
#

=begin
unless system("which redis-server")
  puts '', "** can't find `redis-server` in your path"
  puts "** try running `sudo rake install`"
  abort ''
end


#
# start our own redis when the tests start,
# kill it when they end
#

at_exit do
  next if $!

  exit_code = MiniTest::Test.new(ARGV)

  pid = `ps -A -o pid,command | grep [r]edis-test`.split(" ")[0]
  puts "Killing test redis server..."
  `rm -f #{dir}/dump.rdb`
  Process.kill("KILL", pid.to_i)
  exit exit_code
end

puts "Starting redis for testing at localhost:9736..."
`redis-server #{dir}/redis-test.conf`
Auth.redis = 'localhost:9736'

=end
