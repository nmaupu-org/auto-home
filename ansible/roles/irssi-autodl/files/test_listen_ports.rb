#!/usr/bin/env ruby
require 'deluge'

arg_host = ARGV[0]
arg_port = ARGV[1]
arg_login = ARGV[2]
arg_password = ARGV[3]

# Initialize client
client = Deluge::Rpc::Client.new(
    host: arg_host, port: arg_port,
    login: arg_login, password: arg_password
)

client.connect

puts client.core.test_listen_port()

# Closing
client.close
