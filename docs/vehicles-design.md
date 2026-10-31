# Carts, rails and drones (design, before building)

Goal (your words): drill rigs run out of depth, so make machines that can go an unlimited distance and come back, with
batteries, minecarts carrying machines, rail layers and rail breakers (or a grabber arm moving rails from behind to
in front), mining straight into storage, drones that carry one thing and get weighed down, all controlled through
batteries and wireless. Every piece below has to earn its place in a factory.

## 1. Battery cells (the fuel for anything that moves)

* **Battery Cell**: a physical item (like a plank). Made in the **Assembler** from 1 copper bar + 1 iron bar. Starts empty.
* **Charger**: a machine with a slot on top. Drop a cell in and power it: the cell charges (its stripe fills green,
  no text). Charging uses power from your normal network (windmill, generator, battery), so power plants matter more.
* Anything that moves has a **battery slot**: drop a charged cell in by hand (or with a grabber arm). It drains as the
  machine works; an empty cell can be swapped and recharged.
* *Why it's fun:* a logistics loop of its own - charged cells out, empty cells back, chargers powered by your plant.

## 2. Rails

* **Rail**: a physical item, made in the Assembler (1 iron bar -> 2 rails). Drop it on the ground and press E (or let a
  machine place it) and it *lays*: snaps to the 1 m grid in line with the track it touches. Laid rails can be picked
  up again (E) - they turn back into the item.
* Curves and switches: a **Curved Rail** item, and a **Rail Switch** build whose direction flips when powered (logic!).
* *Why:* rails are how far-away mining reaches home.

## 3. Minecarts (moving platforms that carry machines)

* **Minecart**: built with the hammer at a chosen size (1x1, 1x2, 2x2, 2x3, 2x4 deck squares). Bigger carts carry more
  machines but use battery faster.
* It sits on rails and has a **battery slot**. While it has charge and its **Go** input is powered, it rolls forward
  along the track; power its **Reverse** input and it rolls back. At the end of the track it stops.
* **Machines can be placed on the deck** (the hammer snaps them to deck squares). Everything on one cart shares the
  cart's battery like one little circuit - no wires needed between them. Deck-ready machines: drill rig, storage
  crate, grabber arm, rail layer, rail lifter, wireless receiver/transmitter, logic blocks, lamp, item sensor.
* *Why:* a cart is a factory you can send somewhere.

## 4. Rail Layer and Rail Lifter (cart modules)

* **Rail Layer**: on the front of a cart. When the cart reaches the end of the track it takes a rail out of the cart's
  crate and lays it ahead, so the cart keeps going as long as it has rails.
* **Rail Lifter**: on the back. It picks up the rail behind the cart and puts it in the crate.
* Together (or a **grabber arm** set to move rails from behind to in front, as you suggested) a cart "walks" forever
  with a fixed handful of rails - no endless rail supply needed.
* *Why:* unlimited distance, but you have to design the cart right.

## 5. The unlimited mining run (how it all fits)

1. A cart with: battery slot, drill rig, crate, rail layer + rail lifter, wireless receiver, and a few logic blocks.
2. It stops, the drill rig drills down to its limit, the chunks fall into the crate.
3. When the rig is drilled out, its "done" output (new: drill rigs give power out while drilled out) tells the cart to
   step forward one square (rail layer lays, rail lifter lifts), and the rig starts again on fresh ground.
4. When the crate is full (new: crates give power out when full), the cart **reverses** all the way home on its own
   rails... except the lifter has taken them up. So the "walking" cart sends its load home a different way:
   a **drone** (below), or it leaves the rails laid (a permanent line home) and only lays new ones at the front.
5. At home, a grabber arm empties the cart's crate onto belts into your smelter and assembler.
6. Wireless lets you call it home (or send it out) from your base.

## 6. Drones

* **Drone**: a small flying platform in three sizes. It can carry exactly **one thing** on its pad: a small drone
  lifts a chunk of ore or a bark sheet, a medium one a plank or a bar, a large one a short log or a crate-full basket.
  Too heavy and it can't take off (it bobs and sinks, a clear visual).
* It has a **battery slot** and flies at a fixed height above the ground.
* **Steering by power, the tricky part:** a drone can't have wires, so it has **four built-in receivers, one per
  direction**, each set to a wireless channel (E cycles each one). While a channel is on, the drone flies that way.
  Two at once (north + east) flies diagonally.
* **Grab and drop**: a fifth channel "pad" makes it pick up whatever is below it (on) or drop it (off).
* Automate it with **timers and delays** at base on transmitters: e.g. "fly north 8 s, drop, fly south 8 s, pick up",
  a repeating shuttle between a mining cart and your smelter.
* *Why:* drones jump over things belts and rails can't (rivers, cliffs, your own factory), but they're slow and carry
  one thing at a time, so they're a puzzle, not a replacement for belts.

## 7. Small supporting builds

* **Rail Buffer** (stops a cart at a station), **Station Sensor** (gives power out while a cart is parked on it),
  **Cart Unloader** (tips the cart's crate onto a belt), **Drone Pad** (a landing square with a built-in charger).
* Drill rig and crate get **outputs**: rig "drilled out", crate "full" / "empty", so carts and drones can react.

## Build order (if you agree)

1. Battery cells + charger + battery slots.
2. Rails (straight), minecarts with sizes, deck machines sharing power, Go/Reverse.
3. Rail layer and lifter; drill rig and crate outputs. -> the unlimited mining cart works.
4. Drones with direction channels and the pad channel.
5. Curves, switches, buffers, station sensor, unloader, drone pad.
