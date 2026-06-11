import re
import openpyxl
import os
import sys
import json

def main():
    excel_path = './docs/Ella_Framework_Complete.xlsx'
    index_path = '../ella-mvp/index.html'

    if not os.path.exists(excel_path):
        print(f"Error: Excel file not found at {excel_path}")
        sys.exit(1)
    if not os.path.exists(index_path):
        print(f"Error: index.html not found at {index_path}")
        sys.exit(1)

    print("Loading workbook...")
    wb = openpyxl.load_workbook(excel_path, data_only=True)
    strand_map = {'Vocabulary': 'VOC', 'Grammar': 'GRA', 'Fluency': 'FLU'}

    # 1. Parse CAT (flat skills)
    print("Parsing flat skills (CAT)...")
    CAT = []
    for level in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']:
        sheet = wb[level]
        current_strand = None
        counts = {'VOC': 0, 'GRA': 0, 'FLU': 0}
        
        for row in sheet.iter_rows(values_only=True):
            if not row or all(v is None for v in row):
                continue
            section, subsection, content = row[0], row[1], row[2]
            if section in strand_map:
                current_strand = strand_map[section]
            
            if subsection == 'I can statement' and content:
                counts[current_strand] += 1
                skill_id = f"{level}-{current_strand}-{counts[current_strand]:02d}"
                CAT.append([skill_id, level, current_strand, content.strip()])

    # 2. Parse UNITS
    print("Parsing transition units...")
    UNITS = {}
    transitions = [
        ('A1', 'A1→A2'),
        ('A2', 'A2→B1'),
        ('B1', 'B1→B2'),
        ('B2', 'B2→C1'),
        ('C1', 'C1→C2')
    ]
    for level, sheetname in transitions:
        sheet = wb[sheetname]
        units_list = []
        current_unit = None
        
        for row in sheet.iter_rows(values_only=True):
            if not row or all(v is None for v in row):
                continue
            col0, col1, col2, col3 = row[0], row[1], row[2], row[3]
            
            if col0 and str(col0).startswith('Step '):
                step_num = str(col0).replace('Step ', '').strip()
                current_unit = {
                    'step': step_num,
                    'name': col1.strip() if col1 else '',
                    'focus': '',
                    'skills': []
                }
                units_list.append(current_unit)
                
            if current_unit:
                if col2 == 'Focus' and col3:
                    current_unit['focus'] = col3.strip()
                elif col2 == 'I can statement' and col3:
                    strand_name = col1.strip() if col1 else ''
                    strand_abbr = strand_map.get(strand_name)
                    strand_count = sum(1 for s in current_unit['skills'] if s['strand'] == strand_abbr) + 1
                    skill_id = f"U{current_unit['step']}-{strand_abbr}-{strand_count:02d}"
                    current_unit['skills'].append({
                        'id': skill_id,
                        'strand': strand_abbr,
                        'text': col3.strip()
                    })
        UNITS[level] = units_list
    UNITS['C2'] = []

    # 3. Parse Topics for local JS fallback
    print("Parsing local topics...")
    TOPICS = {}
    for level in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']:
        sheetname = f"Topics — {level}"
        sheet = wb[sheetname]
        topics_list = []
        
        for row in sheet.iter_rows(values_only=True):
            if not row or all(v is None for v in row):
                continue
            col0, col1, col2, col3, col4, col5 = row[0], row[1], row[2], row[3], row[4], row[5]
            
            if col0 is None or "Topics" in str(col0) or "Headline" in str(col0) or "can talk" in str(col0) or col0 == "#":
                continue
                
            theme = col1.strip() if col1 else "General"
            topic_name = col2.strip() if col2 else ""
            starters_raw = col5.strip() if col5 else ""
            
            starters = []
            for s in starters_raw.split("\n"):
                s_clean = re.sub(r'^[•\-\*\s]+', '', s).strip()
                if s_clean:
                    starters.append(s_clean)
            
            topics_list.append({
                "theme": theme,
                "topic": topic_name,
                "starters": " / ".join(starters)
            })
        TOPICS[level] = topics_list

    # 4. Patch index.html
    print("Patching index.html...")
    with open(index_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace CAT list
    cat_match = re.search(r'const CAT\s*=\s*\[\[.*?\]\];', content, re.DOTALL)
    if cat_match:
        content = content.replace(cat_match.group(0), f"const CAT={json.dumps(CAT)};")

    # Replace TOPICS list
    topics_match = re.search(r'const TOPICS\s*=\s*\{.*?\};', content, re.DOTALL)
    if topics_match:
        content = content.replace(topics_match.group(0), f"const TOPICS={json.dumps(TOPICS)};")

    # Replace UNITS_A1 definition and update to general UNITS object
    units_match = re.search(r'const UNITS_A1\s*=\s*\[\{.*?\}\];', content, re.DOTALL)
    if units_match:
        content = content.replace(units_match.group(0), f"const UNITS={json.dumps(UNITS)};")

    # Update UNIT_SKILLS loop (line 102 in original file)
    loop_target = 'const UNIT_SKILLS={};' + '\n' + 'UNITS_A1.forEach(u=>u.skills.forEach(s=>{UNIT_SKILLS[s.id]={...s,step:u.step,stepName:u.name};}));'
    loop_replacement = 'const UNIT_SKILLS={};' + '\n' + 'Object.entries(UNITS).forEach(([lvl, uList])=>{ uList.forEach(u=>u.skills.forEach(s=>{ UNIT_SKILLS[s.id]={...s,step:u.step,stepName:u.name,level:lvl}; })); });'
    content = content.replace(loop_target, loop_replacement)

    # In case there's slight whitespace diff, let's also do a general search-replace
    content = content.replace('UNITS_A1.forEach(u=>u.skills.forEach(s=>{UNIT_SKILLS[s.id]={...s,step:u.step,stepName:u.name};}));', 
                              'Object.entries(UNITS).forEach(([lvl, uList])=>{ uList.forEach(u=>u.skills.forEach(s=>{ UNIT_SKILLS[s.id]={...s,step:u.step,stepName:u.name,level:lvl}; })); });')

    # Update activeStep definition
    content = content.replace('for(const u of UNITS_A1){ if(!unitComplete(mem,u)) return u; }',
                              'const uList = UNITS[mem.level] || UNITS["A1"] || []; for(const u of uList){ if(!unitComplete(mem,u)) return u; }')

    # Update endChat active step lookup
    content = content.replace('const uids=UNITS_A1.flatMap(u=>u.skills.map(s=>s.id)).slice(0,8);',
                              'const activeUnits = UNITS[level] || UNITS["A1"] || []; const uids=activeUnits.flatMap(u=>u.skills.map(s=>s.id)).slice(0,8);')

    # Update UnitsView loop
    content = content.replace('UNITS_A1.map(u=>{const p=stepProgress(mem,u);',
                              '(UNITS[mem.level] || UNITS["A1"] || []).map(u=>{const p=stepProgress(mem,u);')

    with open(index_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print("Success: index.html patched successfully!")

if __name__ == '__main__':
    main()
