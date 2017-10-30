#!/usr/bin/env ruby
require 'deluge'
require 'base64'

arg_host = ARGV[0]
arg_port = ARGV[1]
arg_login = ARGV[2]
arg_password = ARGV[3]
arg_torrent_file = ARGV[4]
arg_label = ARGV[5]

# http://www.rasterbar.com/products/libtorrent/manual.html#status

# Initialize client
client = Deluge::Rpc::Client.new(
    host: arg_host, port: arg_port,
    login: arg_login, password: arg_password
)

client.connect

# adding torrent with label

options = Hash.new
options["add_paused"] = false

torrent_base64 = Base64.encode64(File.open(arg_torrent_file, "rb").read)
torrent_id = client.core.add_torrent_file(arg_torrent_file, torrent_base64, options)
client.label.set_torrent(torrent_id, arg_label)

# Closing
client.close
