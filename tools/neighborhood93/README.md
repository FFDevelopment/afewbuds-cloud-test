# .93 apartment physical lighting taps

Restores nearby single-tap main-room switch and floor lamp during free walking. The walking input router previously checked double-tap stations and missed ROOM_SWITCH_TARGETS. Lights now use the original projected physical targets and original toggle/save/advancement handlers, before the couch's broad double-tap area. Requires apartment interior, no modal and range within 2.7 m. Drags remain look gestures; stations, couch and computers retain double tapping.

Native checks cover actual projected switch/lamp tap on/off, drag rejection, phone blocking, distance limits and couch interception. Actual JS loader verifies byte-identical pack reconstruction.
