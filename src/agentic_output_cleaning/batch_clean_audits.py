import os
from bs4 import BeautifulSoup

def update_all_audit_file_titles(audit_folder, evidence_folder):
    """
    Finds all files ending in _audit.html in audit_folder, locates their 
    partner evidence files in evidence_folder, and updates their <title> and <h1> 
    tags to 'Audit Report - ...' based on the evidence file's title.
    """
    if not os.path.exists(audit_folder):
        print(f"Error: Audit folder not found at '{audit_folder}'")
        return

    if not os.path.exists(evidence_folder):
        print(f"Error: Evidence folder not found at '{evidence_folder}'")
        return

    updated_count = 0
    
    for filename in os.listdir(audit_folder):
        if filename.endswith("_audit.html"):
            audit_file_path = os.path.join(audit_folder, filename)
            
            # Generate partner filename (e.g., '1_28200001-28950000_audit.html' -> '1_28200001-28950000.html')
            partner_filename = filename.replace("_audit.html", ".html")
            partner_file_path = os.path.join(evidence_folder, partner_filename)

            if not os.path.exists(partner_file_path):
                print(f"Skipping '{filename}': Partner evidence file '{partner_filename}' not found.")
                continue

            # Read partner (evidence) file to get its title
            with open(partner_file_path, "r", encoding="utf-8") as f:
                partner_soup = BeautifulSoup(f.read(), "html.parser")

            partner_title_text = ""
            h1_tag = partner_soup.find("h1")
            if h1_tag:
                partner_title_text = h1_tag.get_text().strip()
            else:
                title_tag = partner_soup.find("title")
                if title_tag:
                    partner_title_text = title_tag.get_text().strip()

            if not partner_title_text:
                print(f"Warning: No title or <h1> found in partner file '{partner_filename}'")
                continue

            # Transform "Evidence Table" to "Audit Report"
            audit_title_text = partner_title_text.replace("Evidence Table", "Audit Report")

            # Read the audit file
            with open(audit_file_path, "r", encoding="utf-8") as f:
                audit_soup = BeautifulSoup(f.read(), "html.parser")

            # Update audit file <title>
            title_tag = audit_soup.find("title")
            if title_tag:
                title_tag.string = audit_title_text
            else:
                head = audit_soup.find("head")
                if head:
                    new_title = audit_soup.new_tag("title")
                    new_title.string = audit_title_text
                    head.append(new_title)

            # Update audit file <h1>
            audit_h1 = audit_soup.find("h1")
            if audit_h1:
                audit_h1.string = audit_title_text

            # Write the updated content back to the audit file
            with open(audit_file_path, "w", encoding="utf-8") as f:
                f.write(str(audit_soup))

            print(f"Successfully updated: '{filename}' -> '{audit_title_text}'")
            updated_count += 1

    print(f"\nFinished! Successfully updated {updated_count} audit file(s).")

if __name__ == "__main__":
    # Specify your folders here (can be the same folder if both files live together)
    audit_folder = "clean_audit"
    evidence_folder = "clean_tables"
    
    update_all_audit_file_titles(audit_folder, evidence_folder)