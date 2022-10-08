#!/usr/bin/env ruby
require 'deluge'
require 'base64'

arg_host = ARGV[0]
arg_port = ARGV[1]
arg_login = ARGV[2]
arg_password = ARGV[3]
arg_label = ARGV[4]
arg_max_seed_time = ARGV[5]*24*3600

# https://github.com/t3hk0d3/deluge-rpc
# http://www.rasterbar.com/products/libtorrent/manual.html#status

# Initialize client
client = Deluge::Rpc::Client.new(
    host: arg_host, port: arg_port,
    login: arg_login, password: arg_password
)

client.connect

# getting all torrent with label arg_label
torrents = client.core.get_torrents_status({"label" => arg_label}, ["id", "seeding_time", "name", "state", "ratio", "tracker_status", "all_time_download"])
#puts torrents

nb_torrents = torrents.length
puts "There is a total of #{nb_torrents} torrents in label #{arg_label}"

torrents.each { |key, value|
  torrent_id = key
  seeding_time = value["seeding_time"]
  name = value["name"]
  state = value["state"]
  ratio = value["ratio"].round(3)
  tracker_status = value["tracker_status"]
  all_time_download = value["all_time_download"]

  percent_time = ((seeding_time.to_f*100) / max_seeding_time).round(1)

  message = "[id=#{torrent_id} state=#{state}, ratio=#{ratio}, seeding_time=#{seeding_time} (#{percent_time}%)] #{name} - "
  print(message)

  case state
    when "Downloading"
      if tracker_status.include? "Error: unregistered torrent" then
        print "resuming download"
        client.core.pause_torrent([torrent_id])
        client.core.resume_torrent([torrent_id])
      elsif tracker_status.include? "Announce OK" and all_time_download <= 0 and ratio < 0 then
        # Bug : sometimes in Deluge, torrent get stuck when added
        print "torrent ok, but stuck at 0, resuming"
        client.core.pause_torrent([torrent_id])
        sleep(0.5)
        client.core.resume_torrent([torrent_id])
      else
        print "still downloading, doing nothing"
      end
    when "Paused"
      if ratio >= 1 or seeding_time >= max_seeding_time then
        # Safe delete
        print("deleting torrent")
        client.core.remove_torrent(torrent_id, true)
      else
        print("resuming torrent")
        client.core.resume_torrent([torrent_id])
      end
    when "Seeding"
      if seeding_time >= max_seeding_time then
        print("pausing torrent for further deletion")
        client.core.pause_torrent([torrent_id])
      else
        print("doing nothing")
      end
    else
      print("doing nothing")
  end

  print("\n")
}


# Closing
client.close
