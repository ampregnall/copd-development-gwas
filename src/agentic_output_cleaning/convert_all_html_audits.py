import os
import re
import tempfile
from bs4 import BeautifulSoup

# Master template using native placeholders
MASTER_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>__PAGE_TITLE__</title>
    <link rel="stylesheet" href="../style.css">
</head>
<body>
    <div id="sidebar">
        <div class="sidebar-header">
            🧬 Agentic Gene Prioritization<br>Dashboard
        </div>

        <div class="sidebar-section">
            <div class="sidebar-title">Overview</div>
            <a class="nav-link" href="../index.html">🏠 Home</a>
            <a class="nav-link" href="../methods.html">🔬 Methods</a>
        </div>

        <div class="sidebar-section">
            <div class="sidebar-title">Chromosomes</div>
            <a class="nav-link active" href="../CHR1.html">CHR1</a>
            <a class="nav-link" href="../CHR2.html">CHR2</a>
            <a class="nav-link" href="../CHR3.html">CHR3</a>
            <a class="nav-link" href="../CHR4.html">CHR4</a>
            <a class="nav-link" href="../CHR5.html">CHR5</a>
            <a class="nav-link" href="../CHR6.html">CHR6</a>
            <a class="nav-link" href="../CHR7.html">CHR7</a>
            <a class="nav-link" href="../CHR8.html">CHR8</a>
            <a class="nav-link" href="../CHR9.html">CHR9</a>
            <a class="nav-link" href="../CHR10.html">CHR10</a>
            <a class="nav-link" href="../CHR11.html">CHR11</a>
            <a class="nav-link" href="../CHR12.html">CHR12</a>
            <a class="nav-link" href="../CHR13.html">CHR13</a>
            <a class="nav-link" href="../CHR14.html">CHR14</a>
            <a class="nav-link" href="../CHR15.html">CHR15</a>
            <a class="nav-link" href="../CHR16.html">CHR16</a>
            <a class="nav-link" href="../CHR17.html">CHR17</a>
            <a class="nav-link" href="../CHR18.html">CHR18</a>
            <a class="nav-link" href="../CHR19.html">CHR19</a>
            <a class="nav-link" href="../CHR20.html">CHR20</a>
            <a class="nav-link" href="../CHR21.html">CHR21</a>
            <a class="nav-link" href="../CHR22.html">CHR22</a>
        </div>
    </div>

    <div id="main-content">
        <div class="content-card">
            __CORE_CONTENT__
        </div>
    </div>
</body>
</html>
"""

def add_tags_to_element(element, text, soup):
    """Helper to convert keywords into styled span tags."""
    keywords = [
        ("WEAKENED", "tag-warning"), 
        ("CONTESTED", "tag-warning"), 
        ("RETRACTED", "tag-warning"), 
        ("HOLDS", "tag-hold"), 
        ("VERIFIED", "tag")
    ]
    found = False
    for kw, cls in keywords:
        if kw in text:
            parts = text.split(kw, 1)
            element.clear()
            element.append(parts[0])
            span = soup.new_tag("span", **{"class": cls})
            span.string = kw
            element.append(span)
            element.append(parts[1])
            found = True
            break
    if not found:
        element.string = text

def process_html_file(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f.read(), "html.parser")

    raw_lines = []
    for p in soup.find_all("p"):
        text = p.get_text()
        if not text.strip() or "<br>" in str(p):
            raw_lines.append("")
        else:
            raw_lines.append(text)

    new_soup = BeautifulSoup("<div></div>", "html.parser")
    container = new_soup.div
    container.append("\n    ")

    page_title = "Evidence Table"

    blocks = []
    current_block = []
    for line in raw_lines:
        if line == "":
            if current_block:
                blocks.append(current_block)
                current_block = []
        else:
            current_block.append(line)
    if current_block:
        blocks.append(current_block)

    for block in blocks:
        first_line = block[0].strip()
        
        # Clean potential blockquote prefixes for analysis
        cleaned_first_line = re.sub(r'^(?:&gt;|>)\s*', '', first_line).strip()
        
        # 1. Parse Markdown Tables
        if all(line.strip().startswith("|") for line in block):
            table_tag = new_soup.new_tag("table", **{"class": "evidence-table"})
            thead = new_soup.new_tag("thead")
            tbody = new_soup.new_tag("tbody")
            
            is_header = True
            for line in block:
                cells = [c.strip() for c in line.strip().strip("|").split("|")]
                if all(c.replace("-", "").strip() == "" for c in cells):
                    is_header = False
                    continue
                
                tr = new_soup.new_tag("tr")
                for i, cell_text in enumerate(cells):
                    tag_name = "th" if is_header else "td"
                    cell_tag = new_soup.new_tag(tag_name)
                    if not is_header and i == 0:
                        cell_tag["class"] = "gene"
                    
                    add_tags_to_element(cell_tag, cell_text, new_soup)
                    tr.append(cell_tag)
                
                if is_header:
                    thead.append(tr)
                else:
                    tbody.append(tr)
            
            if thead.contents:
                table_tag.append(thead)
            if tbody.contents:
                table_tag.append(tbody)
                
            wrapper = new_soup.new_tag("div", attrs={"class": "evidence-table-wrapper"})
            wrapper.append(table_tag)
            container.append(wrapper)
            container.append("\n    ")

        # 2. Parse Markdown Numbered Lists (handling optional blockquote wrappers & multi-line items)
        elif re.match(r'^\d+\.\s+', cleaned_first_line):
            ol_tag = new_soup.new_tag("ol")
            current_item_lines = []
            
            def flush_item(item_lines):
                if item_lines:
                    li_tag = new_soup.new_tag("li")
                    joined = " ".join([re.sub(r'^(?:&gt;|>)\s*', '', l).strip() for l in item_lines])
                    li_text = re.sub(r'^\d+\.\s*', '', joined).strip()
                    add_tags_to_element(li_tag, li_text, new_soup)
                    ol_tag.append(li_tag)

            for line in block:
                cleaned_line = re.sub(r'^(?:&gt;|>)\s*', '', line).strip()
                if re.match(r'^\d+\.\s+', cleaned_line):
                    flush_item(current_item_lines)
                    current_item_lines = [line]
                else:
                    current_item_lines.append(line)
            flush_item(current_item_lines)
            
            container.append(ol_tag)
            container.append("\n    ")

        # 3. Parse Markdown Bullet Lists
        elif all(line.strip().startswith(("* ", "- ", "• ")) for line in block) or \
             all(re.match(r'^(?:&gt;|>)\s*[\*\-•]\s+', line.strip()) for line in block):
            ul_tag = new_soup.new_tag("ul")
            for line in block:
                li_tag = new_soup.new_tag("li")
                cleaned = re.sub(r'^(?:&gt;|>)\s*', '', line).strip()
                li_text = cleaned.lstrip("* -•").strip()
                add_tags_to_element(li_tag, li_text, new_soup)
                ul_tag.append(li_tag)
            container.append(ul_tag)
            container.append("\n    ")

        # 4. Parse Headers
        elif cleaned_first_line.startswith("# "):
            h1 = new_soup.new_tag("h1")
            title_text = cleaned_first_line.lstrip("# ").strip()
            h1.string = title_text
            container.append(h1)
            container.append("\n    ")
            
            locus_match = re.search(r'(\d+[\:_]\d+[\-_]\d+)', title_text)
            if locus_match:
                formatted_locus = locus_match.group(1).replace('_', ':')
                h1.string = f"Evidence Table — Locus {formatted_locus}"
                page_title = f"Evidence Table — {formatted_locus}"
            else:
                page_title = title_text
                
        elif cleaned_first_line.startswith("## "):
            h2 = new_soup.new_tag("h2")
            h2.string = cleaned_first_line.lstrip("# ").strip()
            container.append(h2)
            container.append("\n    ")
        elif cleaned_first_line.startswith("### "):
            h3 = new_soup.new_tag("h3")
            h3.string = cleaned_first_line.lstrip("# ").strip()
            container.append(h3)
            container.append("\n    ")
            
        # 5. Parse True Blockquotes
        elif all(line.strip().startswith(">") or line.strip().startswith("&gt;") for line in block):
            blockquote = new_soup.new_tag("blockquote")
            bq_text = " ".join([re.sub(r'^(?:&gt;|>)\s*', '', line).strip() for line in block])
            blockquote.string = bq_text
            container.append(blockquote)
            container.append("\n    ")
            
        # 6. Parse Regular Paragraphs
        else:
            p = new_soup.new_tag("p")
            p_text = " ".join([re.sub(r'^(?:&gt;|>)\s*', '', line).strip() for line in block])
            add_tags_to_element(p, p_text, new_soup)
            container.append(p)
            container.append("\n    ")

    core_content = container.decode_contents()
    return core_content, page_title

def main():
    # Gets the directory where convert_all.py is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    input_dir = os.path.join(script_dir, "messy_html")
    output_dir = os.path.join(script_dir, "clean_html")

    if not os.path.exists(input_dir):
        print(f"Error: Could not find folder '{input_dir}'. Please ensure 'messy_html' is in the same folder as this script.")
        return

    os.makedirs(output_dir, exist_ok=True)

    file_count = 0
    for filename in os.listdir(input_dir):
        if filename.endswith(".html"):
            input_path = os.path.join(input_dir, filename)
            core_content, page_title = process_html_file(input_path)
            
            clean_html = MASTER_TEMPLATE.replace("__PAGE_TITLE__", page_title).replace("__CORE_CONTENT__", core_content)
            
            output_path = os.path.join(output_dir, filename)
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(clean_html)
            
            file_count += 1

    print(f"Successfully converted {file_count} files into '{output_dir}'")

if __name__ == "__main__":
    main()