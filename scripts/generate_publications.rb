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

# Estrai il contenuto di un campo BibTeX gestendo { } bilanciati
def extract_braced_field(content, field_name)
  re = /#{field_name}\s*=\s*\{/mi
  m  = content.match(re)
  return nil unless m

  idx   = m.end(0)
  depth = 1
  result = +''
  while idx < content.length && depth > 0
    ch = content[idx]
    if ch == '{'
      depth += 1
      result << ch
    elsif ch == '}'
      depth -= 1
      break if depth.zero?
      result << ch
    else
      result << ch
    end
    idx += 1
  end

  result.strip
end

def extract_field(content, field_name)
  braced = extract_braced_field(content, field_name)
  return braced if braced

  if content =~ /#{field_name}\s*=\s*"(.*?)"/mi
    return Regexp.last_match(1).strip
  end

  nil
end

# Convert BibTeX/TeX escapes to Unicode
def bibtex_to_unicode(str)
  s = str.to_s.dup

  replacements = {
    # diaeresis
    /\\"a/  => 'ä', /\\"A/  => 'Ä',
    /\\"o/  => 'ö', /\\"O/  => 'Ö',
    /\\"u/  => 'ü', /\\"U/  => 'Ü',
    /\\"e/  => 'ë', /\\"E/  => 'Ë',
    /\\"i/  => 'ï', /\\"I/  => 'Ï',

    # acute
    /\\'a/  => 'á', /\\'A/  => 'Á',
    /\\'e/  => 'é', /\\'E/  => 'É',
    /\\'i/  => 'í', /\\'I/  => 'Í',
    /\\'o/  => 'ó', /\\'O/  => 'Ó',
    /\\'u/  => 'ú', /\\'U/  => 'Ú',
    /\\'c/  => 'ć', /\\'C/  => 'Ć',

    # grave
    /\\`a/  => 'à', /\\`A/  => 'À',
    /\\`e/  => 'è', /\\`E/  => 'È',
    /\\`i/  => 'ì', /\\`I/  => 'Ì',
    /\\`o/  => 'ò', /\\`O/  => 'Ò',
    /\\`u/  => 'ù', /\\`U/  => 'Ù',

    # tilde
    /\\~n/  => 'ñ', /\\~N/  => 'Ñ',

    # cedilla
    /\\c c/     => 'ç',
    /\\cC/      => 'Ç',
    /\\c\{c\}/  => 'ç',
    /\\c\{C\}/  => 'Ç',

    # sharp s
    /\\ss/  => 'ß'
  }

  replacements.each { |pattern, repl| s.gsub!(pattern, repl) }

  s
end

# Rimuovi graffe "inline" mantenendo il testo, es: "{KINS:}" -> "KINS:"
def strip_inline_braces(str)
  s = str.to_s.dup
  # gestisce casi come "{KINS:}", "{KILL:}", anche se appaiono in mezzo al testo
  s.gsub!(/\{([^{}]+)\}/, '\1')
  s
end

def yaml_double_quoted(str)
  s = str.to_s.dup
  s.gsub!('\\', '\\\\')
  s.gsub!('"', '\"')
  s.gsub!(/\s+/, ' ')
  "\"#{s.strip}\""
end

def parse_bib_content(content)
  fields = {}

  if content =~ /^@(\w+)\s*{\s*([^,]+),/m
    fields['entrytype'] = Regexp.last_match(1).strip.downcase
    fields['bibkey']    = Regexp.last_match(2).strip
  end

  %w[title year url note journal booktitle volume].each do |name|
    val = extract_field(content, name)
    fields[name] = val if val
  end

  author_val = extract_field(content, 'author')
  fields['author'] = author_val if author_val

  fields
end

def determine_category(entrytype, fields)
  t = (entrytype || '').downcase

  if t.include?('inbook') || t == 'book'
    return 'books' if fields['booktitle'] || t == 'book'
  end

  return 'manuscripts' if t == 'article'

  'conferences'
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

  fields    = parse_bib_content(content)
  entrytype = fields['entrytype']
  category  = determine_category(entrytype, fields)

  # Titolo
  title_raw = fields['title'] || File.basename(bib_name, '.bib')
  title     = bibtex_to_unicode(title_raw)
  title     = strip_inline_braces(title)

  # Anno / data
  year_raw  = fields['year'] || '1900'
  year      = year_raw.gsub(/[^\d]/, '')
  year      = '1900' if year.empty?
  date      = "#{year}-01-01"

  # Venue
  venue_raw = fields['booktitle'] || fields['journal'] || fields['note'] || ''
  venue     = bibtex_to_unicode(venue_raw)
  venue     = strip_inline_braces(venue)

  # URL paper
  paperurl_raw = fields['url'] || ''
  paperurl     = bibtex_to_unicode(paperurl_raw)

  bibtexurl = "#{GITHUB_BIB_BASE}/#{bib_name}"

  slug       = slugify(title)
  filename   = "#{date}-#{slug}.md"
  out_path   = File.join(OUTPUT_DIR, filename)

  # Autori
  authors_raw = fields['author'] || ''
  authors     = bibtex_to_unicode(authors_raw)
  authors     = strip_inline_braces(authors)

  yaml_title     = yaml_double_quoted(title)
  yaml_venue     = yaml_double_quoted(venue)
  yaml_paperurl  = yaml_double_quoted(paperurl)
  yaml_bibtexurl = yaml_double_quoted(bibtexurl)
  yaml_authors   = yaml_double_quoted(authors)
  yaml_category  = yaml_double_quoted(category)

  permalink = "/publication/#{date}-#{slug}"

  front_matter = <<~YAML
    ---
    title: #{yaml_title}
    collection: "publications"
    category: #{yaml_category}

    permalink: "#{permalink}"
    date: #{date}
    venue: #{yaml_venue}
    paperurl: #{yaml_paperurl}
    bibtexurl: #{yaml_bibtexurl}
    authors: #{yaml_authors}
    ---
  YAML

  File.write(out_path, front_matter, mode: 'w', encoding: 'UTF-8')
  puts "Created: #{out_path} (#{category})"
end