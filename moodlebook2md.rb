#!/usr/bin/env ruby
# coding: utf-8
## Clean HTML Moodle Book and export to markdown

require 'yaml'
require 'nokogiri'
require 'paru/pandoc'
require 'paru/filter'
require 'date'

warn <<-'EOF'
    __  ___                   __ __       ____          __
   /  |/  /____   ____   ____/ // /___   / __ ) ____   / /_
  / /|_/ // __ \ / __ \ / __  // // _ \ / __  |/ __ \ / __/
 / /  / // /_/ // /_/ // /_/ // //  __// /_/ // /_/ // /_
/_/  /_/ \____/ \____/ \__,_//_/ \___//_____/ \____/ \__/

EOF


# Measure and Benchmark Time for Ruby Methods
# https://stackoverflow.com/questions/11406410/measure-and-benchmark-time-for-ruby-methods
start = Time.now
# the global variable to output the result
output = $stdout
# pretty nice output
# https://gist.github.com/mislav/398334
tidy = Nokogiri::XSLT File.open('tidy.xsl')
BASE_DIR= File.absolute_path(".")
yaml_filepath ||= File.join('config.yaml')

if ARGV.empty?
  warn "You must pass a Moodle book html file in order to work:"
  warn "./moodlebook2md.rb input.html > output.md"
  exit
end

# open the Moodle Book html exported
moodleBook = File.open(ARGV[0]) { |file| Nokogiri::HTML(file, &:noblanks)}

=begin
 __     __      __  __ _
 \ \   / //\   |  \/  | |
  \ \_/ //  \  | \  / | |
   \   // /\ \ | |\/| | |
    | |/ ____ \| |  | | |____
    |_/_/    \_\_|  |_|______|

=end

# Load default yaml data
begin
  metadata = YAML.load_file(yaml_filepath)
rescue Errno::ENOENT
  metadata = {
    "key1" => "value1",
    "key2" => "value2"
  }
end

# Maybe we need to extract some metada from the document
base_conf_from_moodlebok = {
  'title' => moodleBook.xpath('//div[@class="book_info"]/table/tbody/tr[3]/td[2]').text,
  'author' => 'Diferents autors',
  'course' => moodleBook.xpath('//div[@class="book_info"]/table/tbody/tr[2]/td[2]').text,
  'printed' => moodleBook.xpath('//div[@class="book_info"]/table/tbody/tr[3]/td[2]').text,
  'edition' => moodleBook.xpath('//div[@class="book_info"]/table/tbody/tr[5]/td[2]').text,
  'date' => Date.today.to_s
}

# check if data is empty?
base_conf_from_moodlebok.each do |key, value|
  if value.empty?
    base_conf_from_moodlebok[key] = "#{key.capitalize} is not defined"
  end
end

metadata.merge!(base_conf_from_moodlebok)

=begin
metadata.merge!
=end

=begin
   _____ _    _          _____ _______ ______ _____   _____
  / ____| |  | |   /\   |  __ \__   __|  ____|  __ \ / ____|
 | |    | |__| |  /  \  | |__) | | |  | |__  | |__) | (___
 | |    |  __  | / /\ \ |  ___/  | |  |  __| |  _  / \___ \
 | |____| |  | |/ ____ \| |      | |  | |____| | \ \ ____) |
  \_____|_|  |_/_/    \_\_|      |_|  |______|_|  \_\_____/
=end

warn "Add chapters and subchapters as a H2 and H3"

chapters = []
moodleBook.xpath('//div[@class="book_toc_numbered"]/ul/li').each do |chapter|
  subchapters = []
  if chapter.at('./ul') != nil
    chapter.at('./ul').children.each do |subchapter|
      subchapters << {
        :title => subchapter.at('./a')['title'].sub(/^\d\.\d\.\s/,''), # remove numbered chapter
        :href  => subchapter.at('./a')['href'].sub(/^.*#/,''), # remove http...
      }
    end
  end
  chapters << {
    :title => chapter.at('./a')['title'].sub(/^\d\.\s/,''), # remove numbered chapter
    :href  => chapter.at('./a')['href'].sub(/^.*#/,''), # remove http...
    :subchapters => subchapters
  }
end

# replace div.book_chapter for h2 chapters
moodleBook.xpath('//div[@class="book_chapter"]/a').each do |book_chapter|
  # replace chapters
  chapters.any? {|chapter|
    if chapter[:href] == book_chapter['name']
      new_node = moodleBook.create_element "h2"
      new_node.inner_html = chapter[:title]
      book_chapter.replace new_node
    end
  }

  # replace subchapters
  chapters.each do |chapter|
    unless chapter[:subchapters].empty?
      chapter[:subchapters].any? { |subchapter|
        if subchapter[:href] == book_chapter['name']
          new_node = moodleBook.create_element "h3"
          new_node.inner_html = subchapter[:title]
          book_chapter.replace new_node
        end
      }
    end
  end
end



=begin
  _____  ______ __  __  ______      ________
 |  __ \|  ____|  \/  |/ __ \ \    / /  ____|
 | |__) | |__  | \  / | |  | \ \  / /| |__
 |  _  /|  __| | |\/| | |  | |\ \/ / |  __|
 | | \ \| |____| |  | | |__| | \  /  | |____
 |_|  \_\______|_|  |_|\____/   \/   |______|
=end

# Remove namespaces
warn "Removing namespaces"
moodleBook.remove_namespaces!

# Empty tags
# https://stackoverflow.com/questions/20123176/cleaning-xml-document-recursively-from-empty-tags-with-nokogiri
# warn "Removing empty tags"
# moodleBook.search(':empty').remove

# Scripts
warn "Removing scripts"
# https://stackoverflow.com/questions/1980845/removing-the-script-elements-of-an-html
moodleBook.xpath("//script").remove

# Book info
warn "Removing book info"
moodleBook.xpath("//*[contains(@class,'book_info')]").remove

# TOC Numbered
warn "Removing table of contents"
moodleBook.xpath("//*[contains(@class,'book_toc_numbered')]").remove

# Onclicks
warn "Removing onclicks"
moodleBook.xpath("//*[@onclick]").remove

# Skiplinks
warn "Removing skiplinks"
moodleBook.xpath("//*[contains(@class,'skiplinks')]").remove

# Shitty YUI
# https://stackoverflow.com/questions/1556028/how-do-i-do-a-regex-search-in-nokogiri-for-text-that-matches-a-certain-beginning
warn "Removing every shitty YUI reminders"
moodleBook.xpath("//*[starts-with(@id, 'yui')]").each do | tag |
  tag.attributes["id"].remove
end

# Remove absurd maincontent link
warn "Remove maincontent link"
moodleBook.xpath("//*[contains(@class, 'sr-only')]").remove

# Clearfix remove
warn "Removing clearfixes class"
moodleBook.xpath("//*[contains(@class,'clearfix')]").each do | tag |
  tag.attributes["class"].remove
end

# Span as spams
warn "Removing shitty spams... well, I said spans"
moodleBook.xpath("//span").each { | span |
  # replace children if empty attributes
  span.replace(span.children) if span.element?
}

# Strange li attributes
warn "Removing strange li attributes"
moodleBook.xpath("//li[starts-with(@id, 'module-')]").each do | tag |
  tag.attributes["id"].remove
  tag.attributes["data-draggroups"].remove
end

# Calendar ids duplicate
warn "Removing duplicated ids"
moodleBook.xpath("//h2[starts-with(@id, 'calendari-')]").each do | tag |
  tag.attributes["id"].remove
end

# Strange p attributes
warn "Removing paragraphs attributes"
moodleBook.xpath("//p[starts-with(@id, 'module-')]").each do | tag |
  tag.attributes["id"].remove
  tag.attributes["data-draggroups"].remove
end

# Empty paragraphs
# TODO: This removes images!
# warn "Removing blank or empty paragraphs"
# moodleBook.xpath("//p").each { | p |
#   p.remove if p.text.empty?
# }

# strong inline tags inside headers
warn "Removing inline tags like strong inside text header"
=begin
moodleBook.xpath('//*[name()="h3"]').css('strong').each { |strong|
    strong.replace("&nbsp;" + strong.text() + "&nbsp;")
}
=end
moodleBook.xpath('//*[name()="h3"]').each do |node|
  node.replace '<h3>' + node.text() + '</h3>' # remove space trailing spaces
end

# Styles
warn "Removing styles"
moodleBook.xpath("//@style").remove

# Strip gaps between HTML and fucking carriage returns
# https://stackoverflow.com/questions/8965897/how-do-you-strip-gaps-between-html-tags-with-nokogiri?rq=1
moodleBook.xpath('//text()[1]').each{ |t|      t.content = t.content.lstrip }
moodleBook.xpath('//text()[last()]').each{ |t| t.content = t.content.rstrip }
moodleBook.xpath('//text()').each{ |t|         t.content = t.content.sub("\n", "").strip }


# Replace return footnote char https://www.fileformat.info/info/unicode/char/21a9/index.htm
moodleBook.xpath('//@*', '//text()').each do |node|
  node.content = node.content.gsub('↩', 'Torna')
end

# Unnecessary shitdivs
warn "Removing divs generated automatically by Moodle Book Module"
moodleBook.xpath("//div").each { | div |
  div.remove if div.attr("class") == "editor-indent"
}

# Replace some divs by its children
# https://stackoverflow.com/questions/47007258/nokogiri-search-over-a-document-and-modify-parent-node-and-cant-access-child-no
# TODO: Rewrite that ugly and reiterative shit
target = %w( page page-content book_chapter)

moodleBook.xpath("//div[contains(@role,'main')]").sort_by{ |n| n.ancestors.size }.reverse!.each do |node|
  node.replace(Nokogiri::HTML::DocumentFragment.parse(node.children.to_html))
end

moodleBook.xpath("//div[contains(@id,'page')]").sort_by{ |n| n.ancestors.size }.reverse!.each do |node|
  node.replace(Nokogiri::HTML::DocumentFragment.parse(node.children.to_html))
end

moodleBook.xpath("//div[contains(@id,'page-content')]").sort_by{ |n| n.ancestors.size }.reverse!.each do |node|
  node.replace(Nokogiri::HTML::DocumentFragment.parse(node.children.to_html))
end

moodleBook.xpath("//div[contains(@class,'book_chapter')]").sort_by{ |n| n.ancestors.size }.reverse!.each do |node|
  node.replace(Nokogiri::HTML::DocumentFragment.parse(node.children.to_html))
end

# Remove empty links
moodleBook.css('a').find_all.each do |a|
  # Ruby solution, as pointed out by Michael Hartl:
  a.remove if a.content.strip.empty?
end


=begin
  _   _ _____ _____ ______   _    _ _______ __  __ _
 | \ | |_   _/ ____|  ____| | |  | |__   __|  \/  | |
 |  \| | | || |    | |__    | |__| |  | |  | \  / | |
 | . ` | | || |    |  __|   |  __  |  | |  | |\/| | |
 | |\  |_| || |____| |____  | |  | |  | |  | |  | | |____
 |_| \_|_____\_____|______| |_|  |_|  |_|  |_|  |_|______|
=end

# https://gist.github.com/mislav/398334
niceBook = tidy.transform(moodleBook).to_html

# Uncomment this line to output a pretty HTML version
# output.puts niceBook
# exit

=begin
  __  __          _____  _  _______   ______          ___   _
 |  \/  |   /\   |  __ \| |/ /  __ \ / __ \ \        / / \ | |
 | \  / |  /  \  | |__) | ' /| |  | | |  | \ \  /\  / /|  \| |
 | |\/| | / /\ \ |  _  /|  < | |  | | |  | |\ \/  \/ / | . ` |
 | |  | |/ ____ \| | \ \| . \| |__| | |__| | \  /\  /  | |\  |
 |_|  |_/_/    \_\_|  \_\_|\_\_____/ \____/   \/  \/   |_| \_|
=end

HTML2MARKDOWN = Paru::Pandoc.new do
  from "html+raw_html"
  to "markdown"
  wrap "none"
end.convert niceBook

=begin
   ____  _    _ _______ _____  _    _ _______
  / __ \| |  | |__   __|  __ \| |  | |__   __|
 | |  | | |  | |  | |  | |__) | |  | |  | |
 | |  | | |  | |  | |  |  ___/| |  | |  | |
 | |__| | |__| |  | |  | |    | |__| |  | |
  \____/ \____/   |_|  |_|     \____/   |_|
=end

file = metadata.to_yaml << "...\n\n" <<  HTML2MARKDOWN

# Clean before output
file.gsub!(/<div.*?>|<\/div>/, '')
file.gsub!(/([ \t]*\n){3,}/, "\n").squeeze("\n").strip

# We warn the time taken by the script
finish = Time.now
diff = finish - start
warn "Time taken: #{diff} seconds"

output.puts file
