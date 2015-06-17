require 'scraperwiki'
require 'rubygems'
require 'mechanize'

comment_url = 'mailto:council@canterbury.nsw.gov.au?subject='
starting_url = 'http://datrack.canterbury.nsw.gov.au/cgi/datrack.pl?search=search&activetab=2&startidx='

def clean_whitespace(a)
  a.gsub("\r", ' ').gsub("\n", ' ').squeeze(" ").strip
end

def scrape_table(agent, scrape_url, comment_url)
  doc = agent.get(scrape_url)
  rows = doc.search('.datrack_resultrow_odd,.datrack_resultrow_label_even,.datrack_resultrow_even,.datrack_resultrow_label_odd')
  puts "Rows on page: " + rows.size
  (0..rows.size - 1).step(2) do |i|
    fields = rows[i].search('td')
    reference = fields[1].inner_text
    record = {
      'info_url' => (doc.uri + fields[1].at('a')['href']).to_s,
      'comment_url' => comment_url + CGI::escape("Development Application Enquiry: " + reference),
      'council_reference' => reference,
      'date_received' => Date.strptime(clean_whitespace(fields[5].inner_text), '%d/%m/%Y').to_s,
      'address' => fields[2..4].map { |e| clean_whitespace(e.inner_text) } * ' ',
      'description' => rows[i + 1].inner_text.strip,
      'date_scraped' => Date.today.to_s
    }
    
    if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true) 
      ScraperWiki.save_sqlite(['council_reference'], record)
      puts "Saving " + reference
    else
      puts "Skipping already saved record " + record['council_reference']
    end
  end
  return rows.size == 20
end

agent = Mechanize.new

start_index = 0

while true do
  scrape_url = starting_url + start_index.to_s
  puts "Scraping " + scrape_url
  if (!scrape_table(agent, scrape_url, comment_url))
    break
  end
  start_index += 10
end