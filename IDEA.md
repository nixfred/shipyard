# Surprise plugin: pick

## PICK: Shipyard (`nixfred.shipyard`)
A bar counter of what got SHIPPED today across every git repo on gus
(~/Projects, ~/.claude, ~/.config/omarchy): commits, repos touched, lines +/-,
and a day streak. Click for a one-screen cockpit: 16-week heatmap, hour-of-day
histogram, top repos, and today's commit feed (scrolls in place, click copies SHA).

Why: Fred + a dozen Larry sessions commit into ~196 repos a day and nothing on the
bar shows the output. Burnbar shows cost (input); Shipyard shows product (output).
Local-only, read-only git, zero secrets, zero network. Daily-useful and a little
bit of a dopamine hit.

## Runner-ups
1. MSI Fan/Thermal cockpit (msi-ec cpu/gpu fan + shift modes). Rejected: writes to
   shift_mode/fan_mode are at unverified EC addresses on this board (see memory
   gus-charge-limit-msi-ec-firmware-override). Read-only half overlaps Pulse.
2. Session Radar: every live Claude session on gus with cwd/age, click to focus.
   Rejected: overlaps herdr attention-spaces plugin.
