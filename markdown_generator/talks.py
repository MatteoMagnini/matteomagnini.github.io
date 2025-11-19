import pandas as pd
import os
import re

talks = pd.read_csv("talks.tsv", sep="\t", header=0)

html_escape_table = {
    "&": "&amp;",
    '"': "&quot;",
    "'": "&apos;"
}

def html_escape(text):
    if isinstance(text, str):
        return "".join(html_escape_table.get(c, c) for c in text)
    else:
        return "False"


def extract_country(location):
    if not isinstance(location, str):
        return ""

    s = location.strip()

    s = re.sub(r'[\(\)\[\]\-–—]*\s*virtuale\s*[\(\)\[\]\-–—]*', ' ', s, flags=re.IGNORECASE)
    s = re.sub(r'[\(\)\[\]\-–—]*\s*virtual\s*[\(\)\[\]\-–—]*', ' ', s, flags=re.IGNORECASE)

    s = re.sub(r'\s+', ' ', s).strip()

    if not s:
        return ""

    parts = [p.strip() for p in s.split(",") if p.strip()]

    if len(parts) == 0:
        return ""

    return parts[-1]


for row, item in talks.iterrows():

    md_filename = f"{item.date}-{item.url_slug}.md"
    html_filename = f"{item.date}-{item.url_slug}"
    year = item.date[:4]
    country = extract_country(item.location)

    md = "---\n"
    md += f'title: "{item.title}"\n'
    md += "collection: talks\n"

    if len(str(item.type)) > 3:
        md += f'type: "{item.type}"\n'
    else:
        md += 'type: "Talk"\n'

    md += f"year: {year}\n"

    if country:
        md += f'country: "{country}"\n'

    md += f"permalink: /talks/{html_filename}\n"

    if len(str(item.venue)) > 3:
        md += f'venue: "{item.venue.replace('"', "'")}"\n'

    if len(str(item.date)) > 3:
        md += f"date: {item.date}\n"

    if len(str(item.location)) > 3:
        md += f'location: "{item.location}"\n'

    if len(str(item.slides_url)) > 5:
        md += f"slidesurl: '{item.slides_url}'\n"

    if len(str(item.poster_url)) > 5:
        md += f"posterurl: '{item.poster_url}'\n"

    md += "---\n"

    if len(str(item.description)) > 3:
        md += "\n" + html_escape(item.description) + "\n"

    md_filename = os.path.basename(md_filename)

    with open("../_talks/" + md_filename, 'w') as f:
        f.write(md)
