require './scraper'

# Fetches plan documents, and the last 18 months worth of claims from united healthcare.

# TODO: fetch account information (plan id, etc)

class UnitedHealthCare < Scraper
  def initialize
    prompt = TTY::Prompt.new
    @username = prompt.ask("Username?", required: true)
    @password = prompt.ask("Password?", echo: false, required: true)

    super(File.join(File.expand_path(File.dirname(__FILE__)), "unitedhealthcare", @username))

    # it would be nice if poltergeist worked, but it really stalls out on some iframes and I don't know why
    Capybara.javascript_driver = :chrome
    Capybara.current_driver = :chrome
  end

  def start
    login

    if needs_authorization?
      log_progress("needs authorization")
      authorize
      log_progress("authorized")
    else
      log_progress("did not need authorization")
    end

    download_documents
    log_progress("download documents")
    download_claims
    log_progress("download claims")
    clean_up
  end

  def log_progress(message)
    @step ||= 1
    path = "#{@data_folder}/logs/#{@step}-#{message.gsub(/\s/, '-')}.png"
    save_screenshot(path)
    @step = @step + 1
  end

  def login
    visit "https://www.myuhc.com/member/prewelcome.do"
    log_progress("visiting site")

    fill_in(id: 'user', with: @username)
    fill_in(id: "password", with: @password)
    log_progress("submitted credentials")
    click_link('Login', class: "link_btnPrimary")
  end

  def download_claims
    visit('https://www.myuhc.com/member/claimsearchlayout.do')
    log_progress("claims root")
    select("Last 18 months", from: 'dateOfService')

    find('#searchButn').click
    first(:link, 'View All').click

    log_progress("all claims")
    find("[pageid='link.download.csv']").click
    sleep(2)

    files = Dir.glob("#{@tmp_folder}/*.csv").sort_by {|filename| File.mtime(filename) }
    save_file(files[0], "claims.csv")
  end

  def download_documents
    visit('https://www.myuhc.com/member/bcIbaagUnetCovDocs.do')
    click_link('Benefits & Coverage')
    sleep(1)
    click_link('Coverage Documents')
    log_progress("plan documents")

    links = find("#printContent").first('table').all(:link)
    names = []

    files = links.collect do |a|
      safe_name = (a.text).gsub(/[\/\:\-\s]+/, '-').downcase
      names << "#{safe_name}.pdf"
      puts "downloading #{safe_name} from #{a[:href]}"
      a.click
      sleep(1)
    end

    files = Dir.glob("#{@tmp_folder}/**").sort_by {|filename| File.mtime(filename) }

    files.each_with_index do |file, index|
      save_file(file, names[index])
    end
  end

  def save_file(tmp_path, good_name)
    FileUtils.rm("#{@download_folder}/#{good_name}.pdf") if File.exist?("#{@download_folder}/#{good_name}.pdf")

    saved_path = "#{@download_folder}/#{good_name}"
    FileUtils.copy_file(tmp_path, saved_path)

    saved_path
  end

  def gather_plan_info
    visit('https://www.myuhc.com/member/bcIbaagPersonsCov.do')
    values = {}
    headers = all('.claim_summary_tb th')
    rows = all('.claim_summary_tb tbody tr').each do |row, index|
      cells = row.find('td')

      headers.each do |header|
        values[header.text] = cells[index].text
      end
    end
  end

  def needs_authorization?
    has_selector?('#aaWebIframe')
  end

  def authorize
    options = []
    within_frame('aaWebIframe') do
      if has_selector?('.callMe .challengeResponseCallValue')
        value  = find('.callMe .challengeResponseCallValue').text
        options << {label: "Call: #{value}", selector: '.callMe'}
      end

      if has_selector?('.emailMe .challengeResponseEmailValue')
        value  = find('.emailMe .challengeResponseEmailValue').text
        options << {label: "Email: #{value}", selector: '.emailMe'}
      end

      if has_selector?('.textMe .challengeResponseTextValue')
        value  = find('.textMe .challengeResponseTextValue').text
        options << {label: "Text: #{value}", selector: '.textMe'}
      end
    end

    prompt = TTY::Prompt.new

    choice = prompt.select("They don't recognize this browser, so they need you to verify some information by typing in a code. How should they give you this code?") do |menu|
      options.each do |option|
        menu.choice option[:label], option[:selector]
      end
    end

    within_frame('aaWebIframe') do
      find("#{choice} input").click
    end

    prompt = TTY::Prompt.new
    authcode = prompt.ask("What's the authorization code?") do |q|
      q.required true
    end

    within_frame('aaWebIframe') do
      fill_in(id: "verifyAuthPasscodeInput", with: authcode)
      find('.verifyAuthSubmit input').click
    end
  end
end

@session = UnitedHealthCare.new
@session.start
