# frozen_string_literal: true

require 'nokogiri'
require 'open-uri'
require 'shellwords'
require 'json'
URL_ROOT = 'https://i.allnightnippon.com/'
PROGRAMS_URL = URI.join(URL_ROOT, 'newlist')
LOG_DIR = File.expand_path('~/.log/anni/')
LOG_FILENAME = 'log.json'
LOG_PATH = File.join(LOG_DIR, LOG_FILENAME)
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36'

def init_log

  Dir.mkdir(LOG_DIR) unless Dir.exist?(LOG_DIR)

  unless File.exist?(LOG_PATH)
    File.open(LOG_PATH, 'w') do |io|
      JSON.dump({ programs: [] }, io)
    end
  end

end

if $PROGRAM_NAME == __FILE__
  init_log

  log = File.open(LOG_PATH, 'r') { |io| JSON.load(io) }

  root = Nokogiri::HTML(open(PROGRAMS_URL, 'User-Agent' => UA))
  programs = root.css('#container .inner li .search_txt a').map do |elem|
    elem[:href]
  end

  results = programs.map do |program_url|
    sanitized_url = URI.join(URL_ROOT, program_url)
    program = Nokogiri::HTML(open(sanitized_url.to_s, 'User-Agent' => UA))

    title = program.css('#program_area .ttl_movie')[0].xpath('text()')

    next unless log['programs'] == [] || log['programs'].fetch(title, false)


    recorded_dir = File.expand_path(ARGV[0])
    filename = Shellwords.escape(File.join(recorded_dir, title.to_s))

    result = { title => false }
    video_source = program&.css('video source')
    next result if video_source.nil? || video_source.empty?


    movie_url = Shellwords.escape(video_source[0]['src'])

    cmd = "ffmpeg -i #{movie_url} -vcodec copy -acodec copy -bsf:a aac_adtstoasc #{filename}.mp4"
    output = `#{cmd}`

    result.update(title => true)
    result

  end.compact

  File.open(File.expand_path(LOG_PATH), 'w+') do |io|
    JSON.dump({ programs: log['programs'].merge(*results) }, io)
  end

end
