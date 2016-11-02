require 'active_model'
require 'csv'
require 'fileutils'
require 'net/http'

class VideoDownloader
  include ActiveModel::Validations
  attr_reader :csv_file
  validates :csv_file, presence: true
  validate  :csv_file_exists

  def initialize(csv_file:)
    @csv_file = csv_file
  end

  def self.download(csv_file:)
    downloader = new(csv_file: csv_file)
    return puts downloader.errors.full_messages unless downloader.valid?
    downloader.parse_and_download
  end

  def parse_and_download
    index = 0
    CSV.foreach(csv_file) do |row|
      download(row, index) if index > 9
      index += 1
    end
  end

  def download(row, index)
    folder         = FileUtils::mkdir_p("#{current_folder}/#{index}. #{row[1]}")[-1]
    m3u8_response  = get_m3u8(row[2])
    chunklist_path = get_chunklist_path(row[2], m3u8_response)
    pid = spawn("ffmpeg -i #{chunklist_path} -c copy \"#{folder}/#{row[0][0..200]}.mkv\"", :out => "#{folder}/#{row[0][0..200]}.out")
    Process.detach(pid)
  end

  def current_folder
    @current_folder ||= File.dirname(File.expand_path(csv_file))
  end

  def get_m3u8(path)
    uri = URI(path)
    Net::HTTP.get(uri)
  end

  def get_chunklist_path(m3u8_path, m3u8_response)
    dirname = File.dirname(m3u8_path)
    dirname + "/#{m3u8_response.split("\n").last}"
  end

  private

  def csv_file_exists
    return unless csv_file.present?
    errors.add(:csv_file, 'does not exist') unless File.exist?(File.expand_path(csv_file))
  end

end