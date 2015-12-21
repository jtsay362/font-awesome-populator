require 'json'
require 'uri'
require 'net/http'
require 'fileutils'
require 'nokogiri'

FONT_AWESOME_CHEATSHEET_URL = 'http://fortawesome.github.io/Font-Awesome/cheatsheet/'
DOWNLOAD_DIR = './downloaded'
DOWNLOAD_FILENAME = "#{DOWNLOAD_DIR}/font-awesome-cheatsheet.html"

class FontAwesomePackagePopulator
  def initialize(output_path)
    @output_path = output_path
  end

  def download
    puts "Starting download ..."

    FileUtils.mkpath(DOWNLOAD_DIR)
    uri = URI.parse(FONT_AWESOME_CHEATSHEET_URL)
    response = Net::HTTP.get_response(uri)
    File.write(DOWNLOAD_FILENAME, response.body)


    puts "Done downloading!"
  end

  def populate
    File.open(@output_path, 'w:UTF-8') do |out|
      out.write <<-eos
{
  "metadata" : {
    "settings" : {
      "analysis": {
        "char_filter" : {
          "no_special" : {
            "type" : "mapping",
            "mappings" : ["-=>"]
          }
        },
        "analyzer" : {
          "lower_whitespace" : {
            "type" : "custom",
            "tokenizer": "whitespace",
            "filter" : ["lowercase"],
            "char_filter" : ["no_special"]
          }
        }
      }
    },
    "mapping" : {
      "_all" : {
        "enabled" : false
      },
      "properties" : {
        "name" : {
          "type" : "string",
          "analyzer" : "lower_whitespace"
        },
        "suggest" : {
          "type" : "completion",
          "analyzer" : "lower_whitespace"
        }
      }
    }
  },
  "updates" :
    eos
      icons = parse_icons

      puts "Found #{icons.length} icons."

      out.write(icons.to_json)
      out.write("\n}")
    end
  end

  def parse_icons()
    source_doc = Nokogiri::HTML(File.read(DOWNLOAD_FILENAME))

    source_doc.css('.container .row .fa.fa-fw').map { |node|
      node.next_sibling.text.strip.gsub(/^fa /, '').gsub('fa-fw', '').gsub(/^fa\-\w+\s+.+/, '');
    }.compact.uniq.map { |css_class| {
      name: css_class,
      suggest: css_class
    } }
  end
end

output_filename = 'font-awesome-icons.json'

download = false

ARGV.each do |arg|
  if arg == '-d'
    download = true
  else
    output_filename = arg
  end
end

populator = FontAwesomePackagePopulator.new(output_filename)

if download
  populator.download()
end

populator.populate()
system("bzip2 -kf #{output_filename}")