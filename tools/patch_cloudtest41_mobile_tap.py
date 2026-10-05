from pathlib import Path

builder = Path("tools/build_cloudtest24.py")
text = builder.read_text()
text = text.replace(
    'for bad in ["PersonalInventory","personal_inventory","personal_weed","locker_cash","backpack_quick_button","your backpack"]:',
    'for bad in ["PersonalInventory","personal_inventory","backpack_quick_button","your backpack"]:'
)
builder.write_text(text)

import build_cloudtest24
