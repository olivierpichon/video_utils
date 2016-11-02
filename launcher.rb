#!/usr/bin/env ruby
require_relative 'video_downloader'
require_relative 'youtube_uploader'


def main
  csv_file = ARGV[1]
  if ARGV[0] == "download"
    VideoDownloader.download(csv_file: csv_file)
  elsif ARGV[0] == "upload"
    YoutubeUploader.upload(csv_file: csv_file)
  end
end

main if __FILE__ == $0
