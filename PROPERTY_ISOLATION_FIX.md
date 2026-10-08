# Property isolation correction

Based on public equipment beta 0.16.0, preserving the session hotfix and Chapter 5 updates.

- Desktop shows nearby station prompts using the same station lookup as mobile, including low house workbenches.
- Acquiring the house offers make-house-primary, keep-apartment-primary, and decide-later actions. Neither confirmation transfers equipment, stock, or workers.
- Production and dealer actions use the worker assignment property (existing crew defaults to apartment), with scoped inventory adapters restored after each action. Tent care filters out other properties, and plant interactions consume supplies from their tent property.
- Physical trimming and bagging retain the selected station identity. Stored stock and processing queues persist independently through save/reload.
- Existing contents are preserved where recorded. Previously misrouted stock cannot be attributed retroactively without evidence and is not moved automatically.

This fixes isolation of the existing workforce. It does not increase the existing production-worker hiring limit or add a second house workforce management screen.

Regression coverage: both house choices, pre-existing house-active saves, apartment worker trim/bag/store, manual house trimming, plant ownership, fertilizer isolation, save/reload, and desktop prompt activation. Existing equipment, progression, inventory, crew, account and session gates remain in place.
