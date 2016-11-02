require 'httparty'
require 'pry-byebug'
require 'google/api_client/client_secrets'
require 'google/apis/core/upload'
require 'google/apis/youtube_v3'
require 'launchy'
require 'csv'

class YoutubeUploader
  include HTTParty
  include ActiveModel::Validations
  CODE         = "4/cItyhGzLcLhc2BBW4vKej3GLwgOysKiZVWXpeia4dRI"
  TOKEN_OBJECT = {"access_token"=>"ya29.Ci-KA-bpYMzN-kI1_duZkJkl7JSVODuWziyISUFRflfDzpEjnqFSVxnfeTfWtOaDrw", "expires_in"=>3600, "refresh_token"=>"1/UAbAhXSD1dKKMdOb7c2qhI1HgBKDqW9c42iNxJBoxiw", "token_type"=>"Bearer"}


  attr_reader :youtube, :csv_file
  validates :csv_file, presence: true
  validate  :csv_file_exists

  def initialize(csv_file:)
    @csv_file = csv_file
    @youtube  = Google::Apis::YoutubeV3::YouTubeService.new
    @youtube.authorization = auth_client
    @youtube.request_options.timeout_sec = 1200
    @youtube.request_options.open_timeout_sec = 1200
    @youtube.request_options.retries = 3
  end

  def auth_client
    return @auth_client if @auth_client
    client_secrets = Google::APIClient::ClientSecrets.load
    @auth_client   = client_secrets.to_authorization
    set_scope(@auth_client) && set_code(@auth_client) && set_access_token(@auth_client)
    @auth_client
  end

  def set_scope(auth_client)
    auth_client.update!(
      :scope => ["https://www.googleapis.com/auth/youtube",
                 "https://www.googleapis.com/auth/youtube.upload",
                 "https://www.googleapis.com/auth/youtubepartner",
                 "https://www.googleapis.com/auth/youtubepartner-channel-audit"],
      :redirect_uri => 'urn:ietf:wg:oauth:2.0:oob'
    )
  end

  def set_code(auth_client)
    return auth_client.code = CODE if CODE
    auth_uri = auth_client.authorization_uri.to_s
    Launchy.open(auth_uri)
    puts 'Paste the code from the auth response page:'
    auth_client.code = STDIN.gets.chomp
  end

  def set_access_token(auth_client)
    if TOKEN_OBJECT
      auth_client.access_token  = TOKEN_OBJECT["access_token"]
      auth_client.expires_in    = TOKEN_OBJECT["expires_in"]
      auth_client.refresh_token = TOKEN_OBJECT["refresh_token"]
    else
      puts auth_client.fetch_access_token!
    end
  end

  def upload(row, index)
    folder         = "#{current_folder}/#{index}. #{row[1]}"
    file_path      = "#{folder}/#{row[0][0..200]}.mkv"

    metadata  = {
      snippet: {
        title: "#{index}. #{row[0][0..90]}",
        description: row[1]
      },
      status: {
        privacy_status: 'unlisted'
      }
    }
    video = youtube.insert_video('snippet,status', metadata, upload_source: file_path)

    playlist_item_object = {
      snippet: {
        playlist_id: "PL_syCUkPzpsWE3hpp2NzERu5S-p5vMmJY",
        resource_id: {
          "kind": "youtube#video",
          "video_id": video.id
        },
        position: index
      }
    }
    youtube.insert_playlist_item('snippet', playlist_item_object, {})
  end

  def self.upload(csv_file:)
    new(csv_file: csv_file).parse_and_upload
  end

  def current_folder
    @current_folder ||= File.dirname(File.expand_path(csv_file))
  end

  def parse_and_upload
    index   = 0
    threads = []

    CSV.foreach(csv_file) do |row|
      local_index = index
      threads << Thread.new { upload(row, local_index) } if local_index > 7 && local_index < 10
      index += 1
    end
    threads.map(&:join)
  end

  private

  def csv_file_exists
    return unless csv_file.present?
    errors.add(:csv_file, 'does not exist') unless File.exist?(File.expand_path(csv_file))
  end
end
