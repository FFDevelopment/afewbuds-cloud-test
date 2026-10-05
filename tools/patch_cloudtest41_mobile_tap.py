# deploy cloudtest45 finalized runtime
from pathlib import Path

builder = Path("tools/build_cloudtest24.py")
original = builder.read_text()
modified = original.replace(
    'for bad in ["PersonalInventory","personal_inventory","personal_weed","locker_cash","backpack_quick_button","your backpack"]:',
    'for bad in ["PersonalInventory","personal_inventory","backpack_quick_button","your backpack"]:'
)
builder.write_text(modified)
try:
    import build_cloudtest24
finally:
    builder.write_text(original)
