# Container inventory preview

Branch: `experiment/container-inventory` in both repositories. Main remains the established paired baseline.

## Try it

Open BACKPACK (I on desktop). Walk up to a grow shelf, storage/stash, dealer storage, or packing container and open it. Only that container appears. Add Stock opens your backpack alongside it; choose an item and amount, then Store or Take. Portrait stacks the panels; landscape displays them side by side with separate scroll areas. Wrong item types are disabled. Reserved sale stock cannot be taken.

Backpack uses one shared weight budget: 35 lb initially, upgraded at Central Market to 55 lb ($250), 80 lb ($750), and 110 lb ($1,750). Seeds weigh 0.02 lb each; a pack of 5 fertilizer weighs 5 lb total. Product weighs exactly 1g per gram; cash is weightless. Packed equipment has item-specific weight (4-12 lb). Existing overweight careers retain everything and can unload items; incoming weighted transfers wait until enough space is available. Shelf and dealer limits still follow existing upgrades.

Central Market pickup uses the same container/backpack transfer UI. Select paid seeds, fertilizer or equipment and a quantity, then Take. Anything that cannot fit stays at the shop without another charge. Direct fertilizer purchases add a whole pack to the backpack only if it fits. New equipment orders must be collected before computer installation. Previously paid deliveries retain ownership and migrate as carried items. The computer has no deposit-supplies action; store supplies at the physical grow shelf.

## Save isolation

A signed-in preview copies the cloud career on first launch and then saves locally. Later launches resume that preview copy. Desktop and browser previews have separate device-local copies: test progress does not sync between platforms, upload to the live career, or report to the leaderboard. Guest previews start separately. Ordinary releases still share the existing live career.

Desktop uses the AFewBuds-Inventory-Preview user directory. Browser uses an account-specific afb_inventory_preview_v1 cache, a separate preview session key, and a distinct runtime save filename. Both account adapters reject live career-write and leaderboard-report endpoints. Returning to the ordinary game resumes the untouched live career.

## Compatibility and scope

Existing production inventory remains authoritative for planting, workers, packing and sales. Container transfers debit and credit together, verify proximity/capacity, and reject stale double submissions. Property extras are saved separately; relocation merges destination stock without losing quantities. Releasing a property is blocked while its containers hold items. Paid packed equipment stays owned and is visible in the backpack; carried paid deliveries still install through the property computer. This preview does not add the future interactive furniture placement editor or new Chapter 5 missions.

## Release checks

Run the inventory integration test, existing gameplay suites, and browser save-isolation tests before publishing. Preview deployment stages main unchanged at the root and mobile-3d-movement compatibility URL, then adds inventory-preview. Both source branches remain experiments until reviewed. A later ordinary main deployment can remove the temporary preview URL; rerun this branch workflow to restore it.
