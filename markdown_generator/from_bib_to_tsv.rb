#!/usr/bin/env ruby
require 'bibtex'
require 'date'

bibfile = 'bibliography.bib'
outfile = 'publications.tsv'

# --- LOAD AND CLEAN BIB FILE ---
clean = []
File.readlines(bibfile).each do |line|
  next if line.strip.start_with?('%')
  clean << line
end

clean_bib = BibTeX::Bibliography.parse(clean.join)
clean_bib.replace_strings

# -------------------- Utility functions --------------------

def to_slug(str)
  str.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
end

def bib_to_date(entry)
  year = entry[:year]&.to_i
  return "" unless year
  Date.new(year, 1, 1).iso8601
end

def parse_authors(entry)
  return "" unless entry[:author]

  entry[:author].to_s.split(/\sand\s/i).map do |a|
    if a.include?(',')
      a.strip
    else
      parts = a.split
      last  = parts.pop
      "#{last}, #{parts.join(' ')}"
    end
  end.join(', ')
end

def to_citation(entry)
  authors = parse_authors(entry)
  title   = entry[:title].to_s.strip
  venue   = entry[:journal].to_s.strip
  year    = entry[:year].to_s
  volume  = entry[:volume]
  number  = entry[:number]

  "#{authors}. (#{year}). \"#{title}\"#{venue.empty? ? '' : " <i>#{venue}</i>"}#{volume ? ", #{volume}" : ''}#{number ? "(#{number})" : ''}."
end


# -------------------- OUTPUT TSV --------------------

FileUtils.mkdir_p("../files") unless Dir.exist?("../files")
File.open(outfile, 'w') do |f|
  f.puts [
    "pub_date",
    "title",
    "venue",
    "category",
    "excerpt",
    "citation",
    "url_slug",
    "paper_url",
    "bibtex_url"
  ].join("\t")

  bib_counter = 1

  clean_bib.each do |entry|
    next unless entry.is_a?(BibTeX::Entry)
    next unless entry[:title]

    pub_date = bib_to_date(entry)
    title    = entry[:title].to_s.strip
    venue    = (entry[:journal] || entry[:booktitle]).to_s.strip
    excerpt  = entry[:abstract].to_s.strip
    citation = to_citation(entry)
    slug     = to_slug(title)
    category =
      if entry[:journal] && !entry[:journal].to_s.strip.empty?
        "manuscripts"
      elsif entry[:booktitle] && !entry[:booktitle].to_s.strip.empty?
        "conferences"
      else
        "conferences" # default
      end
    paper_url =
      if entry[:url]
        entry[:url].to_s.strip
      elsif entry[:doi]
        "https://doi.org/#{entry[:doi].to_s.strip}"
      else
        ""
      end

    bib_filename = "bibtex#{bib_counter}.bib"
    bib_path     = File.join("../files", bib_filename)
    File.open(bib_path, 'w') { |bf| bf.puts entry.to_s }
    bibtex_url   = "https://matteomagnini.github.io/files/#{bib_filename}"
    bib_counter += 1

    row = [
      pub_date,
      title,
      venue,
      category,
      excerpt,
      citation,
      slug,
      paper_url,
      bibtex_url
    ].map { |x| x.to_s.gsub("\t", " ").strip }

    f.puts row.join("\t")
  end
end

puts "publications.tsv generated from #{bibfile}"