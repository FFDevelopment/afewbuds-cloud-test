"""Stage Pages without archival packs/recipes; keep rebuild inputs in Git."""
from pathlib import Path
import argparse, json, re, shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]

def selection():
    html = (ROOT / 'index.html').read_text(encoding='utf-8')
    packs = set(re.findall(r'"mainPack":"([^"?]+)', html))
    recipes = set()
    for script in re.findall(r'<script[^>]+src=["\']([^"\']+)', html):
        path = ROOT / script.split('?')[0]
        for recipe in re.findall(r'runtime/[\w.-]+\.patch\.json', path.read_text(encoding='utf-8')):
            recipes.add(recipe)
    for name in recipes:
        recipe = json.loads((ROOT / name).read_text(encoding='utf-8'))
        packs.add(recipe['base_url'].split('?')[0])
        for segment in recipe['segments']:
            if segment[0] == 'asset':
                assert (ROOT / segment[1].split('?')[0]).is_file()
    files = subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard'], cwd=ROOT, text=True).splitlines()
    kept, removed = [], []
    for name in sorted(set(files)):
        p = Path(name)
        if not (ROOT / p).is_file():
            continue
        archive = (p.suffix == '.pck' and len(p.parts) == 1 and name not in packs) or (p.parts[0] == 'runtime' and name not in recipes)
        source_only = p.parts[0] in {'.github', 'supabase', 'archive', 'tools'} or name.startswith('debug-') or '__pycache__' in p.parts
        (removed if archive or source_only else kept).append(name)
    assert 'index.html' in kept and 'index.wasm' in kept and recipes.issubset(kept)
    assert all(name in kept for name in packs if (ROOT / name).exists())
    return kept, removed

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output', type=Path);ap.add_argument('--report', type=Path);args=ap.parse_args()
    kept, removed=selection()
    if args.output:
        output=args.output.resolve()
        # Never erase an existing tree or place staging inside the source repository.
        assert output != ROOT and ROOT not in output.parents and not output.exists(), output
        output.mkdir(parents=True)
        for name in kept:
            dest=output/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,dest)
    size=lambda names:sum((ROOT/name).stat().st_size for name in names)
    report={'selected_files':len(kept),'source_bytes':size(kept+removed),'deployed_bytes':size(kept),'excluded_bytes':size(removed),'excluded_files':removed,'note':'Uncompressed file sizes; excluded archives were not fetched by gameplay. Git history is unchanged.'}
    if args.report:args.report.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='excluded_files'},indent=2))
if __name__=='__main__':main()
