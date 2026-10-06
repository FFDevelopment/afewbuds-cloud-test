# AFewBuds — Chapter 4: Outgrowing the Apartment

Status: **Cloud-test design blueprint**
Target: **AFewBuds beta / afewbuds-cloud-test**
Production repo remains unchanged until the feature set is tested.

---

## 1. Chapter identity

**Chapter 4 — Outgrowing the Apartment**

Chapter 4 is the point where AFewBuds stops feeling like a small apartment hustle and starts becoming a real operation.

The chapter begins immediately after Chapter 3 is completed. The player's apartment operation is successful, but space, utilities, storage, production volume, staff, dealers, and heat are all beginning to outgrow the starter location.

The Chapter 4 payoff is not another apartment upgrade. The finale is the player's first property decision:

- **Rent**
- **Lease to Own**
- **Purchase**

After signing an agreement and confirming relocation, the player can move the active AFewBuds operation into the first house.

Chapter 5 begins after the move.

---

## 2. Chapter 4 story arc

### Beat 1 — No More Room

The player has proven they can run the apartment operation.

The story acknowledges that the apartment is now becoming a bottleneck:

- grow space is capped
- production is becoming higher volume
- storage is filling faster
- dealers need dedicated inventory
- workers are taking over more tasks
- utilities are becoming a real operating cost
- the business is drawing more attention

**Story message:**
> AFewBuds is working. The apartment isn't. If the operation keeps growing, something has to change.

Chapter 4 starts here.

### Beat 2 — Run It Like a Business

The player must demonstrate that they can operate at a larger scale before being offered a property.

The chapter focuses on:

- production capacity
- grow capacity
- dealer network
- storage
- staffing
- utilities
- revenue
- genetics / product variety

### Beat 3 — The Neighborhood Opens

The starter apartment front door becomes a real exit into a small exterior neighborhood hub.

The first exterior is intentionally a **dense neighborhood block**, not a giant open world.

The player can:

- leave the starter apartment
- walk/navigate around the block
- see the apartment building from outside
- pass a corner store / neighborhood storefront
- see background buildings and streets
- see the future house before it is available
- later walk to the house and inspect it

The exterior should make the world feel larger without requiring a full city simulation.

### Beat 4 — Expansion Opportunity

Near the end of Chapter 4, the house becomes available.

The player receives a property opportunity and can physically go to the house.

Before signing anything they may:

- view the exterior
- inspect the property details
- preview/tour the interior
- compare Rent / Lease-to-Own / Purchase
- leave without committing

### Beat 5 — Time to Move

Signing a property agreement starts the relocation flow.

The player reviews:

- portable equipment
- inventory
- dealer inventory
- seeds/fertilizer
- staff/dealers
- permanent apartment fixtures
- relocation cost/credits

The player confirms **MOVE OPERATION**.

After relocation is complete:

**CHAPTER 4 COMPLETE**

Chapter 5 begins from the new house.

---

## 3. Chapter 4 milestone structure

Chapter 4 should use several grouped milestones instead of dozens of unrelated requirements.

Values below are initial cloud-test balance targets and can be tuned after playtesting.

### Stage A — Production Ready

Goal: prove the apartment production chain is mature.

Requirements:

- Bagging Bench III installed
- 3 grow tents installed
- Storage level at least AFB Storage Vault tier
- 250g lifetime product moved into storage

Reward:

- XP / REP
- Chapter 4 story progression
- unlock next milestone group

### Stage B — Distribution Network

Goal: prove the player can move product without doing every sale personally.

Requirements:

- Dealer Storage at least Level III
- 15 total dealer sales
- at least 2 active staff/dealer roles combined
- at least 10 known customers

Reward:

- XP / REP
- new property-related story text
- unlock next milestone group

### Stage C — Run the Overhead

Goal: introduce utilities as a real business cost.

Requirements:

- pay at least 3 power bills
- pay at least 3 water bills
- no outstanding utility balance when milestone is completed

Reward:

- XP / REP
- utility-management advancement
- unlock next milestone group

### Stage D — Serious Operation

Goal: prove the operation is financially ready to expand.

Initial balance targets:

- Grower Level 10+
- Reputation 150+
- Lifetime revenue $15,000+
- at least 3 hybrid batches created
- at least 30 total dealer sales
- at least 75 production-worker tasks

Reward:

- XP / REP
- property opportunity becomes available
- house changes from unavailable/private to inspectable/listed

### Stage E — Expansion Opportunity

Goal: inspect the first property.

Requirements:

- leave the apartment and enter the neighborhood
- walk/navigate to the house
- inspect the house exterior
- preview the interior
- open the property terms screen

Reward:

- unlock agreement selection
- Rent / Lease-to-Own / Purchase options become actionable

### Stage F — Choose Your Next Base

Final Chapter 4 objective:

- sign one valid property agreement
- confirm relocation of the AFewBuds operation

Valid agreements:

- Rent
- Lease to Own
- Purchase

Completion:

- Chapter 4 completion event
- relocation completed
- Chapter 5 unlocked
- house-only upgrade catalog enabled

---

## 4. Utilities foundation

Water and electricity are core operation expenses and should exist before the house.

### Electricity

Existing power system remains the foundation.

Electric usage should continue to reflect:

- home lighting
- grow-room lighting
- grow lights
- ventilation
- future powered equipment

### Water

Water is not an inventory item. The player is using the property's plumbing/sink supply.

Every real watering route must report water usage through one shared utility function.

Water usage sources:

- manual watering
- production-worker watering while playing
- production-worker watering while paused/away
- Auto Water equipment
- future irrigation equipment

Water billing state:

- current-day water usage/cost
- last water bill
- outstanding water balance
- lifetime water cost
- water bills paid advancement metric

Water charges are posted at daily closeout and appear under:

**Phone → Business → Bills**

Bills screen should show Power and Water independently plus a combined utility balance.

House properties may have different utility rate multipliers and efficiency upgrades.

---

## 5. Exterior neighborhood hub

The first exterior should match the neighborhood concept:

- starter apartment building
- nearby low-rise buildings
- sidewalk/street
- corner storefront
- alleys / fences / dumpsters / utility areas
- background skyline
- first expansion house on the same local block

### Scope

This is a **neighborhood hub**, not a full open-world city.

The playable boundary should be deliberately contained with natural barriers:

- fences
- buildings
- blocked streets
- construction
- parked vehicles
- landscaping

Background buildings outside the playable area are visual scenery.

### Entry / exit

Starter Apartment front door:

- interact
- door opens
- transition to exterior neighborhood

Apartment entrance outside:

- interact
- return inside

House entrance:

- before listing: unavailable/private
- after property opportunity: inspect
- after agreement: enter owned/rented house

### Controls

The exterior must remain usable on both desktop and phone.

Initial implementation should use the current AFewBuds navigation interaction style and a small number of clear walk/navigation nodes or hotspots.

A fully continuous free-walk controller is optional future work and must not block the property system.

---

## 6. First expansion house

Working type:

**Residential Operation Property**

The house concept includes:

- living room
- kitchen / dining
- bedroom
- bathroom
- dedicated grow room
- dedicated production/storage room
- exterior/front yard
- hidden-storage expansion location

The house is intentionally a bridge between the starter apartment and future warehouse/commercial properties.

---

## 7. Agreement options

Prices are cloud-test starting values, not final economy balance.

### Rent

Lowest entry cost.

Initial test terms:

- move-in/deposit: **$1,800**
- recurring rent: **$600 every 7 game days**
- no ownership equity
- can terminate the agreement
- some structural upgrades restricted
- portable equipment and normal business upgrades allowed

### Lease to Own

Middle path.

Initial test terms:

- down payment: **$4,500**
- recurring payment: **$1,000 every 7 game days**
- target ownership total: **$18,500**
- payments build ownership equity
- structural upgrade access broader than rental
- property becomes owned once lease balance reaches zero

Property screen must visibly show:

**$X / $18,500 PAID TOWARD OWNERSHIP**

### Purchase

Highest initial cost, maximum freedom.

Initial test price:

- **$17,500 outright**

Benefits:

- no rent
- full structural upgrades
- permanent ownership
- full placement/edit permissions
- property remains in career portfolio

### Missed payments

Do not instantly delete equipment, crops, or inventory.

Use:

1. due notice
2. grace period
3. overdue notice
4. restricted property services if still unpaid
5. eventual forced move-out only after repeated failure

Lease-to-own equity must never silently disappear.

---

## 8. Relocation rules

The move must preserve the player's investment.

### Portable business assets

Transfer with the operation:

- grow tents
- Bagging Bench tier
- Dealer Storage equipment
- Grow Supply Shelf
- portable automation equipment
- portable storage equipment
- seeds
- fertilizer
- trimmed inventory
- bagged inventory
- dealer inventory
- genetics unlocks
- staff/dealers

### Property-built fixtures

Do not pretend permanent construction can be carried to another building.

Examples:

- apartment ventilation installation
- apartment hidden wall construction
- built-in room modifications

Rules:

- permanent fixtures stay attached to their property
- if the apartment is surrendered, eligible permanent upgrades may generate relocation/salvage credit
- property ownership/unlock history is retained
- new property versions can be unlocked at reduced cost where appropriate

### Multiple properties

The architecture should support a future property portfolio.

Each property should eventually track:

- property ID
- agreement type
- ownership/equity
- utilities
- installed fixtures
- portable equipment assigned to the property
- inventory
- placement layout
- active/inactive operation status

The first implementation may transfer the active operation as one unit, but the save format should not prevent multi-property play later.

---

## 9. House-only upgrades

Moving to the house unlocks a new upgrade catalog.

### Grow capacity

Apartment cap remains 3 grow tents.

House progression:

- Grow Tent Slot 4
- Grow Tent Slot 5
- Grow Tent Slot 6

Future properties may exceed this.

### Ventilation

House-only tiers:

- Ventilation II — higher airflow / better multi-tent support
- Ventilation III — climate-control system
- future efficiency upgrades can reduce power overhead

### Irrigation / water efficiency

House-only:

- Irrigation Manifold I
- Irrigation Manifold II
- Automated Irrigation III

Benefits may include:

- lower water usage per care event
- less wasted water
- automated watering support
- expanded plant coverage

### Power efficiency

Future house upgrades:

- efficient grow lighting
- upgraded electrical panel
- high-efficiency ventilation
- power-use reductions for larger operations

### Dealer Storage

Apartment Level IV remains the apartment maximum.

House can unlock:

- Dealer Storage V
- Dealer Storage VI

Exact capacities to be balanced during testing.

### Production

House can unlock:

- new production workstation tier after Bench III
- larger processing capacity
- future specialized trimming/sealing equipment

### Main storage

House storage should exceed the apartment's practical ceiling and integrate with the hidden room system.

---

## 10. Hidden storage room

The house introduces a real **Hidden Storage Room**, not just another stash object.

The hidden room is a structural property upgrade.

### Hidden Room I

- concealed entry
- small secure room
- starter hidden storage capacity
- limited placement area

### Hidden Room II

- room expands
- more storage placement space
- larger capacity

### Hidden Room III

- second expansion section
- improved concealment
- additional shelving/storage sockets

### Hidden Room IV

- maximum residential hidden-room footprint
- highest house storage capacity
- premium security/concealment bonuses

The room's **physical usable area** grows with tiers, not only a numeric capacity value.

The placement boundary updates when the room expands.

---

## 11. Property setup / placement mode

Players should be able to rearrange the new house without clipping stations, furniture, walls, doors, or leaving the property.

This is a core house feature.

### Fixed objects

Never freely movable:

- exterior walls
- interior structural walls
- doors / door frames
- windows
- bathroom plumbing
- kitchen plumbing / built-in counters
- electrical panels
- hidden-room structural entrance

### Movable objects

System should support movable categories such as:

- grow tents
- grow supply shelving
- storage shelving
- Dealer Storage
- production bench
- work tables
- chairs/stools
- couch
- coffee table
- floor lamps
- selected bedroom furniture
- decorative plants/decor later

### Placement zones

Each property contains explicit X/Z placement polygons or rectangles.

Example zones:

- Grow Room
- Production Room
- Storage / Hidden Room
- Living Room
- Bedroom

Each item has allowed zone tags.

Examples:

- grow tents → Grow Room only
- production bench → Production Room only
- dealer storage → Production or Storage zones
- couch → Living Room
- bed → Bedroom
- hidden shelving → Hidden Room only

### Grid and rotation

Initial target:

- snap step: **0.25 world units**
- rotation: **90° increments**

Later we can allow finer rotation for decorative items.

### Collision validation

Every movable item has a placement footprint.

A placement is valid only when:

- every footprint corner remains inside an allowed zone
- footprint remains inside the property boundary
- it does not overlap another placed object's footprint
- it does not overlap fixed furniture/collision zones
- it does not block a door swing / doorway clearance
- it does not block reserved walking paths
- required interaction clearance remains reachable

Preview state:

- valid = green
- invalid = red
- reason shown to player

Examples:

- OUTSIDE ROOM
- BLOCKING DOOR
- OVERLAPS BENCH
- TOO CLOSE TO WALL
- WRONG ROOM
- BLOCKS WALK PATH

### Setup controls

Property Setup Mode should include:

- Select item
- Move
- Rotate
- Confirm
- Cancel
- Undo last move
- Reset room to recommended layout

No change is committed until placement is valid and confirmed.

### Saving

Save per movable object:

- property ID
- object/equipment ID
- position X/Z
- rotation
- room/zone ID

A bad or outdated saved placement should fall back to the property's safe default layout instead of spawning clipped.

---

## 12. House upgrade restrictions by agreement

### Rental

Allowed:

- portable tents
- portable benches
- portable shelving
- normal dealer storage
- movable furniture

Restricted or landlord-approved:

- hidden room structural expansion
- major electrical modifications
- major permanent wall work

### Lease to Own

More structural access becomes available as equity milestones are reached.

Example:

- 25% equity → Ventilation II
- 50% equity → Hidden Room I
- 75% equity → larger structural upgrades
- 100% → full owner permissions

### Purchase

All property upgrades available once progression/level requirements are satisfied.

---

## 13. Property inspection flow

At the house exterior:

**PROPERTY AVAILABLE**

Options:

- VIEW DETAILS
- TOUR HOUSE
- AGREEMENT OPTIONS
- LEAVE

During preview/tour:

- production zones highlighted when requested
- grow-room capacity preview
- storage capacity preview
- locked house-only upgrades shown
- current apartment equipment compatibility shown

Agreement screen compares all three routes side-by-side.

Before signing:

> This agreement does not move anything yet. You will review your relocation before confirming.

After signing:

**PREPARE RELOCATION**

---

## 14. Chapter 4 completion event

Chapter 4 does not complete merely because the listing appears.

It completes when:

1. player signs Rent / Lease-to-Own / Purchase
2. relocation summary is accepted
3. active operation is moved to the house
4. first entry into the new operation succeeds

Then show:

**CHAPTER 4 COMPLETE**
**OUTGROWING THE APARTMENT**

Reward should emphasize progression rather than a large cash payout:

- major XP
- major REP
- Chapter 5 unlocked
- House Upgrade Catalog unlocked
- Property Setup Mode unlocked
- first house-specific upgrade discount/credit

---

## 15. Chapter 5 handoff

Working direction:

**Chapter 5 — Building an Operation**

The player now has:

- larger grow capacity
- new property overhead
- more dealer/staff potential
- hidden storage room progression
- property layout control
- new upgrade tiers

Chapter 5 can begin expanding into:

- wholesale clients
- larger deliveries
- more employee roles
- larger dealer network
- bulk supply purchasing
- additional properties
- warehouse/commercial progression

---

## 16. Implementation order

### Cloud-test Phase 1 — Chapter 4 foundation

- persistent Chapter 3 completion state
- Chapter 4 state
- Chapter 4 milestone groups
- story messages / Task display
- water-billing foundation
- utility advancement metrics

### Cloud-test Phase 2 — Neighborhood exterior

- exterior neighborhood scene
- apartment entrance/exit
- contained playable boundary
- future house exterior
- house unavailable state
- save/return flow

### Cloud-test Phase 3 — Property opportunity

- house becomes available at late Chapter 4
- property inspection
- house interior preview
- agreement comparison UI
- Rent / Lease / Buy data model

### Cloud-test Phase 4 — Relocation

- relocation summary
- equipment/inventory transfer
- property save state
- active property
- Chapter 4 completion event

### Cloud-test Phase 5 — House operation

- house grow/production/storage zones
- house-only upgrades
- new utility rates
- hidden storage room
- additional tents / ventilation / storage

### Cloud-test Phase 6 — Property Setup Mode

- property bounds
- room zones
- movable object registry
- footprints
- collision/reserved-path validation
- grid snapping
- 90° rotation
- confirm/cancel/undo/reset
- save layouts

---

## 17. Non-negotiable design rules

1. Existing career progress must not be wiped when Chapter 4 is added.
2. Moving properties must not erase purchased equipment or inventory.
3. Missed property payments must not instantly destroy a career.
4. Equipment may never be placed outside valid property/room boundaries.
5. Equipment may never clip through walls, fixed furniture, other equipment, or required door paths.
6. Mobile/browser usability must remain a first-class requirement.
7. The exterior hub must stay performant; background city scenery does not need to be physically simulated.
8. The first house should feel substantially more capable than the apartment.
9. New properties should use the same generic property/agreement/placement framework.
10. Production main remains unchanged until each cloud-test phase is validated.

---

## 18. Current decision

The intended Chapter 4 progression is:

**Chapter 3 Complete**
→ **Chapter 4: Outgrowing the Apartment**
→ mature the apartment operation
→ learn/manage water + electric overhead
→ exterior neighborhood becomes part of the world
→ property opportunity appears
→ physically inspect the house
→ choose Rent / Lease-to-Own / Purchase
→ relocate operation
→ **Chapter 4 Complete**
→ **Chapter 5 starts in the new house**

This document is the implementation blueprint unless changed during cloud-test playtesting.
