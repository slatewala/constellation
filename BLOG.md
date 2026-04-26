---
title: "Constellation - The Spatial Memory Game That Steals Your Brainpower"
date: 2026-04-26
categories:
  - Games
  - Mobile
tags:
  - flutter
  - memory
  - puzzle
  - hyper-casual
  - android
excerpt: "A pattern of stars connects briefly. The lines disappear. Now redraw it from memory. How long can your spatial recall hold?"
featured_image: /assets/games/constellation-feature.png
---

## Stars Have A Memory Of Their Own

**Constellation** is what Echo Tap would be if it traded its rhythm for geography. Instead of remembering an order of pads in a row, you have to remember an order of points scattered across a 2D field. Your eyes have to act as the scratchpad, and 2D is harder than 1D.

Each round adds another star. The lines fade and the dots stay. Your job is to retrace the route in the exact order shown.

## Why 2D Sequences Hurt More

Linear sequences let you chunk - first three, last two. 2D sequences resist chunking because the path is shaped, not numbered. Your brain has to encode position AND order at the same time. That dual encoding is much more fragile than either alone.

The good news is that humans get noticeably better at this with practice. A few minutes of Constellation visibly improves your in-game performance, which is rare for hyper-casual games. The progress feels personal.

## Built In Flutter

The whole render layer is one `CustomPainter` drawing dots, glow halos, and connecting lines. Hit detection uses the simplest distance check - within 36 pixels of a star's center counts as a tap. No widget tree per star, no animation controllers, no overdraw.

A small dust-star background gives the field depth without any image asset. Just a seeded `Random` plus a loop in the paint method.

## Try It

Source, custom icon, sound effect, release APK on GitHub. Sideload, find your wall, then come back tomorrow and beat it.
