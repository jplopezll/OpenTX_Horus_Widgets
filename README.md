# OpenTX Horus Widgets

This will be my a place for new lua widgets to be developed for Taranis radios: 10, 10S, 12S...

A short description of each widget will be placed here.

You can see now a first proof of concept.

Using global variables, I can pass data from one widget to another. This means we only need one of the widgets to be checking the passthrough queue. From this point of view I can:

- Use the messages widget to check the queue and publish data for the others. This means that without this widget on the layout the other widgets will not update.

- Rethink the layout with optional widgets

With this approach, the list of widgets could be:

- Messages widget. Compulsory as without this one there is no data. Maybe I would also put here flight modes.

- Artificial horizon. With speed and altitude in different shapes depending on the size of the container.

- Gauges or text ith key data. Maybe selectable via options menu of the widgets.

- Flight controller flags: armed, landed, failsafe triggers, etc.

- GPS data: fix type, number of satellites, horizontal and vertical distances from home, etc.


# PssThrgMsg

This is the only widget that MUST be present, as this is the one getting data from the Passthrough queue.

It will also show you messages on the display.

Things to do:

- Implement the scrolling function.

- Probably also show flight mode.


# ArtHor

First attempt to make an artificial horizon to be presented as a widget on the screen. The current version already works and adapts to the size of the zone assigned. Colors are editable.

Things to do:

- Improve options management.

- Avoid colors to affect the rest of the template.
