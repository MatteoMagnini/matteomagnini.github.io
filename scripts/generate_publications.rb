#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'open-uri'

REPO_URL        = 'https://github.com/MatteoMagnini/cv'
BIB_URL         = "#{REPO_URL}/tree/master/bibtex"
RAW_BIB_BASE    = 'https://raw.githubusercontent.com/MatteoMagnini/cv/master/bibtex'
GITHUB_BIB_BASE = 'https://github.com/MatteoMagnini/cv/blob/master/bibtex'

OUTPUT_DIR      = File.expand_path('../_publications', __dir__)
FileUtils.mkdir_p(OUTPUT_DIR)

# ----------------- Helpers -----------------

def slugify(str)
  s = str.to_s.dup.downcase
  if s.respond_to?(:encode)
    s = s.encode('ASCII', invalid: :replace, undef: :replace, replace: '')
  end
  s.gsub!(/['`]/, '')
  s.gsub!(/[^a-z0-9]+/, '-')
  s.gsub!(/-+/, '-')
  s.gsub!(/^-|-$/, '')
  s
end

# Converti semplice BibTeX/TeX in Unicode (estendibile se servono altri accenti)
def bibtex_to_unicode(str)
  s = str.to_s.dup

  # Prima rimuovi braces di puro "raggruppamento"
  s.gsub!(/[{}]/, '')

  replacements = {
    # dieresi
    /\\"a/  => 'ä',
    /\\"A/  => 'Ä',
    /\\"o/  => 'ö',
    /\\"O/  => 'Ö',
    /\\"u/  => 'ü',
    /\\"U/  => 'Ü',
    /\\"e/  => 'ë',
    /\\"E/  => 'Ë',
    /\\"i/  => 'ï',
    /\\"I/  => 'Ï',

    # accento acuto
    /\\'a/  => 'á',
    /\\'A/  => 'Á',
    /\\'e/  => 'é',
    /\\'E/  => 'É',
    /\\'i/  => 'í',
    /\\'I/  => 'Í',
    /\\'o/  => 'ó',
    /\\'O/  => 'Ó',
    /\\'u/  => 'ú',
    /\\'U/  => 'Ú',
    /\\'c/  => 'ć',
    /\\'C/  => 'Ć',

    # accento grave
    /\\`a/  => 'à',
    /\\`A/  => 'À',
    /\\`e/  => 'è',
    /\\`E/  => 'È',
    /\\`i/  => 'ì',
    /\\`I/  => 'Ì',
    /\\`o/  => 'ò',
    /\\`O/  => 'Ò',
    /\\`u/  => 'ù',
    /\\`U/  => 'Ù',

    # tilde
    /\\~n/  => 'ñ',
    /\\~N/  => 'Ñ',

    # cediglia
    /\\c c/ => 'ç',
    /\\cC/  => 'Ç',
    /\\c\{c\}/ => 'ç',
    /\\c\{C\}/ => 'Ç',

    # sharp s
    /\\ss/  => 'ß'
  }

  replacements.each do |pattern, repl|
    s.gsub!(pattern, repl)
  end

  s
end

def yaml_double_quoted(str)
  s = str.to_s.dup
  # Niente rimozione braces qui: li abbiamo già gestiti in bibtex_to_unicode
  s.gsub!('\\', '\\\\')
  s.gsub!('"', '\"')
  # tutto su una riga
  s.gsub!(/\s+/, ' ')
  "\"#{s.strip}\""
end

def parse_bib_content(content)
  fields = {}

  # tipo e chiave
  if content =~ /^@\w+\s*{\s*([^,]+),/m
    fields['bibkey'] = Regexp.last_match(1).strip
  end

  # campi semplici su una riga
  simple_fields = {
    'title'      => /title\s*=\s*[{"](.+?)[}"],?/mi,
    'year'       => /year\s*=\s*[{"](.+?)[}"],?/mi,
    'url'        => /url\s*=\s*[{"](.+?)[}"],?/mi,
    'note'       => /note\s*=\s*[{"](.+?)[}"],?/mi,
    'journal'    => /journal\s*=\s*[{"](.+?)[}"],?/mi,
    'booktitle'  => /booktitle\s*=\s*[{"](.+?)[}"],?/mi,
    'volume'     => /volume\s*=\s*[{"](.+?)[}"],?/mi
  }

  simple_fields.each do |key, regex|
    if content =~ regex
      fields[key] = Regexp.last_match(1).strip
    end
  end

  # author può essere multilinea. Prende tutto tra { e la } finale prima della virgola.
  if content =~ /author\s*=\s*\{(.*?)\},/m
    # questo prende il blocco interno, compresi eventuali \"
    fields['author'] = Regexp.last_match(1).strip
  elsif content =~ /author\s*=\s*"(.*?)",/m
    fields['author'] = Regexp.last_match(1).strip
  end

  fields
end

def list_bib_files
  html = URI.open(BIB_URL, &:read)
  files = html.scan(/href="\/MatteoMagnini\/cv\/blob\/master\/bibtex\/([^"?]+\.bib)"/i).flatten
  files.uniq
end

# ----------------- Main -----------------

bib_files = list_bib_files

bib_files.each do |bib_name|
  raw_url = "#{RAW_BIB_BASE}/#{bib_name}"

  begin
    content = URI.open(raw_url, &:read)
  rescue => e
    warn "Skipping #{bib_name}: #{e}"
    next
  end

  fields = parse_bib_content(content)

  title_raw = fields['title'] || File.basename(bib_name, '.bib')
  title     = bibtex_to_unicode(title_raw)

  year_raw  = fields['year'] || '1900'
  year      = year_raw.gsub(/[^\d]/, '')
  year      = '1900' if year.empty?
  date      = "#{year}-01-01"

  venue_raw = fields['booktitle'] || fields['journal'] || fields['note'] || ''
  venue     = bibtex_to_unicode(venue_raw)

  paperurl_raw = fields['url'] || ''
  paperurl     = bibtex_to_unicode(paperurl_raw)

  bibtexurl = "#{GITHUB_BIB_BASE}/#{bib_name}"

  slug       = slugify(title)
  filename   = "#{date}-#{slug}.md"
  out_path   = File.join(OUTPUT_DIR, filename)

  authors_raw = fields['author'] || ''
  authors     = bibtex_to_unicode(authors_raw)

  yaml_title     = yaml_double_quoted(title)
  yaml_venue     = yaml_double_quoted(venue)
  yaml_paperurl  = yaml_double_quoted(paperurl)
  yaml_bibtexurl = yaml_double_quoted(bibtexurl)
  yaml_authors   = yaml_double_quoted(authors)

  permalink = "/publication/#{date}-#{slug}"

  front_matter = <<~YAML
    ---
    title: #{yaml_title}
    collection: "publications"
    category: "conferences"

    permalink: "#{permalink}"
    date: #{date}
    venue: #{yaml_venue}
    paperurl: #{yaml_paperurl}
    bibtexurl: #{yaml_bibtexurl}
    authors: #{yaml_authors}
    ---
  YAML

  File.write(out_path, front_matter, mode: 'w', encoding: 'UTF-8')
  puts "Created: #{out_path}"
end