
require 'capybara'
require 'capybara/dsl'
require 'capybara/poltergeist'
require 'selenium-webdriver'
require 'csv'
require 'tty'
require 'pry'

class Scraper
  include Capybara::DSL

  attr_accessor :data_folder

  def initialize(data_folder = "")
    @data_folder      = data_folder
    @tmp_folder       = File.join(data_folder, 'scrape_tmp')
    @download_folder  = File.join(data_folder, 'download')
    @log_folder       = File.join(data_folder, 'logs')

    Capybara.register_driver :chrome do |app|
      # We want PDFs to download without prompts, so we
      # need to tell chrome to disable its PDF viewer,
      # not prompt for downloads, and also allow automatic multiple
      # downloads from sites.

      prefs = {
        plugins: {
          plugins_disabled: ['Chrome PDF Viewer']
        },
        profile: {
          default_content_setting_values: {
            automatic_downloads: 1
          },
        },
        download: {
          prompt_for_download: false,
          default_directory: @tmp_folder
        }
      }

      Capybara::Selenium::Driver.new(app, :browser => :chrome, prefs: prefs)
    end

    clean_up

    Capybara.register_driver :poltergeist do |app|
      profile = Selenium::WebDriver::Chrome::Profile.new
      profile['download.default_directory'] = @download_folder

      Capybara::Poltergeist::Driver.new(app, :window_size => [1920, 1080], :inspector => true, profile: profile, :debug => true)
    end

    Capybara.javascript_driver = :chrome
    Capybara.current_driver = :chrome
  end

  def clean_up
    FileUtils.rm_r(@tmp_folder) if File.exist?(@tmp_folder)
  end
end
