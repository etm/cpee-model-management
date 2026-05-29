#!/usr/bin/ruby
if File.exist?(File.join(__dir__,'..','lib','cpee-model-management','implementation.rb'))
  require_relative File.join(__dir__,'..','lib','cpee-model-management','implementation')
elsif File.exist?(File.join(Dir.home,'Projects','cpee-model-management','lib','cpee-model-management','implementation.rb'))
  require_relative File.join(Dir.home, 'Projects','cpee-model-management','lib','cpee-model-management','implementation')
else
  require 'cpee-model-management/implementation'
end

options = {
  :host => 'localhost',
  :port => 9317,
  :secure => false
}

Riddl::Server.new(File.join(__dir__,'dashing.xml'), options) do |opts|
  accessible_description true
  cross_site_xhr true

  ### set redis_cmd to nil if you want to do global
  ### at least redis_path or redis_url and redis_db have to be set if you do global
  opts[:redis_db]                   ||= 0
  opts[:redis_url]                  ||= 'unix://redis.sock' # sadly we have to do this for now
  opts[:redis_unixsocket]           ||= true
  opts[:redis_cmd]                  ||= 'redis-server --port #redis_port# --unixsocket #redis_path# --unixsocketperm 600 --pidfile #redis_pid# --dir         #redis_db_dir# --dbfilename                  #redis_db_name# --databases 1 --save 900 1 --save 300 10 --save 60 10000 --rdbcompression yes --            daemonize yes --protected-mode no'
  opts[:redis_pid]                  ||= 'redis.pid' # use e.g. /var/run/redis.pid if you do global. Look it up in your redis config
  opts[:redis_db_name]              ||= 'redis.rdb' # use e.g. /var/lib/redis.rdb for global stuff. Look it up in your redis config

  startup do
    CPEE::redis_connect opts, 'Server Main'
  end

  interface 'events' do
    run StatReceive, opts[:redis], opts[:stat_receivers] if post 'event'
  end
end.loop!
