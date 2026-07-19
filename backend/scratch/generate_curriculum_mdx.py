import os
import sys

# Ensure backend directory is in path
sys.path.append(os.path.join(os.path.dirname(__file__), ".."))

from app.core.curriculum_data import UNITS, HEADLINES

def main():
    mdx_path = os.path.join(os.path.dirname(__file__), "../../docs/mintlify-src/curriculum.mdx")
    print(f"Generating curriculum mdx at: {mdx_path}")

    content = []
    content.append("---")
    content.append('title: "Curriculum & Skills Mapping"')
    content.append('description: "The complete level-aligned step-by-step curriculum and targeted skills for Zoe (A0 to C1)."')
    content.append("---")
    content.append("")
    content.append("This document outlines the structured pedagogical framework of Zoe. Each level consists of 5 progressive units, with specific Vocabulary (VOC), Grammar (GRA), and Fluency (FLU) targets.")
    content.append("")

    levels = ["A0", "A1", "A2", "B1", "B2", "C1"]
    
    for level in levels:
        if level not in UNITS:
            continue
            
        headline = HEADLINES.get(level, "")
        content.append(f"## Level {level}")
        if headline:
            content.append(f"*{headline}*")
        content.append("")

        for unit in UNITS[level]:
            step = unit.get("step", "")
            name = unit.get("name", "")
            focus = unit.get("focus", "")
            
            content.append(f"### Step {step}: {name}")
            if focus:
                content.append(f"**Focus:** {focus}")
                content.append("")
                
            content.append("**Targeted Skills:**")
            for skill in unit.get("skills", []):
                strand = skill.get("strand", "")
                skill_id = skill.get("id", "")
                
                # Assign Tailwind badge styling based on strand
                if strand == "VOC":
                    badge = f'<span className="bg-blue-50 text-blue-700 dark:bg-blue-900/40 dark:text-blue-300 px-1.5 py-0.5 rounded text-xs font-bold font-mono mr-1">{skill_id}</span>'
                elif strand == "GRA":
                    badge = f'<span className="bg-emerald-50 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300 px-1.5 py-0.5 rounded text-xs font-bold font-mono mr-1">{skill_id}</span>'
                elif strand == "FLU":
                    badge = f'<span className="bg-purple-50 text-purple-700 dark:bg-purple-900/40 dark:text-purple-300 px-1.5 py-0.5 rounded text-xs font-bold font-mono mr-1">{skill_id}</span>'
                else:
                    badge = f'<span className="bg-gray-50 text-gray-700 dark:bg-gray-800 dark:text-gray-300 px-1.5 py-0.5 rounded text-xs font-bold font-mono mr-1">{skill_id}</span>'
                
                strand_label = {
                    "VOC": "Vocabulary",
                    "GRA": "Grammar",
                    "FLU": "Fluency"
                }.get(strand, strand)
                
                content.append(f"- {badge} ({strand_label}): {skill.get('text')}")
            content.append("")
        content.append("---")
        content.append("")

    with open(mdx_path, "w", encoding="utf-8") as f:
        f.write("\n".join(content))
    print("✓ MDX generation complete!")

if __name__ == "__main__":
    main()
